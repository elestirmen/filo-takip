// Firebase yerine geçen, bellek içi sahte arka uç.
//
// lib/data/fake_backend_store.dart dosyasının panel karşılığıdır: aynı altı
// araç, aynı üç grup, aynı hareket aralığı. Buna ek olarak panelin ihtiyaç
// duyduğu hesaplar da vardır, çünkü "yetkiye göre görünüm" ancak birden fazla
// rol varken denenebilir.
//
// Veriler diske yazılmaz: sayfa yenilenince her şey başlangıç durumuna döner.

import { BackendError } from './backend-error.js';
import { EventChannel, LatestValue } from './emitter.js';
import { Geofence, GroupConfig, LocationSample, Vehicle, Viewer, WebUser } from './models.js';
import { compareText } from './admin-rules.js';
import { mapDefaults } from './config.js';
import { Strings } from './strings.js';

// Araç başına saklanan en fazla geçmiş kaydı ve okuma sınırı; gerçek
// FleetRepository sabitleriyle aynı.
const HISTORY_MAX_RECORDS = 500;
const HISTORY_READ_LIMIT = 500;
const HISTORY_INTERVAL_MS = 45 * 1000;

// Sahte araçların hareket ettirilme sıklığı; gerçek konum aralığıyla aynı.
const TICK_MS = 5000;

const CENTER_LAT = mapDefaults.centerLat;
const CENTER_LNG = mapDefaults.centerLng;

// Açık oturumun kimliği burada saklanır. Gerçek arka uçta bu işi Firebase Auth
// kendisi yapar (oturum varsayılan olarak tarayıcıda kalıcıdır); demo da aynı
// davransın diye, yoksa her sayfa yenilemesi kullanıcıyı giriş ekranına atar.
// Yalnızca uid tutulur, şifre değil.
const SESSION_KEY = 'filo-takip-demo-oturum';

function readStoredUid() {
  try {
    return window.localStorage.getItem(SESSION_KEY);
  } catch {
    // Gizli sekmede ya da depolama kapalıyken erişim hata atabilir.
    return null;
  }
}

function writeStoredUid(uid) {
  try {
    if (uid === null) window.localStorage.removeItem(SESSION_KEY);
    else window.localStorage.setItem(SESSION_KEY, uid);
  } catch {
    // Oturum yalnızca bu sekmede yaşar; panel yine çalışır.
  }
}

// Tekrarlanabilir demo için sabit tohumlu üreteç (Dart tarafındaki Random(42)
// karşılığı). Math.random() kullanılsaydı her yenilemede başka bir filo çıkardı.
function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

export class DemoBackend {
  constructor() {
    this.isDemo = true;

    this._vehicles = new Map();
    this._groups = new Map();
    this._history = new Map();
    this._motions = new Map();
    this._users = new Map();
    this._geofences = new Map();
    this._admins = new Set();
    this._passwords = new Map();

    this._random = seededRandom(42);
    this._pushCounter = 0;
    this._session = null;

    this.vehicles = new LatestValue([]);
    this.groups = new LatestValue([]);
    this.users = new LatestValue([]);
    this.geofences = new LatestValue([]);
    this.adminUids = new LatestValue(new Set());
    this.viewer = new LatestValue(null);
    this.errors = new EventChannel();

    this._seedGroups();
    this._seedVehicles();
    this._seedUsers();
    this._seedGeofences();
    this._restoreSession();
    this._publish();

    this._timer = window.setInterval(() => this._moveVehicles(), TICK_MS);
  }

  // ---------------------------------------------------------------- Oturum

  async signIn(email, password) {
    await this._delay();
    const normalized = email.trim().toLowerCase();
    const uid = this._uidForEmail(normalized);
    if (uid === null || this._passwords.get(uid) !== password) {
      throw new BackendError(Strings.errorInvalidCredentials);
    }
    this._session = { uid, email: normalized };
    writeStoredUid(uid);
    this._publishViewer();
  }

