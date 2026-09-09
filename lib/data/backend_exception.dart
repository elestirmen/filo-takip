/// Arka uçtan gelen, doğrudan kullanıcıya gösterilebilecek hata.
///
/// Firebase'in `FirebaseAuthException` / `FirebaseException` tipleri bu tipe
/// çevrilir; böylece ekranlar tek bir hata tipini yakalar ve Türkçe mesajı
/// hazır alır.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}
