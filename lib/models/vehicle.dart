import '../core/db_parse.dart';

/// `/vehicles/{uid}` düğümü.
///
/// [id] doğrudan Firebase `auth.uid` değeridir; ayrı bir cihaz kimliği yoktur.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.driverName,
    required this.groupId,
    required this.approved,
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.updatedAt,
  });

  factory Vehicle.fromMap(String id, Object? raw) {
    final Map<String, Object?> map = dbMap(raw);
    return Vehicle(
      id: id,
      plate: dbString(map['plate']),
      driverName: dbString(map['driverName']),
      groupId: dbStringOrNull(map['groupId']),
      // Alan hiç yazılmamışsa onaysız sayılır.
      approved: dbBool(map['approved']),
      lat: dbDouble(map['lat']),
      lng: dbDouble(map['lng']),
      speedKmh: dbDouble(map['speedKmh']),
      updatedAt: dbInt(map['updatedAt']),
    );
  }

  /// Aracın kimliği = `auth.uid`.
  final String id;
  final String plate;
  final String driverName;

  /// Yalnızca yönetici yazar.
  final String? groupId;

  /// Yalnızca yönetici yazar.
  final bool approved;

  final double lat;
  final double lng;
  final double speedKmh;

  /// Sunucu zamanı (ms). Cihaz saatiyle doğrudan karşılaştırılmaz;
  /// `FleetRepository.nowMs()` kullanılır.
  final int updatedAt;

  bool get hasGroup => groupId != null && groupId!.isNotEmpty;

  /// Hiç konum yazılmamış araçları haritada göstermemek için.
  bool get hasLocation => updatedAt > 0;

  Vehicle copyWith({
    String? plate,
    String? driverName,
    String? groupId,
    bool clearGroupId = false,
    bool? approved,
    double? lat,
    double? lng,
    double? speedKmh,
    int? updatedAt,
  }) {
    return Vehicle(
      id: id,
      plate: plate ?? this.plate,
      driverName: driverName ?? this.driverName,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      approved: approved ?? this.approved,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      speedKmh: speedKmh ?? this.speedKmh,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Düğümün tamamı.
  ///
  /// **Yazma yolunda kullanılmaz.** Araç düğümüne `set()` ile tam yazmak
  /// arka plandaki konum güncellemesini ezer; ayrıca güvenlik kuralları
  /// sürücüye düğümün tamamını yazma izni vermez. Kısmi güncellemeler için
  /// `FleetRepository` içindeki `update()` çağrıları kullanılır.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'plate': plate,
      'driverName': driverName,
      'groupId': groupId,
      'approved': approved,
      'lat': lat,
      'lng': lng,
      'speedKmh': speedKmh,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() => 'Vehicle($id, $plate, grup: $groupId, onay: $approved)';
}
