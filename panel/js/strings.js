// Paneldeki tüm kullanıcıya görünen metinler burada toplanır.
//
// Kural, uygulamadaki lib/core/strings.dart ile aynı: görünüm dosyalarının
// içine metin yazılmaz, önce buraya eklenir sonra kullanılır. Uygulamayla
// ortak olan metinler birebir aynı tutulur ki iki arayüz aynı dili konuşsun.

export const Strings = Object.freeze({
  // ---------------------------------------------------------------- Genel
  appTitle: 'Filo Takip',
  panelTitle: 'Filo Takip Yönetim Paneli',
  loading: 'Yükleniyor…',
  retry: 'Tekrar dene',
  cancel: 'Vazgeç',
  close: 'Kapat',
  ok: 'Tamam',
  visible: 'Görünür',
  hidden: 'Gizli',
  save: 'Kaydet',
  search: 'Ara',
  refresh: 'Yenile',

  // ---------------------------------------------------------- Simülasyon
  demoBadge: 'DEMO',
  demoNoticeTitle: 'Demo kipi',
  demoNotice:
    'Panel şu anda sahte verilerle çalışıyor. Hiçbir veri sunucuya yazılmıyor '
    + 've sayfayı yenileyince değişiklikler kaybolur.',
  demoAccountsHint: 'Demo hesapları:',
  demoAdminAccount: 'yonetici@ornek.com / 123456 — yönetici',
  demoViewerAccount: 'izleyici@ornek.com / 123456 — izleyici (Merkez grubu)',
  demoPendingAccount: 'bekleyen@ornek.com / 123456 — onay bekleyen hesap',
  demoConfigHint:
    'Gerçek veriye geçmek için js/config.js dosyasına Firebase web '
    + 'yapılandırmasını yapıştırın.',

  // ------------------------------------------------------------- Gezinme
  navMap: 'Harita',
  navVehicles: 'Araçlar',
  navGroups: 'Gruplar',
  navUsers: 'Kullanıcılar',
  navSettings: 'Ayarlar',

  // --------------------------------------------------------------- Giriş
  loginTitle: 'Panele giriş',
  loginSubtitle: 'Filo Takip yönetim paneli',
  loginEmailLabel: 'E-posta',
  loginPasswordLabel: 'Şifre',
  loginButton: 'Giriş yap',
  loginBusy: 'Giriş yapılıyor…',
  logoutButton: 'Çıkış yap',
  registerTitle: 'Yeni hesap',
  registerNameLabel: 'Ad Soyad',
  registerButton: 'Hesap oluştur',
  registerBusy: 'Hesap oluşturuluyor…',
  registerSwitch: 'Hesabınız yok mu? Kayıt olun',
  loginSwitch: 'Zaten hesabınız var mı? Giriş yapın',
  registerHint:
    'Kaydolduktan sonra hesabınız yönetici onayı bekler. Yönetici sizi bir '
    + 'gruba atayınca o grubun araçlarını haritada görürsünüz.',

  emailRequired: 'E-posta girin.',
  emailInvalid: 'Geçerli bir e-posta girin.',
  passwordRequired: 'Şifre girin.',
  passwordTooShort: 'Şifre en az 6 karakter olmalı.',
  nameRequired: 'Ad Soyad girin.',
  nameTooShort: 'Ad Soyad en az 3 karakter olmalı.',

  // ------------------------------------------------------------- Hatalar
  errorInvalidCredentials: 'E-posta veya şifre hatalı.',
  errorNetwork: 'Ağ bağlantısı kurulamadı. İnternet bağlantınızı kontrol edin.',
  errorTooManyRequests: 'Çok fazla deneme yapıldı. Bir süre bekleyip tekrar deneyin.',
  errorProviderDisabled: 'Bu giriş yöntemi Firebase Console üzerinde etkin değil.',
  errorEmailInUse: 'Bu e-posta ile bir hesap zaten var.',
  errorWeakPassword: 'Şifre çok zayıf. En az 6 karakter kullanın.',
  errorSignInFailed: 'Giriş yapılamadı.',
  errorSignOutFailed: 'Oturum kapatılamadı.',
  errorPermissionDenied: 'Bu işlem için yetkiniz yok.',
  errorSaveFailed: 'Kaydetme işlemi tamamlanamadı.',
  errorDeleteFailed: 'Silme işlemi tamamlanamadı.',
  errorHistoryLoadFailed: 'Konum geçmişi okunamadı.',
  errorVehiclesStream: 'Araç listesi alınamadı. Bağlantınızı kontrol edin.',
  errorGroupConfigsStream: 'Grup ayarları alınamadı.',
  errorUsersStream: 'Kullanıcı listesi alınamadı.',
  errorAdminStream: 'Yönetici yetkisi okunamadı.',
  errorStartupTitle: 'Panel başlatılamadı',
  errorFirebaseInit:
    'Firebase bağlantısı kurulamadı. js/config.js içindeki değerleri kontrol edin.',

  // --------------------------------------------------------------- Roller
  roleAdmin: 'Yönetici',
  roleViewer: 'İzleyici',
  rolePending: 'Onay bekliyor',
  roleAdminHint: 'Tüm araçları görür, her ayarı değiştirebilir.',
  roleViewerHint: 'Yalnızca atandığı grubun araçlarını salt-okunur görür.',
  rolePendingHint: 'Yönetici onaylayana kadar hiçbir araç görünmez.',

  pendingTitle: 'Hesabınız onay bekliyor',
  pendingMessage:
    'Yönetici hesabınızı onaylayıp bir gruba atadığında o grubun araçları '
    + 'haritada görünmeye başlayacak. Bu sayfa kendiliğinden güncellenir.',
  viewerNoGroupTitle: 'Henüz bir gruba atanmadınız',
  viewerNoGroupMessage:
    'Hesabınız onaylı ama bir gruba atanmadığı için görüntülenecek araç yok. '
    + 'Yöneticinin sizi bir gruba atamasını bekleyin.',

  // -------------------------------------------------------------- Harita
  mapSummaryTitle: 'Filo özeti',
  mapSummaryTotal: 'Toplam',
  mapStatusMoving: 'Hareketli',
  mapStatusStopped: 'Duruyor',
  mapStatusOffline: 'Çevrimdışı',
  mapStatusPending: 'Onay bekliyor',
  mapFilterAll: 'Tümü',
  mapFilterUngrouped: 'Grupsuz',
  mapEmptyTitle: 'Görüntülenecek araç yok',
  mapEmptyAdminHint:
    'Henüz kayıtlı araç yok. Sürücüler uygulamadaki Kayıt sekmesinden talep '
    + 'gönderdiğinde burada görünürler.',
  mapEmptyViewerHint:
    'Grubunuzda haritada gösterilecek araç yok.',
  mapFieldHidden: 'Gizli',
  mapFieldSpeed: 'Hız',
  mapFieldDriver: 'Sürücü',
  mapFieldGroup: 'Grup',
  mapFieldUpdated: 'Son güncelleme',
  mapFieldCoords: 'Koordinat',
  mapGroupNone: 'Atanmamış',
  mapNoLocationYet: 'Bu aracın henüz konumu yok.',
  mapFitAll: 'Tümünü sığdır',
  mapLayerStreet: 'Sokak',
  mapLayerSatellite: 'Uydu',
  mapFollow: 'Takip et',
  mapFollowing: 'Takip ediliyor',
  mapHiddenNoLocation: 'konumu olmayan araç haritada gösterilmiyor',

  // ---------------------------------------------------------------- Zaman
  timeJustNow: 'Az önce',
  timeMinutesAgo: 'dakika önce',
  timeHoursAgo: 'saat önce',
  timeDaysAgo: 'gün önce',
  timeNever: 'Hiç güncellenmedi',
  unitSpeed: 'km/s',

  // -------------------------------------------------------------- Araçlar
  vehiclesTitle: 'Araçlar',
  vehiclesSearchHint: 'Plaka veya sürücü ara',
  colPlate: 'Plaka',
  colDriver: 'Sürücü',
  colGroup: 'Grup',
  colStatus: 'Durum',
  colSpeed: 'Hız',
  colUpdated: 'Son güncelleme',
  colActions: 'İşlemler',

  summaryTotal: 'Toplam',
  summaryPending: 'Bekleyen',
  summaryApproved: 'Onaylı',
  summaryGroups: 'Grup',

  noVehicles: 'Kayıtlı araç yok',
  noVehiclesHint:
    'Sürücüler uygulamadaki Kayıt sekmesinden talep gönderdiğinde burada '
    + 'görünürler.',
  noSearchResult: 'Aramayla eşleşen kayıt yok.',

  approve: 'Onayla',
  revoke: 'Onayı kaldır',
  assignGroup: 'Grup ata',
  viewHistory: 'Konum geçmişi',
  showOnMap: 'Haritada göster',
  deleteVehicle: 'Aracı sil',
  deleteVehicleTitle: 'Araç silinsin mi?',
  deleteVehicleMessage:
    'Araç kaydı ve tüm konum geçmişi kalıcı olarak silinecek. Bu işlem geri '
    + 'alınamaz.',
  delete: 'Sil',
  vehicleApproved: 'Araç onaylandı.',
  vehicleRevoked: 'Aracın onayı kaldırıldı.',
  vehicleDeleted: 'Araç ve konum geçmişi silindi.',
  groupAssigned: 'Grup ataması güncellendi.',
  groupNone: 'Grupsuz',
  selectGroupTitle: 'Grup seç',

  // -------------------------------------------------------------- Gruplar
  groupsTitle: 'Gruplar',
  noGroups: 'Henüz grup yok',
  noGroupsHint: 'Yeni bir grup oluşturarak başlayın.',
  createGroup: 'Grup oluştur',
  groupNameLabel: 'Grup adı',
  groupNameHint: 'Merkez',
  groupNameRequired: 'Grup adı girin.',
  groupNameExists: 'Bu adda bir grup zaten var.',
  groupCreated: 'Grup oluşturuldu.',
  editGroup: 'Grup ayarları',
  visibleGroupsLabel: 'Görünür gruplar',
  visibleGroupsHelp:
    'Bu gruptaki sürücüler ve izleyiciler kendi grubuna ek olarak burada '
    + 'işaretlenen grupları görür.',
  showSpeed: 'Hız görünsün',
  showDriverName: 'Sürücü adı görünsün',
  fieldVisibilityHelp:
    'Kapatılan alan bu gruptaki araçlarda diğer sürücülere gizlenir. Sürücü '
    + 'kendi aracını, yönetici ise tüm araçları her zaman tam görür.',
  groupSaved: 'Grup ayarları kaydedildi.',
  deleteGroupTitle: 'Grup silinsin mi?',
  deleteGroupMessage:
    'Bu gruptaki araçların grup ataması kaldırılacak, gruba atanmış '
    + 'izleyiciler grupsuz kalacak ve grup, diğer grupların görünür '
    + 'listelerinden çıkarılacak.',
  groupDeleted: 'Grup silindi.',
  vehicleCountSuffix: 'araç',
  viewerCountSuffix: 'izleyici',

  // --------------------------------------------------------- Kullanıcılar
  usersTitle: 'Panel kullanıcıları',
  usersHint:
    'Panele e-posta ile kaydolan hesaplar burada listelenir. Yetkiyi ve '
    + 'grubu yalnızca yönetici değiştirir.',
  colUser: 'Kullanıcı',
  colEmail: 'E-posta',
  colRole: 'Yetki',
  colCreated: 'Kayıt',
  noUsers: 'Panele kayıtlı kullanıcı yok',
  noUsersHint: 'Kullanıcılar giriş ekranındaki "Kayıt olun" bağlantısını kullanır.',
  userApproved: 'Kullanıcı onaylandı.',
  userRevoked: 'Kullanıcının onayı kaldırıldı.',
  userGroupAssigned: 'Kullanıcının grubu güncellendi.',
  userRoleChanged: 'Kullanıcının yetkisi güncellendi.',
  deleteUserTitle: 'Kullanıcı kaydı silinsin mi?',
  deleteUserMessage:
    'Panel kaydı silinecek ve kullanıcı yeniden onay bekleyen duruma düşecek. '
    + 'Firebase Authentication hesabı silinmez; onu Firebase Console üzerinden '
    + 'kaldırmanız gerekir.',
  userDeleted: 'Kullanıcı kaydı silindi.',
  makeAdmin: 'Yönetici yap',
  removeAdmin: 'Yöneticiliği kaldır',
  makeAdminTitle: 'Yönetici yapılsın mı?',
  makeAdminMessage:
    'Bu hesap tüm araçları görebilecek, grupları ve diğer kullanıcıların '
    + 'yetkilerini değiştirebilecek. Yönetici yetkisi sınırsızdır.',
  removeAdminTitle: 'Yöneticilik kaldırılsın mı?',
  removeAdminMessage:
    'Hesap yönetici listesinden çıkarılacak ve izleyici yetkisine düşecek.',
  selfRoleLocked: 'Kendi yetkinizi bu ekrandan değiştiremezsiniz.',
  youBadge: 'Siz',

  // ------------------------------------------------------- Geçmiş rota
  playbackTitle: 'Geçmiş rota',
  playbackLoading: 'Geçmiş yükleniyor…',
  playbackEmpty: 'Bu araç için konum kaydı yok.',
  playbackNoRoute: 'Kayıtlar tek noktada; çizilecek rota yok.',
  playbackPlay: 'Oynat',
  playbackPause: 'Duraklat',
  playbackReplay: 'Baştan',
  playbackSpeedLabel: 'Hız',
  playbackSpeedSlow: 'Yavaş',
  playbackSpeedNormal: 'Normal',
  playbackSpeedFast: 'Hızlı',
  playbackBackToLive: 'Canlıya dön',
  playbackShowRecords: 'Kayıtları göster',
  playbackFollow: 'Haritada takip et',
  stopLabel: 'Durak',

  reportDistance: 'Katedilen yol',
  reportMoving: 'Hareket süresi',
  reportStopped: 'Duruş süresi',
  reportMaxSpeed: 'En yüksek hız',
  reportAvgSpeed: 'Ortalama hız',
  reportStops: 'Durak sayısı',
  reportRange: 'Kapsanan aralık',
  reportWindowNote:
    'Uygulama araç başına en fazla 500 konum kaydı tutar (45 saniyede bir), '
    + 'yani geçmiş yaklaşık son 6 saati kapsar. Daha eskisi otomatik silinir.',

  // ------------------------------------------------------- Konum geçmişi
  historyTitle: 'Konum geçmişi',
  historyEmpty: 'Bu araç için konum kaydı yok.',
  historyRecordSuffix: 'kayıt',
  historyLimitNote: 'En yeni 500 kayıt gösterilir, en yeni üstte.',
  historyShowTrack: 'Rotayı haritada göster',
  historyHideTrack: 'Rotayı gizle',
  historyTrackShown: 'Rota haritada çizildi.',
  colTime: 'Zaman',
  colCoords: 'Koordinat',

  // ------------------------------------------------------------- Ayarlar
  settingsTitle: 'Ayarlar',
  settingsSession: 'Oturum',
  settingsAccount: 'Hesap',
  settingsUid: 'Oturum kimliği (uid)',
  settingsEmail: 'E-posta',
  settingsRole: 'Yetki',
  settingsGroup: 'Grup',
  settingsBackend: 'Arka uç',
  settingsBackendDemo: 'Demo (bellek içi sahte veri)',
  settingsBackendFirebase: 'Firebase Realtime Database',
  settingsProject: 'Proje',
  settingsAbout: 'Panel hakkında',
  settingsAboutText:
    'Bu panel, Filo Takip Android uygulamasıyla aynı veritabanını okur. '
    + 'Araç kaydı ve konum gönderimi yalnızca uygulamadan yapılır; panel '
    + 'yönetim ve izleme içindir.',
});
