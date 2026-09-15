// Leaflet haritası. Uygulamadaki MapScreen ile aynı karo sunucusunu ve aynı
// açılış noktasını kullanır, işaretçi renkleri de aynı durum paletinden gelir.
//
// İşaretçiler her veri güncellemesinde sıfırdan kurulmaz: araç kimliğine göre
// saklanıp yerleri güncellenir. Araçlar 5 saniyede bir hareket ettiği için
// yeniden kurmak haritayı titretirdi.

import { Strings } from './strings.js';
import { el } from './ui.js';
import { formatCoords, formatSpeed, relativeTime } from './time-format.js';
import { mapDefaults } from './config.js';
import { statusColor, statusLabel, vehicleStatusOf } from './vehicle-status.js';

const RADIUS = 9;
const RADIUS_SELECTED = 13;

export class MapView {
  constructor(container, { onSelect } = {}) {
    this._onSelect = onSelect ?? (() => {});
    this._markers = new Map();
    this._selectedId = null;
    this._followSelected = false;
    this._track = null;
    // İlk veri gelince haritayı filoya sığdırmak için; sonraki
    // güncellemelerde kullanıcının kaydırdığı görünüm korunur.
    this._didInitialFit = false;

    this._map = L.map(container, {
      center: [mapDefaults.centerLat, mapDefaults.centerLng],
      zoom: mapDefaults.zoom,
      zoomControl: true,
      // Kullanıcı haritayı elle kaydırınca takip kendiliğinden bırakılsın.
      attributionControl: true,
    });

    L.tileLayer(mapDefaults.tileUrl, {
      maxZoom: 19,
      attribution: Strings.mapAttribution,
    }).addTo(this._map);

    this._map.on('dragstart', () => {
      this._followSelected = false;
    });
  }

  // Harita bir sekme gizliyken kurulduysa Leaflet boyutunu yanlış ölçer.
  invalidateSize() {
    this._map.invalidateSize();
  }

  get selectedId() {
    return this._selectedId;
  }

  setSelected(vehicleId, { focus = false } = {}) {
    this._selectedId = vehicleId;
    for (const [id, entry] of this._markers) {
      entry.marker.setStyle(this._styleFor(entry.status, id === vehicleId));
      entry.marker.setRadius(id === vehicleId ? RADIUS_SELECTED : RADIUS);
      if (id === vehicleId) entry.marker.bringToFront();
    }
    if (focus && vehicleId !== null) {
      const entry = this._markers.get(vehicleId);
      if (entry !== undefined) {
        this._map.setView(entry.marker.getLatLng(), Math.max(this._map.getZoom(), mapDefaults.focusZoom));
      }
    }
  }

  setFollow(enabled) {
    this._followSelected = enabled;
    if (enabled) this.setSelected(this._selectedId, { focus: true });
  }

  get following() {
    return this._followSelected;
  }

  // vehicles: haritada gösterilecek araçlar (görünürlük filtresi uygulanmış).
  render(vehicles, { groups, viewer, nowMs, fieldVisibilityFor }) {
    const seen = new Set();

    for (const vehicle of vehicles) {
      // Hiç konum yazılmamış araç haritaya konmaz; özet kartında sayılır.
      if (!vehicle.hasLocation) continue;
      seen.add(vehicle.id);

      const status = vehicleStatusOf(vehicle, nowMs);
      const selected = vehicle.id === this._selectedId;
      const latLng = [vehicle.lat, vehicle.lng];
      let entry = this._markers.get(vehicle.id);

      if (entry === undefined) {
        const marker = L.circleMarker(latLng, {
          ...this._styleFor(status, selected),
          radius: selected ? RADIUS_SELECTED : RADIUS,
        });
        marker.on('click', () => {
          this.setSelected(vehicle.id);
          this._onSelect(vehicle.id);
        });
        marker.addTo(this._map);
        marker.bindTooltip(el('span', { class: 'map-plate', text: vehicle.plate }), {
          permanent: true,
          direction: 'right',
          offset: [10, 0],
          className: 'map-tooltip',
        });
        entry = { marker, status };
        this._markers.set(vehicle.id, entry);
      } else {
        entry.marker.setLatLng(latLng);
        if (entry.status !== status || selected) {
          entry.marker.setStyle(this._styleFor(status, selected));
          entry.status = status;
        }
        entry.marker.setTooltipContent(el('span', { class: 'map-plate', text: vehicle.plate }));
      }

      // bindPopup açık bir balonu kapatır; araçlar 5 saniyede bir
      // güncellendiği için ikinci kez bağlamak yerine içerik tazelenir.
      const popup = this._popupFor(vehicle, { groups, viewer, nowMs, status, fieldVisibilityFor });
      if (entry.marker.getPopup() === undefined || entry.marker.getPopup() === null) {
        entry.marker.bindPopup(popup);
      } else {
        entry.marker.setPopupContent(popup);
      }
    }

    // Artık görünmeyen araçların işaretçilerini kaldır.
    for (const [id, entry] of [...this._markers]) {
      if (seen.has(id)) continue;
      entry.marker.remove();
      this._markers.delete(id);
    }

    if (!this._didInitialFit && this._markers.size > 0) {
      this._didInitialFit = true;
      this.fitAll();
    }
    if (this._followSelected && this._selectedId !== null) {
      const entry = this._markers.get(this._selectedId);
      if (entry !== undefined) this._map.panTo(entry.marker.getLatLng(), { animate: true });
    }
  }

