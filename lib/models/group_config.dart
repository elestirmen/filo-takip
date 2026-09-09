import '../core/db_parse.dart';

/// `/groupConfigs/{groupId}` düğümü. Yalnızca yönetici yazar.
class GroupConfig {
  const GroupConfig({
    required this.groupId,
    required this.visibleGroups,
    required this.showSpeed,
    required this.showDriverName,
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
    );
  }

  final String groupId;

  /// Bu grubun araçlarının ek olarak görebileceği grup kimlikleri.
  final List<String> visibleGroups;

  final bool showSpeed;
  final bool showDriverName;

  GroupConfig copyWith({
    List<String>? visibleGroups,
    bool? showSpeed,
    bool? showDriverName,
  }) {
    return GroupConfig(
      groupId: groupId,
      visibleGroups: visibleGroups ?? this.visibleGroups,
      showSpeed: showSpeed ?? this.showSpeed,
      showDriverName: showDriverName ?? this.showDriverName,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'groupId': groupId,
      'visibleGroups': visibleGroups,
      'showSpeed': showSpeed,
      'showDriverName': showDriverName,
    };
  }

  @override
  String toString() => 'GroupConfig($groupId, görünür: $visibleGroups)';
}
