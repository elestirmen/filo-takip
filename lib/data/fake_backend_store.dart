import 'dart:async';
import 'dart:math';

import '../models/group_config.dart';
import '../models/location_sample.dart';
import '../models/vehicle.dart';
import 'fleet_repository.dart';
import 'latest_value.dart';

/// Firebase yerine geçen, bellek içi sahte arka uç.
///
/// Uygulama boyunca tek örnek yaşar. Repository örnekleri oturum değişince
/// yeniden kurulur; veri burada durduğu için sürücüden yöneticiye geçerken
/// yapılan kayıtlar kaybolmaz.
///
/// Veriler diske yazılmaz: uygulama kapanınca her şey başlangıç durumuna
/// döner. Gerçek Firebase'e geçmek için:
/// `flutter run --dart-define=BACKEND=firebase`
class FakeBackendStore {
  FakeBackendStore._() {
    _seed();
    _publish();
    // Tek örnek uygulama boyunca yaşadığı için zamanlayıcı iptal edilmez.
    Timer.periodic(tick, (_) => _moveVehicles());
  }

  static final FakeBackendStore instance = FakeBackendStore._();

  /// Bu cihazın sahte sürücü oturumu.
  static const String driverUid = 'sim-surucu';

  /// Sahte yönetici oturumu ve girişi.
  static const String adminUid = 'sim-yonetici';
  static const String adminEmail = 'yonetici@ornek.com';
  static const String adminPassword = '123456';

  /// Sahte araçların dağıldığı merkez; harita ekranıyla aynı nokta.
  /// (Bu koordinat Nevşehir merkezidir, bkz. MapScreen.)
  static const double centerLat = 38.6246;
  static const double centerLng = 34.7142;

  /// Sahte araçların hareket ettirilme sıklığı; gerçek konum aralığıyla aynı.
  static const Duration tick = Duration(seconds: 5);

  final Map<String, Vehicle> _vehicles = <String, Vehicle>{};
  final Map<String, GroupConfig> _groups = <String, GroupConfig>{};
  final Map<String, List<LocationSample>> _history =
      <String, List<LocationSample>>{};
  final Map<String, _Motion> _motions = <String, _Motion>{};
  final Set<String> _admins = <String>{adminUid};

  final LatestValue<List<Vehicle>> vehicles = LatestValue<List<Vehicle>>(
    const <Vehicle>[],
  );
  final LatestValue<List<GroupConfig>> groups = LatestValue<List<GroupConfig>>(
    const <GroupConfig>[],
  );

  final Random _random = Random(42);
  int _pushCounter = 0;

  bool isAdmin(String userId) => _admins.contains(userId);

  List<LocationSample> history(String vehicleId) {
    final List<LocationSample> samples = List<LocationSample>.of(
      _history[vehicleId] ?? const <LocationSample>[],
    );
    samples.sort(
      (LocationSample a, LocationSample b) =>
          b.recordedAt.compareTo(a.recordedAt),
    );
    if (samples.length > FleetRepository.historyReadLimit) {
      return samples.sublist(0, FleetRepository.historyReadLimit);
    }
    return samples;
  }

  // -------------------------------------------------------------- Yazma

  /// Yalnızca iki alanı değiştirir; araç yoksa oluşturur.
  /// `approved` ve `groupId` alanlarına dokunmaz.
  void saveRegistration(
    String vehicleId, {
    required String plate,
    required String driverName,
  }) {
    final Vehicle? current = _vehicles[vehicleId];
    if (current == null) {
      _vehicles[vehicleId] = Vehicle(
        id: vehicleId,
        plate: plate,
        driverName: driverName,
        groupId: null,
        approved: false,
        lat: 0,
        lng: 0,
        speedKmh: 0,
        updatedAt: 0,
      );
    } else {
      _vehicles[vehicleId] = current.copyWith(
        plate: plate,
        driverName: driverName,
      );
    }
    _publish();
  }

  void writeLocation(
    String vehicleId, {
    required double lat,
    required double lng,
    required double speedKmh,
  }) {
    final Vehicle? current = _vehicles[vehicleId];
    if (current == null) return;
    // Gerçek konum gelen aracı artık sahte hareketle oynatma; yoksa servisin
    // yazdığı konumu 5 saniyede bir zamanlayıcı ezer.
    _motions.remove(vehicleId);
    _vehicles[vehicleId] = current.copyWith(
      lat: lat,
      lng: lng,
      speedKmh: speedKmh,
      updatedAt: nowMs(),
    );
    _publish();
  }

