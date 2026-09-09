/// Hangi arka ucun kullanılacağı derleme sırasında seçilir.
///
/// ```
/// flutter run                                  -> simülasyon (varsayılan)
/// flutter run --dart-define=BACKEND=firebase   -> gerçek Firebase
/// ```
///
/// Varsayılan şimdilik simülasyon; Firebase projesi hazır olunca burada
/// varsayılanı `firebase` yapacağız.
class AppConfig {
  const AppConfig._();

  static const String backend = String.fromEnvironment(
    'BACKEND',
    defaultValue: 'fake',
  );

  static bool get useFakeBackend => backend != 'firebase';
}
