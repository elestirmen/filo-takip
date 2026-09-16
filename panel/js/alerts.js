// Uyarı tespiti: hız aşımı, çevrimdışına düşme ve bölge giriş/çıkışı.
//
// Saf fonksiyondur. Durumu dışarıda tutulur ve her çağrıda geri verilir, bu
// yüzden birim testle kaplanabilir.
//
// Kural: uyarı **geçiş anında** üretilir, durum sürdüğü sürece değil. Hız
// sınırını aşan araç her tikte değil, aştığı anda bir kez uyarır; sınırın
// altına inip tekrar aşarsa yeniden uyarır. Aksi hâlde panel saniyede bir
// aynı uyarıyı yağdırırdı.

import { VehicleStatus, vehicleStatusOf } from './vehicle-status.js';
import { findGroupById } from './visibility-rules.js';
import { isInsideCircle } from './geo.js';

export const AlertKind = Object.freeze({
  speeding: 'speeding',
  offline: 'offline',
  geofenceEnter: 'geofenceEnter',
  geofenceExit: 'geofenceExit',
});

// Bir aracın izlenen durumu. detectAlerts bunu üretir ve bir sonraki çağrıda
// geri ister.
function snapshotOf(vehicle, { status, speeding, zoneIds }) {
  return { id: vehicle.id, status, speeding, zoneIds };
}

// Aracın tabi olduğu hız sınırı; grubundan gelir, 0 ise sınır yok.
export function speedLimitFor(vehicle, groups) {
  if (!vehicle.hasGroup) return 0;
  const group = findGroupById(groups, vehicle.groupId);
  return group === null ? 0 : group.speedLimitKmh;
}

// previous: Map<vehicleId, snapshot> (ilk çağrıda boş)
//
// İlk çağrıda hiç uyarı üretilmez: panel açılır açılmaz geçmişteki her durum
// için bildirim yağması anlamsız olurdu, yalnızca başlangıç durumu kaydedilir.
export function detectAlerts({ vehicles, groups, geofences, previous, nowMs }) {
  const first = previous.size === 0;
  const next = new Map();
  const alerts = [];

  for (const vehicle of vehicles) {
    const status = vehicleStatusOf(vehicle, nowMs);
    const limit = speedLimitFor(vehicle, groups);
    const speeding = limit > 0 && vehicle.speedKmh > limit;

    const zoneIds = new Set();
    if (vehicle.hasLocation) {
      for (const zone of geofences) {
        if (isInsideCircle(vehicle.lat, vehicle.lng, zone.lat, zone.lng, zone.radiusM)) {
          zoneIds.add(zone.id);
        }
      }
    }

    const before = previous.get(vehicle.id);
    next.set(vehicle.id, snapshotOf(vehicle, { status, speeding, zoneIds }));
    if (first || before === undefined) continue;

    if (speeding && !before.speeding) {
      alerts.push({
        kind: AlertKind.speeding,
        vehicleId: vehicle.id,
        plate: vehicle.plate,
        at: nowMs,
        speedKmh: vehicle.speedKmh,
        limitKmh: limit,
      });
    }

    if (status === VehicleStatus.offline && before.status !== VehicleStatus.offline) {
      alerts.push({
        kind: AlertKind.offline,
        vehicleId: vehicle.id,
        plate: vehicle.plate,
        at: nowMs,
      });
    }

    for (const zone of geofences) {
      const inside = zoneIds.has(zone.id);
      const wasInside = before.zoneIds.has(zone.id);
      if (inside === wasInside) continue;
      alerts.push({
        kind: inside ? AlertKind.geofenceEnter : AlertKind.geofenceExit,
        vehicleId: vehicle.id,
        plate: vehicle.plate,
        at: nowMs,
        zoneId: zone.id,
        zoneName: zone.name,
      });
    }
  }

  return { alerts, next };
}
