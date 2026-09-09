import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/strings.dart';
import 'location_permission.dart';
import 'location_task_handler.dart';

/// Servisi başlatma denemesinin sonucu.
enum TrackingStartResult {
  /// Servis çalışıyor ve arka planda da konum gönderecek.
  started,

  /// Servis çalışıyor ama izin yalnızca uygulama açıkken geçerli.
  startedForegroundOnly,

  /// Konum izni yok.
  permissionMissing,

  /// Bildirim izni yok; kalıcı bildirim olmadan ön plan servisi açılamaz.
  notificationMissing,

  /// Servis başlatılamadı.
  failed,
}

/// Ön plan konum servisinin arayüz tarafındaki denetimi.
///
/// Servisin kendisi ayrı bir isolate'te [LocationTaskHandler] içinde çalışır.
class LocationService {
  const LocationService._();

  /// Kullanıcının açık/kapalı tercihi. Yetki bilgisi değildir; yalnızca
  /// "servis açılsın mı" niyetini saklar.
  static const String _preferenceKey = 'konumTakibiAcik';

  static const int _serviceId = 1071;

  static Future<LocationPermissionStage> currentStage() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final LocationPermission permission = await Geolocator.checkPermission();
    return locationStageFrom(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
  }

  /// Kademeli akışın ilk adımı: ön plan konum izni.
  ///
  /// Arka plan izni ayrı bir adımdır ve Android 11+ üzerinde yalnızca
  /// uygulama ayarlarından verilebilir; onu [openAppSettings] yürütür.
  static Future<LocationPermissionStage> requestForegroundPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStage.serviceDisabled;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }
    return locationStageFrom(
      serviceEnabled: true,
      permission: permission,
    );
  }

  /// Android 10'da "her zaman" izni sistem penceresinden alınabilir; 11+
  /// sürümlerde bu çağrı çoğunlukla yalnızca ön plan iznini döndürür ve
  /// kullanıcının ayarlara gitmesi gerekir.
  static Future<LocationPermissionStage> requestBackgroundPermission() async {
    final LocationPermission permission = await Geolocator.requestPermission();
    return locationStageFrom(serviceEnabled: true, permission: permission);
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  static Future<TrackingStartResult> start({required String uid}) async {
    final LocationPermissionStage stage = await currentStage();
    if (!canReadLocation(stage)) return TrackingStartResult.permissionMissing;

    // Android 13+ kalıcı bildirim için ayrı izin ister.
    NotificationPermission notification =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notification != NotificationPermission.granted) {
      notification = await FlutterForegroundTask.requestNotificationPermission();
    }
    if (notification != NotificationPermission.granted) {
      return TrackingStartResult.notificationMissing;
    }

    _initTask();
    // Servis isolate'i araç kimliğini buradan okur.
    await FlutterForegroundTask.saveData(
      key: LocationTaskHandler.uidKey,
      value: uid,
    );

    final ServiceRequestResult result;
    if (await FlutterForegroundTask.isRunningService) {
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: <ForegroundServiceTypes>[ForegroundServiceTypes.location],
        notificationTitle: Strings.serviceNotificationTitle,
        notificationText: Strings.serviceNotificationText,
        callback: startLocationTask,
      );
    }
    if (result is ServiceRequestFailure) return TrackingStartResult.failed;

    return canTrackInBackground(stage)
        ? TrackingStartResult.started
        : TrackingStartResult.startedForegroundOnly;
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ------------------------------------------------------------ Tercih

  static Future<bool> trackingPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_preferenceKey) ?? false;
  }

  static Future<void> setTrackingPreference({required bool enabled}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, enabled);
  }

  // ------------------------------------------------------------ İçeriler

  static void _initTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'filo_takip_konum',
        channelName: Strings.serviceChannelName,
        channelDescription: Strings.serviceChannelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Aralığı konum akışı belirliyor (bkz. LocationTaskHandler);
        // servisin ayrıca bir tekrar olayına ihtiyacı yok.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }
}
