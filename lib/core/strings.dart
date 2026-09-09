/// Uygulamadaki tüm kullanıcıya görünen metinler burada toplanır.
///
/// Kural: widget dosyalarının içine string literal yazılmaz. Yeni bir metin
/// gerektiğinde önce buraya `static const` olarak eklenir, sonra kullanılır.
class Strings {
  const Strings._();

  // ---------------------------------------------------------------- Genel
  static const String appTitle = 'Filo Takip';
  static const String loading = 'Yükleniyor…';
  static const String retry = 'Tekrar dene';
  static const String cancel = 'Vazgeç';
  static const String close = 'Kapat';
  static const String ok = 'Tamam';

  // ------------------------------------------------------- Alt gezinme
  static const String tabMap = 'Harita';
  static const String tabRegistration = 'Kayıt';
  static const String tabAdmin = 'Yönetim';
  static const String tabSettings = 'Ayarlar';

  // ------------------------------------------------------- Açılış / oturum
  static const String startupConnecting = 'Sunucuya bağlanılıyor…';
  static const String startupSigningIn = 'Oturum açılıyor…';
  static const String startupFailedTitle = 'Uygulama başlatılamadı';
  static const String startupFirebaseFailed =
      'Firebase bağlantısı kurulamadı. İnternet bağlantınızı kontrol edin. '
      'Sorun sürerse google-services.json dosyasının projeye eklendiğinden '
      'emin olun.';
  static const String startupSignInFailed =
      'Oturum açılamadı. Firebase Console üzerinde anonim giriş sağlayıcısının '
      'etkin olduğundan emin olun.';

  // ---------------------------------------------------------- Simülasyon
  static const String simulationBadge = 'SİMÜLASYON';

  /// Köşe şeridine sığması gerektiği için kısa tutuldu.
  static const String simulationRibbon = 'DEMO';
  static const String simulationNotice =
      'Uygulama şu anda sahte verilerle çalışıyor. Hiçbir veri sunucuya '
      'yazılmıyor ve uygulama kapanınca değişiklikler kaybolur.';
  static const String simulationAdminHint =
      'Simülasyon yöneticisi: yonetici@ornek.com / 123456';

  // ------------------------------------------------------------- Hatalar
  static const String errorInvalidCredentials = 'E-posta veya şifre hatalı.';
  static const String errorNetwork =
      'Ağ bağlantısı kurulamadı. İnternet bağlantınızı kontrol edin.';
  static const String errorTooManyRequests =
      'Çok fazla deneme yapıldı. Bir süre bekleyip tekrar deneyin.';
  static const String errorProviderDisabled =
      'Bu giriş yöntemi Firebase Console üzerinde etkin değil.';
  static const String errorSignInFailed = 'Giriş yapılamadı.';
  static const String errorSignOutFailed = 'Oturum kapatılamadı.';
  static const String errorPermissionDenied = 'Bu işlem için yetkiniz yok.';
  static const String errorSaveFailed = 'Kaydetme işlemi tamamlanamadı.';
  static const String errorDeleteFailed = 'Silme işlemi tamamlanamadı.';
  static const String errorHistoryLoadFailed = 'Konum geçmişi okunamadı.';
  static const String errorLocationWriteFailed =
      'Konum sunucuya yazılamadı.';
  static const String errorVehiclesStream =
      'Araç listesi alınamadı. Bağlantınızı kontrol edin.';
  static const String errorGroupConfigsStream = 'Grup ayarları alınamadı.';
  static const String errorAdminStream = 'Yönetici yetkisi okunamadı.';

  // ------------------------------------------------------- Geçici içerikler
  static const String screenComingSoon = 'Bu ekran sonraki aşamada eklenecek.';
  static const String mapScreenTitle = 'Harita';
  static const String registrationScreenTitle = 'Araç Kaydı';
  static const String adminScreenTitle = 'Yönetim';
  static const String settingsScreenTitle = 'Ayarlar';

  // ---------------------------------------------------------------- Zaman
  static const String timeJustNow = 'Az önce';
  static const String timeMinutesAgo = 'dakika önce';
  static const String timeHoursAgo = 'saat önce';
  static const String timeDaysAgo = 'gün önce';
  static const String timeNever = 'Hiç güncellenmedi';
  static const String unitSpeed = 'km/s';

