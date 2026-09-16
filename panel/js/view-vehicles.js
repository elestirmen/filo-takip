// Araç tablosu (yalnızca yönetici).
//
// Sıra sortVehiclesForAdmin ile belirlenir: onay bekleyenler üstte. Veri
// 5 saniyede bir tazelendiği için yalnızca tablo gövdesi yeniden kurulur;
// arama kutusu ve odak yerinde kalır.

import { Strings } from './strings.js';
import { adminSummaryOf, matchesVehicleSearch, sortVehiclesForAdmin } from './admin-rules.js';
import { clear, el, emptyState, statusDot, textInput } from './ui.js';
import { formatSpeed, relativeTime } from './time-format.js';
import { statusColor, statusLabel, vehicleStatusOf } from './vehicle-status.js';
import { confirmDeleteVehicle, openGroupPicker, toggleApproved } from './vehicle-actions.js';

export function createVehiclesPage(backend, { onShowOnMap, onShowHistory }) {
  let state = null;

  const search = textInput({ placeholder: Strings.vehiclesSearchHint });
  search.addEventListener('input', () => drawBody());

  const summaryHost = el('div', { class: 'stat-row' });
  const tableBody = el('tbody');
  const emptyHost = el('div');

  const node = el('section', { class: 'page' }, [
    el('div', { class: 'page-head' }, [
      el('h2', { class: 'page-title', text: Strings.vehiclesTitle }),
      el('div', { class: 'page-tools' }, [search]),
    ]),
    summaryHost,
    el('div', { class: 'table-card' }, [
      el('div', { class: 'table-scroll' }, [
        el('table', { class: 'table' }, [
          el('thead', {}, [
            el('tr', {}, [
              el('th', { text: Strings.colPlate }),
              el('th', { text: Strings.colDriver }),
              el('th', { text: Strings.colGroup }),
              el('th', { text: Strings.colStatus }),
              el('th', { text: Strings.colSpeed }),
              el('th', { text: Strings.colUpdated }),
              el('th', { class: 'col-actions', text: Strings.colActions }),
            ]),
          ]),
          tableBody,
        ]),
      ]),
      emptyHost,
    ]),
  ]);

  function update(next) {
    state = next;
    drawSummary();
    drawBody();
  }

  function drawSummary() {
    const summary = adminSummaryOf(state.vehicles, state.groups);
    clear(summaryHost).append(
      statCard(Strings.summaryTotal, summary.total),
      statCard(Strings.summaryPending, summary.pending, summary.pending > 0 ? 'warn' : null),
      statCard(Strings.summaryApproved, summary.approved),
      statCard(Strings.summaryGroups, summary.groupCount),
    );
  }

  function statCard(label, value, kind) {
    return el('div', { class: `stat-card ${kind ? `stat-${kind}` : ''}` }, [
      el('span', { class: 'stat-value', text: String(value) }),
      el('span', { class: 'stat-label', text: label }),
    ]);
  }

  function drawBody() {
    if (state === null) return;
    const { groups, nowMs } = state;
    const query = search.value;
    const rows = sortVehiclesForAdmin(state.vehicles).filter((vehicle) =>
      matchesVehicleSearch(vehicle, query),
    );

    clear(tableBody);
    clear(emptyHost);

    if (state.vehicles.length === 0) {
      emptyHost.append(emptyState(Strings.noVehicles, Strings.noVehiclesHint));
      return;
    }
    if (rows.length === 0) {
      emptyHost.append(emptyState(Strings.noSearchResult));
      return;
    }

    for (const vehicle of rows) {
      const status = vehicleStatusOf(vehicle, nowMs);
      tableBody.append(
        el('tr', { class: vehicle.approved ? '' : 'row-pending' }, [
          el('td', {}, [el('span', { class: 'cell-strong', text: vehicle.plate })]),
          el('td', { text: vehicle.driverName }),
          el('td', { text: vehicle.groupId ?? Strings.groupNone }),
          el('td', {}, [statusDot(statusColor(status), statusLabel(status))]),
          el('td', { text: formatSpeed(vehicle.speedKmh) }),
          el('td', { text: relativeTime(vehicle.updatedAt, nowMs) }),
          el('td', { class: 'col-actions' }, [
            el('div', { class: 'row-actions' }, [
              el('button', {
                type: 'button',
                class: `btn btn-small ${vehicle.approved ? 'btn-ghost' : 'btn-primary'}`,
                onclick: (event) => toggleApproved(backend, vehicle, event.currentTarget),
              }, vehicle.approved ? Strings.revoke : Strings.approve),
              el('button', {
                type: 'button',
                class: 'btn btn-small btn-ghost',
                onclick: () => openGroupPicker(backend, vehicle, groups),
              }, Strings.assignGroup),
              el('button', {
                type: 'button',
                class: 'btn btn-small btn-ghost',
                disabled: !vehicle.hasLocation,
                onclick: () => onShowOnMap(vehicle.id),
              }, Strings.showOnMap),
              el('button', {
                type: 'button',
                class: 'btn btn-small btn-ghost',
                onclick: () => onShowHistory(vehicle),
              }, Strings.viewHistory),
              el('button', {
                type: 'button',
                class: 'btn btn-small btn-danger',
                onclick: () => confirmDeleteVehicle(backend, vehicle),
              }, Strings.delete),
            ]),
          ]),
        ]),
      );
    }
  }

  return { node, update };
}
