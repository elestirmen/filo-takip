import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/db_parse.dart';
import '../core/strings.dart';
import '../models/group_config.dart';
import '../models/location_sample.dart';
import '../models/vehicle.dart';
import 'backend_exception.dart';
import 'fleet_repository.dart';
import 'latest_value.dart';

/// Gerçek arka uç: Firebase Realtime Database.
///
/// Veritabanı kökü **asla** dinlenmez; `vehicles` ve `groupConfigs` için ayrı
/// dinleyiciler kurulur. `locationHistory` yalnızca istek üzerine, tek
/// seferlik ve sınırlı okunur.
class FirebaseFleetRepository implements FleetRepository {
  FirebaseFleetRepository({required this.uid, FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance {
    _vehiclesSubscription = _database
        .ref(_vehiclesPath)
        .onValue
        .listen(
          (DatabaseEvent event) => _vehicles.add(_vehiclesFrom(event)),
          onError: (Object _) => _report(Strings.errorVehiclesStream),
        );

    _groupsSubscription = _database
        .ref(_groupConfigsPath)
        .onValue
        .listen(
          (DatabaseEvent event) => _groups.add(_groupsFrom(event)),
          onError: (Object _) => _report(Strings.errorGroupConfigsStream),
        );

    _adminSubscription = _database
        .ref('$_adminsPath/$uid')
        .onValue
        .listen(
          (DatabaseEvent event) => _isAdmin.add(_adminFrom(event.snapshot)),
          onError: (Object _) => _report(Strings.errorAdminStream),
        );

    // Sunucu ile cihaz saati arasındaki fark. Bayatlık hesabında tek
    // "şu an" kaynağı budur; okunamazsa 0 kalır ve cihaz saati kullanılır.
    _offsetSubscription = _database
        .ref(_serverTimeOffsetPath)
        .onValue
        .listen(
          (DatabaseEvent event) =>
              _serverTimeOffsetMs = dbInt(event.snapshot.value),
          onError: (Object _) {},
        );
  }

  static const String _vehiclesPath = 'vehicles';
  static const String _groupConfigsPath = 'groupConfigs';
  static const String _locationHistoryPath = 'locationHistory';
  static const String _adminsPath = 'admins';
  static const String _serverTimeOffsetPath = '.info/serverTimeOffset';

  /// Kaç geçmiş kaydında bir budama denenir. 40 x 45 sn, yaklaşık 30 dakika.
  static const int _pruneEveryWrites = 40;

  /// Bir budama turunda silinecek en fazla kayıt.
  static const int _pruneBatchSize = 200;

  @override
  final String uid;

  final FirebaseDatabase _database;

  // pending: ilk anlık görüntü gelene kadar akış susar, ekranlar
  // "yükleniyor" ile "hiç kayıt yok" durumlarını karıştırmaz.
  final LatestValue<List<Vehicle>> _vehicles =
      LatestValue<List<Vehicle>>.pending(const <Vehicle>[]);
  final LatestValue<List<GroupConfig>> _groups =
      LatestValue<List<GroupConfig>>.pending(const <GroupConfig>[]);
  final LatestValue<bool> _isAdmin = LatestValue<bool>.pending(false);
  final StreamController<String> _errors = StreamController<String>.broadcast();

  late final StreamSubscription<DatabaseEvent> _vehiclesSubscription;
  late final StreamSubscription<DatabaseEvent> _groupsSubscription;
  late final StreamSubscription<DatabaseEvent> _adminSubscription;
  late final StreamSubscription<DatabaseEvent> _offsetSubscription;

  int _serverTimeOffsetMs = 0;
  int? _lastHistoryWriteAtMs;
  int _historyWritesSincePrune = 0;

  // ------------------------------------------------------------- Akışlar

  @override
  Stream<List<Vehicle>> get vehicles => _vehicles.stream;

  @override
  List<Vehicle> get latestVehicles => _vehicles.latest;

  @override
  Stream<List<GroupConfig>> get groupConfigs => _groups.stream;

  @override
  List<GroupConfig> get latestGroupConfigs => _groups.latest;

  @override
  Stream<bool> get isAdmin => _isAdmin.stream;

  @override
  bool get latestIsAdmin => _isAdmin.latest;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch + _serverTimeOffsetMs;

  // -------------------------------------------------------------- Yazma

  @override
  Future<void> saveRegistration({
    required String plate,
    required String driverName,
  }) {
    // Yalnızca iki alan. update() olduğu için arka plandaki konum yazımını
    // ezmez ve approved/groupId alanlarına dokunmaz.
    return _guard(
      Strings.errorSaveFailed,
      () => _vehicleRef(uid).update(<String, Object?>{
        'plate': plate,
        'driverName': driverName,
      }),
    );
  }

  @override
  Future<void> writeLocation({
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    await _guard(
      Strings.errorLocationWriteFailed,
      () => _vehicleRef(uid).update(<String, Object?>{
        'lat': lat,
        'lng': lng,
        'speedKmh': speedKmh,
        'updatedAt': ServerValue.timestamp,
      }),
    );
    await _appendHistoryIfDue(lat: lat, lng: lng, speedKmh: speedKmh);
  }

  @override
  Future<void> setVehicleApproved(String vehicleId, {required bool approved}) {
    return _guard(
      Strings.errorSaveFailed,
      () => _vehicleRef(
        vehicleId,
      ).update(<String, Object?>{'approved': approved}),
    );
  }

  @override
  Future<void> setVehicleGroup(String vehicleId, String? groupId) {
    // null yazmak alanı siler; "grupsuz" durumu budur.
    return _guard(
      Strings.errorSaveFailed,
      () => _vehicleRef(vehicleId).update(<String, Object?>{
        'groupId': groupId,
      }),
    );
  }

  @override
  Future<void> deleteVehicle(String vehicleId) {
    // Kökten tek bir çok yollu güncelleme: iki düğüm birlikte gider.
    // Kök burada yalnızca yazma için kullanılıyor, dinlenmiyor.
    return _guard(
      Strings.errorDeleteFailed,
      () => _database.ref().update(<String, Object?>{
        '$_vehiclesPath/$vehicleId': null,
        '$_locationHistoryPath/$vehicleId': null,
      }),
    );
  }

  @override
  Future<void> saveGroupConfig(GroupConfig config) {
    // Grup ayarını yazan tek taraf yöneticidir; yarışan bir yazıcı yok.
    // Bu yüzden düğümün tamamını yazmak güvenli ve listeden çıkarılan
    // grupların gerçekten silinmesini sağlıyor.
    return _guard(
      Strings.errorSaveFailed,
      () => _database
          .ref('$_groupConfigsPath/${config.groupId}')
          .set(config.toMap()),
    );
  }

  @override
  Future<void> deleteGroup(String groupId) {
    final Map<String, Object?> updates = <String, Object?>{
      '$_groupConfigsPath/$groupId': null,
    };
    for (final Vehicle vehicle in _vehicles.latest) {
      if (vehicle.groupId == groupId) {
        updates['$_vehiclesPath/${vehicle.id}/groupId'] = null;
      }
    }
    for (final GroupConfig group in _groups.latest) {
      if (group.groupId == groupId) continue;
      if (!group.visibleGroups.contains(groupId)) continue;
      updates['$_groupConfigsPath/${group.groupId}/visibleGroups'] = group
          .visibleGroups
          .where((String id) => id != groupId)
          .toList();
    }
    return _guard(
      Strings.errorDeleteFailed,
      () => _database.ref().update(updates),
    );
  }

  // -------------------------------------------------------------- Okuma

  @override
  Future<List<LocationSample>> loadHistory(String vehicleId) async {
    final DataSnapshot snapshot = await _guard(
      Strings.errorHistoryLoadFailed,
      () => _historyRef(vehicleId)
          .orderByKey()
          .limitToLast(FleetRepository.historyReadLimit)
          .get(),
    );
    final List<LocationSample> samples = <LocationSample>[];
    for (final DataSnapshot child in snapshot.children) {
      final String? key = child.key;
      if (key == null) continue;
      samples.add(LocationSample.fromMap(key, child.value));
    }
    // En yeni üstte.
    samples.sort(
      (LocationSample a, LocationSample b) =>
          b.recordedAt.compareTo(a.recordedAt),
    );
    return samples;
  }

  @override
  Future<bool> isAdminOnce(String userId) async {
    final DataSnapshot snapshot = await _guard(
      Strings.errorAdminStream,
      () => _database.ref('$_adminsPath/$userId').get(),
    );
    return _adminFrom(snapshot);
  }

  @override
  void dispose() {
    unawaited(_vehiclesSubscription.cancel());
    unawaited(_groupsSubscription.cancel());
    unawaited(_adminSubscription.cancel());
    unawaited(_offsetSubscription.cancel());
    unawaited(_vehicles.close());
    unawaited(_groups.close());
    unawaited(_isAdmin.close());
    unawaited(_errors.close());
  }

  // ------------------------------------------------------------ İçeriler

  DatabaseReference _vehicleRef(String vehicleId) =>
      _database.ref('$_vehiclesPath/$vehicleId');

  DatabaseReference _historyRef(String vehicleId) =>
      _database.ref('$_locationHistoryPath/$vehicleId');

  void _report(String message) {
    if (!_errors.isClosed) _errors.add(message);
  }

  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      throw BackendException(
        error.code == 'permission-denied'
            ? Strings.errorPermissionDenied
            : message,
      );
    } catch (_) {
      throw BackendException(message);
    }
  }

  /// Geçmiş kaydı seyrek yazılır. Buradaki karşılaştırma iki cihaz zamanı
  /// arasındaki *süre* ölçümüdür, sunucu zamanıyla kıyaslama değildir.
  Future<void> _appendHistoryIfDue({
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int? last = _lastHistoryWriteAtMs;
    final bool tooSoon =
        last != null &&
        now >= last &&
        now - last < FleetRepository.historyMinInterval.inMilliseconds;
    if (tooSoon) return;
    _lastHistoryWriteAtMs = now;

    await _guard(
      Strings.errorLocationWriteFailed,
      () => _historyRef(uid).push().set(<String, Object?>{
        'lat': lat,
        'lng': lng,
        'speedKmh': speedKmh,
        'recordedAt': ServerValue.timestamp,
      }),
    );

    _historyWritesSincePrune++;
    if (_historyWritesSincePrune >= _pruneEveryWrites) {
      _historyWritesSincePrune = 0;
      await _pruneHistory(uid);
    }
  }

  /// Araç başına kayıt sayısını [FleetRepository.historyMaxRecords] ile
  /// sınırlar. En yeni pencerenin ilk anahtarından eski olan kayıtlar tek bir
  /// çok yollu güncellemeyle silinir. Push anahtarları zaman sıralı olduğu
  /// için anahtar sıralaması kayıt sıralamasıdır.
  Future<void> _pruneHistory(String vehicleId) async {
    final DatabaseReference ref = _historyRef(vehicleId);
    final DataSnapshot newest = await ref
        .orderByKey()
        .limitToLast(FleetRepository.historyMaxRecords)
        .get();
    if (newest.children.length < FleetRepository.historyMaxRecords) return;

    final String? cutKey = newest.children.first.key;
    if (cutKey == null) return;

    final DataSnapshot old = await ref
        .orderByKey()
        .endBefore(cutKey)
        .limitToFirst(_pruneBatchSize)
        .get();

    final Map<String, Object?> deletions = <String, Object?>{};
    for (final DataSnapshot child in old.children) {
      final String? key = child.key;
      if (key != null) deletions[key] = null;
    }
    if (deletions.isEmpty) return;
    await ref.update(deletions);
  }

  static List<Vehicle> _vehiclesFrom(DatabaseEvent event) {
    final List<Vehicle> result = <Vehicle>[];
    for (final DataSnapshot child in event.snapshot.children) {
      final String? key = child.key;
      if (key == null) continue;
      result.add(Vehicle.fromMap(key, child.value));
    }
    result.sort((Vehicle a, Vehicle b) => a.plate.compareTo(b.plate));
    return result;
  }

  static List<GroupConfig> _groupsFrom(DatabaseEvent event) {
    final List<GroupConfig> result = <GroupConfig>[];
    for (final DataSnapshot child in event.snapshot.children) {
      final String? key = child.key;
      if (key == null) continue;
      result.add(GroupConfig.fromMap(key, child.value));
    }
    result.sort(
      (GroupConfig a, GroupConfig b) => a.groupId.compareTo(b.groupId),
    );
    return result;
  }

  static bool _adminFrom(DataSnapshot snapshot) =>
      snapshot.exists && snapshot.value != false;
}