  async register({ email, password, displayName }) {
    await this._delay();
    const normalized = email.trim().toLowerCase();
    if (this._uidForEmail(normalized) !== null) {
      throw new BackendError(Strings.errorEmailInUse);
    }
    if (password.length < 6) throw new BackendError(Strings.errorWeakPassword);

    const uid = `demo-${this._users.size + 1}-${Date.now().toString(36)}`;
    this._passwords.set(uid, password);
    // Yeni hesap onaysız doğar; yönetici onaylayana kadar hiçbir araç görmez.
    this._users.set(
      uid,
      new WebUser({
        uid,
        email: normalized,
        displayName,
        groupId: null,
        approved: false,
        createdAt: this.nowMs(),
      }),
    );
    this._session = { uid, email: normalized };
    writeStoredUid(uid);
    this._publish();
  }

  async signOut() {
    this._session = null;
    writeStoredUid(null);
    this._publishViewer();
  }

  // ---------------------------------------------------------------- Zaman

  // Demo kipinde sunucu ofseti yoktur; tarayıcı saati tek kaynaktır.
  nowMs() {
    return Date.now();
  }

  // ---------------------------------------------------------------- Yazma

  async setVehicleApproved(vehicleId, approved) {
    await this._delay();
    this._requireAdmin();
    const current = this._vehicles.get(vehicleId);
    if (current === undefined) throw new BackendError(Strings.errorSaveFailed);
    this._vehicles.set(vehicleId, current.copyWith({ approved }));
    this._publish();
  }

  async setVehicleGroup(vehicleId, groupId) {
    await this._delay();
    this._requireAdmin();
    const current = this._vehicles.get(vehicleId);
    if (current === undefined) throw new BackendError(Strings.errorSaveFailed);
    this._vehicles.set(
      vehicleId,
      current.copyWith({ groupId, clearGroupId: groupId === null }),
    );
    this._publish();
  }

  // Araç düğümü ve konum geçmişi birlikte gider.
  async deleteVehicle(vehicleId) {
    await this._delay();
    this._requireAdmin();
    this._vehicles.delete(vehicleId);
    this._history.delete(vehicleId);
    this._motions.delete(vehicleId);
    this._publish();
  }

  async saveGroupConfig(config) {
    await this._delay();
    this._requireAdmin();
    this._groups.set(config.groupId, config);
    this._publish();
  }

  // Grubu siler; bağlı araçların ve izleyicilerin atamasını, diğer grupların
  // görünür listelerini aynı anda temizler.
  async deleteGroup(groupId) {
    await this._delay();
    this._requireAdmin();
    this._groups.delete(groupId);

    for (const [id, vehicle] of [...this._vehicles]) {
      if (vehicle.groupId === groupId) {
        this._vehicles.set(id, vehicle.copyWith({ clearGroupId: true }));
      }
    }
    for (const [id, user] of [...this._users]) {
      if (user.groupId === groupId) {
        this._users.set(id, user.copyWith({ clearGroupId: true }));
      }
    }
    for (const [id, group] of [...this._groups]) {
      if (!group.visibleGroups.includes(groupId)) continue;
      this._groups.set(
        id,
        group.copyWith({
          visibleGroups: group.visibleGroups.filter((name) => name !== groupId),
        }),
      );
    }
    this._publish();
  }

  async saveGeofence(geofence) {
    await this._delay();
    this._requireAdmin();
    this._geofences.set(geofence.id, geofence);
    this._publish();
  }

  async deleteGeofence(id) {
    await this._delay();
    this._requireAdmin();
    this._geofences.delete(id);
    this._publish();
  }

  async setUserApproved(uid, approved) {
    await this._delay();
    this._requireAdmin();
    const current = this._users.get(uid);
    if (current === undefined) throw new BackendError(Strings.errorSaveFailed);
    this._users.set(uid, current.copyWith({ approved }));
    this._publish();
  }

  async setUserGroup(uid, groupId) {
    await this._delay();
    this._requireAdmin();
    const current = this._users.get(uid);
    if (current === undefined) throw new BackendError(Strings.errorSaveFailed);
    this._users.set(uid, current.copyWith({ groupId, clearGroupId: groupId === null }));
    this._publish();
  }

  async setUserAdmin(uid, isAdmin) {
    await this._delay();
    this._requireAdmin();
    // Yönetici kendi yetkisini bu yoldan düşüremez; gerçek arka uçta bunu
    // veritabanı kuralı da engeller.
    if (uid === this._session.uid && !isAdmin) {
      throw new BackendError(Strings.selfRoleLocked);
    }
    if (isAdmin) this._admins.add(uid);
    else this._admins.delete(uid);
    this._publish();
  }

