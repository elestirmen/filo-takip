/// Yönetim ekranının saf mantığı: sıralama ve sayımlar.
///
/// Firebase, widget ya da zaman bağımlılığı yoktur; doğrudan birim testle
/// kaplanır.
library;

import '../models/group_config.dart';
import '../models/vehicle.dart';

/// Yönetici listesinin sırası: **onay bekleyenler üstte**, sonra plakaya
/// göre. Plakalar eşitse kimliğe göre; böylece sıra her yenilemede aynı
/// kalır ve liste gözle takip edilebilir.
List<Vehicle> sortVehiclesForAdmin(List<Vehicle> vehicles) {
  final List<Vehicle> sorted = List<Vehicle>.of(vehicles);
  sorted.sort((Vehicle a, Vehicle b) {
    if (a.approved != b.approved) return a.approved ? 1 : -1;
    final int byPlate = a.plate.compareTo(b.plate);
    if (byPlate != 0) return byPlate;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

/// Yönetim ekranındaki özet kartlarının sayıları.
class AdminSummary {
  const AdminSummary({
    required this.total,
    required this.pending,
    required this.approved,
    required this.groupCount,
  });

  factory AdminSummary.of(
    Iterable<Vehicle> vehicles,
    Iterable<GroupConfig> groups,
  ) {
    int total = 0;
    int pending = 0;
    for (final Vehicle vehicle in vehicles) {
      total++;
      if (!vehicle.approved) pending++;
    }
    return AdminSummary(
      total: total,
      pending: pending,
      approved: total - pending,
      groupCount: groups.length,
    );
  }

  final int total;
  final int pending;
  final int approved;
  final int groupCount;
}

/// Bir gruba atanmış araç sayısı. Grup listesinde gösterilir ve silmeden
/// önce kullanıcıyı uyarmak için kullanılır.
int vehicleCountInGroup(Iterable<Vehicle> vehicles, String groupId) {
  int count = 0;
  for (final Vehicle vehicle in vehicles) {
    if (vehicle.groupId == groupId) count++;
  }
  return count;
}

/// Yeni grup adı kabul edilebilir mi.
///
/// Boş olamaz ve var olan bir grupla çakışamaz. Karşılaştırma normalleşmiş
/// ad üzerinden yapılır; büyük/küçük harf farkı ayrı grup sayılır çünkü
/// grup adı aynı zamanda veritabanı anahtarıdır.
bool isGroupNameAvailable(String name, Iterable<GroupConfig> groups) {
  if (name.isEmpty) return false;
  for (final GroupConfig group in groups) {
    if (group.groupId == name) return false;
  }
  return true;
}
