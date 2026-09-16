import { Strings } from './strings.js';

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
};

// Harita katmanları. Sağ üstteki seçiciden değiştirilir, seçim tarayıcıda
// hatırlanır. İkisi de anahtarsız ve ücretsizdir; kullanım koşulları atıf
// göstermeyi şart koşar, o yüzden attribution alanları boş bırakılmamalıdır.
export const mapLayers = [
  {
    id: 'sokak',
    label: Strings.mapLayerStreet,
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap katkıcıları',
    maxZoom: 19,
  },
  {
    id: 'uydu',
    label: Strings.mapLayerSatellite,
    // Esri World Imagery. Dikkat: karo yolu {z}/{y}/{x} sırasındadır,
    // OpenStreetMap'teki {z}/{x}/{y} değil.
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Uydu görüntüleri &copy; Esri',
    maxZoom: 19,
    // Çıplak uyduda sokak ve yer adı yok; okunur kalsın diye üstüne saydam
    // bir etiket katmanı bindirilir.
    labelsUrl:
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
  },
];

export const defaultMapLayerId = 'sokak';