  async deleteUser(uid) {
    await this._delay();
    this._requireAdmin();
    if (uid === this._session.uid) throw new BackendError(Strings.selfRoleLocked);
    this._users.delete(uid);
    this._admins.delete(uid);
    this._publish();
  }

  // ---------------------------------------------------------------- Okuma

  async loadHistory(vehicleId) {
    await this._delay();
    const samples = [...(this._history.get(vehicleId) ?? [])];
    samples.sort((a, b) => b.recordedAt - a.recordedAt);
    return samples.slice(0, HISTORY_READ_LIMIT);
  }

  dispose() {
    window.clearInterval(this._timer);
  }

  // -------------------------------------------------------------- İçeriler

  // Kayıtlı oturumu geri yükler. Demo verisi her yenilemede sıfırdan üretildiği
  // için, kaydedilen uid artık yoksa (örneğin kendi kaydettiği bir hesapsa)
  // oturum sessizce düşer.
  _restoreSession() {
    const uid = readStoredUid();
    if (uid === null) return;
    const user = this._users.get(uid);
    if (user === undefined) {
      writeStoredUid(null);
      return;
    }
    this._session = { uid, email: user.email };
  }

  _requireAdmin() {
    if (this._session === null || !this._admins.has(this._session.uid)) {
      throw new BackendError(Strings.errorPermissionDenied);
    }
  }

  // Gerçek arka uçtaki ağ gecikmesinin yerine küçük bir bekleme; düğmelerin
  // yüklenme durumu demo kipinde de görünür olsun diye.
  _delay() {
    return new Promise((resolve) => window.setTimeout(resolve, 120));
  }

  _uidForEmail(email) {
    for (const user of this._users.values()) {
      if (user.email === email) return user.uid;
    }
    return null;
  }

  _nextPushId() {
    this._pushCounter++;
    // Gerçek push anahtarları gibi sıralanabilir olsun diye sabit genişlik.
    return `demo-${this._pushCounter.toString().padStart(6, '0')}`;
  }

  _publish() {
    const vehicleList = [...this._vehicles.values()].sort((a, b) =>
      compareText(a.plate, b.plate),
    );
    const groupList = [...this._groups.values()].sort((a, b) =>
      compareText(a.groupId, b.groupId),
    );
    const userList = [...this._users.values()];
    const zoneList = [...this._geofences.values()].sort((a, b) => compareText(a.name, b.name));
    this.vehicles.add(vehicleList);
    this.groups.add(groupList);
    this.users.add(userList);
    this.geofences.add(zoneList);
    this.adminUids.add(new Set(this._admins));
    this._publishViewer();
  }

  // Yetki değişince açık olan sayfanın kendiliğinden güncellenmesi buna bağlı:
  // yönetici bir hesabı onayladığında o hesabın Viewer nesnesi yeniden yayılır.
  _publishViewer() {
    if (this._session === null) {
      this.viewer.add(null);
      return;
    }
    const { uid, email } = this._session;
    this.viewer.add(
      new Viewer({
        uid,
        email,
        isAdmin: this._admins.has(uid),
        webUser: this._users.get(uid) ?? null,
      }),
    );
  }

  _seedGroups() {
    this._groups.set(
      'Kaman',
      new GroupConfig({
        groupId: 'Kaman',
        visibleGroups: [],
        showSpeed: true,
        // Hız görünür, sürücü adı gizli: alan gizleme mantığını denemek için.
        showDriverName: false,
      }),
    );
    this._groups.set(
      'Merkez',
      new GroupConfig({
        groupId: 'Merkez',
        visibleGroups: ['Kaman'],
        showSpeed: true,
        showDriverName: true,
        // Merkez araçları 50 km/s üstünde uyarı üretir.
        speedLimitKmh: 50,
      }),
    );
    this._groups.set(
      'Mucur',
      new GroupConfig({
        groupId: 'Mucur',
        visibleGroups: ['Merkez', 'Kaman'],
        showSpeed: false,
        showDriverName: true,
      }),
    );
  }

  // Demo bölgeleri: biri araçların dolaştığı merkezde (giriş/çıkış uyarısı
  // kendiliğinden tetiklenir), biri kenarda.
  _seedGeofences() {
    this._geofences.set('merkez-depo', new Geofence({
      id: 'merkez-depo',
      name: 'Merkez Depo',
      lat: CENTER_LAT,
      lng: CENTER_LNG,
      radiusM: 2500,
      createdAt: this.nowMs() - 86400000,
    }));
    this._geofences.set('kuzey-saha', new Geofence({
      id: 'kuzey-saha',
      name: 'Kuzey Saha',
      lat: CENTER_LAT + 0.022,
      lng: CENTER_LNG + 0.02,
      radiusM: 1800,
      createdAt: this.nowMs() - 86400000,
    }));
  }

