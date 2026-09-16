// Filo raporu (yalnızca yönetici).
//
// Her araç için konum geçmişi ayrı ayrı okunur — Firebase'de bu araç başına
// bir istek demektir — bu yüzden rapor kendiliğinden değil, düğmeye basınca
// hesaplanır. Sonuç tabloda gösterilir ve CSV olarak indirilebilir.

import { Strings } from './strings.js';
import { clear, el, emptyState, toast } from './ui.js';
import { downloadCsv, safeFilename } from './csv.js';
import { formatDistance, formatDuration } from './geo.js';
import { formatSpeed, formatTimestamp } from './time-format.js';
import { averageMovingSpeedKmh, tripReport } from './trip-report.js';
import { compareText } from './admin-rules.js';

export function createReportsPage(backend) {
  let state = null;
  // vehicleId -> { vehicle, report } ; null ise henüz hesaplanmadı.
  let results = null;
  let busy = false;

  const buildButton = el('button', {
    type: 'button',
    class: 'btn btn-primary',
    onclick: () => build(),
  }, Strings.reportsBuild);

  const exportButton = el('button', {
    type: 'button',
    class: 'btn btn-ghost',
    onclick: () => exportCsv(),
  }, Strings.reportsExport);

  const bodyHost = el('div');

  const node = el('section', { class: 'page' }, [
    el('div', { class: 'page-head' }, [
      el('h2', { class: 'page-title', text: Strings.reportsTitle }),
      el('div', { class: 'page-tools' }, [exportButton, buildButton]),
    ]),
    el('p', { class: 'page-hint', text: Strings.reportsHint }),
    bodyHost,
  ]);

  function update(next) {
    state = next;
    draw();
  }

  async function build() {
    if (busy || state === null) return;
    busy = true;
    buildButton.disabled = true;
    buildButton.textContent = Strings.reportsBuilding;
    exportButton.disabled = true;

    try {
      const vehicles = [...state.vehicles].sort((a, b) => compareText(a.plate, b.plate));
      const loaded = await Promise.all(
        vehicles.map(async (vehicle) => ({
          vehicle,
          report: tripReport(await backend.loadHistory(vehicle.id)),
        })),
      );
      results = loaded;
    } catch (error) {
      toast(error?.message ?? Strings.reportsFailed, 'error');
    } finally {
      busy = false;
      buildButton.disabled = false;
      buildButton.textContent = results === null ? Strings.reportsBuild : Strings.reportsRefresh;
      draw();
    }
  }

  function totals() {
    return results.reduce(
      (sum, { report }) => ({
        distanceM: sum.distanceM + report.distanceM,
        movingMs: sum.movingMs + report.movingMs,
        stoppedMs: sum.stoppedMs + report.stoppedMs,
        stops: sum.stops + report.stops.length,
      }),
      { distanceM: 0, movingMs: 0, stoppedMs: 0, stops: 0 },
    );
  }

  function draw() {
    exportButton.disabled = results === null || busy;
    clear(bodyHost);

    if (state.vehicles.length === 0) {
      bodyHost.append(emptyState(Strings.reportsEmpty, Strings.noVehiclesHint));
      return;
    }
    if (results === null) {
      bodyHost.append(emptyState(Strings.reportsNotBuilt, Strings.reportsNotBuiltHint));
      return;
    }

    const sum = totals();

    bodyHost.append(
      el('div', { class: 'stat-row' }, [
        statCard(Strings.reportDistance, formatDistance(sum.distanceM)),
        statCard(Strings.reportMoving, formatDuration(sum.movingMs)),
        statCard(Strings.reportStopped, formatDuration(sum.stoppedMs)),
        statCard(Strings.reportStops, String(sum.stops)),
      ]),
      el('div', { class: 'table-card' }, [
        el('div', { class: 'table-scroll' }, [
          el('table', { class: 'table' }, [
            el('thead', {}, [
              el('tr', {}, [
                el('th', { text: Strings.colPlate }),
                el('th', { text: Strings.colDriver }),
                el('th', { text: Strings.colGroup }),
                el('th', { text: Strings.reportDistance }),
                el('th', { text: Strings.reportMoving }),
                el('th', { text: Strings.reportStopped }),
                el('th', { text: Strings.reportStops }),
                el('th', { text: Strings.reportMaxSpeed }),
                el('th', { text: Strings.reportAvgSpeed }),
              ]),
            ]),
            el('tbody', {}, results.map(({ vehicle, report }) =>
              el('tr', {}, [
                el('td', {}, [el('span', { class: 'cell-strong', text: vehicle.plate })]),
                el('td', { text: vehicle.driverName }),
                el('td', { text: vehicle.groupId ?? Strings.groupNone }),
                el('td', { text: formatDistance(report.distanceM) }),
                el('td', { text: formatDuration(report.movingMs) }),
                el('td', { text: formatDuration(report.stoppedMs) }),
                el('td', { text: String(report.stops.length) }),
                el('td', {
                  text: report.sampleCount === 0
                    ? Strings.reportsNoData
                    : formatSpeed(report.maxSpeedKmh),
                }),
                el('td', {
                  text: report.sampleCount === 0
                    ? '—'
                    : formatSpeed(averageMovingSpeedKmh(report)),
                }),
              ]),
            )),
          ]),
        ]),
      ]),
      el('p', { class: 'field-hint', text: Strings.reportWindowNote }),
    );
  }

  function statCard(label, value) {
    return el('div', { class: 'stat-card' }, [
      el('span', { class: 'stat-value stat-value-small', text: value }),
      el('span', { class: 'stat-label', text: label }),
    ]);
  }

  function exportCsv() {
    if (results === null) return;
    const rows = [
      [
        Strings.colPlate,
        Strings.colDriver,
        Strings.colGroup,
        'Yol (km)',
        'Hareket (dk)',
        'Duruş (dk)',
        Strings.reportStops,
        'En yüksek hız (km/s)',
        'Ortalama hız (km/s)',
        'İlk kayıt',
        'Son kayıt',
      ],
    ];
    for (const { vehicle, report } of results) {
      rows.push([
        vehicle.plate,
        vehicle.driverName,
        vehicle.groupId ?? '',
        // Sayılar Excel'de hesaplanabilsin diye biçimlenmemiş; Türkçe yerelde
        // ondalık ayracı virgüldür.
        (report.distanceM / 1000).toFixed(2).replace('.', ','),
        Math.round(report.movingMs / 60000),
        Math.round(report.stoppedMs / 60000),
        report.stops.length,
        Math.round(report.maxSpeedKmh),
        Math.round(averageMovingSpeedKmh(report)),
        report.from > 0 ? formatTimestamp(report.from) : '',
        report.to > 0 ? formatTimestamp(report.to) : '',
      ]);
    }

    const stamp = formatTimestamp(backend.nowMs()).replace(/[.: ]/g, '-');
    downloadCsv(`${safeFilename(`${Strings.reportsFileName}-${stamp}`)}.csv`, rows);
  }

  return { node, update };
}
