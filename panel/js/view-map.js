// Harita sayfası: canlı harita, filo özeti, grup filtresi ve araç listesi.
//
// Her iki rol de bu sayfayı görür. Fark veridedir: yöneticiye tüm araçlar ve
// işlem düğmeleri gelir, izleyiciye yalnızca grubunun araçları ve salt-okunur
// bir liste. Filtreleme kararını visibility-rules.js verir, bu dosya değil.

import { Role } from './models.js';
import { Strings } from './strings.js';
import {
  fieldVisibilityFor,
  filterMatches,
  filtersEqual,
  groupFilterAll,
  groupFilterFor,
  groupFilterUngrouped,
  visibleVehiclesFor,
} from './visibility-rules.js';
import { MapView } from './map-view.js';
import { clear, el, emptyState, statusDot } from './ui.js';
import { fleetSummaryOf, statusColor, statusLabel, vehicleStatusOf } from './vehicle-status.js';
import { formatSpeed, relativeTime } from './time-format.js';
import {
  confirmDeleteVehicle,
  openGroupPicker,
  openHistory,
  toggleApproved,
} from './vehicle-actions.js';

export function createMapPage(backend) {
  let state = null;
  let filter = groupFilterAll();
  let selectedId = null;

  const mapHost = el('div', { class: 'map-canvas' });
  const summaryHost = el('div', { class: 'map-overlay' });
  const filterHost = el('div', { class: 'chip-row' });
  const listHost = el('div', { class: 'vehicle-list' });
  const detailHost = el('div', { class: 'detail-host' });

  // Leaflet haritası sayfa **belgeye eklendikten sonra** kurulur.
  //
  // Bağlı olmayan bir elemanla kurulursa Leaflet, elemanın hesaplanan
  // position değerini okuyamayıp üzerine satır içi `position: relative`
  // yazar; bu da .map-canvas kuralını ezip haritayı sıfır yükseklikte
  // bırakır. Bu yüzden kurulum onShow()'a ertelenir.
  let mapView = null;

  function ensureMap() {
    if (mapView === null) {
      mapView = new MapView(mapHost, {
        onSelect: (vehicleId) => {
          selectedId = vehicleId;
          draw();
        },
      });
    }
    return mapView;
  }

  const fitButton = el('button', {
    type: 'button',
    class: 'btn btn-ghost btn-small',
    onclick: () => mapView.fitAll(),
  }, Strings.mapFitAll);

  const followButton = el('button', {
    type: 'button',
    class: 'btn btn-ghost btn-small',
    onclick: () => {
      mapView.setFollow(!mapView.following);
      draw();
    },
  }, Strings.mapFollow);

  const clearTrackButton = el('button', {
    type: 'button',
    class: 'btn btn-ghost btn-small',
    onclick: () => {
      mapView.clearTrack();
      draw();
    },
  }, Strings.historyHideTrack);

  const node = el('div', { class: 'map-page' }, [
    el('div', { class: 'map-holder' }, [mapHost, summaryHost]),
    el('aside', { class: 'map-side' }, [
      el('div', { class: 'side-head' }, [
        el('h2', { class: 'side-title', text: Strings.navMap }),
        el('div', { class: 'side-actions' }, [fitButton, followButton, clearTrackButton]),
      ]),
      filterHost,
      listHost,
      detailHost,
    ]),
  ]);

  // Sayfa açıldığında harita (gerekiyorsa) kurulur ve Leaflet ölçüyü yeniden
  // alır; gizliyken kurulan harita yoksa yarım bir tuval olarak kalır.
  function onShow() {
    ensureMap().invalidateSize();
    if (state !== null) draw();
  }

  function update(next) {
    state = next;
    draw();
  }

  function visibleVehicles() {
    return visibleVehiclesFor(state.vehicles, state.groups, state.viewer);
  }

  function draw() {
    // Harita henüz kurulmadıysa sayfa görünür değildir; onShow() çizecek.
    if (state === null || mapView === null) return;
    const { viewer, groups, nowMs } = state;
    const visible = visibleVehicles();
    const shown = visible.filter((vehicle) => filterMatches(filter, vehicle));

    // Seçili araç artık görünmüyorsa seçim bırakılır.
    if (selectedId !== null && !shown.some((vehicle) => vehicle.id === selectedId)) {
      selectedId = null;
    }

    mapView.render(shown, { groups, viewer, nowMs, fieldVisibilityFor });
    mapView.setSelected(selectedId);

    drawSummary(visible, nowMs);
    drawFilters(visible, viewer);
    drawList(shown, nowMs, viewer, groups);
    drawDetail(shown, nowMs, viewer, groups);

    followButton.textContent = mapView.following ? Strings.mapFollowing : Strings.mapFollow;
    followButton.classList.toggle('btn-active', mapView.following);
    followButton.disabled = selectedId === null;
    clearTrackButton.hidden = !mapView.hasTrack;
  }

  function drawSummary(vehicles, nowMs) {
    const summary = fleetSummaryOf(vehicles, nowMs);
    const withoutLocation = vehicles.filter((vehicle) => !vehicle.hasLocation).length;

    clear(summaryHost).append(
      el('div', { class: 'summary-card' }, [
        el('div', { class: 'summary-head' }, [
          el('span', { class: 'summary-title', text: Strings.mapSummaryTitle }),
          el('span', { class: 'summary-total', text: String(summary.total) }),
        ]),
        el('div', { class: 'summary-grid' }, [
          summaryCell('moving', Strings.mapStatusMoving, summary.moving),
          summaryCell('stopped', Strings.mapStatusStopped, summary.stopped),
          summaryCell('offline', Strings.mapStatusOffline, summary.offline),
          summaryCell('pending', Strings.mapStatusPending, summary.pending),
        ]),
        withoutLocation > 0
          ? el('p', {
              class: 'summary-note',
              text: `${withoutLocation} ${Strings.mapHiddenNoLocation}`,
            })
          : null,
      ]),
    );
  }

  function summaryCell(status, label, count) {
    return el('div', { class: 'summary-cell' }, [
      el('span', { class: 'summary-dot', style: `background:${statusColor(status)}` }),
      el('span', { class: 'summary-count', text: String(count) }),
      el('span', { class: 'summary-label', text: label }),
    ]);
  }

  function drawFilters(vehicles, viewer) {
    const present = new Set(
      vehicles.filter((vehicle) => vehicle.hasGroup).map((vehicle) => vehicle.groupId),
    );
    const hasUngrouped = vehicles.some((vehicle) => !vehicle.hasGroup);
    const options = [{ filter: groupFilterAll(), label: Strings.mapFilterAll }];
    for (const groupId of [...present].sort((a, b) => a.localeCompare(b, 'tr'))) {
      options.push({ filter: groupFilterFor(groupId), label: groupId });
    }
    // "Grupsuz" çipi yalnızca yöneticide anlamlı: izleyici zaten grupsuz araç
    // göremez.
    if (hasUngrouped && viewer.role === Role.admin) {
      options.push({ filter: groupFilterUngrouped(), label: Strings.mapFilterUngrouped });
    }

    // Seçili filtrenin grubu kaybolduysa "Tümü"ne dönülür.
    if (!options.some((option) => filtersEqual(option.filter, filter))) {
      filter = groupFilterAll();
    }

    clear(filterHost);
    if (options.length <= 1) return;
    for (const option of options) {
      const active = filtersEqual(option.filter, filter);
      filterHost.append(
        el('button', {
          type: 'button',
          class: `chip ${active ? 'chip-active' : ''}`,
          'aria-pressed': active ? 'true' : 'false',
          onclick: () => {
            filter = option.filter;
            draw();
          },
        }, option.label),
      );
    }
  }

  function drawList(vehicles, nowMs, viewer, groups) {
    // Liste 5 saniyede bir yeniden kuruluyor; kaydırma yerinde kalmazsa
    // kullanıcı uzun listede aşağı inemez.
    const scrollTop = listHost.scrollTop;
    clear(listHost);
    if (vehicles.length === 0) {
      listHost.append(
        emptyState(
          Strings.mapEmptyTitle,
          viewer.role === Role.admin ? Strings.mapEmptyAdminHint : Strings.mapEmptyViewerHint,
        ),
      );
      return;
    }

    for (const vehicle of vehicles) {
      const status = vehicleStatusOf(vehicle, nowMs);
      const visibility = fieldVisibilityFor(vehicle, groups, viewer);
      const selected = vehicle.id === selectedId;

      listHost.append(
        el('button', {
          type: 'button',
          class: `vehicle-row ${selected ? 'vehicle-row-selected' : ''}`,
          onclick: () => {
            selectedId = vehicle.id;
            mapView.setSelected(vehicle.id, { focus: true });
            draw();
          },
        }, [
          el('span', { class: 'vehicle-dot', style: `background:${statusColor(status)}` }),
          el('span', { class: 'vehicle-main' }, [
            el('span', { class: 'vehicle-plate', text: vehicle.plate }),
            el('span', {
              class: 'vehicle-sub',
              text: visibility.showDriverName ? vehicle.driverName : Strings.mapFieldHidden,
            }),
          ]),
          el('span', { class: 'vehicle-meta' }, [
            el('span', {
              class: 'vehicle-speed',
              text: visibility.showSpeed ? formatSpeed(vehicle.speedKmh) : Strings.mapFieldHidden,
            }),
            el('span', { class: 'vehicle-time', text: relativeTime(vehicle.updatedAt, nowMs) }),
          ]),
        ]),
      );
    }
    listHost.scrollTop = scrollTop;
  }

  function drawDetail(vehicles, nowMs, viewer, groups) {
    clear(detailHost);
    if (selectedId === null) return;
    const vehicle = vehicles.find((item) => item.id === selectedId);
    if (vehicle === undefined) return;

    const status = vehicleStatusOf(vehicle, nowMs);
    const visibility = fieldVisibilityFor(vehicle, groups, viewer);

    const rows = el('dl', { class: 'summary-rows' }, [
      detailRow(Strings.mapFieldDriver, visibility.showDriverName ? vehicle.driverName : Strings.mapFieldHidden),
      detailRow(Strings.mapFieldSpeed, visibility.showSpeed ? formatSpeed(vehicle.speedKmh) : Strings.mapFieldHidden),
      detailRow(Strings.mapFieldGroup, vehicle.groupId ?? Strings.mapGroupNone),
      detailRow(Strings.mapFieldUpdated, relativeTime(vehicle.updatedAt, nowMs)),
    ]);

    const actions = viewer.role === Role.admin
      ? el('div', { class: 'detail-actions' }, [
          el('button', {
            type: 'button',
            class: 'btn btn-small btn-primary',
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
            onclick: () => openHistory(backend, vehicle, { mapView }),
          }, Strings.viewHistory),
          el('button', {
            type: 'button',
            class: 'btn btn-small btn-danger',
            onclick: () => confirmDeleteVehicle(backend, vehicle),
          }, Strings.delete),
        ])
      : null;

    detailHost.append(
      el('div', { class: 'detail-card' }, [
        el('div', { class: 'detail-head' }, [
          el('span', { class: 'detail-plate', text: vehicle.plate }),
          statusDot(statusColor(status), statusLabel(status)),
        ]),
        rows,
        !vehicle.hasLocation ? el('p', { class: 'field-hint', text: Strings.mapNoLocationYet }) : null,
        actions,
      ]),
    );
  }

  function detailRow(label, value) {
    return el('div', { class: 'summary-row' }, [
      el('dt', { text: label }),
      el('dd', { text: value }),
    ]);
  }

  // Araç tablosundan "Haritada göster" ile gelindiğinde kullanılır.
  function focusVehicle(vehicleId) {
    filter = groupFilterAll();
    selectedId = vehicleId;
    ensureMap();
    draw();
    mapView.setSelected(vehicleId, { focus: true });
  }

  return { node, update, onShow, focusVehicle };
}