  // -------------------------------------------------------------- Harita
  static const String mapSummaryTitle = 'Filo özeti';
  static const String mapSummaryTotal = 'Toplam';
  static const String mapStatusMoving = 'Hareketli';
  static const String mapStatusStopped = 'Duruyor';
  static const String mapStatusOffline = 'Çevrimdışı';
  static const String mapStatusPending = 'Onay bekliyor';
  static const String mapFilterAll = 'Tümü';
  static const String mapFilterUngrouped = 'Grupsuz';
  static const String mapEmptyTitle = 'Görüntülenecek araç yok';
  static const String mapEmptyDriverHint =
      'Aracınız onaylanıp bir gruba atandığında grubunuzdaki araçlar burada '
      'görünür.';
  static const String mapEmptyAdminHint =
      'Henüz kayıtlı araç yok. Sürücüler Kayıt sekmesinden talep gönderdiğinde '
      'burada görünürler.';
  static const String mapOwnVehicle = 'Bu cihaz';
  static const String mapFieldHidden = 'Gizli';
  static const String mapFieldSpeed = 'Hız';
  static const String mapFieldDriver = 'Sürücü';
  static const String mapFieldGroup = 'Grup';
  static const String mapFieldUpdated = 'Son güncelleme';
  static const String mapGroupNone = 'Atanmamış';
  static const String mapNoLocationYet = 'Bu aracın henüz konumu yok.';
  static const String mapGoToOwnVehicle = 'Aracıma git';
  static const String mapOwnVehicleMissing = 'Bu cihazın haritada konumu yok.';
  static const String mapExpand = 'Genişlet';
  static const String mapCollapse = 'Daralt';
  static const String mapAttribution = 'OpenStreetMap katkıcıları';

  // --------------------------------------------------------------- Kayıt
  static const String registrationNoVehicleTitle =
      'Bu cihaz için araç kaydı yok';
  static const String registrationNoVehicleHint =
      'Plaka ve sürücü adını girip kayıt talebi gönderin. Yönetici '
      'onayladıktan sonra aracınız gruptaki diğer sürücülere görünür.';
  static const String registrationPlateLabel = 'Plaka';
  static const String registrationPlateHint = '40 ABC 123';
  static const String registrationPlateRequired = 'Plaka girin.';
  static const String registrationPlateTooShort =
      'Plaka en az 6 karakter olmalı.';
  static const String registrationNameLabel = 'Sürücü adı';
  static const String registrationNameHint = 'Ad Soyad';
  static const String registrationNameRequired = 'Sürücü adı girin.';
  static const String registrationNameTooShort =
      'Sürücü adı en az 3 karakter olmalı.';
  static const String registrationSubmitNew = 'Kayıt talebi gönder';
  static const String registrationSubmitUpdate = 'Bilgileri güncelle';
  static const String registrationSaved = 'Bilgiler kaydedildi.';
  static const String registrationRequestSent =
      'Kayıt talebiniz gönderildi. Yönetici onayı bekleniyor.';
  static const String registrationStatusApproved = 'Onaylı';
  static const String registrationStatusPending = 'Onay bekliyor';
  static const String registrationApprovedHint =
      'Aracınız grubunuzdaki sürücülerin haritasında görünüyor.';
  static const String registrationPendingHint =
      'Yönetici onaylayana kadar aracınızı haritada yalnızca siz görürsünüz.';
  static const String registrationGroupLabel = 'Grup';
  static const String registrationGroupNone = 'Atanmamış';
  static const String registrationManagedByAdmin =
      'Onay durumunu ve grubu yalnızca yönetici değiştirebilir.';
  static const String registrationAdminSessionTitle = 'Yönetici oturumu açık';
  static const String registrationAdminSessionHint =
      'Araç kaydı sürücü (anonim) oturumuna aittir. Yönetici cihazı takip '
      'edilen bir araç olmamalıdır, bu yüzden kayıt formu kapalıdır. Sürücü '
      'olarak kaydolmak için Ayarlar sekmesinden yönetici oturumunu kapatın.';

