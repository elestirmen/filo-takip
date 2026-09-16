// Bölge (geofence) oluşturma ve düzenleme penceresi.
//
// Bölge dairedir: merkez haritadan tıklanarak seçilir, yarıçap metre olarak
// girilir. Yeni bölgede kimlik addan türetilir; grup adında olduğu gibi
// Realtime Database anahtarında kullanılamayan karakterler atılır.

import { Geofence } from './models.js';
import { Strings } from './strings.js';
import { el, field, openModal, runAction, textInput } from './ui.js';
import { normalizeGroupName } from './normalize.js';

const MIN_RADIUS_M = 50;
const MAX_RADIUS_M = 50000;

// zone verilirse düzenlenir; verilmezse lat/lng ile yeni bölge kurulur.
export function openZoneEditor({ backend, zone, lat, lng }) {
  const isNew = zone === null || zone === undefined;
  const nameInput = textInput({
    value: isNew ? '' : zone.name,
    placeholder: Strings.zoneNameHint,
  });
  const radiusInput = textInput({
    type: 'number',
    value: String(isNew ? 500 : zone.radiusM),
  });
  const error = el('p', { class: 'form-error', role: 'alert' });

  const centerLat = isNew ? lat : zone.lat;
  const centerLng = isNew ? lng : zone.lng;

  openModal({
    title: isNew ? Strings.zoneAdd : Strings.zoneEdit,
    body: el('div', { class: 'stack' }, [
      field(Strings.zoneNameLabel, nameInput),
      field(Strings.zoneRadiusLabel, radiusInput),
      el('p', {
        class: 'field-hint mono',
        text: `${centerLat.toFixed(5)}, ${centerLng.toFixed(5)}`,
      }),
      el('p', { class: 'field-hint', text: Strings.zonesHint }),
      error,
    ]),
    actions: [
      { label: Strings.cancel, onClick: (close) => close() },
      {
        label: Strings.save,
        class: 'btn-primary',
        onClick: async (close) => {
          error.textContent = '';
          const name = nameInput.value.trim().replace(/\s+/g, ' ');
          if (name.length === 0) {
            error.textContent = Strings.zoneNameRequired;
            return;
          }
          const radius = Number(radiusInput.value);
          if (!Number.isFinite(radius) || radius < MIN_RADIUS_M || radius > MAX_RADIUS_M) {
            error.textContent = Strings.zoneRadiusInvalid;
            return;
          }

          // Kimlik yalnızca oluştururken türetilir; ad değişse de bölge
          // taşınmaz, yoksa her yeniden adlandırma yeni bir bölge yaratırdı.
          const id = isNew
            ? `${normalizeGroupName(name).toLowerCase().replace(/\s+/g, '-') || 'bolge'}-${Date.now().toString(36)}`
            : zone.id;

          const saved = new Geofence({
            id,
            name,
            lat: centerLat,
            lng: centerLng,
            radiusM: Math.round(radius),
            createdAt: isNew ? backend.nowMs() : zone.createdAt,
          });

          const ok = await runAction(null, () => backend.saveGeofence(saved), Strings.zoneSaved);
          if (ok) close();
        },
      },
    ],
  });
}
