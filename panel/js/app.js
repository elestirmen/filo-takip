// Panelin açılış akışı ve rol yönlendirmesi.
//
// Tek kural: **görünümü rol belirler, kullanıcı değil.** Rol, arka ucun
// yaydığı Viewer nesnesinden gelir; o da sunucudaki iki düğümü okur. Bir
// sekmeyi gizlemek güvenlik sağlamaz, asıl sınır veritabanı kurallarıdır —
// buradaki yönlendirme yalnızca kimsenin işine yaramayacak bir ekranla
// uğraşmamasını sağlar.

import { Role } from './models.js';
import { Strings } from './strings.js';
import { createBackend } from './backend.js';
import { createAlertCenter } from './alert-center.js';
import { openAlertsModal } from './view-alerts.js';
import { visibleVehiclesFor } from './visibility-rules.js';
import { createGroupsPage } from './view-groups.js';
import { createMapPage } from './view-map.js';
import { createReportsPage } from './view-reports.js';
import { createSettingsPage } from './view-settings.js';
import { createUsersPage } from './view-users.js';
import { createVehiclesPage } from './view-vehicles.js';
import { renderAuthScreen, renderPendingScreen } from './view-auth.js';
import { badge, clear, el, toast } from './ui.js';
import { useDemoBackend } from './config.js';

// Veri değişmese bile "3 dakika önce" ve çevrimdışı eşiği ilerlesin diye
// arayüz düzenli aralıkla tazelenir.
const REFRESH_MS = 15000;

const root = document.getElementById('app');

let backend = null;
let shell = null;
let currentScreen = null;

boot();

async function boot() {
  showBootScreen(Strings.loading);
  try {
    backend = await createBackend();
  } catch (error) {
    showBootError(error?.message ?? Strings.errorFirebaseInit);
    return;
  }

  backend.errors.listen((message) => toast(message, 'error'));
  backend.viewer.listen(() => render());
  backend.vehicles.listen(() => renderIfShell());
  backend.groups.listen(() => renderIfShell());
  backend.users.listen(() => renderIfShell());
  backend.geofences.listen(() => renderIfShell());
  backend.adminUids.listen(() => renderIfShell());

  window.setInterval(() => renderIfShell(), REFRESH_MS);
}

function currentState() {
  return {
    viewer: backend.viewer.value,
    vehicles: backend.vehicles.value,
    groups: backend.groups.value,
    users: backend.users.value,
    geofences: backend.geofences.value,
    adminUids: backend.adminUids.value,
    nowMs: backend.nowMs(),
  };
}

function renderIfShell() {
  if (shell === null) return;
  shell.update(currentState());
}

function render() {
  const viewer = backend.viewer.value;

  if (viewer === null) {
    showScreen('auth', () => renderAuthScreen(backend));
    return;
  }
  if (viewer.role === Role.pending) {
    showScreen('pending', () => renderPendingScreen(viewer, backend));
    return;
  }

  // Yönetici ile izleyicinin sekmeleri farklı; rol değişince kabuk yeniden
  // kurulur, aynı rolde kalındığında yalnızca veri tazelenir.
  const key = `shell-${viewer.role}`;
  if (currentScreen !== key) {
    showScreen(key, () => {
      shell = createShell(backend, viewer);
      return shell.node;
    });
    // İlk sekme ancak kabuk belgeye eklendikten sonra açılır. Harita bundan
    // önce kurulursa Leaflet, bağlı olmayan elemanın position değerini
    // okuyamayıp üzerine satır içi `position: relative` yazar; o da
    // .map-canvas kuralını ezip haritayı sıfır yükseklikte bırakır.
    shell.start();
  }
  renderIfShell();
}

function showScreen(key, build) {
  if (currentScreen === key) return;
  currentScreen = key;
  if (!key.startsWith('shell-')) shell = null;
  clear(root).append(build());
}

function showBootScreen(message) {
  currentScreen = 'boot';
  clear(root).append(
    el('div', { class: 'auth-screen' }, [
      el('div', { class: 'auth-card' }, [
        el('div', { class: 'spinner', 'aria-hidden': 'true' }),
        el('p', { class: 'auth-subtitle', text: message }),
      ]),
    ]),
  );
}

function showBootError(message) {
  currentScreen = 'boot-error';
  clear(root).append(
    el('div', { class: 'auth-screen' }, [
      el('div', { class: 'auth-card' }, [
        el('div', { class: 'state-icon state-icon-error', 'aria-hidden': 'true' }),
        el('h1', { class: 'auth-title', text: Strings.errorStartupTitle }),
        el('p', { class: 'auth-subtitle', text: message }),
        el('button', {
          type: 'button',
          class: 'btn btn-primary btn-block',
          onclick: () => window.location.reload(),
        }, Strings.retry),
      ]),
    ]),
  );
}

// ------------------------------------------------------------------ Kabuk

