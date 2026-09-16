// Panelin saf mantığının birim testleri: görünürlük kuralları, durum
// eşikleri, sıralama ve demo arka ucun yazma yolları.
//
// Tarayıcı ya da Firebase gerektirmez:
//
//   cd panel && node --test
//
// Görünüm dosyaları (view-*.js, ui.js, map-view.js) DOM istediği için burada
// test edilmez; onlar tarayıcıda denenir.

import assert from 'node:assert/strict';
import test from 'node:test';

// DemoBackend zamanlayıcı için window'a bakar; Node'da karşılığını kuralım.
//
// Araçları hareket ettiren aralık unref edilir, yoksa test bitmez. Yazma
// çağrılarındaki kısa bekleme unref EDİLMEZ: beklenen bir söz olduğu için
// olay döngüsünü açık tutması gerekir.
//
// Açık oturum localStorage'da tutulduğu için onun da bellek içi bir karşılığı
// gerekiyor. Depolama freshBackend() içinde temizlenir; yoksa bir testte
// açılan oturum bir sonrakine sızar.
const storage = new Map();

globalThis.window = {
  setInterval: (fn, ms) => setInterval(fn, ms).unref(),
  clearInterval: (handle) => clearInterval(handle),
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  localStorage: {
    getItem: (key) => (storage.has(key) ? storage.get(key) : null),
    setItem: (key, value) => storage.set(key, String(value)),
    removeItem: (key) => storage.delete(key),
  },
};

const { DemoBackend } = await import('../js/backend-demo.js');
const { Role, Vehicle, Viewer, WebUser, GroupConfig } = await import('../js/models.js');
const { fieldVisibilityFor, visibleVehiclesFor, allowedGroupIdsFor } =
  await import('../js/visibility-rules.js');
const { vehicleStatusOf, VehicleStatus, fleetSummaryOf } =
  await import('../js/vehicle-status.js');
const { sortVehiclesForAdmin, isGroupNameAvailable, matchesVehicleSearch } =
  await import('../js/admin-rules.js');
const { normalizeGroupName, normalizeDriverName, isValidEmail, turkishUpperCase } =
  await import('../js/normalize.js');

function freshBackend() {
  // Kalıcı oturum testler arasında sızmasın.
  storage.clear();
  return new DemoBackend();
}

function viewerFor(backend, email) {
  const user = backend.users.value.find((item) => item.email === email);
  assert.ok(user, `${email} demo verisinde yok`);
  return new Viewer({
    uid: user.uid,
    email: user.email,
    isAdmin: backend.adminUids.value.has(user.uid),
    webUser: user,
  });
}

async function signedInAdmin(backend) {
  await backend.signIn('yonetici@ornek.com', '123456');
  return backend.viewer.value;
}

// ------------------------------------------------------------ Demo veri

test('demo arka uç uygulamadaki filoyla aynı tohumla açılır', () => {
  const backend = freshBackend();
  assert.equal(backend.vehicles.value.length, 6);
  assert.deepEqual(
    backend.groups.value.map((group) => group.groupId),
    ['Kaman', 'Merkez', 'Mucur'],
  );
  assert.equal(backend.users.value.length, 3);
  assert.equal(backend.adminUids.value.size, 1);
  backend.dispose();
});

test('araç durumları uygulamadaki eşiklerle aynı çıkar', () => {
  const backend = freshBackend();
  const now = backend.nowMs();
  const byPlate = (plate) => backend.vehicles.value.find((v) => v.plate === plate);

  assert.equal(vehicleStatusOf(byPlate('40 ABC 001'), now), VehicleStatus.moving);
  assert.equal(vehicleStatusOf(byPlate('40 DEF 202'), now), VehicleStatus.stopped);
  // 22 dakika önce güncellenmiş: 5 dakikalık eşiği aştığı için çevrimdışı.
  assert.equal(vehicleStatusOf(byPlate('40 JKL 404'), now), VehicleStatus.offline);
  // Onaysız araç hareket ediyor olsa bile turuncu kalır.
  assert.equal(vehicleStatusOf(byPlate('40 PRS 606'), now), VehicleStatus.pending);

  const summary = fleetSummaryOf(backend.vehicles.value, now);
  assert.equal(summary.total, 6);
  assert.equal(summary.pending, 1);
  assert.equal(summary.offline, 1);
  backend.dispose();
});

