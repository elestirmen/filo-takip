import 'dart:math';

import '../models/vehicle.dart';

/// Aracın haritadaki durumu. İşaretçi rengi buradan seçilir.
enum VehicleStatus {
  /// Hareket halinde (yeşil).
  moving,

  /// Duruyor (kırmızı).
  stopped,

  /// Son güncellemesi bayat (gri).
  offline,

  /// Yönetici onayı bekliyor (turuncu).
  pending,
}

/// Durum eşikleri tek yerde.
class StatusThresholds {
  const StatusThresholds._();

  /// Bu süreden eski `updatedAt` çevrimdışı sayılır.
  static const Duration offlineAfter = Duration(minutes: 5);

  /// Bu hızın üzerindeki araç hareket halinde sayılır.
  static const double movingAboveKmh = 3;
}

/// Aracın son güncellemesi bayat mı.
///
/// [nowMs] `FleetRepository.nowMs()` değeridir: cihaz saati + sunucu ofseti.
/// Cihaz saati doğrudan kullanılmaz, çünkü `updatedAt` sunucu zamanıdır.
bool isStale(Vehicle vehicle, {required int nowMs}) {
  // Hiç konum yazılmamış araç da bayat sayılır.
  if (vehicle.updatedAt <= 0) return true;
  final int age = nowMs - vehicle.updatedAt;
  return age > StatusThresholds.offlineAfter.inMilliseconds;
}

/// Aracın durumu.
///
/// Öncelik sırası: onay bekliyor > çevrimdışı > hareketli / duruyor.
/// Onaysız araç, hareket ediyor olsa bile turuncu kalır; yöneticinin
/// işlem yapması gereken durum budur.
VehicleStatus vehicleStatusOf(Vehicle vehicle, {required int nowMs}) {
  if (!vehicle.approved) return VehicleStatus.pending;
  if (isStale(vehicle, nowMs: nowMs)) return VehicleStatus.offline;
  if (vehicle.speedKmh > StatusThresholds.movingAboveKmh) {
    return VehicleStatus.moving;
  }
  return VehicleStatus.stopped;
}

/// Konum sağlayıcısından gelen m/s hızını km/s'ye çevirir.
///
/// Bazı cihazlar duruyorken küçük negatif değerler ya da NaN döndürür;
/// ikisi de sıfıra çekilir.
double speedKmhFromMps(double metresPerSecond) {
  if (!metresPerSecond.isFinite) return 0;
  return max(0, metresPerSecond * 3.6);
}

/// Harita üstündeki özet kartının sayıları.
class FleetSummary {
  const FleetSummary({
    required this.total,
    required this.moving,
    required this.stopped,
    required this.offline,
    required this.pending,
  });

  factory FleetSummary.of(Iterable<Vehicle> vehicles, {required int nowMs}) {
    int total = 0;
    int moving = 0;
    int stopped = 0;
    int offline = 0;
    int pending = 0;
    for (final Vehicle vehicle in vehicles) {
      total++;
      switch (vehicleStatusOf(vehicle, nowMs: nowMs)) {
        case VehicleStatus.moving:
          moving++;
        case VehicleStatus.stopped:
          stopped++;
        case VehicleStatus.offline:
          offline++;
        case VehicleStatus.pending:
          pending++;
      }
    }
    return FleetSummary(
      total: total,
      moving: moving,
      stopped: stopped,
      offline: offline,
      pending: pending,
    );
  }

  final int total;
  final int moving;
  final int stopped;
  final int offline;
  final int pending;
}
