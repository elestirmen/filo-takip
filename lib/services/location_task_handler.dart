import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_config.dart';
import '../core/vehicle_status.dart';
import '../data/firebase_fleet_repository.dart';
import '../data/fleet_repository.dart';

/// Ön plan servisinin giriş noktası.
///
/// Bu fonksiyon **ayrı bir isolate'te** çalışır; uygulamanın belleğine,
/// widget ağacına ve Provider'daki repository'ye erişemez. Bu yüzden kendi
/// Firebase bağlantısını kurar.
@pragma('vm:entry-point')
void startLocationTask() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// Servis isolate'i: konum akışını dinler ve her güncellemeyi yazar.
///
/// Tek seferlik `getCurrentPosition` çağrılarını tekrarlamak yerine kalıcı
/// bir akışa abone olunuyor. Sebep: işletim sistemi düzeltmeleri kendi
/// üretir, her turda yeni bir konum istemcisi kurulmaz ve tek bir okumanın
/// asılı kalması sonraki turları kilitlemez.
class LocationTaskHandler extends TaskHandler {
  /// Servise aracın kimliğini geçirmek için kullanılan anahtar.
  static const String uidKey = 'takipUid';

  /// Servis isolate'inde **Activity yoktur**.
  ///
  /// Geolocator'ın varsayılan yolu (FusedLocationProvider) Play Services'in
  /// ayar kontrolünü kullanır; bu kontrol bir çözüm penceresi göstermek
  /// isteyip Activity bulamayınca hatayı "konum servisi kapalı" diye
  /// bildirir — konum açık olsa bile. Bu yüzden arka planda doğrudan
  /// Android LocationManager kullanılıyor.
  static final AndroidSettings _locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    // Şartnamedeki 5 saniyelik konum aralığı.
    intervalDuration: const Duration(seconds: 5),
    forceLocationManager: true,
  );

  FleetRepository? _repository;
  StreamSubscription<Position>? _positionSubscription;
  bool _writing = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final String? uid = await FlutterForegroundTask.getData<String>(
      key: uidKey,
    );
    _log('servis basladi (starter: ${starter.name}, uid: $uid)');
    if (uid == null || uid.isEmpty) {
      _log('uid bulunamadi, konum yazilamayacak');
      return;
    }

    // Simülasyon kipinde sahte veri ana isolate'in belleğinde durur; buradan
    // erişilemez. O yüzden repository kurulmaz ve konum ana isolate'e
    // gönderilir (bkz. _publish).
    if (!AppConfig.useFakeBackend) {
      try {
        await Firebase.initializeApp();
        _repository = FirebaseFleetRepository(uid: uid);
      } catch (error) {
        // Firebase kurulamazsa servis çalışmaya devam eder ama yazamaz;
        // kullanıcı bunu haritada bayat konum olarak görür.
        _log('Firebase kurulamadi: $error');
        _repository = null;
      }
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_onPosition, onError: (Object error) => _log('akis hatasi: $error'));
    _log('konum akisi dinleniyor');
  }

  /// Aralığı konum akışı belirlediği için bu geri çağrı kullanılmıyor
  /// (`ForegroundTaskEventAction.nothing()`).
  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _log('servis durduruluyor (zaman asimi: $isTimeout)');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _repository?.dispose();
    _repository = null;
  }

  Future<void> _onPosition(Position position) async {
    // Yazma uzarsa gelen konumlar üst üste binmesin; bir sonraki güncelleme
    // zaten 5 saniye sonra gelecek.
    if (_writing) return;
    _writing = true;
    try {
      await _publish(
        lat: position.latitude,
        lng: position.longitude,
        speedKmh: speedKmhFromMps(position.speed),
      );
    } catch (error) {
      // Tek bir yazmanın başarısız olması servisi durdurmaz, ama sessizce
      // yutulmaz: arka planda ne olduğunu görmenin tek yolu bu.
      _log('konum yazilamadi: $error');
    } finally {
      _writing = false;
    }
  }

  Future<void> _publish({
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    _log('konum: $lat, $lng ($speedKmh km/s)');
    final FleetRepository? repository = _repository;
    if (repository != null) {
      await repository.writeLocation(lat: lat, lng: lng, speedKmh: speedKmh);
      return;
    }
    // Simülasyon yolu: ana isolate açıksa sahte veriyi o günceller.
    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      'lat': lat,
      'lng': lng,
      'speedKmh': speedKmh,
    });
  }

  /// Servis ayrı bir isolate'te çalıştığı için hata ayıklamanın tek yolu
  /// logcat. `debugPrint` sürüm derlemesinde sessizdir.
  static void _log(String message) {
    debugPrint('[FiloTakipKonum] $message');
  }
}