  // ------------------------------------------------------------- Yönetim
  static const String adminLoginTitle = 'Yönetici girişi';
  static const String adminLoginHint =
      'Yönetici hesabı Firebase Console üzerinden oluşturulur ve yetkisi '
      'veritabanındaki admins listesinden okunur.';
  static const String adminEmailLabel = 'E-posta';
  static const String adminPasswordLabel = 'Şifre';
  static const String adminEmailRequired = 'E-posta girin.';
  static const String adminEmailInvalid = 'Geçerli bir e-posta girin.';
  static const String adminPasswordRequired = 'Şifre girin.';
  static const String adminLoginButton = 'Giriş yap';
  static const String adminLogoutButton = 'Çıkış yap';
  static const String adminVerifying = 'Yetki doğrulanıyor…';
  static const String adminNotAuthorized =
      'Bu hesap yönetici değil. Oturum kapatıldı.';
  static const String adminNotAuthorizedTitle = 'Yönetici yetkiniz yok';
  static const String adminNotAuthorizedHint =
      'Bu hesap veritabanındaki admins listesinde bulunmuyor. Çıkış yapıp '
      'sürücü oturumuna dönebilirsiniz.';

  static const String adminTabVehicles = 'Araçlar';
  static const String adminTabGroups = 'Gruplar';

  static const String adminSummaryTotal = 'Toplam';
  static const String adminSummaryPending = 'Bekleyen';
  static const String adminSummaryApproved = 'Onaylı';
  static const String adminSummaryGroups = 'Grup';

  static const String adminNoVehicles = 'Kayıtlı araç yok';
  static const String adminNoVehiclesHint =
      'Sürücüler Kayıt sekmesinden talep gönderdiğinde burada görünürler.';
  static const String adminApprove = 'Onayla';
  static const String adminRevoke = 'Onayı kaldır';
  static const String adminAssignGroup = 'Grup ata';
  static const String adminViewHistory = 'Konum geçmişi';
  static const String adminDeleteVehicle = 'Aracı sil';
  static const String adminDeleteVehicleTitle = 'Araç silinsin mi?';
  static const String adminDeleteVehicleMessage =
      'Araç kaydı ve tüm konum geçmişi kalıcı olarak silinecek. Bu işlem geri '
      'alınamaz.';
  static const String adminDelete = 'Sil';
  static const String adminSave = 'Kaydet';
  static const String adminVehicleApproved = 'Araç onaylandı.';
  static const String adminVehicleRevoked = 'Aracın onayı kaldırıldı.';
  static const String adminVehicleDeleted = 'Araç ve konum geçmişi silindi.';
  static const String adminGroupAssigned = 'Grup ataması güncellendi.';
  static const String adminGroupNone = 'Grupsuz';
  static const String adminSelectGroupTitle = 'Grup seç';
  static const String adminNoGroups = 'Henüz grup yok';
  static const String adminNoGroupsHint =
      'Gruplar sekmesinden yeni bir grup oluşturun.';

  static const String adminCreateGroup = 'Grup oluştur';
  static const String adminGroupNameLabel = 'Grup adı';
  static const String adminGroupNameHint = 'Merkez';
  static const String adminGroupNameRequired = 'Grup adı girin.';
  static const String adminGroupNameExists = 'Bu adda bir grup zaten var.';
  static const String adminGroupCreated = 'Grup oluşturuldu.';
  static const String adminEditGroup = 'Grup ayarları';
  static const String adminVisibleGroupsLabel = 'Görünür gruplar';
  static const String adminVisibleGroupsHint = 'Merkez, Kaman';
  static const String adminVisibleGroupsHelp =
      'Bu gruptaki sürücüler kendi grubuna ek olarak burada yazan grupları '
      'görür. Virgülle ayırın.';
  static const String adminShowSpeed = 'Hız görünsün';
  static const String adminShowDriverName = 'Sürücü adı görünsün';
  static const String adminFieldVisibilityHelp =
      'Kapatılan alan bu gruptaki araçlarda diğer sürücülere gizlenir. '
      'Sürücü kendi aracını her zaman tam görür.';
  static const String adminGroupSaved = 'Grup ayarları kaydedildi.';
  static const String adminDeleteGroupTitle = 'Grup silinsin mi?';
  static const String adminDeleteGroupMessage =
      'Bu gruptaki araçların grup ataması kaldırılacak ve diğer grupların '
      'görünür listelerinden çıkarılacak.';
  static const String adminGroupDeleted = 'Grup silindi.';
  static const String adminVehicleCountSuffix = 'araç';

  // ------------------------------------------------------- Konum geçmişi
  static const String historyTitle = 'Konum geçmişi';
  static const String historyEmpty = 'Bu araç için konum kaydı yok.';
  static const String historyRefresh = 'Yenile';
  static const String historyRecordSuffix = 'kayıt';
  static const String historyLimitNote =
      'En yeni 500 kayıt gösterilir, en yeni üstte.';

