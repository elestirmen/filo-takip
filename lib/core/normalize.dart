/// Metin normalizasyonu. Hepsi saf fonksiyondur: Firebase, widget ya da
/// başka bir bağımlılığı yoktur, doğrudan birim testle kaplanır.
library;

final RegExp _whitespace = RegExp(r'\s+');

/// Realtime Database anahtarlarında kullanılamayan karakterler.
final RegExp _invalidKeyChars = RegExp(r'[.$#\[\]/\x00-\x1F\x7F]');

/// Türkçe kurallarına göre büyük harfe çevirir.
///
/// Dart'ın `toUpperCase()` metodu locale tanımaz ve `i` harfini `I` yapar;
/// Türkçe'de karşılığı `İ` olmalıdır. `ı` harfi de `I` olmalıdır.
String turkishUpperCase(String value) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in value.runes) {
    if (rune == 0x69) {
      buffer.writeCharCode(0x130); // i -> İ
    } else if (rune == 0x131) {
      buffer.writeCharCode(0x49); // ı -> I
    } else {
      buffer.write(String.fromCharCode(rune).toUpperCase());
    }
  }
  return buffer.toString();
}

/// Plakayı büyük harfe çevirir ve fazla boşlukları temizler.
///
/// `"  34 abc  123 "` -> `"34 ABC 123"`
String normalizePlate(String raw) {
  return turkishUpperCase(raw.trim()).replaceAll(_whitespace, ' ');
}

/// Sürücü adındaki baş/son ve tekrarlı boşlukları temizler.
/// Büyük/küçük harfe dokunmaz.
String normalizeDriverName(String raw) {
  return raw.trim().replaceAll(_whitespace, ' ');
}

/// Grup adını normalleştirir.
///
/// Grup adı aynı zamanda veritabanı anahtarıdır; anahtarlarda `.`, `$`, `#`,
/// `[`, `]`, `/` ve kontrol karakterleri kullanılamaz, bu yüzden atılırlar.
String normalizeGroupName(String raw) {
  return raw
      .trim()
      .replaceAll(_whitespace, ' ')
      .replaceAll(_invalidKeyChars, '')
      .trim();
}

/// Yöneticinin yazdığı "görünür gruplar" metnini listeye çevirir.
///
/// Virgülle ayrılır, boşlar atılır, yinelenenler tekilleştirilir, sıra korunur.
/// `"Merkez, Kaman ,, Merkez"` -> `["Merkez", "Kaman"]`
List<String> parseGroupList(String raw) {
  final List<String> result = <String>[];
  for (final String part in raw.split(',')) {
    final String name = normalizeGroupName(part);
    if (name.isEmpty) continue;
    if (result.contains(name)) continue;
    result.add(name);
  }
  return result;
}

/// Listeyi düzenleme kutusunda gösterilecek metne çevirir.
String formatGroupList(Iterable<String> groups) => groups.join(', ');
