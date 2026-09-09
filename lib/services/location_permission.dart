/// Konum izni durumunun tek bir değere indirgenmesi.
///
/// Eşleme saf fonksiyondur ve birim testle kaplıdır; sistem çağrıları
/// [LocationService] içindedir.
library;

import 'package:geolocator/geolocator.dart';

import '../core/strings.dart';

enum LocationPermissionStage {
  /// Cihazın konum servisi (GPS) kapalı. İzinden bağımsız olarak konum alınamaz.
  serviceDisabled,

  /// Henüz izin verilmedi ya da reddedildi (tekrar sorulabilir).
  denied,

  /// Kalıcı olarak reddedildi; yalnızca uygulama ayarlarından açılabilir.
  deniedForever,

  /// Yalnızca uygulama açıkken konum alınabilir.
  foregroundOnly,

  /// Arka planda da konum alınabilir.
  always,
}

/// [Geolocator]'ın iki ayrı bilgisini tek duruma indirir.
///
/// Konum servisi kapalıysa izin ne olursa olsun konum okunamaz; bu yüzden
/// [LocationPermissionStage.serviceDisabled] önceliklidir.
LocationPermissionStage locationStageFrom({
  required bool serviceEnabled,
  required LocationPermission permission,
}) {
  if (!serviceEnabled) return LocationPermissionStage.serviceDisabled;
  switch (permission) {
    case LocationPermission.always:
      return LocationPermissionStage.always;
    case LocationPermission.whileInUse:
      return LocationPermissionStage.foregroundOnly;
    case LocationPermission.deniedForever:
      return LocationPermissionStage.deniedForever;
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationPermissionStage.denied;
  }
}

/// Konum okunabilir mi (harita ve ön plan takibi için yeterli).
bool canReadLocation(LocationPermissionStage stage) {
  return stage == LocationPermissionStage.always ||
      stage == LocationPermissionStage.foregroundOnly;
}

/// Uygulama kapalıyken de konum gönderilebilir mi.
bool canTrackInBackground(LocationPermissionStage stage) {
  return stage == LocationPermissionStage.always;
}

String locationStageLabel(LocationPermissionStage stage) {
  switch (stage) {
    case LocationPermissionStage.serviceDisabled:
      return Strings.permissionServiceDisabled;
    case LocationPermissionStage.denied:
      return Strings.permissionDenied;
    case LocationPermissionStage.deniedForever:
      return Strings.permissionDeniedForever;
    case LocationPermissionStage.foregroundOnly:
      return Strings.permissionForegroundOnly;
    case LocationPermissionStage.always:
      return Strings.permissionAlways;
  }
}