  // ------------------------------------------------------- Konum servisi
  static const String serviceChannelName = 'Konum takibi';
  static const String serviceChannelDescription =
      'Araç konumunun sunucuya gönderilebilmesi için kalıcı bildirim.';
  static const String serviceNotificationTitle = 'Filo Takip çalışıyor';
  static const String serviceNotificationText =
      'Aracınızın konumu gönderiliyor.';

  static const String trackingSection = 'Konum takibi';
  static const String trackingSwitch = 'Arka planda konum gönder';
  static const String trackingSwitchHint =
      'Açıkken uygulama kapalı olsa da aracınızın konumu gönderilir.';
  static const String trackingPermissionLabel = 'Konum izni';
  static const String trackingStateOn = 'Servis çalışıyor';
  static const String trackingStateOff = 'Servis kapalı';

  static const String permissionServiceDisabled =
      'Cihazın konum servisi kapalı';
  static const String permissionDenied = 'İzin verilmedi';
  static const String permissionForegroundOnly =
      'Yalnızca uygulama açıkken';
  static const String permissionAlways = 'Her zaman (arka plan dahil)';
  static const String permissionDeniedForever =
      'İzin kalıcı olarak reddedildi';

  static const String permissionServiceDisabledTitle = 'Konum servisi kapalı';
  static const String permissionServiceDisabledRationale =
      'Cihazın konum servisi kapalı olduğu için konum alınamıyor. Konum '
      'ayarlarından açmanız gerekiyor.';
  static const String trackingPermissionAction = 'İzin ver';
  static const String permissionForegroundTitle = 'Konum izni gerekli';
  static const String permissionForegroundRationale =
      'Aracınızın haritada görünebilmesi için konum izni vermeniz gerekiyor. '
      'İzin vermezseniz harita çalışmaya devam eder, yalnızca kendi konumunuz '
      'gönderilmez.';
  static const String permissionBackgroundTitle = 'Arka plan konum izni';
  static const String permissionBackgroundRationale =
      'Uygulama kapalıyken de konum gönderebilmek için konum iznini '
      '"Her zaman izin ver" yapmanız gerekiyor. Android bu seçeneği yalnızca '
      'uygulama ayarları ekranından sunar.';
  static const String permissionDeniedForeverRationale =
      'Konum izni kalıcı olarak reddedilmiş. Devam etmek için uygulama '
      'ayarlarından izni elle vermeniz gerekiyor.';
  static const String permissionOpenAppSettings = 'Uygulama ayarlarını aç';
  static const String permissionOpenLocationSettings = 'Konum ayarlarını aç';
  static const String permissionContinue = 'Devam et';
  static const String permissionSkip = 'Şimdilik geç';

  static const String trackingNeedsVehicle =
      'Önce Kayıt sekmesinden araç kaydı oluşturun.';
  static const String trackingNeedsPermission =
      'Konum izni verilmediği için takip başlatılamadı.';
  static const String trackingNeedsNotification =
      'Bildirim izni verilmedi. Kalıcı bildirim olmadan servis çalışamaz.';
  static const String trackingStarted = 'Konum gönderimi başladı.';
  static const String trackingStopped = 'Konum gönderimi durduruldu.';
  static const String trackingStartFailed = 'Konum servisi başlatılamadı.';
  static const String trackingForegroundOnlyWarning =
      'Takip başladı. İzin "yalnızca uygulama açıkken" olduğu için konum, '
      'kalıcı bildirim göründüğü sürece gönderilir; servis kapanırsa '
      'kendiliğinden devam edemez. Kesintisiz takip için "Her zaman izin ver" '
      'önerilir.';
  static const String trackingSimulationNote =
      'Simülasyon kipinde konum sunucuya yazılmaz; yalnızca uygulama açıkken '
      'sahte veriye işlenir.';
  static const String trackingVehicleDeleted =
      'Araç kaydı silindiği için konum gönderimi durduruldu.';

  // ------------------------------------------------------------- Ayarlar
  static const String settingsSessionSection = 'Oturum';
  static const String settingsSessionUid = 'Oturum kimliği (uid)';
  static const String settingsSessionAnonymous = 'Anonim oturum (sürücü)';
  static const String settingsSessionEmail = 'E-posta oturumu (yönetici)';
  static const String settingsAdminDeviceWarning =
      'Yönetici girişi bu cihazdaki anonim sürücü oturumunun yerini alır. '
      'Bu yüzden yönetici cihazı takip edilen bir araç olmamalıdır.';
}
