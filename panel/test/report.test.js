// Coğrafi hesaplar ve konum geçmişinden çıkarılan yol/durak raporunun
// testleri. Tarayıcı, DOM ya da Firebase gerektirmez.

import assert from 'node:assert/strict';
import test from 'node:test';

const { distanceM, isInsideCircle, formatDistance, formatDuration } =
  await import('../js/geo.js');
const { tripReport, averageMovingSpeedKmh, ReportThresholds } =
  await import('../js/trip-report.js');

// Kayıt üretici: t saniye sonra, verilen konum ve hızda.
const at = (seconds, lat, lng, speedKmh) => ({
  id: `s${seconds}`,
  lat,
  lng,
  speedKmh,
  recordedAt: 1_700_000_000_000 + seconds * 1000,
});

// Nevşehir civarı; enlem başına ~111 km.
const LAT = 38.6246;
const LNG = 34.7142;

// ------------------------------------------------------------------ geo

test('mesafe bilinen bir değere yakın çıkar', () => {
  // 1 derece enlem ~111,2 km.
  const d = distanceM(0, 0, 1, 0);
  assert.ok(Math.abs(d - 111195) < 200, `beklenen ~111195 m, gelen ${d}`);

  // Aynı nokta sıfır verir.
  assert.equal(distanceM(LAT, LNG, LAT, LNG), 0);

  // 0,001 derece enlem ~111 m.
  const short = distanceM(LAT, LNG, LAT + 0.001, LNG);
  assert.ok(Math.abs(short - 111) < 2, `beklenen ~111 m, gelen ${short}`);
});

test('daire içi/dışı doğru ayrılır', () => {
  assert.equal(isInsideCircle(LAT, LNG, LAT, LNG, 100), true);
  // ~111 m kuzeyde: 150 m yarıçapın içinde, 50 m yarıçapın dışında.
  assert.equal(isInsideCircle(LAT + 0.001, LNG, LAT, LNG, 150), true);
  assert.equal(isInsideCircle(LAT + 0.001, LNG, LAT, LNG, 50), false);
});

test('mesafe ve süre okunur biçimde yazılır', () => {
  assert.equal(formatDistance(940), '940 m');
  assert.equal(formatDistance(12400), '12,4 km');
  assert.equal(formatDistance(0), '0 m');
  assert.equal(formatDistance(-5), '0 m');

  assert.equal(formatDuration(45000), '45 sn');
  assert.equal(formatDuration(12 * 60000), '12 dk');
  assert.equal(formatDuration(125 * 60000), '2 sa 5 dk');
  assert.equal(formatDuration(120 * 60000), '2 sa');
  assert.equal(formatDuration(0), '0 dk');
});

// ---------------------------------------------------------------- rapor

test('boş geçmiş sıfır rapor verir', () => {
  const report = tripReport([]);
  assert.equal(report.distanceM, 0);
  assert.equal(report.stops.length, 0);
  assert.equal(report.sampleCount, 0);
});

test('düz gidişte yol toplanır ve süre harekete yazılır', () => {
  // 45 saniyede bir, her adımda 0,001 derece kuzey (~111 m).
  const samples = [];
  for (let i = 0; i < 5; i++) samples.push(at(i * 45, LAT + i * 0.001, LNG, 50));

  const report = tripReport(samples);
  // 4 adım x ~111 m.
  assert.ok(Math.abs(report.distanceM - 444) < 10, `gelen ${report.distanceM}`);
  assert.equal(report.movingMs, 4 * 45000);
  assert.equal(report.stoppedMs, 0);
  assert.equal(report.stops.length, 0);
  assert.equal(report.maxSpeedKmh, 50);
});

test('giriş sırası karışık olsa da rapor aynı çıkar', () => {
  const ordered = [at(0, LAT, LNG, 40), at(45, LAT + 0.001, LNG, 40), at(90, LAT + 0.002, LNG, 40)];
  const shuffled = [ordered[2], ordered[0], ordered[1]];
  assert.deepEqual(tripReport(shuffled), tripReport(ordered));
});

test('dururken GPS titremesi yola eklenmez', () => {
  // Araç duruyor; konum birkaç metre oynuyor (eşik 8 m).
  const samples = [
    at(0, LAT, LNG, 0),
    at(45, LAT + 0.00002, LNG, 0),
    at(90, LAT, LNG + 0.00002, 0),
    at(135, LAT + 0.00001, LNG, 0),
  ];
  const report = tripReport(samples);
  assert.equal(report.distanceM, 0, 'titreme yola eklenmiş');
  assert.equal(report.movingMs, 0);
  assert.equal(report.stoppedMs, 3 * 45000);
});

test('uzun duruş durak sayılır, kısa duruş sayılmaz', () => {
  // 4 dakikalık duruş: eşik 3 dakika, durak olmalı.
  const uzun = [
    at(0, LAT, LNG, 30),
    at(45, LAT + 0.001, LNG, 0),
    at(285, LAT + 0.001, LNG, 0), // 240 sn duruş
    at(330, LAT + 0.002, LNG, 30),
  ];
  const r1 = tripReport(uzun);
  assert.equal(r1.stops.length, 1);
  assert.equal(r1.stops[0].durationMs, 240000);
  assert.ok(Math.abs(r1.stops[0].lat - (LAT + 0.001)) < 1e-9);

  // 90 saniyelik duruş: eşiğin altında, durak değil.
  const kisa = [
    at(0, LAT, LNG, 30),
    at(45, LAT + 0.001, LNG, 0),
    at(135, LAT + 0.001, LNG, 0),
    at(180, LAT + 0.002, LNG, 30),
  ];
  assert.equal(tripReport(kisa).stops.length, 0);
});

test('sıçrayan tek kayıt mesafeyi şişirmez', () => {
  // İkinci kayıt 45 saniyede ~11 km öteye atlamış: 890 km/s, imkânsız.
  const samples = [
    at(0, LAT, LNG, 60),
    at(45, LAT + 0.1, LNG, 60),
    at(90, LAT + 0.101, LNG, 60),
  ];
  const report = tripReport(samples);
  // Sıçrama atılır, yalnızca son adım (~111 m) sayılır.
  assert.ok(report.distanceM < 200, `sıçrama elenmemiş: ${report.distanceM}`);
  assert.ok(ReportThresholds.maxPlausibleKmh < 890);
});

test('konumu olmayan kayıtlar rapora girmez', () => {
  const samples = [
    at(0, 0, 0, 0),
    at(45, LAT, LNG, 40),
    at(90, LAT + 0.001, LNG, 40),
  ];
  const report = tripReport(samples);
  assert.equal(report.sampleCount, 2);
  assert.ok(Math.abs(report.distanceM - 111) < 5);
});

test('ortalama hız yalnızca hareket süresine bölünür', () => {
  // 1 km yol, 2 dakika hareket, 10 dakika duruş.
  const samples = [
    at(0, LAT, LNG, 30),
    at(120, LAT + 0.009, LNG, 30), // ~1000 m, 120 sn hareket
    at(720, LAT + 0.009, LNG, 0),  // 600 sn duruş
  ];
  const report = tripReport(samples);
  const avg = averageMovingSpeedKmh(report);
  // 1 km / 2 dk = 30 km/s. Duruş hesaba katılsaydı ~8 km/s çıkardı.
  assert.ok(Math.abs(avg - 30) < 2, `gelen ${avg}`);
  assert.equal(averageMovingSpeedKmh({ movingMs: 0, distanceM: 0 }), 0);
});
