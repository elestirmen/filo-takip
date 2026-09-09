/// Kimin hangi aracı göreceğini belirleyen kurallar.
///
/// Tamamı saf fonksiyondur: Firebase, widget ya da zaman bağımlılığı yoktur,
/// doğrudan birim testle kaplanır.
///
/// Not: bu kurallar bir **arayüz** filtresidir, güvenlik sınırı değildir.
/// Veritabanı kuralları `vehicles` düğümünü giriş yapmış herkese okutur.
library;

import '../models/group_config.dart';
import '../models/vehicle.dart';

/// Bu kullanıcıya görünecek araçlar. Giriş sırası korunur.
///
/// * Yönetici: tüm araçlar.
/// * Onaysız ya da grupsuz sürücü: yalnızca kendi aracı.
/// * Onaylı ve gruplu sürücü: kendi aracı + kendi grubu + grubunun
///   `visibleGroups` listesindeki gruplar. Kendisi dışındaki onaysız
///   araçlar gösterilmez.
List<Vehicle> visibleVehiclesFor({
  required List<Vehicle> allVehicles,
  required List<GroupConfig> groups,
  required String viewerUid,
  required bool isAdmin,
}) {
  if (isAdmin) return List<Vehicle>.of(allVehicles);

  final Vehicle? viewer = findVehicleById(allVehicles, viewerUid);
  // Kaydı olmayan sürücü henüz hiçbir şey görmez.
  if (viewer == null) return const <Vehicle>[];

  // Kendi aracı her zaman görünür, onaysız ve grupsuz olsa bile.
  if (!viewer.approved || !viewer.hasGroup) return <Vehicle>[viewer];

  final Set<String> allowed = allowedGroupIdsFor(
    viewerGroupId: viewer.groupId!,
    groups: groups,
  );

  return <Vehicle>[
    for (final Vehicle vehicle in allVehicles)
      if (vehicle.id == viewerUid ||
          (vehicle.approved &&
              vehicle.hasGroup &&
              allowed.contains(vehicle.groupId)))
        vehicle,
  ];
}

/// Sürücünün görebileceği grup kimlikleri: kendi grubu + ayarındaki gruplar.
Set<String> allowedGroupIdsFor({
  required String viewerGroupId,
  required List<GroupConfig> groups,
}) {
  final Set<String> allowed = <String>{viewerGroupId};
  final GroupConfig? config = findGroupById(groups, viewerGroupId);
  if (config != null) allowed.addAll(config.visibleGroups);
  return allowed;
}

/// Bir aracın hangi alanlarının gösterileceği.
class FieldVisibility {
  const FieldVisibility({
    required this.showSpeed,
    required this.showDriverName,
  });

  static const FieldVisibility full = FieldVisibility(
    showSpeed: true,
    showDriverName: true,
  );

  final bool showSpeed;
  final bool showDriverName;

  @override
  bool operator ==(Object other) {
    return other is FieldVisibility &&
        other.showSpeed == showSpeed &&
        other.showDriverName == showDriverName;
  }

  @override
  int get hashCode => Object.hash(showSpeed, showDriverName);

  @override
  String toString() =>
      'FieldVisibility(hız: $showSpeed, sürücü adı: $showDriverName)';
}

/// Alan gizleme, **bakılan aracın** grup ayarına göre yapılır: bir grup
/// kendi araçlarının hızını ya da sürücü adını başkalarından gizleyebilir.
///
/// İki istisna tam görünürlük verir:
/// * kullanıcı kendi aracına bakıyorsa,
/// * yöneticiye bakıyorsa (filoyu yönetebilmesi için).
FieldVisibility fieldVisibilityFor({
  required Vehicle vehicle,
  required List<GroupConfig> groups,
  required String viewerUid,
  required bool isAdmin,
}) {
  if (vehicle.id == viewerUid) return FieldVisibility.full;
  if (isAdmin) return FieldVisibility.full;
  if (!vehicle.hasGroup) return FieldVisibility.full;

  final GroupConfig? config = findGroupById(groups, vehicle.groupId!);
  if (config == null) return FieldVisibility.full;
  return FieldVisibility(
    showSpeed: config.showSpeed,
    showDriverName: config.showDriverName,
  );
}

/// Yönetici haritasındaki grup filtresi çipleri.
enum GroupFilterKind { all, ungrouped, specific }

class GroupFilter {
  const GroupFilter.all() : kind = GroupFilterKind.all, groupId = null;

  const GroupFilter.ungrouped()
    : kind = GroupFilterKind.ungrouped,
      groupId = null;

  const GroupFilter.group(String this.groupId) : kind = GroupFilterKind.specific;

  final GroupFilterKind kind;
  final String? groupId;

  bool matches(Vehicle vehicle) {
    switch (kind) {
      case GroupFilterKind.all:
        return true;
      case GroupFilterKind.ungrouped:
        return !vehicle.hasGroup;
      case GroupFilterKind.specific:
        return vehicle.groupId == groupId;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is GroupFilter &&
        other.kind == kind &&
        other.groupId == groupId;
  }

  @override
  int get hashCode => Object.hash(kind, groupId);
}

Vehicle? findVehicleById(List<Vehicle> vehicles, String id) {
  for (final Vehicle vehicle in vehicles) {
    if (vehicle.id == id) return vehicle;
  }
  return null;
}

GroupConfig? findGroupById(List<GroupConfig> groups, String groupId) {
  for (final GroupConfig group in groups) {
    if (group.groupId == groupId) return group;
  }
  return null;
}
