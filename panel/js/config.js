// Panelin arka uç seçimi.
//
// Aşağıdaki nesne boş kaldığı sürece panel **demo kipinde** çalışır: veriler
// bellekte üretilir, hiçbir şey sunucuya yazılmaz. Firebase Console ->
// Proje ayarları -> Web uygulaması bölümünden alınan değerler buraya
// yapıştırıldığı anda panel gerçek Realtime Database'e bağlanır.
//
// Bu dosya derlenmez; konteynere salt-okunur bağlanan asıl dosyadır.
// Değiştirdikten sonra tarayıcıyı yenilemek yeterlidir.
//
// databaseURL örneği:
//   https://filo-takip-default-rtdb.europe-west1.firebasedatabase.app

export const firebaseConfig = {
  apiKey: '',
  authDomain: '',
  databaseURL: '',
  projectId: '',
  appId: '',
};

const REQUIRED_KEYS = ['apiKey', 'authDomain', 'databaseURL', 'projectId', 'appId'];

// Gerçek arka uca geçmek için hepsi dolu olmalı. Yarım yapılandırma, sessizce
// bozuk bir bağlantı kurmaktansa demo kipinde kalsın.
function isFirebaseConfigured() {
  return REQUIRED_KEYS.every(
    (key) => typeof firebaseConfig[key] === 'string' && firebaseConfig[key].length > 0,
  );
}

export const useDemoBackend = !isFirebaseConfigured();

// Haritanın açılış noktası; uygulamadaki MapScreen ile aynı (Nevşehir).
export const mapDefaults = {
  centerLat: 38.6246,
  centerLng: 34.7142,
  zoom: 12,
  focusZoom: 15,
  tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
};
