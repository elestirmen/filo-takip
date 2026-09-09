import '../models/app_user.dart';

/// Oturum işlemleri. Gerçek uygulaması Firebase Auth, simülasyon uygulaması
/// bellek içi sahte oturumdur.
abstract class SessionService {
  /// Oturum değişimleri. Oturum yoksa `null` yayar; açılış akışı bunu görüp
  /// anonim girişi yeniden yapar.
  Stream<AppUser?> get userChanges;

  AppUser? get currentUser;

  Future<void> signInAnonymously();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  void dispose();
}
