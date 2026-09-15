// Zaman biçimlendirme. lib/core/time_format.dart dosyasının karşılığı.
// "şu an" değeri her zaman dışarıdan verilir ki tarayıcı saati ile sunucu
// zamanı karışmasın.

import { Strings } from './strings.js';

function pad(value) {
  return value.toString().padStart(2, '0');
}

// `dd.MM.yyyy HH:mm:ss` — konum geçmişi listesinde kullanılır.
export function formatTimestamp(millis) {
  if (millis <= 0) return Strings.timeNever;
  const date = new Date(millis);
  const day = `${pad(date.getDate())}.${pad(date.getMonth() + 1)}.${date.getFullYear()}`;
  const time = `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  return `${day} ${time}`;
}

// "Az önce", "3 dakika önce", "2 saat önce", "4 gün önce".
export function relativeTime(millis, nowMs) {
  if (millis <= 0) return Strings.timeNever;

  const diff = nowMs - millis;
  // Sunucu zamanı tarayıcınınkinden birkaç saniye ileri olabilir.
  if (diff < 0) return Strings.timeJustNow;

  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return Strings.timeJustNow;

  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} ${Strings.timeMinutesAgo}`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} ${Strings.timeHoursAgo}`;

  return `${Math.floor(hours / 24)} ${Strings.timeDaysAgo}`;
}

// "52 km/s" — ondalık gösterilmez, hız zaten yaklaşık bir değerdir.
export function formatSpeed(speedKmh) {
  const rounded = Number.isFinite(speedKmh) ? Math.round(speedKmh) : 0;
  return `${rounded} ${Strings.unitSpeed}`;
}

// Haritadaki açılır balonda ve geçmiş listesinde koordinat gösterimi.
export function formatCoords(lat, lng) {
  return `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
}
