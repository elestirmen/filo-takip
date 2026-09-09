import '../models/group_config.dart';
import '../models/location_sample.dart';
import '../models/vehicle.dart';

/// Filo verisine erişim. Gerçek uygulaması Realtime Database, simülasyon
/// uygulaması bellek içi sahte veridir.
///
/// Hata politikası:
/// * `Future` döndüren yazma/okuma çağrıları başarısız olursa
///   [BackendException] **fırlatır** — çağıran ekran bunu yakalayıp forma
///   ya da düğmeye özel bir mesaj gösterir.
/// * Sürekli dinlenen akışların (araçlar, gruplar, yetki) hataları [errors]
///   akışından **tek seferlik olay** olarak yayılır. Bu akış son değeri
///   saklamaz; yeni bir dinleyici eski hatayı tekrar almaz.
abstract class FleetRepository {
  /// Konum geçmişine iki kayıt arasındaki en kısa süre.
  /// Araç düğümü daha sık güncellenir; geçmiş kaydı seyrektir.
  static const Duration historyMinInterval = Duration(seconds: 45);

  /// Araç başına saklanan en fazla geçmiş kaydı. Fazlası budanır.
  static const int historyMaxRecords = 500;

  /// Yönetici geçmişi açtığında tek seferde okunan kayıt sayısı.
  static const int historyReadLimit = 500;

  /// Bu cihazın oturum kimliği. Sürücü için aynı zamanda aracın kimliğidir.
  String get uid;

  // ------------------------------------------------------------- Akışlar

  Stream<List<Vehicle>> get vehicles;
  List<Vehicle> get latestVehicles;

  Stream<List<GroupConfig>> get groupConfigs;
  List<GroupConfig> get latestGroupConfigs;

  /// `admins/{uid}` düğümünün varlığı. Cihazda saklanan bir bayrak değildir.
  Stream<bool> get isAdmin;
  bool get latestIsAdmin;

  /// Tek seferlik hata olayları. Bkz. sınıf açıklaması.
  Stream<String> get errors;

  // --------------------------------------------------------------- Zaman

  /// Uygulamadaki tek "şu an" kaynağı: cihaz saati + sunucu zaman ofseti.
  ///
  /// `updatedAt` sunucu zamanıdır; bayatlık hesabı yapılırken cihaz saatiyle
  /// doğrudan karşılaştırılmaz.
  int nowMs();

  // -------------------------------------------------------------- Yazma

  /// Yalnızca `plate` ve `driverName` alanlarını günceller.
  /// `approved` ve `groupId` alanlarına dokunmaz.
  Future<void> saveRegistration({
    required String plate,
    required String driverName,
  });

  /// Araç düğümündeki konum alanlarını günceller ve gerekiyorsa geçmişe
  /// kayıt ekler. Geçmiş yazımı [historyMinInterval] ile seyrekleştirilir.
  Future<void> writeLocation({
    required double lat,
    required double lng,
    required double speedKmh,
  });

  Future<void> setVehicleApproved(String vehicleId, {required bool approved});

  Future<void> setVehicleGroup(String vehicleId, String? groupId);

  /// Araç düğümünü ve konum geçmişini **tek bir çok yollu güncellemeyle**
  /// birlikte siler; iki ayrı silme yetim veri bırakırdı.
  Future<void> deleteVehicle(String vehicleId);

  Future<void> saveGroupConfig(GroupConfig config);

  /// Grubu siler; bağlı araçların grup atamasını ve diğer grupların
  /// `visibleGroups` listelerini aynı güncellemede temizler.
  Future<void> deleteGroup(String groupId);

  // -------------------------------------------------------------- Okuma

  /// Tek seferlik okuma, en yeni [historyReadLimit] kayıt, en yeni üstte.
  Future<List<LocationSample>> loadHistory(String vehicleId);

  /// `admins/{uid}` düğümünü tek seferlik okur. Yönetici girişinden hemen
  /// sonra yetki doğrulamak için kullanılır.
  Future<bool> isAdminOnce(String userId);

  void dispose();
}
