import 'dart:async';

import '../core/strings.dart';
import '../models/app_user.dart';
import 'backend_exception.dart';
import 'fake_backend_store.dart';
import 'latest_value.dart';
import 'session_service.dart';

/// [SessionService] arayüzünün simülasyon uygulaması.
///
/// Sürücü oturumu sabit bir uid ile açılır. Yönetici girişi yalnızca
/// [FakeBackendStore.adminEmail] / [FakeBackendStore.adminPassword] çiftini
/// kabul eder; bu bilgiler yalnızca simülasyonda geçerlidir ve gerçek
/// arka uçta hiçbir karşılığı yoktur.
class FakeSessionService implements SessionService {
  static const Duration _latency = Duration(milliseconds: 350);

  final LatestValue<AppUser?> _user = LatestValue<AppUser?>(null);

  @override
  Stream<AppUser?> get userChanges => _user.stream;

  @override
  AppUser? get currentUser => _user.latest;

  @override
  Future<void> signInAnonymously() async {
    await Future<void>.delayed(_latency);
    _user.add(
      const AppUser(uid: FakeBackendStore.driverUid, isAnonymous: true),
    );
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    final bool matches =
        email.trim().toLowerCase() == FakeBackendStore.adminEmail &&
        password == FakeBackendStore.adminPassword;
    if (!matches) {
      throw const BackendException(Strings.errorInvalidCredentials);
    }
    _user.add(
      const AppUser(
        uid: FakeBackendStore.adminUid,
        isAnonymous: false,
        email: FakeBackendStore.adminEmail,
      ),
    );
  }

  /// Çıkışta oturum boşa düşer; açılış akışı cihazı yeniden anonim sürücü
  /// oturumuna döndürür.
  @override
  Future<void> signOut() async {
    await Future<void>.delayed(_latency);
    _user.add(null);
  }

  @override
  void dispose() {
    unawaited(_user.close());
  }
}