  fitAll() {
    if (this._markers.size === 0) return;
    const bounds = L.latLngBounds([...this._markers.values()].map((e) => e.marker.getLatLng()));
    this._map.fitBounds(bounds, { padding: [48, 48], maxZoom: 15 });
  }

  // Konum geçmişi ekranından çağrılır: aracın rotasını haritaya çizer.
  drawTrack(samples) {
    this.clearTrack();
    const points = samples
      .filter((sample) => sample.lat !== 0 || sample.lng !== 0)
      .map((sample) => [sample.lat, sample.lng]);
    if (points.length < 2) return false;
    this._track = L.polyline(points, {
      color: '#1565C0',
      weight: 4,
      opacity: 0.75,
    }).addTo(this._map);
    this._map.fitBounds(this._track.getBounds(), { padding: [48, 48] });
    return true;
  }

  clearTrack() {
    if (this._track !== null) {
      this._track.remove();
      this._track = null;
    }
  }

  get hasTrack() {
    return this._track !== null;
  }

  destroy() {
    this._map.remove();
    this._markers.clear();
  }

  _styleFor(status, selected) {
    const color = statusColor(status);
    return {
      color: selected ? '#0D47A1' : '#FFFFFF',
      weight: selected ? 4 : 2,
      fillColor: color,
      fillOpacity: 0.95,
    };
  }

  _popupFor(vehicle, { groups, viewer, nowMs, status, fieldVisibilityFor }) {
    const visibility = fieldVisibilityFor(vehicle, groups, viewer);
    const rows = [];

    rows.push(
      row(
        Strings.mapFieldDriver,
        visibility.showDriverName ? vehicle.driverName : Strings.mapFieldHidden,
        !visibility.showDriverName,
      ),
    );
    rows.push(
      row(
        Strings.mapFieldSpeed,
        visibility.showSpeed ? formatSpeed(vehicle.speedKmh) : Strings.mapFieldHidden,
        !visibility.showSpeed,
      ),
    );
    rows.push(row(Strings.mapFieldGroup, vehicle.groupId ?? Strings.mapGroupNone));
    rows.push(row(Strings.mapFieldUpdated, relativeTime(vehicle.updatedAt, nowMs)));
    rows.push(row(Strings.mapFieldCoords, formatCoords(vehicle.lat, vehicle.lng)));

    return el('div', { class: 'map-popup' }, [
      el('div', { class: 'map-popup-head' }, [
        el('span', { class: 'map-popup-plate', text: vehicle.plate }),
        el('span', {
          class: 'map-popup-status',
          style: `color:${statusColor(status)}`,
          text: statusLabel(status),
        }),
      ]),
      el('dl', { class: 'map-popup-rows' }, rows),
    ]);
  }
}

function row(label, value, muted = false) {
  return el('div', { class: 'map-popup-row' }, [
    el('dt', { text: label }),
    el('dd', { class: muted ? 'muted' : '', text: value }),
  ]);
}
