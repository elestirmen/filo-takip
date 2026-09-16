import '../core/db_parse.dart';

/// `/groupConfigs/{groupId}` düğümü. Yalnızca yönetici yazar.
class GroupConfig {
  const GroupConfig({
    required this.groupId,
    required this.visibleGroups,
    required this.showSpeed,
    required this.showDriverName,
    this.speedLimitKmh = 0,
  });

  factory GroupConfig.fromMap(String id, Object? raw) {
    final Map<String, Object?> map = dbMap(raw);
    return GroupConfig(
      // Düğüm anahtarı asıl kaynaktır; alan eksikse ona düşülür.
      groupId: dbString(map['groupId'], fallback: id),
      visibleGroups: dbStringList(map['visibleGroups']),
      // Alan yazılmamışsa gizleme yok: yeni grup her şeyi gösterir.
      showSpeed: dbBool(map['showSpeed'], fallback: true),
      showDriverName: dbBool(map['showDriverName'], fallback: true),
      // Web panelinde tanımlanır; 0 ise sınır yok. Uygulama bu alanı
      // göstermez ama **taşımak zorundadır**: aşağıdaki toMap düğümün
      // tamamını yazdığı için, alan burada okunmazsa panelde girilen sınır
      // uygulamadan yapılan ilk grup düzenlemesinde silinirdi.
      speedLimitKmh: dbInt(map['speedLimitKmh']),
    );
  }

  final String groupId;

  /// Bu grubun araçlarının ek olarak görebileceği grup kimlikleri.
  final List<String> visibleGroups;

  final bool showSpeed;
  final bool showDriverName;

  /// Hız aşımı uyarısı eşiği (km/s), 0 ise sınır yok. Yalnızca web paneli
  /// okur ve yazar; uygulama değeri korur.
  final int speedLimitKmh;

  GroupConfig copyWith({
    List<String>? visibleGroups,
    bool? showSpeed,
    bool? showDriverName,
    int? speedLimitKmh,
  }) {
    return GroupConfig(
      groupId: groupId,
      visibleGroups: visibleGroups ?? this.visibleGroups,
      showSpeed: showSpeed ?? this.showSpeed,
      showDriverName: showDriverName ?? this.showDriverName,
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'groupId': groupId,
      'visibleGroups': visibleGroups,
      'showSpeed': showSpeed,
      'showDriverName': showDriverName,
      'speedLimitKmh': speedLimitKmh,
    };
  }

  @override
  String toString() => 'GroupConfig($groupId, görünür: $visibleGroups)';
}
