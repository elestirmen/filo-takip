// Düz veri modelleri, elle yazılmış fromMap/toMap. Uygulamadaki
// lib/models/ klasörünün karşılığıdır; alan adları birebir aynıdır, çünkü
// ikisi de aynı Realtime Database düğümlerini okur.

import {
  dbBool,
  dbDouble,
  dbInt,
  dbMap,
  dbString,
  dbStringList,
  dbStringOrNull,
} from './db-parse.js';

// `/vehicles/{uid}` düğümü. id doğrudan Firebase auth.uid değeridir.
export class Vehicle {
  constructor({ id, plate, driverName, groupId, approved, lat, lng, speedKmh, updatedAt }) {
    this.id = id;
    this.plate = plate;
    this.driverName = driverName;
    this.groupId = groupId;
    this.approved = approved;
    this.lat = lat;
    this.lng = lng;
    this.speedKmh = speedKmh;
    this.updatedAt = updatedAt;
    Object.freeze(this);
  }

  static fromMap(id, raw) {
    const map = dbMap(raw);
    return new Vehicle({
      id,
      plate: dbString(map.plate),
      driverName: dbString(map.driverName),
      groupId: dbStringOrNull(map.groupId),
      // Alan hiç yazılmamışsa onaysız sayılır.
      approved: dbBool(map.approved),
      lat: dbDouble(map.lat),
      lng: dbDouble(map.lng),
      speedKmh: dbDouble(map.speedKmh),
      updatedAt: dbInt(map.updatedAt),
    });
  }

  get hasGroup() {
    return this.groupId !== null && this.groupId !== undefined && this.groupId.length > 0;
  }

  // Hiç konum yazılmamış araçları haritada göstermemek için.
  get hasLocation() {
    return this.updatedAt > 0;
  }

  copyWith(changes = {}) {
    return new Vehicle({
      id: this.id,
      plate: changes.plate ?? this.plate,
      driverName: changes.driverName ?? this.driverName,
      groupId: changes.clearGroupId ? null : (changes.groupId ?? this.groupId),
      approved: changes.approved ?? this.approved,
      lat: changes.lat ?? this.lat,
      lng: changes.lng ?? this.lng,
      speedKmh: changes.speedKmh ?? this.speedKmh,
      updatedAt: changes.updatedAt ?? this.updatedAt,
    });
  }
}

// `/groupConfigs/{groupId}` düğümü. Yalnızca yönetici yazar.
export class GroupConfig {
  constructor({ groupId, visibleGroups, showSpeed, showDriverName, speedLimitKmh = 0 }) {
    this.groupId = groupId;
    this.visibleGroups = Object.freeze([...visibleGroups]);
    this.showSpeed = showSpeed;
    this.showDriverName = showDriverName;
    // 0 ise sınır yok. Bu gruptaki araç sınırı aştığında uyarı üretilir.
    this.speedLimitKmh = speedLimitKmh;
    Object.freeze(this);
  }

  static fromMap(id, raw) {
    const map = dbMap(raw);
    return new GroupConfig({
      // Düğüm anahtarı asıl kaynaktır; alan eksikse ona düşülür.
      groupId: dbString(map.groupId, id),
      visibleGroups: dbStringList(map.visibleGroups),
      // Alan yazılmamışsa gizleme yok: yeni grup her şeyi gösterir.
      showSpeed: dbBool(map.showSpeed, true),
      showDriverName: dbBool(map.showDriverName, true),
      speedLimitKmh: dbDouble(map.speedLimitKmh),
    });
  }

  copyWith(changes = {}) {
    return new GroupConfig({
      groupId: this.groupId,
      visibleGroups: changes.visibleGroups ?? this.visibleGroups,
      showSpeed: changes.showSpeed ?? this.showSpeed,
      showDriverName: changes.showDriverName ?? this.showDriverName,
      speedLimitKmh: changes.speedLimitKmh ?? this.speedLimitKmh,
    });
  }

  toMap() {
    return {
      groupId: this.groupId,
      visibleGroups: [...this.visibleGroups],
      showSpeed: this.showSpeed,
      showDriverName: this.showDriverName,
      speedLimitKmh: this.speedLimitKmh,
    };
  }
}

// `/locationHistory/{uid}/{pushId}` düğümü.
export class LocationSample {
  constructor({ id, lat, lng, speedKmh, recordedAt }) {
    this.id = id;
    this.lat = lat;
    this.lng = lng;
    this.speedKmh = speedKmh;
    this.recordedAt = recordedAt;
    Object.freeze(this);
  }

