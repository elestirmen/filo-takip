import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/models/group_config.dart';
import 'package:harita_takip/models/location_sample.dart';
import 'package:harita_takip/models/vehicle.dart';

/// Modellerin Realtime Database'den gelen düzensiz veriye dayanıklılığı.
/// RTDB tip garantisi vermez; eksik alan, int/double karışıklığı ve
/// listenin Map olarak gelmesi gerçek durumlardır.
void main() {
  group('Vehicle.fromMap', () {
    test('tam veriyi okur', () {
      final Vehicle vehicle = Vehicle.fromMap('uid1', <String, Object?>{
        'plate': '40 ABC 123',
        'driverName': 'Ahmet Yıldız',
        'groupId': 'Merkez',
        'approved': true,
        'lat': 38.6246,
        'lng': 34.7142,
        'speedKmh': 52.5,
        'updatedAt': 1700000000000,
      });

      expect(vehicle.id, 'uid1');
      expect(vehicle.plate, '40 ABC 123');
      expect(vehicle.groupId, 'Merkez');
      expect(vehicle.approved, isTrue);
      expect(vehicle.lat, 38.6246);
      expect(vehicle.speedKmh, 52.5);
      expect(vehicle.updatedAt, 1700000000000);
    });

    test('approved alanı yoksa onaysız sayılır', () {
      final Vehicle vehicle = Vehicle.fromMap('uid1', <String, Object?>{
        'plate': '40 ABC 123',
      });
      expect(vehicle.approved, isFalse);
    });

    test('düğüm boşsa çökmez, varsayılanlara düşer', () {
      final Vehicle vehicle = Vehicle.fromMap('uid1', null);
      expect(vehicle.plate, '');
      expect(vehicle.approved, isFalse);
      expect(vehicle.groupId, isNull);
      expect(vehicle.lat, 0);
      expect(vehicle.updatedAt, 0);
    });

    test('tam sayı yazılmış koordinatı double olarak okur', () {
      final Vehicle vehicle = Vehicle.fromMap('uid1', <String, Object?>{
        'lat': 38,
        'lng': 34,
        'speedKmh': 0,
      });
      expect(vehicle.lat, 38.0);
      expect(vehicle.lng, 34.0);
      expect(vehicle.speedKmh, 0.0);
    });

    test('boş groupId metni grupsuz sayılır', () {
      final Vehicle vehicle = Vehicle.fromMap('uid1', <String, Object?>{
        'groupId': '',
      });
      expect(vehicle.groupId, isNull);
      expect(vehicle.hasGroup, isFalse);
    });

    test('anahtarları Object olan ham RTDB haritasını okur', () {
      final Vehicle vehicle = Vehicle.fromMap('uid1', <Object?, Object?>{
        'plate': '40 XYZ 999',
        'approved': true,
      });
      expect(vehicle.plate, '40 XYZ 999');
      expect(vehicle.approved, isTrue);
    });

    test('hasLocation hiç konum yazılmamış aracı ayırır', () {
      expect(Vehicle.fromMap('uid1', null).hasLocation, isFalse);
      expect(
        Vehicle.fromMap('uid1', <String, Object?>{
          'updatedAt': 1700000000000,
        }).hasLocation,
        isTrue,
      );
    });

    test('toMap / fromMap gidiş dönüşü alanları korur', () {
      const Vehicle vehicle = Vehicle(
        id: 'uid1',
        plate: '40 ABC 123',
        driverName: 'Ahmet Yıldız',
        groupId: 'Merkez',
        approved: true,
        lat: 38.6246,
        lng: 34.7142,
        speedKmh: 52.5,
        updatedAt: 1700000000000,
      );
      expect(Vehicle.fromMap('uid1', vehicle.toMap()).toMap(), vehicle.toMap());
    });
  });

  group('Vehicle.copyWith', () {
    const Vehicle base = Vehicle(
      id: 'uid1',
      plate: '40 ABC 123',
      driverName: 'Ahmet Yıldız',
      groupId: 'Merkez',
      approved: true,
      lat: 1,
      lng: 2,
      speedKmh: 3,
      updatedAt: 4,
    );

    test('verilmeyen alanları korur', () {
      final Vehicle copy = base.copyWith(speedKmh: 90);
      expect(copy.speedKmh, 90);
      expect(copy.plate, base.plate);
      expect(copy.groupId, 'Merkez');
    });

    test('clearGroupId grubu siler', () {
      expect(base.copyWith(clearGroupId: true).groupId, isNull);
    });
  });

  group('GroupConfig.fromMap', () {
    test('tam veriyi okur', () {
      final GroupConfig config = GroupConfig.fromMap('Merkez', <String, Object?>{
        'groupId': 'Merkez',
        'visibleGroups': <Object?>['Kaman', 'Mucur'],
        'showSpeed': false,
        'showDriverName': true,
      });
      expect(config.groupId, 'Merkez');
      expect(config.visibleGroups, <String>['Kaman', 'Mucur']);
      expect(config.showSpeed, isFalse);
      expect(config.showDriverName, isTrue);
    });

    test('görünürlük alanları yoksa gizleme yapılmaz', () {
      final GroupConfig config = GroupConfig.fromMap(
        'Merkez',
        <String, Object?>{},
      );
      expect(config.showSpeed, isTrue);
      expect(config.showDriverName, isTrue);
    });

    test('groupId alanı yoksa düğüm anahtarına düşer', () {
      expect(GroupConfig.fromMap('Kaman', null).groupId, 'Kaman');
    });

    test('visibleGroups Map olarak geldiğinde de listeye çevrilir', () {
      // RTDB, araya boşluk giren listeleri sayısal anahtarlı Map yapar.
      final GroupConfig config = GroupConfig.fromMap('Merkez', <String, Object?>{
        'visibleGroups': <Object?, Object?>{'0': 'Kaman', '2': 'Mucur'},
      });
      expect(config.visibleGroups, <String>['Kaman', 'Mucur']);
    });

    test('visibleGroups yoksa boş liste olur', () {
      expect(GroupConfig.fromMap('Merkez', null).visibleGroups, isEmpty);
    });

    test('toMap / fromMap gidiş dönüşü alanları korur', () {
      const GroupConfig config = GroupConfig(
        groupId: 'Merkez',
        visibleGroups: <String>['Kaman'],
        showSpeed: false,
        showDriverName: true,
        speedLimitKmh: 90,
      );
      expect(
        GroupConfig.fromMap('Merkez', config.toMap()).toMap(),
        config.toMap(),
      );
    });

    test('speedLimitKmh yoksa sıfıra düşer', () {
      expect(GroupConfig.fromMap('Merkez', null).speedLimitKmh, 0);
    });

    test('web panelinin yazdığı hız sınırı uygulamadan geçince kaybolmaz', () {
      // saveGroupConfig düğümün tamamını set() ile yazar. Uygulama bu alanı
      // hiç göstermese de okuyup geri yazmazsa, panelde girilen sınır
      // uygulamadan yapılan ilk grup düzenlemesinde silinirdi.
      final GroupConfig fromPanel = GroupConfig.fromMap(
        'Merkez',
        <String, Object?>{
          'visibleGroups': <String>['Kaman'],
          'showSpeed': true,
          'showDriverName': true,
          'speedLimitKmh': 70,
        },
      );
      final GroupConfig edited = fromPanel.copyWith(showSpeed: false);
      expect(edited.speedLimitKmh, 70);
      expect(edited.toMap()['speedLimitKmh'], 70);
    });
  });

  group('LocationSample.fromMap', () {
    test('kaydı okur', () {
      final LocationSample sample = LocationSample.fromMap(
        'push1',
        <String, Object?>{
          'lat': 38.6,
          'lng': 34.7,
          'speedKmh': 12,
          'recordedAt': 1700000000000,
        },
      );
      expect(sample.id, 'push1');
      expect(sample.speedKmh, 12.0);
      expect(sample.recordedAt, 1700000000000);
    });

    test('bozuk düğümde varsayılanlara düşer', () {
      final LocationSample sample = LocationSample.fromMap('push1', 'bozuk');
      expect(sample.lat, 0);
      expect(sample.recordedAt, 0);
    });

    test('toMap / fromMap gidiş dönüşü alanları korur', () {
      const LocationSample sample = LocationSample(
        id: 'push1',
        lat: 38.6,
        lng: 34.7,
        speedKmh: 12.5,
        recordedAt: 1700000000000,
      );
      expect(
        LocationSample.fromMap('push1', sample.toMap()).toMap(),
        sample.toMap(),
      );
    });
  });
}
