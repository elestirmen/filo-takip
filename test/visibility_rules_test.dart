import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/core/visibility_rules.dart';
import 'package:harita_takip/models/group_config.dart';
import 'package:harita_takip/models/vehicle.dart';

Vehicle _v(
  String id, {
  String? groupId,
  bool approved = true,
  String? plate,
}) {
  return Vehicle(
    id: id,
    plate: plate ?? '40 ${id.toUpperCase()} 000',
    driverName: 'Sürücü $id',
    groupId: groupId,
    approved: approved,
    lat: 38.6,
    lng: 34.7,
    speedKmh: 10,
    updatedAt: 1700000000000,
  );
}

/// Merkez -> Kaman'ı görür. Kaman kimseyi görmez. Mucur -> Merkez'i görür.
const List<GroupConfig> _groups = <GroupConfig>[
  GroupConfig(
    groupId: 'Merkez',
    visibleGroups: <String>['Kaman'],
    showSpeed: true,
    showDriverName: true,
  ),
  GroupConfig(
    groupId: 'Kaman',
    visibleGroups: <String>[],
    showSpeed: true,
    showDriverName: false,
  ),
  GroupConfig(
    groupId: 'Mucur',
    visibleGroups: <String>['Merkez'],
    showSpeed: false,
    showDriverName: true,
  ),
];

final List<Vehicle> _fleet = <Vehicle>[
  _v('m1', groupId: 'Merkez'),
  _v('m2', groupId: 'Merkez'),
  _v('m3', groupId: 'Merkez', approved: false),
  _v('k1', groupId: 'Kaman'),
  _v('k2', groupId: 'Kaman'),
  _v('u1', groupId: 'Mucur'),
  _v('g1'),
  _v('p1', approved: false),
];

List<String> _ids(List<Vehicle> vehicles) =>
    vehicles.map((Vehicle v) => v.id).toList();

