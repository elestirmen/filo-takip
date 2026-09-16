// Konum geçmişinden yol, süre ve durak çıkarımı. Saf fonksiyon, birim testle
// kaplanır.
//
// Gerçek GPS verisi gürültülüdür: araç dururken bile konum birkaç metre
// oynar ve arada sıçrayan tek tük kayıt olur. İkisi de mesafeyi şişirir, o
// yüzden aşağıdaki eşiklerle ayıklanır.

import { StatusThresholds } from './vehicle-status.js';
import { distanceM } from './geo.js';

export const ReportThresholds = Object.freeze({
  // Bu süreden uzun duruş "durak" sayılır. Kısa duruşlar (kavşak, trafik)
  // rapora girmez.
  minStopMs: 3 * 60 * 1000,
  // Bundan kısa adımlar GPS titremesi sayılıp yola eklenmez.
  minSegmentM: 8,
  // Bu hızı aşan bir adım veri hatasıdır (tünel çıkışı, kötü sinyal);
  // mesafeye katılmaz.
  maxPlausibleKmh: 250,
});

const isStopped = (sample) => sample.speedKmh <= StatusThresholds.movingAboveKmh;
const hasLocation = (sample) => sample.lat !== 0 || sample.lng !== 0;

// Kayıtlardan özet çıkarır. Giriş sırası önemsizdir; zamana göre sıralanır.
//
// Dönen değer:
//   from, to            ilk ve son kaydın zamanı (ms)
//   distanceM           katedilen yol
//   movingMs, stoppedMs hareket ve duruş süresi
//   maxSpeedKmh         görülen en yüksek hız
//   stops               [{lat, lng, startedAt, endedAt, durationMs}]
export function tripReport(samples) {
  const points = samples.filter(hasLocation).sort((a, b) => a.recordedAt - b.recordedAt);

  const empty = {
    from: 0,
    to: 0,
    distanceM: 0,
    movingMs: 0,
    stoppedMs: 0,
    maxSpeedKmh: 0,
    sampleCount: points.length,
    stops: [],
  };
  if (points.length === 0) return empty;

  let distance = 0;
  let movingMs = 0;
  let stoppedMs = 0;
  let maxSpeedKmh = 0;
  const stops = [];
  // Süregelen duruş; yeterince uzarsa durak listesine geçer.
  let stopRun = null;

  const closeStopRun = () => {
    if (stopRun === null) return;
    const durationMs = stopRun.endedAt - stopRun.startedAt;
    if (durationMs >= ReportThresholds.minStopMs) {
      stops.push({ ...stopRun, durationMs });
    }
    stopRun = null;
  };

  for (let i = 0; i < points.length; i++) {
    const point = points[i];
    maxSpeedKmh = Math.max(maxSpeedKmh, point.speedKmh);

    if (isStopped(point)) {
      if (stopRun === null) {
        stopRun = {
          lat: point.lat,
          lng: point.lng,
          startedAt: point.recordedAt,
          endedAt: point.recordedAt,
        };
      } else {
        stopRun.endedAt = point.recordedAt;
      }
    } else {
      closeStopRun();
    }

    if (i === 0) continue;
    const previous = points[i - 1];
    const stepMs = point.recordedAt - previous.recordedAt;
    if (stepMs <= 0) continue;

    const stepM = distanceM(previous.lat, previous.lng, point.lat, point.lng);
    const stepKmh = (stepM / 1000) / (stepMs / 3600000);

    // Aralık, **gerçekten yol alındıysa** hareket sayılır; kararı anlık hız
    // alanı değil katedilen mesafe verir.
    //
    // Uç noktaların hızına bakmak yanıltıyordu: hareketten duruşa geçen bir
    // aralık (son kayıt 30 km/s, sonraki 0) on dakikalık molayı hareket
    // süresine yazıyor ve ortalama hızı altı kat düşürüyordu.
    const realMove =
      stepM >= ReportThresholds.minSegmentM && stepKmh <= ReportThresholds.maxPlausibleKmh;

    if (realMove) {
      distance += stepM;
      movingMs += stepMs;
    } else {
      // Titreme, duruş ve inandırıcı olmayan sıçramalar duruşa yazılır;
      // toplam süre böylece kayıtlarla tutar.
      stoppedMs += stepMs;
    }
  }
  closeStopRun();

  return {
    from: points[0].recordedAt,
    to: points[points.length - 1].recordedAt,
    distanceM: distance,
    movingMs,
    stoppedMs,
    maxSpeedKmh,
    sampleCount: points.length,
    stops,
  };
}

// Hareket hâlindeki ortalama hız (km/s). Duruşlar dışarıda bırakılır, yoksa
// uzun bir molada ortalama anlamsızca düşer.
export function averageMovingSpeedKmh(report) {
  if (report.movingMs <= 0) return 0;
  return (report.distanceM / 1000) / (report.movingMs / 3600000);
}
