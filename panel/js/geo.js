// Coğrafi hesaplar. Hepsi saf fonksiyondur, doğrudan birim testle kaplanır.
//
// Mesafeler haversine ile hesaplanır: küresel yaklaşım, birkaç metre hatayla.
// Filo takibinde ölçülen şey onlarca metre ile kilometreler arası olduğu için
// bu yaklaşım fazlasıyla yeterlidir, elipsoit hesabına gerek yoktur.

const EARTH_RADIUS_M = 6371008.8;

const toRad = (degrees) => (degrees * Math.PI) / 180;

// İki nokta arasındaki mesafe, metre.
export function distanceM(lat1, lng1, lat2, lng2) {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a)));
}

// Nokta, merkezi (lat, lng) olan yarıçapı metre cinsinden dairenin içinde mi.
export function isInsideCircle(pointLat, pointLng, centerLat, centerLng, radiusM) {
  return distanceM(pointLat, pointLng, centerLat, centerLng) <= radiusM;
}

// Metreyi okunur metne çevirir: 940 m, 12,4 km.
export function formatDistance(metres) {
  if (!Number.isFinite(metres) || metres < 0) return '0 m';
  if (metres < 1000) return `${Math.round(metres)} m`;
  return `${(metres / 1000).toFixed(1).replace('.', ',')} km`;
}

// Süreyi okunur metne çevirir: 45 sn, 12 dk, 2 sa 5 dk.
export function formatDuration(millis) {
  if (!Number.isFinite(millis) || millis <= 0) return '0 dk';
  // Eşik yuvarlamadan ÖNCE bakılır; yoksa 45 saniye "1 dk" olurdu.
  if (millis < 60000) return `${Math.round(millis / 1000)} sn`;
  const totalMinutes = Math.round(millis / 60000);
  if (totalMinutes < 60) return `${totalMinutes} dk`;
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return minutes === 0 ? `${hours} sa` : `${hours} sa ${minutes} dk`;
}
