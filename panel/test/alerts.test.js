// Uyarı tespitinin testleri.
//
// Asıl incelik: uyarı **geçiş anında** üretilir, durum sürdüğü sürece değil.
// Bu bozulursa panel saniyede bir aynı uyarıyı yağdırır.

import assert from 'node:assert/strict';
import test from 'node:test';

const { AlertKind, detectAlerts, speedLimitFor } = await import('../js/alerts.js');
const { Geofence, GroupConfig, Vehicle } = await import('../js/models.js');

const NOW = 1_700_000_000_000;
const LAT = 38.6246;
const LNG = 34.7142;

const vehicleAt = ({ speedKmh = 0, lat = LAT, lng = LNG, updatedAt = NOW, approved = true } = {}) =>
  new Vehicle({
    id: 'v1',
    plate: '40 ABC 001',
    driverName: 'Test',
    groupId: 'Merkez',
    approved,
    lat,
    lng,
    speedKmh,
    updatedAt,
  });

const groups = [
  new GroupConfig({
    groupId: 'Merkez',
    visibleGroups: [],
    showSpeed: true,
    showDriverName: true,
    speedLimitKmh: 50,
  }),
];

const zone = new Geofence({
  id: 'depo',
  name: 'Merkez Depo',
  lat: LAT,
  lng: LNG,
  radiusM: 500,
  createdAt: 0,
});

// Bir adım çalıştırır ve yeni durumu geri verir.
function step(previous, vehicle, { geofences = [], nowMs = NOW } = {}) {
  return detectAlerts({ vehicles: [vehicle], groups, geofences, previous, nowMs });
}

test('ilk çağrı uyarı üretmez, yalnızca durumu kaydeder', () => {
  const result = step(new Map(), vehicleAt({ speedKmh: 90 }));
  assert.equal(result.alerts.length, 0, 'açılışta uyarı yağmamalı');
  assert.equal(result.next.size, 1);
});

test('hız sınırı aşılınca bir kez uyarılır', () => {
  let { next } = step(new Map(), vehicleAt({ speedKmh: 40 }));

  // 40 -> 70: sınır aşıldı.
  let result = step(next, vehicleAt({ speedKmh: 70 }));
  assert.equal(result.alerts.length, 1);
  assert.equal(result.alerts[0].kind, AlertKind.speeding);
  assert.equal(result.alerts[0].limitKmh, 50);
  next = result.next;

  // 70 -> 80: hâlâ aşıyor ama yeni bir geçiş yok.
  result = step(next, vehicleAt({ speedKmh: 80 }));
  assert.equal(result.alerts.length, 0, 'süregelen aşım tekrar uyarmamalı');
  next = result.next;

  // Sınırın altına in, sonra tekrar aş: yeniden uyarmalı.
  next = step(next, vehicleAt({ speedKmh: 30 })).next;
  result = step(next, vehicleAt({ speedKmh: 65 }));
  assert.equal(result.alerts.length, 1, 'yeni aşım uyarmalı');
});

test('sınır tanımsızsa hız uyarısı çıkmaz', () => {
  const noLimit = [
    new GroupConfig({
      groupId: 'Merkez',
      visibleGroups: [],
      showSpeed: true,
      showDriverName: true,
      speedLimitKmh: 0,
    }),
  ];
  const first = detectAlerts({
    vehicles: [vehicleAt({ speedKmh: 10 })],
    groups: noLimit,
    geofences: [],
    previous: new Map(),
    nowMs: NOW,
  });
  const second = detectAlerts({
    vehicles: [vehicleAt({ speedKmh: 200 })],
    groups: noLimit,
    geofences: [],
    previous: first.next,
    nowMs: NOW,
  });
  assert.equal(second.alerts.length, 0);
  assert.equal(speedLimitFor(vehicleAt(), noLimit), 0);
  assert.equal(speedLimitFor(vehicleAt(), groups), 50);
});

test('araç çevrimdışına düşünce bir kez uyarılır', () => {
  let { next } = step(new Map(), vehicleAt({ speedKmh: 10, updatedAt: NOW }));

  // Son güncelleme 10 dakika geride: 5 dakikalık eşiği aştı.
  const stale = vehicleAt({ speedKmh: 10, updatedAt: NOW - 10 * 60000 });
  let result = step(next, stale);
  assert.equal(result.alerts.length, 1);
  assert.equal(result.alerts[0].kind, AlertKind.offline);
  next = result.next;

  // Hâlâ çevrimdışı: tekrar uyarmamalı.
  result = step(next, stale);
  assert.equal(result.alerts.length, 0);
});

test('bölgeye giriş ve çıkış ayrı ayrı uyarır', () => {
  const inside = vehicleAt({ lat: LAT, lng: LNG, speedKmh: 20 });
  // ~1,1 km kuzey: 500 m yarıçaplı bölgenin dışında.
  const outside = vehicleAt({ lat: LAT + 0.01, lng: LNG, speedKmh: 20 });

  let { next } = step(new Map(), outside, { geofences: [zone] });

  let result = step(next, inside, { geofences: [zone] });
  assert.equal(result.alerts.length, 1);
  assert.equal(result.alerts[0].kind, AlertKind.geofenceEnter);
  assert.equal(result.alerts[0].zoneName, 'Merkez Depo');
  next = result.next;

  // İçeride kalmak tekrar uyarmaz.
  result = step(next, inside, { geofences: [zone] });
  assert.equal(result.alerts.length, 0);
  next = result.next;

  result = step(next, outside, { geofences: [zone] });
  assert.equal(result.alerts.length, 1);
  assert.equal(result.alerts[0].kind, AlertKind.geofenceExit);
});

test('konumu olmayan araç hiçbir bölgede sayılmaz', () => {
  const noLocation = new Vehicle({
    id: 'v1', plate: '40 ABC 001', driverName: 'Test', groupId: 'Merkez',
    approved: true, lat: 0, lng: 0, speedKmh: 0, updatedAt: 0,
  });
  const { next } = step(new Map(), noLocation, { geofences: [zone] });
  assert.equal(next.get('v1').zoneIds.size, 0);
});

test('aynı adımda birden fazla uyarı birlikte gelir', () => {
  // Önce: yavaş ve bölge dışında. Sonra: hızlı ve bölge içinde.
  const before = vehicleAt({ speedKmh: 10, lat: LAT + 0.01 });
  const after = vehicleAt({ speedKmh: 90, lat: LAT });

  const { next } = step(new Map(), before, { geofences: [zone] });
  const result = step(next, after, { geofences: [zone] });

  const kinds = result.alerts.map((alert) => alert.kind).sort();
  assert.deepEqual(kinds, [AlertKind.geofenceEnter, AlertKind.speeding].sort());
});