  void appendHistory(
    String vehicleId, {
    required double lat,
    required double lng,
    required double speedKmh,
    int? recordedAt,
  }) {
    final List<LocationSample> samples = _history.putIfAbsent(
      vehicleId,
      () => <LocationSample>[],
    );
    samples.add(
      LocationSample(
        id: _nextPushId(),
        lat: lat,
        lng: lng,
        speedKmh: speedKmh,
        recordedAt: recordedAt ?? nowMs(),
      ),
    );
    // Gerçek arka uçtaki budamanın karşılığı.
    while (samples.length > FleetRepository.historyMaxRecords) {
      samples.removeAt(0);
    }
  }

  void setApproved(String vehicleId, {required bool approved}) {
    final Vehicle? current = _vehicles[vehicleId];
    if (current == null) return;
    _vehicles[vehicleId] = current.copyWith(approved: approved);
    _publish();
  }

  void setGroup(String vehicleId, String? groupId) {
    final Vehicle? current = _vehicles[vehicleId];
    if (current == null) return;
    _vehicles[vehicleId] = current.copyWith(
      groupId: groupId,
      clearGroupId: groupId == null,
    );
    _publish();
  }

  /// Araç düğümü ve konum geçmişi birlikte gider.
  void deleteVehicle(String vehicleId) {
    _vehicles.remove(vehicleId);
    _history.remove(vehicleId);
    _motions.remove(vehicleId);
    _publish();
  }

  void saveGroup(GroupConfig config) {
    _groups[config.groupId] = config;
    _publish();
  }

  /// Grubu siler, bağlı araçların atamasını ve diğer grupların görünür
  /// listelerini aynı anda temizler.
  void deleteGroup(String groupId) {
    _groups.remove(groupId);
    for (final MapEntry<String, Vehicle> entry in _vehicles.entries.toList()) {
      if (entry.value.groupId == groupId) {
        _vehicles[entry.key] = entry.value.copyWith(clearGroupId: true);
      }
    }
    for (final MapEntry<String, GroupConfig> entry
        in _groups.entries.toList()) {
      if (!entry.value.visibleGroups.contains(groupId)) continue;
      _groups[entry.key] = entry.value.copyWith(
        visibleGroups: entry.value.visibleGroups
            .where((String id) => id != groupId)
            .toList(),
      );
    }
    _publish();
  }

  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  // ------------------------------------------------------------ İçeriler

  String _nextPushId() {
    _pushCounter++;
    // Gerçek push anahtarları gibi sıralanabilir olsun diye sabit genişlik.
    return 'sim-${_pushCounter.toString().padLeft(6, '0')}';
  }

  void _publish() {
    final List<Vehicle> vehicleList = _vehicles.values.toList()
      ..sort((Vehicle a, Vehicle b) => a.plate.compareTo(b.plate));
    final List<GroupConfig> groupList = _groups.values.toList()
      ..sort((GroupConfig a, GroupConfig b) => a.groupId.compareTo(b.groupId));
    vehicles.add(vehicleList);
    groups.add(groupList);
  }

