import 'package:firebase_auth/firebase_auth.dart';

import '../core/strings.dart';
import '../models/app_user.dart';
import 'backend_exception.dart';
import 'session_service.dart';

/// Gerçek arka uç: Firebase Auth.
class FirebaseSessionService implements SessionService {
  FirebaseSessionService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      throw BackendException(_messageFor(error));
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw BackendException(_messageFor(error));
    }
  }

  /// Çıkışta oturum boşa düşer; açılış akışı bunu görüp cihazı yeniden
  /// anonim sürücü oturumuna döndürür.
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      throw const BackendException(Strings.errorSignOutFailed);
    }
  }

  @override
  void dispose() {}

  static AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
    );
  }

  static String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return Strings.errorInvalidCredentials;
      case 'network-request-failed':
        return Strings.errorNetwork;
      case 'too-many-requests':
        return Strings.errorTooManyRequests;
      case 'operation-not-allowed':
        return Strings.errorProviderDisabled;
      default:
        return Strings.errorSignInFailed;
    }
  }
}