// ------------------------------------------------------ Görünürlük kuralı

test('yönetici tüm araçları görür', () => {
  const backend = freshBackend();
  const viewer = viewerFor(backend, 'yonetici@ornek.com');
  assert.equal(viewer.role, Role.admin);
  assert.equal(
    visibleVehiclesFor(backend.vehicles.value, backend.groups.value, viewer).length,
    6,
  );
  backend.dispose();
});

test('izleyici kendi grubunu ve grubunun görebildiği grupları görür', () => {
  const backend = freshBackend();
  const viewer = viewerFor(backend, 'izleyici@ornek.com');
  assert.equal(viewer.role, Role.viewer);
  assert.equal(viewer.groupId, 'Merkez');

  // Merkez -> kendisi + Kaman.
  assert.deepEqual(
    [...allowedGroupIdsFor('Merkez', backend.groups.value)].sort(),
    ['Kaman', 'Merkez'],
  );

  const visible = visibleVehiclesFor(backend.vehicles.value, backend.groups.value, viewer);
  assert.deepEqual(
    visible.map((vehicle) => vehicle.plate).sort(),
    ['40 ABC 001', '40 DEF 202', '40 GHI 303'],
  );
  // Mucur grubundaki, grupsuz olan ve onay bekleyen araçlar dışarıda kalır.
  assert.ok(!visible.some((vehicle) => vehicle.groupId === 'Mucur'));
  assert.ok(visible.every((vehicle) => vehicle.approved));
  backend.dispose();
});

test('onay bekleyen hesap hiçbir araç görmez', () => {
  const backend = freshBackend();
  const viewer = viewerFor(backend, 'bekleyen@ornek.com');
  assert.equal(viewer.role, Role.pending);
  assert.equal(
    visibleVehiclesFor(backend.vehicles.value, backend.groups.value, viewer).length,
    0,
  );
  backend.dispose();
});

test('onaylı ama grupsuz izleyici de araç görmez', () => {
  const backend = freshBackend();
  const viewer = new Viewer({
    uid: 'x',
    email: 'x@ornek.com',
    isAdmin: false,
    webUser: new WebUser({
      uid: 'x',
      email: 'x@ornek.com',
      displayName: 'X',
      groupId: null,
      approved: true,
      createdAt: 0,
    }),
  });
  assert.equal(viewer.role, Role.viewer);
  assert.equal(
    visibleVehiclesFor(backend.vehicles.value, backend.groups.value, viewer).length,
    0,
  );
  backend.dispose();
});

test('alan gizleme bakılan aracın grubuna göre yapılır', () => {
  const backend = freshBackend();
  const groups = backend.groups.value;
  const viewer = viewerFor(backend, 'izleyici@ornek.com');
  const admin = viewerFor(backend, 'yonetici@ornek.com');
  const kamanVehicle = backend.vehicles.value.find((v) => v.groupId === 'Kaman');
  const merkezVehicle = backend.vehicles.value.find((v) => v.groupId === 'Merkez');

  // Kaman: hız görünür, sürücü adı gizli.
  assert.deepEqual(fieldVisibilityFor(kamanVehicle, groups, viewer), {
    showSpeed: true,
    showDriverName: false,
  });
  // Merkez: ikisi de görünür.
  assert.deepEqual(fieldVisibilityFor(merkezVehicle, groups, viewer), {
    showSpeed: true,
    showDriverName: true,
  });
  // Yönetici her zaman tam görür.
  assert.deepEqual(fieldVisibilityFor(kamanVehicle, groups, admin), {
    showSpeed: true,
    showDriverName: true,
  });
  backend.dispose();
});

// ------------------------------------------------------- Yönetici işlemleri

