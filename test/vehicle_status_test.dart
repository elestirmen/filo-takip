import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/core/time_format.dart';
import 'package:harita_takip/core/vehicle_status.dart';
import 'package:harita_takip/models/vehicle.dart';

const int _now = 1700000000000;

Vehicle _v({
  bool approved = true,
  double speedKmh = 0,
  int? updatedAt,
  int ageMs = 0,
}) {
  return Vehicle(
    id: 'v1',
    plate: '40 ABC 123',
    driverName: 'Sürücü',
    groupId: 'Merkez',
    approved: approved,
    lat: 38.6,
    lng: 34.7,
    speedKmh: speedKmh,
    updatedAt: updatedAt ?? _now - ageMs,
  );
}

void main() {
  group('isStale', () {
    test('taze güncelleme bayat değil', () {
      expect(isStale(_v(ageMs: 1000), nowMs: _now), isFalse);
    });

    test('tam eşikte henüz bayat değil', () {
      final int limit = StatusThresholds.offlineAfter.inMilliseconds;
      expect(isStale(_v(ageMs: limit), nowMs: _now), isFalse);
    });

    test('eşiğin 1 ms ötesi bayat', () {
      final int limit = StatusThresholds.offlineAfter.inMilliseconds;
      expect(isStale(_v(ageMs: limit + 1), nowMs: _now), isTrue);
    });

    test('hiç güncellenmemiş araç bayat sayılır', () {
      expect(isStale(_v(updatedAt: 0), nowMs: _now), isTrue);
    });

    test('sunucu zamanı cihazdan ileriyse bayat sayılmaz', () {
      expect(isStale(_v(updatedAt: _now + 5000), nowMs: _now), isFalse);
    });
  });

  group('vehicleStatusOf', () {
    test('eşiğin üstündeki hız hareketli', () {
      expect(
        vehicleStatusOf(_v(speedKmh: 3.1), nowMs: _now),
        VehicleStatus.moving,
      );
    });

    test('tam eşikteki hız duruyor sayılır', () {
      expect(
        vehicleStatusOf(
          _v(speedKmh: StatusThresholds.movingAboveKmh),
          nowMs: _now,
        ),
        VehicleStatus.stopped,
      );
    });

    test('sıfır hız duruyor', () {
      expect(vehicleStatusOf(_v(), nowMs: _now), VehicleStatus.stopped);
    });

    test('bayat araç hızlı bile olsa çevrimdışı', () {
      expect(
        vehicleStatusOf(
          _v(speedKmh: 90, ageMs: 20 * 60 * 1000),
          nowMs: _now,
        ),
        VehicleStatus.offline,
      );
    });

    test('onaysız araç hareket ederken de onay bekliyor kalır', () {
      expect(
        vehicleStatusOf(_v(approved: false, speedKmh: 90), nowMs: _now),
        VehicleStatus.pending,
      );
    });

    test('onaysız ve bayat araç yine onay bekliyor', () {
      expect(
        vehicleStatusOf(
          _v(approved: false, ageMs: 60 * 60 * 1000),
          nowMs: _now,
        ),
        VehicleStatus.pending,
      );
    });
  });

  group('FleetSummary', () {
    test('durumları sayar', () {
      final FleetSummary summary = FleetSummary.of(<Vehicle>[
        _v(speedKmh: 50),
        _v(speedKmh: 60),
        _v(),
        _v(ageMs: 30 * 60 * 1000),
        _v(approved: false),
      ], nowMs: _now);

      expect(summary.total, 5);
      expect(summary.moving, 2);
      expect(summary.stopped, 1);
      expect(summary.offline, 1);
      expect(summary.pending, 1);
    });

    test('boş filo sıfırlanır', () {
      final FleetSummary summary = FleetSummary.of(
        const <Vehicle>[],
        nowMs: _now,
      );
      expect(summary.total, 0);
      expect(summary.moving, 0);
    });
  });

  group('relativeTime', () {
    test('bir dakikadan yeni güncelleme az önce', () {
      expect(relativeTime(_now - 30 * 1000, nowMs: _now), 'Az önce');
    });

    test('dakika gösterir', () {
      expect(relativeTime(_now - 3 * 60 * 1000, nowMs: _now), '3 dakika önce');
    });

    test('saat gösterir', () {
      expect(
        relativeTime(_now - 2 * 60 * 60 * 1000, nowMs: _now),
        '2 saat önce',
      );
    });

    test('gün gösterir', () {
      expect(
        relativeTime(_now - 4 * 24 * 60 * 60 * 1000, nowMs: _now),
        '4 gün önce',
      );
    });

    test('hiç güncellenmemişse özel metin', () {
      expect(relativeTime(0, nowMs: _now), 'Hiç güncellenmedi');
    });

    test('sunucu zamanı ileri ise az önce', () {
      expect(relativeTime(_now + 4000, nowMs: _now), 'Az önce');
    });
  });

  group('formatTimestamp', () {
    test('dd.MM.yyyy HH:mm:ss biçiminde yazar', () {
      final DateTime moment = DateTime(2026, 3, 5, 14, 7, 9);
      expect(
        formatTimestamp(moment.millisecondsSinceEpoch),
        '05.03.2026 14:07:09',
      );
    });

    test('sıfır zaman damgası için özel metin', () {
      expect(formatTimestamp(0), 'Hiç güncellenmedi');
    });
  });

  group('speedKmhFromMps', () {
    test('m/s değerini km/s yapar', () {
      expect(speedKmhFromMps(10), closeTo(36, 0.001));
    });

    test('negatif hızı sıfıra çeker', () {
      // Bazı cihazlar duruyorken küçük negatif değer döndürür.
      expect(speedKmhFromMps(-1.5), 0);
    });

    test('NaN ve sonsuz değerleri sıfıra çeker', () {
      expect(speedKmhFromMps(double.nan), 0);
      expect(speedKmhFromMps(double.infinity), 0);
    });

    test('sıfır sıfır kalır', () {
      expect(speedKmhFromMps(0), 0);
    });
  });

  group('formatSpeed', () {
    test('yuvarlar ve birim ekler', () {
      expect(formatSpeed(52.4), '52 km/s');
      expect(formatSpeed(52.6), '53 km/s');
      expect(formatSpeed(0), '0 km/s');
    });
  });
}
