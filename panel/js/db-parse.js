// Realtime Database'den gelen ham değerleri güvenli okumak için yardımcılar.
// lib/core/db_parse.dart dosyasının karşılığı.
//
// RTDB tip garantisi vermez: sayı int ya da double dönebilir, bir liste araya
// boşluk girerse Map olur, yazılmamış alan null'dır. Bu yüzden her alan
// savunmacı okunur; eksik alan varsayılana düşer.

export function dbMap(raw) {
  if (raw !== null && typeof raw === 'object' && !Array.isArray(raw)) return raw;
  return {};
}

export function dbString(raw, fallback = '') {
  return typeof raw === 'string' ? raw : fallback;
}

// Boş metni de null sayar; groupId gibi "yok" durumu olan alanlar için.
export function dbStringOrNull(raw) {
  if (typeof raw === 'string' && raw.length > 0) return raw;
  return null;
}

export function dbDouble(raw, fallback = 0) {
  if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
  if (typeof raw === 'string') {
    const parsed = Number.parseFloat(raw);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

export function dbInt(raw, fallback = 0) {
  if (typeof raw === 'number' && Number.isFinite(raw)) return Math.trunc(raw);
  if (typeof raw === 'string') {
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

export function dbBool(raw, fallback = false) {
  if (typeof raw === 'boolean') return raw;
  if (typeof raw === 'number') return raw !== 0;
  return fallback;
}

// Metin listesi. RTDB listeyi dizi ya da sayısal anahtarlı Map olarak
// döndürebilir; ikisi de kabul edilir.
export function dbStringList(raw) {
  let source = [];
  if (Array.isArray(raw)) source = raw;
  else if (raw !== null && typeof raw === 'object') source = Object.values(raw);
  return source.filter((value) => typeof value === 'string' && value.length > 0);
}