test('onaylanan ve gruba atanan araç izleyicinin haritasına girer', async () => {
  const backend = freshBackend();
  await signedInAdmin(backend);

  const pending = backend.vehicles.value.find((vehicle) => !vehicle.approved);
  const viewer = () => viewerFor(backend, 'izleyici@ornek.com');
  const visibleCount = () =>
    visibleVehiclesFor(backend.vehicles.value, backend.groups.value, viewer()).length;

  assert.equal(visibleCount(), 3);
  await backend.setVehicleApproved(pending.id, true);
  // Onaylandı ama hâlâ grupsuz: izleyici göremez.
  assert.equal(visibleCount(), 3);

  await backend.setVehicleGroup(pending.id, 'Merkez');
  assert.equal(visibleCount(), 4);
  backend.dispose();
});

test('grup silinince araçların ve izleyicilerin ataması temizlenir', async () => {
  const backend = freshBackend();
  await signedInAdmin(backend);

  await backend.deleteGroup('Merkez');

  assert.equal(backend.groups.value.length, 2);
  assert.ok(backend.vehicles.value.every((vehicle) => vehicle.groupId !== 'Merkez'));
  assert.ok(backend.users.value.every((user) => user.groupId !== 'Merkez'));
  // Mucur'un görünür listesinden de düşmeli.
  const mucur = backend.groups.value.find((group) => group.groupId === 'Mucur');
  assert.deepEqual([...mucur.visibleGroups], ['Kaman']);
  backend.dispose();
});

test('araç silinince konum geçmişi de gider', async () => {
  const backend = freshBackend();
  await signedInAdmin(backend);
  const vehicle = backend.vehicles.value[0];

  assert.equal((await backend.loadHistory(vehicle.id)).length, 120);
  await backend.deleteVehicle(vehicle.id);
  assert.equal((await backend.loadHistory(vehicle.id)).length, 0);
  assert.equal(backend.vehicles.value.length, 5);
  backend.dispose();
});

test('konum geçmişi en yeni kayıt üstte gelir', async () => {
  const backend = freshBackend();
  const samples = await backend.loadHistory(backend.vehicles.value[0].id);
  for (let i = 1; i < samples.length; i++) {
    assert.ok(samples[i - 1].recordedAt >= samples[i].recordedAt);
  }
  backend.dispose();
});

test('izleyici yazma çağrılarında yetki hatası alır', async () => {
  const backend = freshBackend();
  await backend.signIn('izleyici@ornek.com', '123456');
  await assert.rejects(
    () => backend.setVehicleApproved(backend.vehicles.value[0].id, true),
    /yetkiniz yok/i,
  );
  backend.dispose();
});

test('yönetici kendi yetkisini düşüremez', async () => {
  const backend = freshBackend();
  const admin = await signedInAdmin(backend);
  await assert.rejects(() => backend.setUserAdmin(admin.uid, false), /kendi yetkinizi/i);
  backend.dispose();
});

test('yeni kayıt onaysız doğar ve yönetici onayıyla izleyici olur', async () => {
  const backend = freshBackend();
  await backend.register({
    email: 'yeni@ornek.com',
    password: '123456',
    displayName: 'Yeni Kullanıcı',
  });
  assert.equal(backend.viewer.value.role, Role.pending);
  const uid = backend.viewer.value.uid;

  await signedInAdmin(backend);
  await backend.setUserApproved(uid, true);
  await backend.setUserGroup(uid, 'Mucur');

  const updated = backend.users.value.find((user) => user.uid === uid);
  assert.equal(updated.approved, true);
  assert.equal(updated.groupId, 'Mucur');
  backend.dispose();
});

test('oturum sayfa yenilenince açık kalır', async () => {
  const backend = freshBackend();
  await backend.signIn('izleyici@ornek.com', '123456');
  assert.equal(backend.viewer.value.email, 'izleyici@ornek.com');
  backend.dispose();

  // Yenileme: aynı depolamayla yeni bir arka uç kurulur (storage temizlenmez).
  const reloaded = new DemoBackend();
  assert.ok(reloaded.viewer.value, 'oturum geri yüklenmedi, giriş ekranına düşer');
  assert.equal(reloaded.viewer.value.email, 'izleyici@ornek.com');
  assert.equal(reloaded.viewer.value.role, Role.viewer);

  // Çıkış yapılınca yenilemede de kapalı kalmalı.
  await reloaded.signOut();
  reloaded.dispose();
  const afterSignOut = new DemoBackend();
  assert.equal(afterSignOut.viewer.value, null);
  afterSignOut.dispose();
});

