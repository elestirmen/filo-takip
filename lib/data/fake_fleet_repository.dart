import 'dart:async';

import '../models/group_config.dart';
import '../models/location_sample.dart';
import '../models/vehicle.dart';
import 'fake_backend_store.dart';
import 'fleet_repository.dart';
import 'latest_value.dart';

/// [FleetRepository] arayüzünün simülasyon uygulaması.
///
/// Veriyi [FakeBackendStore] tutar; bu sınıf yalnızca ona bakan ince bir
/// katmandır. Gerçek uygulamadaki gecikmelerin görülebilmesi için yazma
/// çağrılarına küçük bir gecikme eklenir.
class FakeFleetRepository implements FleetRepository {
  FakeFleetRepository({required this.uid})
    : _store = FakeBackendStore.instance {
    _isAdmin = LatestValue<bool>(_store.isAdmin(uid));
  }

  static const Duration _latency = Duration(milliseconds: 180);

  @override
  final String uid;

  final FakeBackendStore _store;
  late final LatestValue<bool> _isAdmin;
  final StreamController<String> _errors = StreamController<String>.broadcast();

  int? _lastHistoryWriteAtMs;

  // ------------------------------------------------------------- Akışlar

  @override
  Stream<List<Vehicle>> get vehicles => _store.vehicles.stream;

  @override
  List<Vehicle> get latestVehicles => _store.vehicles.latest;

  @override
  Stream<List<GroupConfig>> get groupConfigs => _store.groups.stream;

  @override
  List<GroupConfig> get latestGroupConfigs => _store.groups.latest;

  @override
  Stream<bool> get isAdmin => _isAdmin.stream;

  @override
  bool get latestIsAdmin => _isAdmin.latest;

  /// Simülasyonda hata üretilmez; akış arayüz uyumu için vardır.
  @override
  Stream<String> get errors => _errors.stream;

  /// Simülasyonda sunucu ofseti yoktur, cihaz saati kullanılır.
  @override
  int nowMs() => _store.nowMs();

  // -------------------------------------------------------------- Yazma

  @override
  Future<void> saveRegistration({
    required String plate,
    required String driverName,
  }) async {
    await Future<void>.delayed(_latency);
    _store.saveRegistration(uid, plate: plate, driverName: driverName);
  }

  @override
  Future<void> writeLocation({
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    _store.writeLocation(uid, lat: lat, lng: lng, speedKmh: speedKmh);

    // Gerçek uygulamadaki seyreltmenin aynısı.
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int? last = _lastHistoryWriteAtMs;
    final bool tooSoon =
        last != null &&
        now >= last &&
        now - last < FleetRepository.historyMinInterval.inMilliseconds;
    if (tooSoon) return;
    _lastHistoryWriteAtMs = now;
    _store.appendHistory(uid, lat: lat, lng: lng, speedKmh: speedKmh);
  }

  @override
  Future<void> setVehicleApproved(
    String vehicleId, {
    required bool approved,
  }) async {
    await Future<void>.delayed(_latency);
    _store.setApproved(vehicleId, approved: approved);
  }

  @override
  Future<void> setVehicleGroup(String vehicleId, String? groupId) async {
    await Future<void>.delayed(_latency);
    _store.setGroup(vehicleId, groupId);
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    await Future<void>.delayed(_latency);
    _store.deleteVehicle(vehicleId);
  }

  @override
  Future<void> saveGroupConfig(GroupConfig config) async {
    await Future<void>.delayed(_latency);
    _store.saveGroup(config);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await Future<void>.delayed(_latency);
    _store.deleteGroup(groupId);
  }

  // -------------------------------------------------------------- Okuma

  @override
  Future<List<LocationSample>> loadHistory(String vehicleId) async {
    await Future<void>.delayed(_latency);
    return _store.history(vehicleId);
  }

  @override
  Future<bool> isAdminOnce(String userId) async {
    await Future<void>.delayed(_latency);
    return _store.isAdmin(userId);
  }

  @override
  void dispose() {
    // Store paylaşılan ve kalıcı olduğu için burada kapatılmaz; yalnızca bu
    // örneğe ait akışlar kapatılır.
    unawaited(_isAdmin.close());
    unawaited(_errors.close());
  }
}
