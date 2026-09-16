// Geçmiş rota oynatma paneli.
//
// Haritanın yan sütununu devralır: aracın rotasını çizer, duraklarını
// işaretler ve kayıtları zaman çubuğuyla ileri sarmayı sağlar. Açıkken canlı
// araç işaretçileri gizlenir, yoksa aynı araç haritada iki yerde görünür.
//
// Kayıtlar tek seferlik okunur; canlı akış değildir.

import { Strings } from './strings.js';
import { clear, el, emptyState } from './ui.js';
import { formatDistance, formatDuration } from './geo.js';
import { formatSpeed, formatTimestamp } from './time-format.js';
import { averageMovingSpeedKmh, tripReport } from './trip-report.js';
import { openHistoryTable } from './vehicle-actions.js';

// Adım aralıkları. Kayıtlar 45 saniyede bir olduğu için gerçek zamanlı
// oynatmak anlamsız yavaş olurdu; bunlar kayıt başına geçen süredir.
const SPEEDS = [
  { id: 'yavas', label: Strings.playbackSpeedSlow, stepMs: 700 },
  { id: 'normal', label: Strings.playbackSpeedNormal, stepMs: 260 },
  { id: 'hizli', label: Strings.playbackSpeedFast, stepMs: 90 },
];

export function createPlaybackPanel({ backend, mapView, vehicle, onClose }) {
  let samples = [];
  let report = null;
  let index = 0;
  let playing = false;
  let stepMs = SPEEDS[1].stepMs;
  let timer = null;
  let follow = true;
  let destroyed = false;
  // Her adımda yalnızca bu iki alan tazelenir; tüm paneli yeniden kurmak
  // kaydırıcının tutamağını kullanıcının elinden alırdı.
  let refs = null;

  const body = el('div', { class: 'playback-body' });

  const node = el('div', { class: 'playback' }, [
    el('div', { class: 'side-head' }, [
      el('div', {}, [
        el('h2', { class: 'side-title', text: Strings.playbackTitle }),
        el('p', { class: 'playback-plate', text: vehicle.plate }),
      ]),
      el('button', {
        type: 'button',
        class: 'btn btn-ghost btn-small',
        onclick: () => close(),
      }, Strings.playbackBackToLive),
    ]),
    body,
  ]);

  clear(body).append(el('p', { class: 'muted playback-status', text: Strings.playbackLoading }));

  mapView.setLiveMarkersVisible(false);

  backend
    .loadHistory(vehicle.id)
    .then((loaded) => {
      if (destroyed) return;
      // En eski kayıt başta olacak şekilde: oynatma ileriye doğru akar.
      samples = [...loaded]
        .filter((sample) => sample.lat !== 0 || sample.lng !== 0)
        .sort((a, b) => a.recordedAt - b.recordedAt);
      report = tripReport(samples);
      draw();
    })
    .catch((error) => {
      if (destroyed) return;
      clear(body).append(
        el('p', { class: 'form-error', text: error?.message ?? Strings.errorHistoryLoadFailed }),
      );
    });

  function draw() {
    if (samples.length === 0) {
      clear(body).append(emptyState(Strings.playbackEmpty));
      return;
    }

    const drawn = mapView.showRoute(samples, stopsForMap());
    mapView.setPlaybackPosition(samples[index]);

    // DOM'un append'i null'ı "null" metnine çevirir; el() bunu filtreler ama
    // burada doğrudan çağrıldığı için koşullu parçalar elenmeli.
    clear(body).append(
      ...[
        drawn < 2 ? el('p', { class: 'field-hint', text: Strings.playbackNoRoute }) : null,
        controls(),
        summary(),
        el('p', { class: 'field-hint', text: Strings.reportWindowNote }),
      ].filter((child) => child !== null),
    );
  }

  function stopsForMap() {
    return report.stops.map((stop) => ({
      lat: stop.lat,
      lng: stop.lng,
      label: formatDuration(stop.durationMs),
    }));
  }

  // -------------------------------------------------------------- Denetim

  function controls() {
    const slider = el('input', {
      type: 'range',
      class: 'playback-slider',
      min: '0',
      max: String(samples.length - 1),
      value: String(index),
      'aria-label': Strings.playbackTitle,
    });
    slider.addEventListener('input', () => {
      pause();
      seek(Number(slider.value));
    });

    const playButton = el('button', {
      type: 'button',
      class: 'btn btn-primary btn-small',
      onclick: () => (playing ? pause() : play()),
    }, playing ? Strings.playbackPause : Strings.playbackPlay);

    const time = el('span', {
      class: 'playback-time',
      text: formatTimestamp(samples[index].recordedAt),
    });

    const speedButtons = SPEEDS.map((speed) =>
      el('button', {
        type: 'button',
        class: `chip ${speed.stepMs === stepMs ? 'chip-active' : ''}`,
        onclick: () => {
          stepMs = speed.stepMs;
          if (playing) {
            pause();
            play();
          }
          draw();
        },
      }, speed.label),
    );

    const followBox = el('input', { type: 'checkbox', checked: follow });
    followBox.addEventListener('change', () => {
      follow = followBox.checked;
    });

    refs = { slider, playButton, time };

    return el('div', { class: 'playback-controls' }, [
      el('div', { class: 'playback-row' }, [
        playButton,
        el('button', {
          type: 'button',
          class: 'btn btn-ghost btn-small',
          onclick: () => {
            pause();
            seek(0);
          },
        }, Strings.playbackReplay),
        time,
      ]),
      slider,
      el('div', { class: 'playback-row' }, [
        el('span', { class: 'field-label', text: Strings.playbackSpeedLabel }),
        ...speedButtons,
      ]),
      el('label', { class: 'checkbox' }, [followBox, el('span', { text: Strings.playbackFollow })]),
    ]);
  }

  function summary() {
    const rows = [
      [Strings.reportDistance, formatDistance(report.distanceM)],
      [Strings.reportMoving, formatDuration(report.movingMs)],
      [Strings.reportStopped, formatDuration(report.stoppedMs)],
      [Strings.reportMaxSpeed, formatSpeed(report.maxSpeedKmh)],
      [Strings.reportAvgSpeed, formatSpeed(averageMovingSpeedKmh(report))],
      [Strings.reportStops, String(report.stops.length)],
      [
        Strings.reportRange,
        `${formatTimestamp(report.from)} — ${formatTimestamp(report.to)}`,
      ],
    ];

    return el('div', { class: 'detail-card' }, [
      el('dl', { class: 'summary-rows' }, rows.map(([label, value]) =>
        el('div', { class: 'summary-row' }, [
          el('dt', { text: label }),
          el('dd', { text: value }),
        ]),
      )),
      el('button', {
        type: 'button',
        class: 'btn btn-ghost btn-small',
        onclick: () => openHistoryTable(vehicle, samples),
      }, Strings.playbackShowRecords),
    ]);
  }

  // -------------------------------------------------------------- Oynatma

  function seek(next) {
    index = Math.max(0, Math.min(samples.length - 1, next));
    mapView.setPlaybackPosition(samples[index], { follow });
    if (refs !== null) {
      refs.slider.value = String(index);
      refs.time.textContent = formatTimestamp(samples[index].recordedAt);
    }
  }

  function play() {
    if (samples.length === 0 || playing) return;
    // Sondayken oynat'a basmak baştan başlatır.
    if (index >= samples.length - 1) seek(0);
    playing = true;
    if (refs !== null) refs.playButton.textContent = Strings.playbackPause;
    timer = window.setInterval(() => {
      if (index >= samples.length - 1) {
        pause();
        return;
      }
      seek(index + 1);
    }, stepMs);
  }

  function pause() {
    playing = false;
    if (timer !== null) {
      window.clearInterval(timer);
      timer = null;
    }
    if (refs !== null) refs.playButton.textContent = Strings.playbackPlay;
  }

  function close() {
    destroy();
    onClose();
  }

  function destroy() {
    destroyed = true;
    pause();
    mapView.clearRoute();
    mapView.setLiveMarkersVisible(true);
  }

  return { node, destroy };
}
