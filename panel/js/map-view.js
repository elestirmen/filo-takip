// Leaflet haritası. Uygulamadaki MapScreen ile aynı karo sunucusunu ve aynı
// açılış noktasını kullanır, işaretçi renkleri de aynı durum paletinden gelir.
//
// İşaretçiler her veri güncellemesinde sıfırdan kurulmaz: araç kimliğine göre
// saklanıp yerleri güncellenir. Araçlar 5 saniyede bir hareket ettiği için
// yeniden kurmak haritayı titretirdi.

import { Strings } from './strings.js';
import { el } from './ui.js';
import { formatCoords, formatSpeed, relativeTime } from './time-format.js';
import { defaultMapLayerId, mapDefaults, mapLayers } from './config.js';
import { VehicleStatus, statusColor, statusLabel, vehicleStatusOf } from './vehicle-status.js';

// Seçilen harita katmanı tarayıcıda hatırlanır.
const LAYER_KEY = 'filo-takip-harita-katmani';

function readStoredLayerId() {
  try {
    return window.localStorage.getItem(LAYER_KEY);
  } catch {
    return null;
  }
}

function writeStoredLayerId(id) {
  try {
    if (id === null) window.localStorage.removeItem(LAYER_KEY);
    else window.localStorage.setItem(LAYER_KEY, id);
  } catch {
    // Depolama kapalıysa seçim yalnızca bu oturumda yaşar.
  }
}

// İşaretçi ölçüsü. Sivri uç tam koordinatın üstünde dursun diye tutturma
// noktası alt uçtadır.
const PIN_WIDTH = 32;
const PIN_HEIGHT = 40;
const PIN_ANCHOR = [16, 39];

// Durum rengiyle boyanan damla biçimli iğne ve içinde beyaz bir araç.
//
// Metin araya girmediği için (renk sabit paletten gelir, plaka ayrı bir
// tooltip'te durur) SVG'yi dize olarak kurmak güvenlidir.
function pinSvg(color) {
  return `<svg viewBox="0 0 32 40" width="${PIN_WIDTH}" height="${PIN_HEIGHT}"
    xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <path d="M16 39C16 39 2.5 23.8 2.5 15A13.5 13.5 0 1 1 29.5 15C29.5 23.8 16 39 16 39Z"
      fill="${color}" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>
    <g fill="#fff">
      <path d="M11.5 10.4h9l2.1 3.3H9.4z"/>
      <rect x="6.8" y="13.3" width="18.4" height="4.7" rx="1.7"/>
    </g>
    <g fill="rgba(0,0,0,0.42)">
      <circle cx="11.3" cy="18" r="1.6"/>
      <circle cx="20.7" cy="18" r="1.6"/>
    </g>
  </svg>`;
}

export class MapView {
  constructor(container, { onSelect } = {}) {
    this._onSelect = onSelect ?? (() => {});
    this._markers = new Map();
    this._selectedId = null;
    this._followSelected = false;
    this._route = null;
    this._stopMarkers = [];
    this._playbackMarker = null;
    // Geçmiş rotası açıkken canlı işaretçiler gizlenir.
    this._liveVisible = true;
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

    this._addBaseLayers();

    this._map.on('dragstart', () => {
      this._followSelected = false;
    });
  }

