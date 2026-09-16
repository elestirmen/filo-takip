// Uyarıların durumunu tutan ve gösteren katman.
//
// Tespit alerts.js içinde saf olarak yapılır; burada yalnızca önceki durum
// saklanır, üretilen uyarılar sınırlı bir listede biriktirilir ve kullanıcıya
// gösterilir.
//
// Önemli sınır: uyarılar **yalnızca panel açıkken** üretilir. Sunucu tarafı
// bir izleyici yoktur; sekme kapalıyken olan bir hız aşımı fark edilmez.

import { Strings } from './strings.js';
import { AlertKind, detectAlerts } from './alerts.js';
import { formatSpeed } from './time-format.js';
import { toast } from './ui.js';

// Listede tutulan en fazla uyarı. Eskiler düşer; kalıcı kayıt değildir.
const MAX_ALERTS = 100;

const NOTIFY_KEY = 'filo-takip-bildirim';

function notificationsWanted() {
  try {
    return window.localStorage.getItem(NOTIFY_KEY) === 'acik';
  } catch {
    return false;
  }
}

function setNotificationsWanted(value) {
  try {
    if (value) window.localStorage.setItem(NOTIFY_KEY, 'acik');
    else window.localStorage.removeItem(NOTIFY_KEY);
  } catch {
    // Depolama kapalıysa tercih bu oturumda yaşar.
  }
}

export function alertTitle(alert) {
  switch (alert.kind) {
    case AlertKind.speeding:
      return Strings.alertSpeeding;
    case AlertKind.offline:
      return Strings.alertOffline;
    case AlertKind.geofenceEnter:
      return Strings.alertZoneEnter;
    default:
      return Strings.alertZoneExit;
  }
}

export function alertDetail(alert) {
  switch (alert.kind) {
    case AlertKind.speeding:
      return `${formatSpeed(alert.speedKmh)} (sınır ${formatSpeed(alert.limitKmh)})`;
    case AlertKind.offline:
      return '';
    default:
      return alert.zoneName;
  }
}

export function alertKindClass(alert) {
  if (alert.kind === AlertKind.speeding) return 'warn';
  if (alert.kind === AlertKind.offline) return 'neutral';
  return 'ok';
}

export function createAlertCenter({ onChange }) {
  let previous = new Map();
  let recent = [];
  let unseen = 0;
  let notify = notificationsWanted();

  // Her veri güncellemesinde çağrılır.
  function process({ vehicles, groups, geofences, nowMs }) {
    const { alerts, next } = detectAlerts({ vehicles, groups, geofences, previous, nowMs });
    previous = next;
    if (alerts.length === 0) return;

    recent = [...alerts.reverse(), ...recent].slice(0, MAX_ALERTS);
    unseen += alerts.length;

    for (const alert of alerts) {
      const detail = alertDetail(alert);
      const line = `${alert.plate} — ${alertTitle(alert)}${detail ? ` · ${detail}` : ''}`;
      toast(line, alert.kind === AlertKind.speeding ? 'error' : 'info');
      showNotification(line);
    }
    onChange();
  }

  function showNotification(line) {
    if (!notify) return;
    if (typeof window.Notification === 'undefined') return;
    if (window.Notification.permission !== 'granted') return;
    try {
      // eslint-disable-next-line no-new
      new window.Notification(Strings.appTitle, { body: line, tag: 'filo-takip' });
    } catch {
      // Bazı tarayıcılar masaüstü dışında yapıcıyı engeller; sessiz geç.
    }
  }

  // Bildirim izni yalnızca kullanıcı isteyince sorulur; açılışta sormak hem
  // kaba olur hem de tarayıcılar böyle istekleri engelliyor.
  async function setNotifyEnabled(enabled) {
    if (!enabled) {
      notify = false;
      setNotificationsWanted(false);
      return { enabled: false, blocked: false };
    }
    if (typeof window.Notification === 'undefined') {
      return { enabled: false, blocked: true };
    }
    let permission = window.Notification.permission;
    if (permission === 'default') permission = await window.Notification.requestPermission();
    if (permission !== 'granted') {
      notify = false;
      setNotificationsWanted(false);
      return { enabled: false, blocked: true };
    }
    notify = true;
    setNotificationsWanted(true);
    return { enabled: true, blocked: false };
  }

  return {
    process,
    setNotifyEnabled,
    get notifyEnabled() {
      return notify;
    },
    list: () => recent,
    unseenCount: () => unseen,
    markSeen: () => {
      unseen = 0;
      onChange();
    },
    clear: () => {
      recent = [];
      unseen = 0;
      onChange();
    },
  };
}
