import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harita_takip/services/location_permission.dart';

void main() {
  group('locationStageFrom', () {
    test('konum servisi kapalıysa izinden bağımsız olarak öncelikli', () {
      expect(
        locationStageFrom(
          serviceEnabled: false,
          permission: LocationPermission.always,
        ),
        LocationPermissionStage.serviceDisabled,
      );
    });

    test('always izni arka plan takibine izin verir', () {
      expect(
        locationStageFrom(
          serviceEnabled: true,
          permission: LocationPermission.always,
        ),
        LocationPermissionStage.always,
      );
    });

    test('whileInUse yalnızca ön plan', () {
      expect(
        locationStageFrom(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
        ),
        LocationPermissionStage.foregroundOnly,
      );
    });

    test('kalıcı ret ayrı durum', () {
      expect(
        locationStageFrom(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        ),
        LocationPermissionStage.deniedForever,
      );
    });

    test('denied ve unableToDetermine aynı duruma düşer', () {
      expect(
        locationStageFrom(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        ),
        LocationPermissionStage.denied,
      );
      expect(
        locationStageFrom(
          serviceEnabled: true,
          permission: LocationPermission.unableToDetermine,
        ),
        LocationPermissionStage.denied,
      );
    });
  });

  group('canReadLocation', () {
    test('ön plan ve her zaman izinleri konum okumaya yeter', () {
      expect(canReadLocation(LocationPermissionStage.always), isTrue);
      expect(canReadLocation(LocationPermissionStage.foregroundOnly), isTrue);
    });

    test('izinsiz ve servis kapalı durumlarda okunamaz', () {
      expect(canReadLocation(LocationPermissionStage.denied), isFalse);
      expect(canReadLocation(LocationPermissionStage.deniedForever), isFalse);
      expect(canReadLocation(LocationPermissionStage.serviceDisabled), isFalse);
    });
  });

  group('canTrackInBackground', () {
    test('yalnızca always yeterlidir', () {
      expect(canTrackInBackground(LocationPermissionStage.always), isTrue);
      expect(
        canTrackInBackground(LocationPermissionStage.foregroundOnly),
        isFalse,
      );
      expect(canTrackInBackground(LocationPermissionStage.denied), isFalse);
    });
  });

  group('locationStageLabel', () {
    test('her durum için Türkçe etiket verir', () {
      for (final LocationPermissionStage stage
          in LocationPermissionStage.values) {
        expect(locationStageLabel(stage), isNotEmpty);
      }
    });
  });
}
