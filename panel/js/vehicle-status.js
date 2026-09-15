// Aracın haritadaki durumu ve filo özeti.
// lib/core/vehicle_status.dart dosyasının karşılığı; eşikler birebir aynıdır
// ki panelle uygulama aynı aracı aynı renkte göstersin.

import { Strings } from './strings.js';

export const VehicleStatus = Object.freeze({
  moving: 'moving',
  stopped: 'stopped',
  offline: 'offline',
  pending: 'pending',
});

export const StatusThresholds = Object.freeze({
  // Bu süreden eski updatedAt çevrimdışı sayılır.
  offlineAfterMs: 5 * 60 * 1000,
  // Bu hızın üzerindeki araç hareket halinde sayılır.
  movingAboveKmh: 3,
});

// Aracın son güncellemesi bayat mı.
//
// nowMs, arka ucun sunucu ofsetiyle düzeltilmiş "şu an" değeridir. Tarayıcı
// saati doğrudan kullanılmaz, çünkü updatedAt sunucu zamanıdır.
export function isStale(vehicle, nowMs) {
  // Hiç konum yazılmamış araç da bayat sayılır.
  if (vehicle.updatedAt <= 0) return true;
  return nowMs - vehicle.updatedAt > StatusThresholds.offlineAfterMs;
}

// Öncelik sırası: onay bekliyor > çevrimdışı > hareketli / duruyor.
// Onaysız araç hareket ediyor olsa bile turuncu kalır; yöneticinin işlem
// yapması gereken durum budur.
export function vehicleStatusOf(vehicle, nowMs) {
  if (!vehicle.approved) return VehicleStatus.pending;
  if (isStale(vehicle, nowMs)) return VehicleStatus.offline;
  if (vehicle.speedKmh > StatusThresholds.movingAboveKmh) return VehicleStatus.moving;
  return VehicleStatus.stopped;
}

// Renkler uygulamadaki widgets/status_visuals.dart ile aynı.
const STATUS_COLORS = Object.freeze({
  [VehicleStatus.moving]: '#2E7D32',
  [VehicleStatus.stopped]: '#C62828',
  [VehicleStatus.offline]: '#6D6D6D',
  [VehicleStatus.pending]: '#EF6C00',
});

const STATUS_LABELS = Object.freeze({
  [VehicleStatus.moving]: Strings.mapStatusMoving,
  [VehicleStatus.stopped]: Strings.mapStatusStopped,
  [VehicleStatus.offline]: Strings.mapStatusOffline,
  [VehicleStatus.pending]: Strings.mapStatusPending,
});

export function statusColor(status) {
  return STATUS_COLORS[status];
}

export function statusLabel(status) {
  return STATUS_LABELS[status];
}

// Harita üstündeki özet kartının sayıları.
export function fleetSummaryOf(vehicles, nowMs) {
  const summary = { total: 0, moving: 0, stopped: 0, offline: 0, pending: 0 };
  for (const vehicle of vehicles) {
    summary.total++;
    summary[vehicleStatusOf(vehicle, nowMs)]++;
  }
  return summary;
}