function createShell(backend, viewer) {
  const isAdmin = viewer.role === Role.admin;

  // Uyarılar yalnızca **bu kullanıcının görebildiği** araçlar için üretilir;
  // izleyiciye göremediği bir aracın hız aşımını bildirmek anlamsız olurdu.
  const alertCenter = createAlertCenter({ onChange: () => refreshAlertButton() });

  const mapPage = createMapPage(backend);
  const vehiclesPage = isAdmin
    ? createVehiclesPage(backend, {
        onShowOnMap: (vehicleId) => {
          activate('map');
          mapPage.focusVehicle(vehicleId);
        },
        // Geçmiş, haritanın yan sütununda oynatma paneli olarak açılır;
        // araç tablosuyla harita aynı düğmeye aynı şeyi yapsın.
        onShowHistory: (vehicle) => {
          activate('map');
          mapPage.openPlayback(vehicle);
        },
      })
    : null;
  const reportsPage = isAdmin ? createReportsPage(backend) : null;
  const groupsPage = isAdmin ? createGroupsPage(backend) : null;
  const usersPage = isAdmin ? createUsersPage(backend) : null;
  const settingsPage = createSettingsPage(backend);

  const tabs = [
    { id: 'map', label: Strings.navMap, page: mapPage },
    isAdmin ? { id: 'vehicles', label: Strings.navVehicles, page: vehiclesPage } : null,
    isAdmin ? { id: 'reports', label: Strings.navReports, page: reportsPage } : null,
    isAdmin ? { id: 'groups', label: Strings.navGroups, page: groupsPage } : null,
    isAdmin ? { id: 'users', label: Strings.navUsers, page: usersPage } : null,
    { id: 'settings', label: Strings.navSettings, page: settingsPage },
  ].filter((tab) => tab !== null);

  let activeId = 'map';
  let state = null;

  const content = el('main', { class: 'content' });
  const navHost = el('nav', { class: 'nav', 'aria-label': Strings.panelTitle });
  const pendingBadge = el('span', { class: 'nav-count' });

  const alertCount = el('span', { class: 'nav-count' });
  const alertButton = el('button', {
    type: 'button',
    class: 'btn btn-ghost btn-small',
    title: Strings.alertsTitle,
    onclick: () => {
      alertCenter.markSeen();
      openAlertsModal(alertCenter);
    },
  }, [Strings.alertsOpen, alertCount]);

  function refreshAlertButton() {
    const unseen = alertCenter.unseenCount();
    alertCount.textContent = unseen > 0 ? String(unseen) : '';
    alertCount.hidden = unseen === 0;
    alertButton.classList.toggle('btn-active', unseen > 0);
  }
  refreshAlertButton();

  const buttons = new Map();
  for (const tab of tabs) {
    const button = el('button', {
      type: 'button',
      class: 'nav-btn',
      onclick: () => activate(tab.id),
    }, [tab.label, tab.id === 'vehicles' ? pendingBadge : null]);
    buttons.set(tab.id, button);
    navHost.append(button);
  }

  const node = el('div', { class: 'shell' }, [
    el('header', { class: 'topbar' }, [
      el('div', { class: 'brand' }, [
        el('span', { class: 'brand-mark', 'aria-hidden': 'true' }),
        el('span', { class: 'brand-text', text: Strings.appTitle }),
        useDemoBackend ? badge(Strings.demoBadge, 'demo') : null,
      ]),
      navHost,
      el('div', { class: 'topbar-user' }, [
        alertButton,
        el('span', { class: 'user-name', text: viewer.label }),
        badge(isAdmin ? Strings.roleAdmin : Strings.roleViewer, isAdmin ? 'admin' : 'ok'),
        el('button', {
          type: 'button',
          class: 'btn btn-ghost btn-small',
          onclick: async () => {
            try {
              await backend.signOut();
            } catch (error) {
              toast(error?.message ?? Strings.errorSignOutFailed, 'error');
            }
          },
        }, Strings.logoutButton),
      ]),
    ]),
    content,
  ]);

  function activate(id) {
    if (!buttons.has(id)) return;
    activeId = id;
    for (const [tabId, button] of buttons) {
      const active = tabId === id;
      button.classList.toggle('nav-btn-active', active);
      button.setAttribute('aria-current', active ? 'page' : 'false');
    }
    const tab = tabs.find((item) => item.id === id);
    clear(content).append(tab.page.node);
    if (state !== null) tab.page.update(state);
    if (typeof tab.page.onShow === 'function') tab.page.onShow();
  }

  function update(next) {
    state = next;

    alertCenter.process({
      vehicles: visibleVehiclesFor(state.vehicles, state.groups, state.viewer),
      groups: state.groups,
      geofences: state.geofences,
      nowMs: state.nowMs,
    });

    // Yalnızca açık sekme güncellenir; gizli sayfalar sekmeye dönülünce
    // tazelenir, böylece her tikte beş ekran birden kurulmaz.
    const tab = tabs.find((item) => item.id === activeId);
    if (tab !== undefined) tab.page.update(state);

    if (isAdmin) {
      const pending = state.vehicles.filter((vehicle) => !vehicle.approved).length;
      pendingBadge.textContent = pending > 0 ? String(pending) : '';
      pendingBadge.hidden = pending === 0;
    }
  }

  // activate burada değil, kabuk belgeye eklendikten sonra çağrılır.
  return { node, update, start: () => activate('map') };
}
