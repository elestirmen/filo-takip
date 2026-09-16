// Uyarı listesi penceresi.
//
// Uyarılar kalıcı değildir: panel açıkken üretilir, sayfa yenilenince liste
// sıfırlanır. Sunucu tarafı bir izleyici olmadığı için sekme kapalıyken olan
// bir hız aşımı hiç fark edilmez — bu, arayüzde de açıkça söylenir.

import { Strings } from './strings.js';
import { badge, checkbox, clear, el, emptyState, openModal, toast } from './ui.js';
import { alertDetail, alertKindClass, alertTitle } from './alert-center.js';
import { formatTimestamp } from './time-format.js';

export function openAlertsModal(alertCenter) {
  const body = el('div', { class: 'stack' });

  const notifyControl = checkbox(Strings.alertsNotifications, alertCenter.notifyEnabled);
  notifyControl.input.addEventListener('change', async () => {
    const wanted = notifyControl.input.checked;
    const result = await alertCenter.setNotifyEnabled(wanted);
    notifyControl.input.checked = result.enabled;
    if (wanted && result.blocked) toast(Strings.alertsNotificationsBlocked, 'error');
  });

  function draw() {
    const alerts = alertCenter.list();
    clear(body).append(
      el('div', { class: 'field' }, [
        notifyControl.node,
        el('span', { class: 'field-hint', text: Strings.alertsNotificationsHint }),
      ]),
    );

    if (alerts.length === 0) {
      body.append(emptyState(Strings.alertsEmpty, Strings.alertsEmptyHint));
      return;
    }

    body.append(
      el('div', { class: 'table-scroll' }, [
        el('table', { class: 'table' }, [
          el('tbody', {}, alerts.map((alert) =>
            el('tr', {}, [
              el('td', { text: formatTimestamp(alert.at) }),
              el('td', {}, [el('span', { class: 'cell-strong', text: alert.plate })]),
              el('td', {}, [badge(alertTitle(alert), alertKindClass(alert))]),
              el('td', { text: alertDetail(alert) }),
            ]),
          )),
        ]),
      ]),
      el('button', {
        type: 'button',
        class: 'btn btn-ghost btn-small',
        onclick: () => {
          alertCenter.clear();
          draw();
        },
      }, Strings.alertsClear),
    );
  }

  draw();

  openModal({
    title: Strings.alertsTitle,
    body,
    wide: true,
    actions: [{ label: Strings.close, onClick: (close) => close() }],
  });
}