  static fromMap(id, raw) {
    const map = dbMap(raw);
    return new LocationSample({
      id,
      lat: dbDouble(map.lat),
      lng: dbDouble(map.lng),
      speedKmh: dbDouble(map.speedKmh),
      recordedAt: dbInt(map.recordedAt),
    });
  }
}

// `/geofences/{id}` düğümü — harita üzerinde tanımlı dairesel bölge.
//
// Poligon yerine daire: merkez ve yarıçap iki sayıdır, çizim aracı
// gerektirmez ve depo/müşteri sahası/şehir sınırı gibi gerçek ihtiyaçların
// çoğunu karşılar.
export class Geofence {
  constructor({ id, name, lat, lng, radiusM, createdAt }) {
    this.id = id;
    this.name = name;
    this.lat = lat;
    this.lng = lng;
    this.radiusM = radiusM;
    this.createdAt = createdAt;
    Object.freeze(this);
  }

  static fromMap(id, raw) {
    const map = dbMap(raw);
    return new Geofence({
      id,
      name: dbString(map.name, id),
      lat: dbDouble(map.lat),
      lng: dbDouble(map.lng),
      // Yarıçapsız bir bölge hiçbir aracı içermez; makul bir tabana düşülür.
      radiusM: dbDouble(map.radiusM, 500),
      createdAt: dbInt(map.createdAt),
    });
  }

  toMap() {
    return {
      name: this.name,
      lat: this.lat,
      lng: this.lng,
      radiusM: this.radiusM,
      createdAt: this.createdAt,
    };
  }
}

// `/webUsers/{uid}` düğümü — panele e-posta ile giren hesaplar.
//
// Uygulamadaki sürücü kaydının aynısı gibi çalışır: kullanıcı kendi adını ve
// e-postasını yazar, `approved` ve `groupId` alanlarına yalnızca yönetici
// dokunur. Yönetici yetkisi burada değil, `/admins/{uid}` düğümünde durur.
export class WebUser {
  constructor({ uid, email, displayName, groupId, approved, createdAt }) {
    this.uid = uid;
    this.email = email;
    this.displayName = displayName;
    this.groupId = groupId;
    this.approved = approved;
    this.createdAt = createdAt;
    Object.freeze(this);
  }

  static fromMap(uid, raw) {
    const map = dbMap(raw);
    return new WebUser({
      uid,
      email: dbString(map.email),
      displayName: dbString(map.displayName),
      groupId: dbStringOrNull(map.groupId),
      approved: dbBool(map.approved),
      createdAt: dbInt(map.createdAt),
    });
  }

  get hasGroup() {
    return this.groupId !== null && this.groupId !== undefined && this.groupId.length > 0;
  }

  // Listede gösterilecek ad; boşsa e-postanın kullanıcı adı kısmına düşülür.
  get label() {
    if (this.displayName.length > 0) return this.displayName;
    const at = this.email.indexOf('@');
    return at > 0 ? this.email.slice(0, at) : this.email;
  }

  copyWith(changes = {}) {
    return new WebUser({
      uid: this.uid,
      email: changes.email ?? this.email,
      displayName: changes.displayName ?? this.displayName,
      groupId: changes.clearGroupId ? null : (changes.groupId ?? this.groupId),
      approved: changes.approved ?? this.approved,
      createdAt: changes.createdAt ?? this.createdAt,
    });
  }
}

// Panelin tanıdığı yetkiler.
export const Role = Object.freeze({
  admin: 'admin',
  viewer: 'viewer',
  pending: 'pending',
});

// Oturum açmış kullanıcının panel içindeki kimliği.
//
// Yetki iki kaynaktan türetilir ve ikisini de sunucu belirler:
//   * `/admins/{uid}` varsa yönetici,
//   * `/webUsers/{uid}.approved` doğruysa izleyici,
//   * ikisi de yoksa onay bekliyor.
export class Viewer {
  constructor({ uid, email, isAdmin, webUser }) {
    this.uid = uid;
    this.email = email;
    this.isAdmin = isAdmin;
    this.webUser = webUser ?? null;
    Object.freeze(this);
  }

  get role() {
    if (this.isAdmin) return Role.admin;
    if (this.webUser !== null && this.webUser.approved) return Role.viewer;
    return Role.pending;
  }

  // İzleyicinin araçlarını göreceği grup. Yönetici için anlamsızdır.
  get groupId() {
    return this.webUser !== null ? this.webUser.groupId : null;
  }

  get label() {
    if (this.webUser !== null) return this.webUser.label;
    const at = this.email.indexOf('@');
    return at > 0 ? this.email.slice(0, at) : this.email;
  }
}
