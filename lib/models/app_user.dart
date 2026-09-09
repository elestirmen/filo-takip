/// Oturum açmış kullanıcı. Firebase'in `User` tipinden bağımsız tutulur ki
/// simülasyon arka ucu da aynı tipi üretebilsin.
class AppUser {
  const AppUser({required this.uid, required this.isAnonymous, this.email});

  /// Sürücüler için bu değer aynı zamanda aracın kimliğidir.
  final String uid;

  final bool isAnonymous;
  final String? email;

  @override
  String toString() => 'AppUser($uid, anonim: $isAnonymous)';
}
