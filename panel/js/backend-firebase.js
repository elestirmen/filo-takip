// Gerçek arka uç: Firebase Auth + Realtime Database.
//
// lib/data/firebase_fleet_repository.dart ile aynı düğümleri okur ve aynı
// çok yollu güncellemeleri yazar; iki istemci birbirinin verisini bozmaz.
//
// SDK, derleme adımı olmasın diye doğrudan gstatic üzerinden ES modülü olarak
// yüklenir. Sürümü değiştirmek isterseniz aşağıdaki iki satır yeter.

import {
  createUserWithEmailAndPassword,
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';
import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {
  get,
  getDatabase,
  limitToLast,
  onValue,
  orderByKey,
  query,
  ref,
  serverTimestamp,
  update,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-database.js';

import { BackendError } from './backend-error.js';
import { EventChannel, LatestValue } from './emitter.js';
import { Geofence, GroupConfig, LocationSample, Vehicle, Viewer, WebUser } from './models.js';
import { compareText } from './admin-rules.js';
import { firebaseConfig } from './config.js';
import { Strings } from './strings.js';

const VEHICLES_PATH = 'vehicles';
const GROUP_CONFIGS_PATH = 'groupConfigs';
const LOCATION_HISTORY_PATH = 'locationHistory';
const ADMINS_PATH = 'admins';
const WEB_USERS_PATH = 'webUsers';
const GEOFENCES_PATH = 'geofences';
const SERVER_TIME_OFFSET_PATH = '.info/serverTimeOffset';

const HISTORY_READ_LIMIT = 500;

// Firebase Auth hata kodlarını kullanıcıya gösterilecek Türkçe metne çevirir.
function authErrorMessage(error) {
  switch (error?.code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
    case 'auth/invalid-email':
      return Strings.errorInvalidCredentials;
    case 'auth/network-request-failed':
      return Strings.errorNetwork;
    case 'auth/too-many-requests':
      return Strings.errorTooManyRequests;
    case 'auth/operation-not-allowed':
      return Strings.errorProviderDisabled;
    case 'auth/email-already-in-use':
      return Strings.errorEmailInUse;
    case 'auth/weak-password':
      return Strings.errorWeakPassword;
    default:
      return Strings.errorSignInFailed;
  }
}

export class FirebaseBackend {
  constructor() {
    this.isDemo = false;

    try {
      this._app = initializeApp(firebaseConfig);
      this._auth = getAuth(this._app);
      this._database = getDatabase(this._app);
    } catch (error) {
      throw new BackendError(Strings.errorFirebaseInit, error);
    }

    this.vehicles = new LatestValue([]);
    this.groups = new LatestValue([]);
    this.users = new LatestValue([]);
    this.geofences = new LatestValue([]);
    this.adminUids = new LatestValue(new Set());
    this.viewer = new LatestValue(null);
    this.errors = new EventChannel();

    this._serverTimeOffset = 0;
    this._unsubscribers = [];
    // Yalnızca oturum açıkken kurulan abonelikler; çıkışta hepsi kapatılır.
    this._sessionUnsubscribers = [];
    this._adminUnsubscribers = [];

    // Kendi yetkisi ve kendi kaydı ayrı ayrı gelir; Viewer ikisi de en az bir
    // kez raporladıktan sonra yayılır, yoksa panel bir an "onay bekliyor"
    // ekranını gösterip sonra yönetici görünümüne atlardı.
    this._authUser = null;
    this._selfIsAdmin = false;
    this._selfWebUser = null;
    this._selfAdminLoaded = false;
    this._selfUserLoaded = false;

    this._listenServerTimeOffset();
    this._listenAuth();
  }

  // ---------------------------------------------------------------- Oturum

  async signIn(email, password) {
    try {
      await signInWithEmailAndPassword(this._auth, email.trim(), password);
    } catch (error) {
      throw new BackendError(authErrorMessage(error), error);
    }
  }

  async register({ email, password, displayName }) {
    const normalized = email.trim();
    let credential;
    try {
      credential = await createUserWithEmailAndPassword(this._auth, normalized, password);
    } catch (error) {
      throw new BackendError(authErrorMessage(error), error);
    }
    // Hesap açıldı ama panel kaydı yazılamazsa kullanıcı hiçbir listede
    // görünmez ve yönetici onu onaylayamaz; bu yüzden hata yutulmaz.
    try {
      await update(ref(this._database, `${WEB_USERS_PATH}/${credential.user.uid}`), {
        email: normalized,
        displayName,
        createdAt: serverTimestamp(),
      });
    } catch (error) {
      throw new BackendError(Strings.errorSaveFailed, error);
    }
  }

  async signOut() {
    try {
      await signOut(this._auth);
    } catch (error) {
      throw new BackendError(Strings.errorSignOutFailed, error);
    }
  }

  // ---------------------------------------------------------------- Zaman

  // Tarayıcı saati + sunucu zaman ofseti. updatedAt sunucu zamanı olduğu için
  // bayatlık hesabı tarayıcı saatiyle doğrudan yapılmaz.
  nowMs() {
    return Date.now() + this._serverTimeOffset;
  }

  // ---------------------------------------------------------------- Yazma

  async setVehicleApproved(vehicleId, approved) {
    await this._write(`${VEHICLES_PATH}/${vehicleId}`, { approved }, Strings.errorSaveFailed);
  }

  async setVehicleGroup(vehicleId, groupId) {
    await this._write(
      `${VEHICLES_PATH}/${vehicleId}`,
      { groupId: groupId ?? null },
      Strings.errorSaveFailed,
    );
  }

  // Araç düğümü ve konum geçmişi **tek bir çok yollu güncellemeyle** gider;
  // iki ayrı silme yetim veri bırakırdı.
  async deleteVehicle(vehicleId) {
    await this._writeRoot(
      {
        [`${VEHICLES_PATH}/${vehicleId}`]: null,
        [`${LOCATION_HISTORY_PATH}/${vehicleId}`]: null,
      },
      Strings.errorDeleteFailed,
    );
  }

  async saveGroupConfig(config) {
    await this._write(
      `${GROUP_CONFIGS_PATH}/${config.groupId}`,
      config.toMap(),
      Strings.errorSaveFailed,
    );
  }

  // Grubu siler; bağlı araçların ve izleyicilerin atamasını, diğer grupların
  // görünür listelerini aynı güncellemede temizler.
  async deleteGroup(groupId) {
    const updates = { [`${GROUP_CONFIGS_PATH}/${groupId}`]: null };
    for (const vehicle of this.vehicles.value) {
      if (vehicle.groupId !== groupId) continue;
      updates[`${VEHICLES_PATH}/${vehicle.id}/groupId`] = null;
    }
    for (const user of this.users.value) {
      if (user.groupId !== groupId) continue;
      updates[`${WEB_USERS_PATH}/${user.uid}/groupId`] = null;
    }
    for (const group of this.groups.value) {
      if (!group.visibleGroups.includes(groupId)) continue;
      updates[`${GROUP_CONFIGS_PATH}/${group.groupId}/visibleGroups`] =
        group.visibleGroups.filter((name) => name !== groupId);
    }
    await this._writeRoot(updates, Strings.errorDeleteFailed);
  }

  async saveGeofence(geofence) {
    await this._write(`${GEOFENCES_PATH}/${geofence.id}`, geofence.toMap(), Strings.errorSaveFailed);
  }

  async deleteGeofence(id) {
    await this._writeRoot({ [`${GEOFENCES_PATH}/${id}`]: null }, Strings.errorDeleteFailed);
  }

  async setUserApproved(uid, approved) {
    await this._write(`${WEB_USERS_PATH}/${uid}`, { approved }, Strings.errorSaveFailed);
  }

  async setUserGroup(uid, groupId) {
    await this._write(
      `${WEB_USERS_PATH}/${uid}`,
      { groupId: groupId ?? null },
      Strings.errorSaveFailed,
    );
  }

  // Yetki `/admins/{uid}` düğümünün varlığıdır. Kural, yöneticinin kendi
  // düğümünü silmesini engeller; arayüz de düğmeyi hiç göstermez.
  async setUserAdmin(uid, isAdmin) {
    await this._writeRoot(
      { [`${ADMINS_PATH}/${uid}`]: isAdmin ? true : null },
      Strings.errorSaveFailed,
    );
  }

  // Panel kaydını ve yönetici işaretini birlikte siler. Firebase
  // Authentication hesabı istemciden silinemez; o Console'dan kaldırılır.
  async deleteUser(uid) {
    await this._writeRoot(
      { [`${WEB_USERS_PATH}/${uid}`]: null, [`${ADMINS_PATH}/${uid}`]: null },
      Strings.errorDeleteFailed,
    );
  }

  // ---------------------------------------------------------------- Okuma

  // Tek seferlik okuma, en yeni HISTORY_READ_LIMIT kayıt, en yeni üstte.
  async loadHistory(vehicleId) {
    try {
      const snapshot = await get(
        query(
          ref(this._database, `${LOCATION_HISTORY_PATH}/${vehicleId}`),
          orderByKey(),
          limitToLast(HISTORY_READ_LIMIT),
        ),
      );
      const samples = [];
      snapshot.forEach((child) => {
        samples.push(LocationSample.fromMap(child.key, child.val()));
      });
      return samples.reverse();
    } catch (error) {
      throw new BackendError(Strings.errorHistoryLoadFailed, error);
    }
  }

  dispose() {
    this._clearSessionSubscriptions();
    for (const unsubscribe of this._unsubscribers) unsubscribe();
    this._unsubscribers = [];
  }

  // -------------------------------------------------------------- İçeriler

  async _write(path, values, message) {
    try {
      await update(ref(this._database, path), values);
    } catch (error) {
      throw new BackendError(this._writeErrorMessage(error, message), error);
    }
  }

  async _writeRoot(updates, message) {
    try {
      await update(ref(this._database), updates);
    } catch (error) {
      throw new BackendError(this._writeErrorMessage(error, message), error);
    }
  }

  _writeErrorMessage(error, fallback) {
    const code = String(error?.code ?? error?.message ?? '');
    if (code.includes('permission-denied') || code.includes('PERMISSION_DENIED')) {
      return Strings.errorPermissionDenied;
    }
    return fallback;
  }

  _listenServerTimeOffset() {
    this._unsubscribers.push(
      onValue(ref(this._database, SERVER_TIME_OFFSET_PATH), (snapshot) => {
        const offset = snapshot.val();
        if (typeof offset === 'number' && Number.isFinite(offset)) {
          this._serverTimeOffset = offset;
        }
      }),
    );
  }

  _listenAuth() {
    this._unsubscribers.push(
      onAuthStateChanged(this._auth, (user) => {
        this._clearSessionSubscriptions();
        this._authUser = user;
        this._selfIsAdmin = false;
        this._selfWebUser = null;
        this._selfAdminLoaded = false;
        this._selfUserLoaded = false;

        if (user === null) {
          this.viewer.add(null);
          return;
        }
        this._listenSelf(user);
        this._listenFleet();
      }),
    );
  }

  // Kendi yetkisi ve kendi panel kaydı. İkisi de canlı dinlenir: yönetici
  // hesabı onayladığı anda, açık duran "onay bekliyor" sayfası kendiliğinden
  // izleyici görünümüne döner.
  _listenSelf(user) {
    this._sessionUnsubscribers.push(
      onValue(
        ref(this._database, `${ADMINS_PATH}/${user.uid}`),
        (snapshot) => {
          this._selfIsAdmin = snapshot.exists() && snapshot.val() !== false;
          this._selfAdminLoaded = true;
          this._publishViewer();
          this._syncAdminSubscriptions();
        },
        () => {
          this._selfAdminLoaded = true;
          this.errors.add(Strings.errorAdminStream);
          this._publishViewer();
        },
      ),
    );

    this._sessionUnsubscribers.push(
      onValue(
        ref(this._database, `${WEB_USERS_PATH}/${user.uid}`),
        (snapshot) => {
          this._selfWebUser = snapshot.exists()
            ? WebUser.fromMap(user.uid, snapshot.val())
            : null;
          this._selfUserLoaded = true;
          this._publishViewer();
        },
        () => {
          this._selfUserLoaded = true;
          this.errors.add(Strings.errorUsersStream);
          this._publishViewer();
        },
      ),
    );
  }

  _listenFleet() {
    this._sessionUnsubscribers.push(
      onValue(
        ref(this._database, VEHICLES_PATH),
        (snapshot) => {
          const vehicles = [];
          snapshot.forEach((child) => {
            vehicles.push(Vehicle.fromMap(child.key, child.val()));
          });
          vehicles.sort((a, b) => compareText(a.plate, b.plate));
          this.vehicles.add(vehicles);
        },
        () => this.errors.add(Strings.errorVehiclesStream),
      ),
    );

    this._sessionUnsubscribers.push(
      onValue(
        ref(this._database, GEOFENCES_PATH),
        (snapshot) => {
          const zones = [];
          snapshot.forEach((child) => {
            zones.push(Geofence.fromMap(child.key, child.val()));
          });
          zones.sort((a, b) => compareText(a.name, b.name));
          this.geofences.add(zones);
        },
        () => this.errors.add(Strings.errorGeofencesStream),
      ),
    );

    this._sessionUnsubscribers.push(
      onValue(
        ref(this._database, GROUP_CONFIGS_PATH),
        (snapshot) => {
          const groups = [];
          snapshot.forEach((child) => {
            groups.push(GroupConfig.fromMap(child.key, child.val()));
          });
          groups.sort((a, b) => compareText(a.groupId, b.groupId));
          this.groups.add(groups);
        },
        () => this.errors.add(Strings.errorGroupConfigsStream),
      ),
    );
  }

  // Kullanıcı listesini ve yönetici listesini yalnızca yönetici okuyabilir;
  // izleyiciyken abone olmak kuralları ihlal edip gereksiz hata üretirdi.
  _syncAdminSubscriptions() {
    if (this._selfIsAdmin && this._adminUnsubscribers.length === 0) {
      this._adminUnsubscribers.push(
        onValue(
          ref(this._database, WEB_USERS_PATH),
          (snapshot) => {
            const users = [];
            snapshot.forEach((child) => {
              users.push(WebUser.fromMap(child.key, child.val()));
            });
            this.users.add(users);
          },
          () => this.errors.add(Strings.errorUsersStream),
        ),
      );
      this._adminUnsubscribers.push(
        onValue(
          ref(this._database, ADMINS_PATH),
          (snapshot) => {
            const uids = new Set();
            snapshot.forEach((child) => {
              if (child.val() !== false) uids.add(child.key);
            });
            this.adminUids.add(uids);
          },
          () => this.errors.add(Strings.errorAdminStream),
        ),
      );
      return;
    }
    if (!this._selfIsAdmin && this._adminUnsubscribers.length > 0) {
      for (const unsubscribe of this._adminUnsubscribers) unsubscribe();
      this._adminUnsubscribers = [];
      this.users.add([]);
      this.adminUids.add(new Set());
    }
  }

  _publishViewer() {
    if (this._authUser === null) return;
    // İki kaynak da raporlamadan yetki belli olmaz.
    if (!this._selfAdminLoaded || !this._selfUserLoaded) return;
    this.viewer.add(
      new Viewer({
        uid: this._authUser.uid,
        email: this._authUser.email ?? '',
        isAdmin: this._selfIsAdmin,
        webUser: this._selfWebUser,
      }),
    );
  }

  _clearSessionSubscriptions() {
    for (const unsubscribe of this._sessionUnsubscribers) unsubscribe();
    this._sessionUnsubscribers = [];
    for (const unsubscribe of this._adminUnsubscribers) unsubscribe();
    this._adminUnsubscribers = [];
    this.vehicles.add([]);
    this.groups.add([]);
    this.users.add([]);
    this.geofences.add([]);
    this.adminUids.add(new Set());
  }
}
