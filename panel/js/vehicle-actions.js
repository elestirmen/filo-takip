// Yönetici işlemleri: onay, grup atama, silme ve konum geçmişi.
//
// Hem harita sayfası hem araç tablosu aynı düğmeleri gösterir; iki ekranın
// davranışı ayrışmasın diye işlemler burada tek yerde durur.

import { Strings } from './strings.js';
import { confirmDialog, el, emptyState, openModal, runAction, select } from './ui.js';
import { formatSpeed, formatTimestamp } from './time-format.js';

export async function toggleApproved(backend, vehicle, button) {
  const approved = !vehicle.approved;
  await runAction(
    button,
    () => backend.setVehicleApproved(vehicle.id, approved),
    approved ? Strings.vehicleApproved : Strings.vehicleRevoked,
  );
}

// Grup atama penceresi. "Grupsuz" seçeneği groupId'yi null yapar.
export function openGroupPicker(backend, vehicle, groups) {
  const picker = select(
    [
      { value: '', label: Strings.groupNone },
      ...groups.map((group) => ({ value: group.groupId, label: group.groupId })),
    ],
    vehicle.groupId ?? '',
  );

  openModal({
    title: Strings.selectGroupTitle,
    body: el('div', { class: 'stack' }, [
      el('p', { class: 'modal-message', text: vehicle.plate }),
      picker,
      groups.length === 0
        ? el('p', { class: 'field-hint', text: Strings.noGroupsHint })
        : null,
    ]),
    actions: [
      { label: Strings.cancel, onClick: (close) => close() },
      {
        label: Strings.save,
        class: 'btn-primary',
        onClick: async (close) => {
          const value = picker.value.length > 0 ? picker.value : null;
          const ok = await runAction(
            null,
            () => backend.setVehicleGroup(vehicle.id, value),
            Strings.groupAssigned,
          );
          if (ok) close();
        },
      },
    ],
  });
}

export async function confirmDeleteVehicle(backend, vehicle) {
  const confirmed = await confirmDialog({
    title: Strings.deleteVehicleTitle,
    message: `${vehicle.plate} — ${Strings.deleteVehicleMessage}`,
    confirmLabel: Strings.delete,
    danger: true,
  });
  if (!confirmed) return;
  await runAction(null, () => backend.deleteVehicle(vehicle.id), Strings.vehicleDeleted);
}

// Ham konum kayıtlarının tablosu. Veriyi yüklemez; elindekini gösterir, bu
// yüzden oynatma paneli ikinci kez okuma yapmadan aynı pencereyi açabilir.
export function openHistoryTable(vehicle, samples) {
  const ordered = [...samples].sort((a, b) => b.recordedAt - a.recordedAt);

  const body = el('div', { class: 'stack' });
  if (ordered.length === 0) {
    body.append(emptyState(Strings.historyEmpty));
  } else {
    body.append(
      el('p', {
        class: 'muted',
        text: `${ordered.length} ${Strings.historyRecordSuffix} — ${Strings.historyLimitNote}`,
      }),
      el('div', { class: 'table-scroll' }, [
        el('table', { class: 'table' }, [
          el('thead', {}, [
            el('tr', {}, [
              el('th', { text: Strings.colTime }),
              el('th', { text: Strings.colSpeed }),
              el('th', { text: Strings.colCoords }),
            ]),
          ]),
          el('tbody', {}, ordered.map((sample) =>
            el('tr', {}, [
              el('td', { text: formatTimestamp(sample.recordedAt) }),
              el('td', { text: formatSpeed(sample.speedKmh) }),
              el('td', { class: 'mono', text: `${sample.lat.toFixed(5)}, ${sample.lng.toFixed(5)}` }),
            ]),
          )),
        ]),
      ]),
    );
  }

  openModal({
    title: `${Strings.historyTitle} — ${vehicle.plate}`,
    body,
    wide: true,
    actions: [{ label: Strings.close, onClick: (close) => close() }],
  });
}