  _seedUsers() {
    // Yönetici: tüm araçları görür, her ayarı değiştirebilir.
    this._addUser({
      uid: 'sim-yonetici',
      email: 'yonetici@ornek.com',
      displayName: 'Demo Yönetici',
      groupId: null,
      approved: true,
      isAdmin: true,
    });
    // İzleyici: Merkez grubunda. Merkez, Kaman'ı da gördüğü için haritada iki
    // grubun araçları çıkar; Mucur ve grupsuz araçlar çıkmaz.
    this._addUser({
      uid: 'sim-izleyici',
      email: 'izleyici@ornek.com',
      displayName: 'Demo İzleyici',
      groupId: 'Merkez',
      approved: true,
      isAdmin: false,
    });
    // Onay bekleyen hesap: hiçbir araç görmez.
    this._addUser({
      uid: 'sim-bekleyen',
      email: 'bekleyen@ornek.com',
      displayName: 'Demo Bekleyen',
      groupId: null,
      approved: false,
      isAdmin: false,
    });
  }

  _addUser({ uid, email, displayName, groupId, approved, isAdmin }) {
    this._users.set(
      uid,
      new WebUser({
        uid,
        email,
        displayName,
        groupId,
        approved,
        createdAt: this.nowMs() - 86400000,
      }),
    );
    this._passwords.set(uid, '123456');
    if (isAdmin) this._admins.add(uid);
  }

  _seedVehicles() {
    // Uygulamadaki sahte filonun aynısı. "Bu Cihaz" aracı, uygulamada
    // sürücünün kendi aracıdır; panelde sıradan bir araç olarak görünür.
    this._addVehicle({
      id: 'sim-surucu',
      plate: '40 ABC 001',
      driverName: 'Mehmet Şahin',
      groupId: 'Merkez',
      approved: true,
      dLat: 0.004,
      dLng: -0.006,
      speedKmh: 38,
    });
    this._addVehicle({
      id: 'sim-2',
      plate: '40 DEF 202',
      driverName: 'Ahmet Yıldız',
      groupId: 'Merkez',
      approved: true,
      dLat: -0.01,
      dLng: 0.013,
      // Duruyor: kırmızı işaretçi.
      speedKmh: 0,
    });
    this._addVehicle({
      id: 'sim-3',
      plate: '40 GHI 303',
      driverName: 'Ayşe Demir',
      groupId: 'Kaman',
      approved: true,
      dLat: 0.021,
      dLng: 0.018,
      speedKmh: 64,
    });
    this._addVehicle({
      id: 'sim-4',
      plate: '40 JKL 404',
      driverName: 'Zeynep Arslan',
      groupId: 'Mucur',
      approved: true,
      dLat: -0.024,
      dLng: -0.019,
      speedKmh: 51,
      // Çevrimdışı: son güncelleme 22 dakika önce, gri işaretçi.
      ageMs: 22 * 60 * 1000,
    });
    this._addVehicle({
      id: 'sim-5',
      plate: '40 MNO 505',
      driverName: 'Hasan Çelik',
      groupId: null,
      approved: true,
      dLat: 0.013,
      dLng: -0.021,
      speedKmh: 27,
    });
    this._addVehicle({
      id: 'sim-6',
      plate: '40 PRS 606',
      driverName: 'Elif Korkmaz',
      groupId: null,
      // Onay bekliyor: turuncu işaretçi, listede en üstte.
      approved: false,
      dLat: -0.006,
      dLng: 0.009,
      speedKmh: 12,
    });
  }

  _addVehicle({ id, plate, driverName, groupId, approved, dLat, dLng, speedKmh, ageMs = 0 }) {
    const now = this.nowMs();
    const lat = CENTER_LAT + dLat;
    const lng = CENTER_LNG + dLng;
    this._vehicles.set(
      id,
      new Vehicle({
        id,
        plate,
        driverName,
        groupId,
        approved,
        lat,
        lng,
        speedKmh,
        updatedAt: now - ageMs,
      }),
    );
    this._motions.set(id, {
      heading: this._random() * 2 * Math.PI,
      speedKmh,
      // true ise araç hiç güncellenmez, çevrimdışı görünür.
      frozen: ageMs > 0,
    });

    this._history.set(id, this._seedHistory({ lat, lng, speedKmh, now, ageMs }));
  }