test('hatalı şifre girişi reddedilir', async () => {
  const backend = freshBackend();
  await assert.rejects(() => backend.signIn('yonetici@ornek.com', 'yanlis'), /hatalı/i);
  assert.equal(backend.viewer.value, null);
  backend.dispose();
});

// ------------------------------------------------- Sıralama ve metin işleri

test('onay bekleyen araçlar listenin başında durur', () => {
  const vehicles = [
    new Vehicle({ id: 'b', plate: '40 B', driverName: '', groupId: null, approved: true, lat: 0, lng: 0, speedKmh: 0, updatedAt: 1 }),
    new Vehicle({ id: 'a', plate: '40 A', driverName: '', groupId: null, approved: true, lat: 0, lng: 0, speedKmh: 0, updatedAt: 1 }),
    new Vehicle({ id: 'c', plate: '40 C', driverName: '', groupId: null, approved: false, lat: 0, lng: 0, speedKmh: 0, updatedAt: 1 }),
  ];
  assert.deepEqual(
    sortVehiclesForAdmin(vehicles).map((vehicle) => vehicle.id),
    ['c', 'a', 'b'],
  );
});

test('grup adı çakışması büyük/küçük harften bağımsız yakalanır', () => {
  const groups = [new GroupConfig({ groupId: 'Merkez', visibleGroups: [], showSpeed: true, showDriverName: true })];
  assert.equal(isGroupNameAvailable('Kaman', groups), true);
  assert.equal(isGroupNameAvailable('Merkez', groups), false);
  assert.equal(isGroupNameAvailable('merkez', groups), false);
  assert.equal(isGroupNameAvailable('', groups), false);
});

test('Türkçe büyük harf kuralı i ve ı harflerinde bozulmaz', () => {
  // JS'in toUpperCase() metodu locale tanımaz: 'i' -> 'I' yapardı.
  assert.equal(turkishUpperCase('istanbul'), 'İSTANBUL');
  assert.equal(turkishUpperCase('ırmak'), 'IRMAK');
});

test('grup adından veritabanı anahtarında yasak karakterler atılır', () => {
  // Grup adı aynı zamanda RTDB anahtarıdır; bu karakterler yazmayı bozardı.
  assert.equal(normalizeGroupName('  Mer.kez/ $#[] '), 'Merkez');
  assert.equal(normalizeGroupName('Ka\x00ma\x1Fn\x7F'), 'Kaman');
  assert.equal(normalizeGroupName('Merkez   Şube'), 'Merkez Şube');
  assert.equal(normalizeGroupName('   '), '');
});

test('ad ve e-posta doğrulaması formda beklendiği gibi çalışır', () => {
  assert.equal(normalizeDriverName('  Ayşe   Demir '), 'Ayşe Demir');
  assert.equal(isValidEmail('izleyici@ornek.com'), true);
  assert.equal(isValidEmail('izleyici@ornek'), false);
  assert.equal(isValidEmail('bos degil'), false);
});

test('arama plaka, sürücü ve grup üzerinde çalışır', () => {
  const vehicle = new Vehicle({
    id: 'a', plate: '40 ABC 001', driverName: 'Ayşe Demir', groupId: 'Merkez',
    approved: true, lat: 0, lng: 0, speedKmh: 0, updatedAt: 1,
  });
  assert.equal(matchesVehicleSearch(vehicle, 'abc'), true);
  assert.equal(matchesVehicleSearch(vehicle, 'ayşe'), true);
  assert.equal(matchesVehicleSearch(vehicle, 'merkez'), true);
  assert.equal(matchesVehicleSearch(vehicle, 'mucur'), false);
  assert.equal(matchesVehicleSearch(vehicle, '   '), true);
});