  void _seed() {
    _groups['Kaman'] = const GroupConfig(
      groupId: 'Kaman',
      visibleGroups: <String>[],
      showSpeed: true,
      // Hız görünür, sürücü adı gizli: alan gizleme mantığını denemek için.
      showDriverName: false,
    );
    _groups['Merkez'] = const GroupConfig(
      groupId: 'Merkez',
      visibleGroups: <String>['Kaman'],
      showSpeed: true,
      showDriverName: true,
    );
    _groups['Mucur'] = const GroupConfig(
      groupId: 'Mucur',
      visibleGroups: <String>['Merkez', 'Kaman'],
      showSpeed: false,
      showDriverName: true,
    );

    // Bu cihazın aracı: kayıtlı, onaylı ve Merkez grubunda. Kayıt ekranındaki
    // "yeni kayıt" akışını denemek için Yönetim sekmesinden silebilirsin.
    _add(
      id: driverUid,
      plate: '40 ABC 001',
      driverName: 'Bu Cihaz',
      groupId: 'Merkez',
      approved: true,
      dLat: 0.004,
      dLng: -0.006,
      speedKmh: 38,
    );
    _add(
      id: 'sim-2',
      plate: '40 DEF 202',
      driverName: 'Ahmet Yıldız',
      groupId: 'Merkez',
      approved: true,
      dLat: -0.010,
      dLng: 0.013,
      // Duruyor: kırmızı işaretçi.
      speedKmh: 0,
    );
    _add(
      id: 'sim-3',
      plate: '40 GHI 303',
      driverName: 'Ayşe Demir',
      groupId: 'Kaman',
      approved: true,
      dLat: 0.021,
      dLng: 0.018,
      speedKmh: 64,
    );
    _add(
      id: 'sim-4',
      plate: '40 JKL 404',
      driverName: 'Zeynep Arslan',
      groupId: 'Mucur',
      approved: true,
      dLat: -0.024,
      dLng: -0.019,
      speedKmh: 51,
      // Çevrimdışı: son güncelleme 22 dakika önce, gri işaretçi.
      ageMs: 22 * 60 * 1000,
    );
    _add(
      id: 'sim-5',
      plate: '40 MNO 505',
      driverName: 'Hasan Çelik',
      groupId: null,
      approved: true,
      dLat: 0.013,
      dLng: -0.021,
      speedKmh: 27,
    );
    _add(
      id: 'sim-6',
      plate: '40 PRS 606',
      driverName: 'Elif Korkmaz',
      groupId: null,
      // Onay bekliyor: turuncu işaretçi.
      approved: false,
      dLat: -0.006,
      dLng: 0.009,
      speedKmh: 12,
    );
  }

  void _add({
    required String id,
    required String plate,
    required String driverName,
    required String? groupId,
    required bool approved,
    required double dLat,
    required double dLng,
    required double speedKmh,
    int ageMs = 0,
  }) {
    final int now = nowMs();
    final double lat = centerLat + dLat;
    final double lng = centerLng + dLng;
    _vehicles[id] = Vehicle(
      id: id,
      plate: plate,
      driverName: driverName,
      groupId: groupId,
      approved: approved,
      lat: lat,
      lng: lng,
      speedKmh: speedKmh,
      updatedAt: now - ageMs,
    );
    _motions[id] = _Motion(
      heading: _random.nextDouble() * 2 * pi,
      speedKmh: speedKmh,
      frozen: ageMs > 0,
    );

    // Yönetim ekranındaki konum geçmişi boş kalmasın diye geçmişe doğru
    // 120 kayıt üret; aralık gerçek yazma aralığıyla aynı.
    final int step = FleetRepository.historyMinInterval.inMilliseconds;
    for (int i = 120; i > 0; i--) {
      appendHistory(
        id,
        lat: lat - dLat * i / 400,
        lng: lng - dLng * i / 400,
        speedKmh: speedKmh == 0
            ? 0.0
            : max(0.0, speedKmh + _random.nextInt(15) - 7),
        recordedAt: now - ageMs - i * step,
      );
    }
  }

  void _moveVehicles() {
    bool changed = false;
    for (final MapEntry<String, _Motion> entry in _motions.entries) {
      final _Motion motion = entry.value;
      // Çevrimdışı araç hiç güncellenmez; updatedAt eskidikçe gri kalır.
      if (motion.frozen) continue;

      final Vehicle? current = _vehicles[entry.key];
      if (current == null) continue;

      double lat = current.lat;
      double lng = current.lng;
      if (motion.speedKmh > 0) {
        motion.heading += (_random.nextDouble() - 0.5) * 0.7;
        final double metres =
            motion.speedKmh * 1000 / 3600 * tick.inSeconds.toDouble();
        lat += metres * cos(motion.heading) / 111320;
        lng +=
            metres * sin(motion.heading) / (111320 * cos(lat * pi / 180));
        // Merkezden fazla uzaklaşırsa geri döndür.
        if ((lat - centerLat).abs() > 0.05 || (lng - centerLng).abs() > 0.05) {
          motion.heading += pi;
          lat = current.lat;
          lng = current.lng;
        }
      }

      _vehicles[entry.key] = current.copyWith(
        lat: lat,
        lng: lng,
        speedKmh: motion.speedKmh,
        updatedAt: nowMs(),
      );
      changed = true;
    }
    if (changed) _publish();
  }
}

/// Sahte aracın hareket durumu.
class _Motion {
  _Motion({
    required this.heading,
    required this.speedKmh,
    required this.frozen,
  });

  double heading;
  final double speedKmh;

  /// true ise araç hiç güncellenmez, çevrimdışı görünür.
  final bool frozen;
}