void main() {
  group('visibleVehiclesFor', () {
    test('yönetici tüm araçları görür', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'yonetici',
        isAdmin: true,
      );
      expect(_ids(visible), _ids(_fleet));
    });

    test('kaydı olmayan sürücü hiçbir araç görmez', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'kayitsiz',
        isAdmin: false,
      );
      expect(visible, isEmpty);
    });

    test('onaysız sürücü yalnızca kendi aracını görür', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'p1',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['p1']);
    });

    test('gruptaki onaysız sürücü de yalnızca kendi aracını görür', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'm3',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['m3']);
    });

    test('grupsuz onaylı sürücü yalnızca kendi aracını görür', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'g1',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['g1']);
    });

    test('gruplu sürücü kendi grubunu ve görünür grupları görür', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'm1',
        isAdmin: false,
      );
      // Merkez (m1, m2) + Kaman (k1, k2). m3 onaysız, u1 Mucur, g1 grupsuz.
      expect(_ids(visible), <String>['m1', 'm2', 'k1', 'k2']);
    });

    test('kendisi dışındaki onaysız araçları göstermez', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'm1',
        isAdmin: false,
      );
      expect(_ids(visible), isNot(contains('m3')));
    });

    test('görünürlük tek yönlüdür: Kaman, Merkez\'i görmez', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'k1',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['k1', 'k2']);
    });

    test('görünür grup listesi geçişli değildir', () {
      // Mucur -> Merkez'i görür, Merkez -> Kaman'ı görür.
      // Mucur, Kaman'ı görmemeli.
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: _groups,
        viewerUid: 'u1',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['m1', 'm2', 'u1']);
      expect(_ids(visible), isNot(contains('k1')));
    });

    test('grup ayarı tanımsızsa yalnızca kendi grubu görünür', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet,
        groups: const <GroupConfig>[],
        viewerUid: 'm1',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['m1', 'm2']);
    });

    test('giriş sırasını korur', () {
      final List<Vehicle> visible = visibleVehiclesFor(
        allVehicles: _fleet.reversed.toList(),
        groups: _groups,
        viewerUid: 'm1',
        isAdmin: false,
      );
      expect(_ids(visible), <String>['k2', 'k1', 'm2', 'm1']);
    });
  });

  group('allowedGroupIdsFor', () {
    test('kendi grubu her zaman içeride', () {
      expect(
        allowedGroupIdsFor(viewerGroupId: 'Kaman', groups: _groups),
        <String>{'Kaman'},
      );
    });

    test('görünür gruplar eklenir', () {
      expect(
        allowedGroupIdsFor(viewerGroupId: 'Merkez', groups: _groups),
        <String>{'Merkez', 'Kaman'},
      );
    });

    test('tanımsız grup için yalnızca kendisi', () {
      expect(
        allowedGroupIdsFor(viewerGroupId: 'Yok', groups: _groups),
        <String>{'Yok'},
      );
    });
  });

  group('fieldVisibilityFor', () {
    test('kullanıcı kendi aracını grup gizlese bile tam görür', () {
      // Kaman grubu sürücü adını gizliyor.
      expect(
        fieldVisibilityFor(
          vehicle: _v('k1', groupId: 'Kaman'),
          groups: _groups,
          viewerUid: 'k1',
          isAdmin: false,
        ),
        FieldVisibility.full,
      );
    });

    test('yönetici tüm alanları görür', () {
      expect(
        fieldVisibilityFor(
          vehicle: _v('k1', groupId: 'Kaman'),
          groups: _groups,
          viewerUid: 'yonetici',
          isAdmin: true,
        ),
        FieldVisibility.full,
      );
    });

    test('bakılan aracın grup ayarı sürücü adını gizler', () {
      final FieldVisibility visibility = fieldVisibilityFor(
        vehicle: _v('k1', groupId: 'Kaman'),
        groups: _groups,
        viewerUid: 'm1',
        isAdmin: false,
      );
      expect(visibility.showDriverName, isFalse);
      expect(visibility.showSpeed, isTrue);
    });

    test('bakılan aracın grup ayarı hızı gizler', () {
      final FieldVisibility visibility = fieldVisibilityFor(
        vehicle: _v('u1', groupId: 'Mucur'),
        groups: _groups,
        viewerUid: 'm1',
        isAdmin: false,
      );
      expect(visibility.showSpeed, isFalse);
      expect(visibility.showDriverName, isTrue);
    });

    test('gizleyen grup bakanın değil, bakılanın grubudur', () {
      // Kaman sürücüsü Merkez aracına baksa alanlar görünür olmalı;
      // gizleyen ayar Kaman'ın değil Merkez'in ayarıdır.
      final FieldVisibility visibility = fieldVisibilityFor(
        vehicle: _v('m1', groupId: 'Merkez'),
        groups: _groups,
        viewerUid: 'k1',
        isAdmin: false,
      );
      expect(visibility, FieldVisibility.full);
    });

    test('grupsuz araçta gizleme yok', () {
      expect(
        fieldVisibilityFor(
          vehicle: _v('g1'),
          groups: _groups,
          viewerUid: 'm1',
          isAdmin: false,
        ),
        FieldVisibility.full,
      );
    });

    test('grup ayarı bulunamazsa gizleme yok', () {
      expect(
        fieldVisibilityFor(
          vehicle: _v('x1', groupId: 'Bilinmeyen'),
          groups: _groups,
          viewerUid: 'm1',
          isAdmin: false,
        ),
        FieldVisibility.full,
      );
    });
  });

  group('GroupFilter', () {
    test('tümü hepsini geçirir', () {
      const GroupFilter filter = GroupFilter.all();
      expect(_fleet.where(filter.matches).length, _fleet.length);
    });

    test('grupsuz yalnızca grubu olmayanları geçirir', () {
      const GroupFilter filter = GroupFilter.ungrouped();
      expect(_ids(_fleet.where(filter.matches).toList()), <String>['g1', 'p1']);
    });

    test('belirli grup yalnızca o grubu geçirir', () {
      const GroupFilter filter = GroupFilter.group('Merkez');
      expect(_ids(_fleet.where(filter.matches).toList()), <String>[
        'm1',
        'm2',
        'm3',
      ]);
    });

    test('eşitlik çip seçimini doğru karşılaştırır', () {
      expect(const GroupFilter.group('Merkez'), const GroupFilter.group('Merkez'));
      expect(
        const GroupFilter.group('Merkez'),
        isNot(const GroupFilter.group('Kaman')),
      );
      expect(const GroupFilter.all(), isNot(const GroupFilter.ungrouped()));
    });
  });
}