  // Sokak / uydu katmanları ve sağ üstteki seçici.
  //
  // Seçim tarayıcıda hatırlanır: filoyu uydu üzerinde izlemeyi tercih eden
  // biri her açılışta yeniden seçmek zorunda kalmasın.
  _addBaseLayers() {
    const options = {};
    let active = null;
    const savedId = readStoredLayerId();

    for (const layer of mapLayers) {
      const tiles = L.tileLayer(layer.url, {
        maxZoom: layer.maxZoom,
        attribution: layer.attribution,
      });
      // Etiket katmanı varsa taban ve etiketler birlikte tek katman sayılır.
      const base = layer.labelsUrl
        ? L.layerGroup([tiles, L.tileLayer(layer.labelsUrl, { maxZoom: layer.maxZoom })])
        : tiles;

      options[layer.label] = base;
      const wanted = savedId !== null ? savedId : defaultMapLayerId;
      if (layer.id === wanted) active = base;
      base.filoLayerId = layer.id;
    }

    // Kayıtlı kimlik artık tanınmıyorsa ilk katmana düşülür.
    (active ?? Object.values(options)[0]).addTo(this._map);

    L.control.layers(options, null, { position: 'topright' }).addTo(this._map);
    this._map.on('baselayerchange', (event) => {
      writeStoredLayerId(event.layer?.filoLayerId ?? null);
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
      const selected = id === vehicleId;
      if (entry.selected !== selected) {
        entry.marker.setIcon(this._iconFor(entry.status, selected));
        entry.selected = selected;
      }
      // Seçili araç diğerlerinin üstünde kalsın.
      entry.marker.setZIndexOffset(selected ? 1000 : 0);
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
    if (!this._liveVisible) return;
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
        const marker = L.marker(latLng, {
          icon: this._iconFor(status, selected),
          zIndexOffset: selected ? 1000 : 0,
          keyboard: false,
        });
        marker.on('click', () => {
          this.setSelected(vehicle.id);
          this._onSelect(vehicle.id);
        });
        marker.addTo(this._map);
        marker.bindTooltip(el('span', { class: 'map-plate', text: vehicle.plate }), {
          permanent: true,
          direction: 'right',
          // İğnenin başının hizasında dursun; tutturma noktası alt uçta.
          offset: [12, -26],
          className: 'map-tooltip',
        });
        entry = { marker, status, selected };
        this._markers.set(vehicle.id, entry);
      } else {
        entry.marker.setLatLng(latLng);
        // İkon yalnızca gerçekten değiştiyse kurulur; her tikte yenilemek
        // işaretçiyi titretirdi.
        if (entry.status !== status || entry.selected !== selected) {
          entry.marker.setIcon(this._iconFor(status, selected));
          entry.status = status;
          entry.selected = selected;
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

  // ------------------------------------------------------- Geçmiş rotası

  // Aracın rotasını, duraklarını ve oynatma işaretçisini haritaya koyar.
  // Canlı işaretçiler bu sırada gizlenir; yoksa aynı araç iki yerde görünür.
  showRoute(samples, stops) {
    this.clearRoute();
    const points = samples
      .filter((sample) => sample.lat !== 0 || sample.lng !== 0)
      .map((sample) => [sample.lat, sample.lng]);
    if (points.length === 0) return 0;

    if (points.length >= 2) {
      // Alttaki kalın açık çizgi rotayı haritadan ayırır, üstteki ince koyu
      // çizgi yönü okunur kılar.
      this._route = L.layerGroup([
        L.polyline(points, { color: '#ffffff', weight: 7, opacity: 0.85 }),
        L.polyline(points, { color: '#1565C0', weight: 3.5, opacity: 0.95 }),
      ]).addTo(this._map);
      this._map.fitBounds(L.latLngBounds(points), { padding: [56, 56] });
    }

    for (const stop of stops ?? []) {
      const marker = L.circleMarker([stop.lat, stop.lng], {
        radius: 7,
        color: '#ffffff',
        weight: 2,
        fillColor: '#455A64',
        fillOpacity: 0.95,
      }).addTo(this._map);
      marker.bindTooltip(
        el('span', { class: 'map-plate', text: `${Strings.stopLabel} · ${stop.label}` }),
        { direction: 'top', className: 'map-tooltip' },
      );
      this._stopMarkers.push(marker);
    }
    return points.length;
  }

  // Oynatma sırasında aracın o andaki yeri.
  setPlaybackPosition(sample, { follow = false } = {}) {
    if (sample === null || sample === undefined) return;
    const latLng = [sample.lat, sample.lng];
    if (this._playbackMarker === null) {
      this._playbackMarker = L.marker(latLng, {
        icon: this._iconFor(VehicleStatus.moving, true),
        zIndexOffset: 2000,
        keyboard: false,
      }).addTo(this._map);
    } else {
      this._playbackMarker.setLatLng(latLng);
    }
    if (follow && !this._map.getBounds().pad(-0.15).contains(latLng)) {
      this._map.panTo(latLng, { animate: true });
    }
  }

  clearRoute() {
    if (this._route !== null) {
      this._route.remove();
      this._route = null;
    }
    for (const marker of this._stopMarkers) marker.remove();
    this._stopMarkers = [];
    if (this._playbackMarker !== null) {
      this._playbackMarker.remove();
      this._playbackMarker = null;
    }
  }

  // Canlı araç işaretçilerini gizler/gösterir. Gizlenince işaretçiler
  // haritadan kaldırılır; sonraki render çağrısı yeniden kurar.
  setLiveMarkersVisible(visible) {
    this._liveVisible = visible;
    if (visible) return;
    for (const entry of this._markers.values()) entry.marker.remove();
    this._markers.clear();
  }

  destroy() {
    this._map.remove();
    this._markers.clear();
  }

  _iconFor(status, selected) {
    return L.divIcon({
      className: `vehicle-pin${selected ? ' vehicle-pin-selected' : ''}`,
      html: pinSvg(statusColor(status)),
      iconSize: [PIN_WIDTH, PIN_HEIGHT],
      iconAnchor: PIN_ANCHOR,
      popupAnchor: [0, -34],
    });
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
