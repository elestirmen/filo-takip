import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/data/fleet_repository.dart';
import 'package:harita_takip/data/latest_value.dart';
import 'package:harita_takip/models/group_config.dart';
import 'package:harita_takip/models/location_sample.dart';
import 'package:harita_takip/models/vehicle.dart';
import 'package:harita_takip/screens/registration_screen.dart';
import 'package:provider/provider.dart';

/// Kayıt ekranı için sahte repository. Yalnızca ekranın kullandığı üyeler
/// gerçekten uygulanır; kalanı çağrılırsa test kasıtlı olarak patlar.
class _TestRepository implements FleetRepository {
  @override
  final String uid = 'uid-1';

  final LatestValue<List<Vehicle>> _vehicles =
      LatestValue<List<Vehicle>>.pending(const <Vehicle>[]);

  /// Kaydetme çağrılarının kaydı: hangi alanlar yazıldı?
  final List<Map<String, String>> savedCalls = <Map<String, String>>[];

  void emit(List<Vehicle> vehicles) => _vehicles.add(vehicles);

  @override
  Stream<List<Vehicle>> get vehicles => _vehicles.stream;

  @override
  List<Vehicle> get latestVehicles => _vehicles.latest;

  @override
  Future<void> saveRegistration({
    required String plate,
    required String driverName,
  }) async {
    savedCalls.add(<String, String>{'plate': plate, 'driverName': driverName});
  }

  @override
  void dispose() {}

  // --- Bu ekranın kullanmadığı üyeler ---

  @override
  Stream<List<GroupConfig>> get groupConfigs => throw UnimplementedError();

  @override
  List<GroupConfig> get latestGroupConfigs => throw UnimplementedError();

  @override
  Stream<bool> get isAdmin => throw UnimplementedError();

  @override
  bool get latestIsAdmin => throw UnimplementedError();

  @override
  Stream<String> get errors => throw UnimplementedError();

  @override
  int nowMs() => throw UnimplementedError();

  @override
  Future<void> writeLocation({
    required double lat,
    required double lng,
    required double speedKmh,
  }) => throw UnimplementedError();

  @override
  Future<void> setVehicleApproved(String vehicleId, {required bool approved}) =>
      throw UnimplementedError();

  @override
  Future<void> setVehicleGroup(String vehicleId, String? groupId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteVehicle(String vehicleId) => throw UnimplementedError();

  @override
  Future<void> saveGroupConfig(GroupConfig config) =>
      throw UnimplementedError();

  @override
  Future<void> deleteGroup(String groupId) => throw UnimplementedError();

  @override
  Future<List<LocationSample>> loadHistory(String vehicleId) =>
      throw UnimplementedError();

  @override
  Future<bool> isAdminOnce(String userId) => throw UnimplementedError();
}

Vehicle _vehicle({
  String id = 'uid-1',
  String plate = '34 XYZ 789',
  String driverName = 'Ahmet Yıldız',
  String? groupId = 'Merkez',
  bool approved = true,
  double lat = 38.6,
  double lng = 34.7,
  double speedKmh = 0,
  int updatedAt = 1700000000000,
}) {
  return Vehicle(
    id: id,
    plate: plate,
    driverName: driverName,
    groupId: groupId,
    approved: approved,
    lat: lat,
    lng: lng,
    speedKmh: speedKmh,
    updatedAt: updatedAt,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _TestRepository repository, {
  bool isAnonymous = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Provider<FleetRepository>.value(
        value: repository,
        child: RegistrationScreen(isAnonymous: isAnonymous),
      ),
    ),
  );
}

void main() {
  testWidgets('veri gelene kadar yükleniyor gösterir', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, _TestRepository());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Kayıt talebi gönder'), findsNothing);
  });

  testWidgets('kayıt yokken "Kayıt talebi gönder" yazar', (
    WidgetTester tester,
  ) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(const <Vehicle>[]);
    await tester.pumpAndSettle();

    expect(find.text('Kayıt talebi gönder'), findsOneWidget);
    expect(find.text('Bu cihaz için araç kaydı yok'), findsOneWidget);
  });

  testWidgets('kayıt varken alanlar dolar ve buton güncellemeye döner', (
    WidgetTester tester,
  ) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(<Vehicle>[_vehicle()]);
    await tester.pumpAndSettle();

    expect(find.text('Bilgileri güncelle'), findsOneWidget);
    expect(find.text('34 XYZ 789'), findsOneWidget);
    expect(find.text('Ahmet Yıldız'), findsOneWidget);
    expect(find.text('Onaylı'), findsOneWidget);
    expect(find.text('Merkez'), findsOneWidget);
  });

  testWidgets('onaysız araçta onay bekliyor durumu görünür', (
    WidgetTester tester,
  ) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(<Vehicle>[_vehicle(approved: false, groupId: null)]);
    await tester.pumpAndSettle();

    expect(find.text('Onay bekliyor'), findsOneWidget);
    expect(find.text('Atanmamış'), findsOneWidget);
  });

  testWidgets('konum güncellemesi kullanıcının yazdığını silmez', (
    WidgetTester tester,
  ) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(<Vehicle>[_vehicle()]);
    await tester.pumpAndSettle();

    // Kullanıcı plakayı değiştiriyor.
    await tester.enterText(find.byType(TextFormField).first, '06 XYZ 999');
    await tester.pump();

    // Bu sırada araç düğümü konum yüzünden güncelleniyor.
    repository.emit(<Vehicle>[_vehicle(lat: 39.1, updatedAt: 1700000005000)]);
    await tester.pumpAndSettle();

    expect(find.text('06 XYZ 999'), findsOneWidget);
    expect(find.text('34 XYZ 789'), findsNothing);
  });

  testWidgets('kaydetme plakayı normalleştirip yalnızca iki alanı yazar', (
    WidgetTester tester,
  ) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(const <Vehicle>[]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '  06 dp  1234 ');
    await tester.enterText(
      find.byType(TextFormField).last,
      '  Mehmet   Kaya ',
    );
    await tester.tap(find.text('Kayıt talebi gönder'));
    await tester.pumpAndSettle();

    expect(repository.savedCalls, hasLength(1));
    expect(repository.savedCalls.single, <String, String>{
      'plate': '06 DP 1234',
      'driverName': 'Mehmet Kaya',
    });
  });

  testWidgets('kısa plaka kaydedilmez', (WidgetTester tester) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(const <Vehicle>[]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '40 A');
    await tester.enterText(find.byType(TextFormField).last, 'Ali Can');
    await tester.tap(find.text('Kayıt talebi gönder'));
    await tester.pumpAndSettle();

    expect(repository.savedCalls, isEmpty);
    expect(find.text('Plaka en az 6 karakter olmalı.'), findsOneWidget);
  });

  testWidgets('kısa sürücü adı kaydedilmez', (WidgetTester tester) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository);
    repository.emit(const <Vehicle>[]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '40 ABC 123');
    await tester.enterText(find.byType(TextFormField).last, 'Al');
    await tester.tap(find.text('Kayıt talebi gönder'));
    await tester.pumpAndSettle();

    expect(repository.savedCalls, isEmpty);
    expect(find.text('Sürücü adı en az 3 karakter olmalı.'), findsOneWidget);
  });

  testWidgets('yönetici oturumunda form yerine uyarı görünür', (
    WidgetTester tester,
  ) async {
    final _TestRepository repository = _TestRepository();
    await _pumpScreen(tester, repository, isAnonymous: false);
    await tester.pumpAndSettle();

    expect(find.text('Yönetici oturumu açık'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
