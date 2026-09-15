// Metin normalizasyonu. lib/core/normalize.dart dosyasının karşılığı.
// Hepsi saf fonksiyondur.

const WHITESPACE = /\s+/g;

// Realtime Database anahtarlarında kullanılamayan karakterler.
const INVALID_KEY_CHARS = /[.$#[\]/\x00-\x1F\x7F]/g;

// Türkçe kurallarına göre büyük harfe çevirir.
//
// JS'in toUpperCase() metodu da Dart'ınki gibi locale tanımaz: `i` harfini `I`
// yapar, Türkçe'de karşılığı `İ` olmalıdır. `ı` harfi de `I` olmalıdır.
export function turkishUpperCase(value) {
  let result = '';
  for (const char of value) {
    if (char === 'i') result += 'İ';
    else if (char === 'ı') result += 'I';
    else result += char.toUpperCase();
  }
  return result;
}

// Baş/son ve tekrarlı boşlukları temizler, büyük/küçük harfe dokunmaz.
export function normalizeDriverName(raw) {
  return raw.trim().replace(WHITESPACE, ' ');
}

// Grup adı aynı zamanda veritabanı anahtarıdır; yasak karakterler atılır.
export function normalizeGroupName(raw) {
  return raw.trim().replace(WHITESPACE, ' ').replace(INVALID_KEY_CHARS, '').trim();
}

// E-posta biçimi. Formun kendi kontrolüdür, güvenlik sınırı değildir;
// asıl doğrulamayı Firebase Auth yapar.
export function isValidEmail(raw) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(raw.trim());
}
