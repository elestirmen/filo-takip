import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/core/admin_rules.dart';
import 'package:harita_takip/models/group_config.dart';
import 'package:harita_takip/models/vehicle.dart';

Vehicle _v(
  String id, {
  required String plate,
  bool approved = true,
  String? groupId,
}) {
  return Vehicle(
    id: id,
    plate: plate,
    driverName: 'Sürücü $id',
    groupId: groupId,
    approved: approved,
    lat: 38.6,
    lng: 34.7,
    speedKmh: 0,
    updatedAt: 1700000000000,
  );
}

GroupConfig _g(String id) {
  return GroupConfig(
    groupId: id,
    visibleGroups: const <String>[],
    showSpeed: true,
    showDriverName: true,
  );
}

List<String> _ids(List<Vehicle> vehicles) =>
    vehicles.map((Vehicle v) => v.id).toList();

void main() {
  group('sortVehiclesForAdmin', () {
    test('onay bekleyenler üstte', () {
      final List<Vehicle> sorted = sortVehiclesForAdmin(<Vehicle>[
        _v('a', plate: '06 AAA 111'),
        _v('b', plate: '34 BBB 222', approved: false),
        _v('c', plate: '40 CCC 333'),
      ]);
      expect(_ids(sorted), <String>['b', 'a', 'c']);
    });

    test('aynı onay durumunda plakaya göre sıralar', () {
      final List<Vehicle> sorted = sortVehiclesForAdmin(<Vehicle>[
        _v('a', plate: '40 ZZZ 999'),
        _v('b', plate: '06 AAA 111'),
        _v('c', plate: '34 MMM 555'),
      ]);
      expect(_ids(sorted), <String>['b', 'c', 'a']);
    });

    test('bekleyenler kendi aralarında da plakaya göre sıralanır', () {
      final List<Vehicle> sorted = sortVehiclesForAdmin(<Vehicle>[
        _v('a', plate: '40 ZZZ 999', approved: false),
        _v('b', plate: '06 AAA 111', approved: false),
        _v('c', plate: '34 MMM 555'),
      ]);
      expect(_ids(sorted), <String>['b', 'a', 'c']);
    });

    test('plakalar eşitse sıra kimliğe göre kararlı kalır', () {
      final List<Vehicle> sorted = sortVehiclesForAdmin(<Vehicle>[
        _v('z', plate: '40 ABC 123'),
        _v('a', plate: '40 ABC 123'),
      ]);
      expect(_ids(sorted), <String>['a', 'z']);
    });

    test('girdiyi değiştirmez', () {
      final List<Vehicle> input = <Vehicle>[
        _v('a', plate: '40 ZZZ 999'),
        _v('b', plate: '06 AAA 111'),
      ];
      sortVehiclesForAdmin(input);
      expect(_ids(input), <String>['a', 'b']);
    });

    test('boş liste boş kalır', () {
      expect(sortVehiclesForAdmin(const <Vehicle>[]), isEmpty);
    });
  });

  group('AdminSummary', () {
    test('toplam, bekleyen, onaylı ve grup sayısını hesaplar', () {
      final AdminSummary summary = AdminSummary.of(
        <Vehicle>[
          _v('a', plate: '1', approved: false),
          _v('b', plate: '2', approved: false),
          _v('c', plate: '3'),
        ],
        <GroupConfig>[_g('Merkez'), _g('Kaman')],
      );
      expect(summary.total, 3);
      expect(summary.pending, 2);
      expect(summary.approved, 1);
      expect(summary.groupCount, 2);
    });

    test('boş filo sıfırlanır', () {
      final AdminSummary summary = AdminSummary.of(
        const <Vehicle>[],
        const <GroupConfig>[],
      );
      expect(summary.total, 0);
      expect(summary.pending, 0);
      expect(summary.approved, 0);
      expect(summary.groupCount, 0);
    });
  });

  group('vehicleCountInGroup', () {
    final List<Vehicle> fleet = <Vehicle>[
      _v('a', plate: '1', groupId: 'Merkez'),
      _v('b', plate: '2', groupId: 'Merkez'),
      _v('c', plate: '3', groupId: 'Kaman'),
      _v('d', plate: '4'),
    ];

    test('gruptaki araçları sayar', () {
      expect(vehicleCountInGroup(fleet, 'Merkez'), 2);
      expect(vehicleCountInGroup(fleet, 'Kaman'), 1);
    });

    test('bilinmeyen grup sıfır verir', () {
      expect(vehicleCountInGroup(fleet, 'Yok'), 0);
    });

    test('grupsuz araçlar hiçbir gruba sayılmaz', () {
      expect(vehicleCountInGroup(fleet, ''), 0);
    });
  });

  group('isGroupNameAvailable', () {
    final List<GroupConfig> groups = <GroupConfig>[_g('Merkez'), _g('Kaman')];

    test('yeni ad kabul edilir', () {
      expect(isGroupNameAvailable('Mucur', groups), isTrue);
    });

    test('var olan ad reddedilir', () {
      expect(isGroupNameAvailable('Merkez', groups), isFalse);
    });

    test('boş ad reddedilir', () {
      expect(isGroupNameAvailable('', groups), isFalse);
    });

    test('büyük/küçük harf farkı ayrı grup sayılır', () {
      // Grup adı aynı zamanda veritabanı anahtarı; anahtarlar harf
      // duyarlıdır.
      expect(isGroupNameAvailable('merkez', groups), isTrue);
    });
  });
}
