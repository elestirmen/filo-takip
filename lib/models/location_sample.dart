import '../core/db_parse.dart';

/// `/locationHistory/{uid}/{pushId}` düğümü.
///
/// Yalnızca yönetici bir aracın geçmişini açtığında, tek seferlik okunur.
class LocationSample {
  const LocationSample({
    required this.id,
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.recordedAt,
  });

  factory LocationSample.fromMap(String id, Object? raw) {
    final Map<String, Object?> map = dbMap(raw);
    return LocationSample(
      id: id,
      lat: dbDouble(map['lat']),
      lng: dbDouble(map['lng']),
      speedKmh: dbDouble(map['speedKmh']),
      recordedAt: dbInt(map['recordedAt']),
    );
  }

  /// RTDB push anahtarı.
  final String id;
  final double lat;
  final double lng;
  final double speedKmh;

  /// Sunucu zamanı (ms).
  final int recordedAt;

  /// Yazma yolunda kullanılmaz: kayıt eklenirken `recordedAt` yerine
  /// `ServerValue.timestamp` gönderilir (bkz. `FleetRepository`).
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'lat': lat,
      'lng': lng,
      'speedKmh': speedKmh,
      'recordedAt': recordedAt,
    };
  }

  @override
  String toString() => 'LocationSample($id, $lat, $lng, $recordedAt)';
}