  // Aracın geçmiş rotasını şimdiden geriye doğru üretir.
  //
  // Önceki sürüm noktaları birbirine ~1 metre uzaklıkta koyuyordu; bu, gerçek
  // GPS titremesinin altında kaldığı için rapor "0 km yol, hep duruş"
  // çıkarıyordu. Artık adım uzunluğu gerçek hızdan hesaplanır (45 saniyede
  // 40 km/s ≈ 500 m) ve yön rastgele sapar, yani rota gerçek bir güzergâh
  // gibi görünür. Ortaya bir de duruş konur ki durak tespiti denenebilsin.
  _seedHistory({ lat, lng, speedKmh, now, ageMs }) {
    const count = 120;
    // Duran araç geçmişte de durur; yalnızca hareketli olanlara rota üretilir.
    const stopFrom = speedKmh > 0 ? 46 : -1;
    const stopTo = speedKmh > 0 ? 60 : -1;

    let heading = this._random() * 2 * Math.PI;
    let currentLat = lat;
    let currentLng = lng;
    const samples = [];

    // i = 1 en yeni kayıttan bir önceki; geriye doğru yürünür.
    for (let i = 1; i <= count; i++) {
      // Duran aracın geçmişi de durgundur; alt sınır yalnızca hareketli
      // araçlara uygulanır, yoksa hızı sıfır olan araç da yol yapmış görünür.
      const stopped = speedKmh === 0 || (i >= stopFrom && i <= stopTo);
      const stepSpeed = stopped ? 0 : Math.max(5, speedKmh + this._random() * 14 - 7);

      samples.push(
        new LocationSample({
          id: this._nextPushId(),
          lat: currentLat,
          lng: currentLng,
          speedKmh: stepSpeed,
          recordedAt: now - ageMs - (i - 1) * HISTORY_INTERVAL_MS,
        }),
      );

      if (stopped) continue;
      heading += (this._random() - 0.5) * 0.8;
      const metres = ((stepSpeed * 1000) / 3600) * (HISTORY_INTERVAL_MS / 1000);
      // Geriye doğru gidildiği için işaret ters.
      currentLat -= (metres * Math.cos(heading)) / 111320;
      currentLng -= (metres * Math.sin(heading)) / (111320 * Math.cos((currentLat * Math.PI) / 180));
      // Merkezden fazla uzaklaşırsa geri döndür; rota bölgede kalsın.
      if (Math.abs(currentLat - CENTER_LAT) > 0.06 || Math.abs(currentLng - CENTER_LNG) > 0.06) {
        heading += Math.PI;
      }
    }

    // En eski kayıt başta.
    samples.reverse();
    while (samples.length > HISTORY_MAX_RECORDS) samples.shift();
    return samples;
  }

  _moveVehicles() {
    let changed = false;
    for (const [id, motion] of this._motions) {
      // Çevrimdışı araç hiç güncellenmez; updatedAt eskidikçe gri kalır.
      if (motion.frozen) continue;

      const current = this._vehicles.get(id);
      if (current === undefined) continue;

      let lat = current.lat;
      let lng = current.lng;
      if (motion.speedKmh > 0) {
        motion.heading += (this._random() - 0.5) * 0.7;
        const metres = ((motion.speedKmh * 1000) / 3600) * (TICK_MS / 1000);
        lat += (metres * Math.cos(motion.heading)) / 111320;
        lng += (metres * Math.sin(motion.heading)) / (111320 * Math.cos((lat * Math.PI) / 180));
        // Merkezden fazla uzaklaşırsa geri döndür.
        if (Math.abs(lat - CENTER_LAT) > 0.05 || Math.abs(lng - CENTER_LNG) > 0.05) {
          motion.heading += Math.PI;
          lat = current.lat;
          lng = current.lng;
        }
      }

      this._vehicles.set(
        id,
        current.copyWith({ lat, lng, speedKmh: motion.speedKmh, updatedAt: this.nowMs() }),
      );
      changed = true;
    }
    if (changed) this._publish();
  }
}
