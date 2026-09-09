/// Realtime Database'den gelen ham değerleri güvenli okumak için yardımcılar.
///
/// RTDB tip garantisi vermez:
/// * `12.0` yazılan bir sayı `12` (int) olarak geri gelebilir,
/// * bir liste araya boşluk girerse `Map` olarak döner, boş liste hiç gelmez,
/// * silinen ya da hiç yazılmamış alan `null`'dır.
///
/// Bu yüzden her alan savunmacı okunur; eksik alan varsayılana düşer.
library;

/// İç içe düğümleri `Map<String, Object?>` olarak verir.
Map<String, Object?> dbMap(Object? raw) {
  if (raw is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in raw.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return const <String, Object?>{};
}

String dbString(Object? raw, {String fallback = ''}) {
  return raw is String ? raw : fallback;
}

/// Boş metni de `null` sayar; `groupId` gibi "yok" durumu olan alanlar için.
String? dbStringOrNull(Object? raw) {
  if (raw is String && raw.isNotEmpty) return raw;
  return null;
}

double dbDouble(Object? raw, {double fallback = 0}) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? fallback;
  return fallback;
}

int dbInt(Object? raw, {int fallback = 0}) {
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? fallback;
  return fallback;
}

bool dbBool(Object? raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  return fallback;
}

/// Metin listesi. RTDB listeyi `List` ya da (aralarında boşluk varsa)
/// sayısal anahtarlı `Map` olarak döndürebilir; ikisini de kabul eder.
List<String> dbStringList(Object? raw) {
  if (raw is List) {
    return <String>[
      for (final Object? value in raw)
        if (value is String && value.isNotEmpty) value,
    ];
  }
  if (raw is Map) {
    return <String>[
      for (final Object? value in raw.values)
        if (value is String && value.isNotEmpty) value,
    ];
  }
  return const <String>[];
}
