// Ayarlar: oturum bilgisi, hangi arka uçla çalışıldığı ve çıkış.
//
// Her iki rol de görür. Yetki burada değiştirilemez; yalnızca gösterilir.

import { Role } from './models.js';
import { Strings } from './strings.js';
import { badge, clear, el, toast } from './ui.js';
import { firebaseConfig, useDemoBackend } from './config.js';

export function createSettingsPage(backend) {
  let state = null;
  const node = el('section', { class: 'page' });

  function update(next) {
    state = next;
    draw();
  }

  function draw() {
    const { viewer } = state;
    clear(node).append(
      el('div', { class: 'page-head' }, [
        el('h2', { class: 'page-title', text: Strings.settingsTitle }),
      ]),
      el('div', { class: 'card-grid' }, [
        el('article', { class: 'group-card' }, [
          el('h3', { class: 'group-name', text: Strings.settingsSession }),
          el('dl', { class: 'summary-rows' }, [
            row(Strings.settingsEmail, viewer.email),
            row(Strings.settingsUid, viewer.uid, true),
            roleRow(viewer),
            row(
              Strings.settingsGroup,
              viewer.role === Role.admin ? '—' : (viewer.groupId ?? Strings.groupNone),
            ),
          ]),
          el('button', {
            type: 'button',
            class: 'btn btn-ghost',
            onclick: async () => {
              try {
                await backend.signOut();
              } catch (error) {
                toast(error?.message ?? Strings.errorSignOutFailed, 'error');
              }
            },
          }, Strings.logoutButton),
        ]),

        el('article', { class: 'group-card' }, [
          el('h3', { class: 'group-name', text: Strings.settingsBackend }),
          el('dl', { class: 'summary-rows' }, [
            row(
              Strings.settingsBackend,
              useDemoBackend ? Strings.settingsBackendDemo : Strings.settingsBackendFirebase,
            ),
            useDemoBackend ? null : row(Strings.settingsProject, firebaseConfig.projectId),
          ]),
          useDemoBackend
            ? el('div', { class: 'notice notice-demo' }, [
                el('p', { class: 'notice-title', text: Strings.demoNoticeTitle }),
                el('p', { text: Strings.demoNotice }),
                el('p', { class: 'notice-sub', text: Strings.demoConfigHint }),
              ])
            : null,
        ]),

        el('article', { class: 'group-card' }, [
          el('h3', { class: 'group-name', text: Strings.settingsAbout }),
          el('p', { class: 'field-hint', text: Strings.settingsAboutText }),
          el('dl', { class: 'summary-rows' }, [
            row(Strings.roleAdmin, Strings.roleAdminHint),
            row(Strings.roleViewer, Strings.roleViewerHint),
            row(Strings.rolePending, Strings.rolePendingHint),
          ]),
        ]),
      ]),
    );
  }

  function roleRow(viewer) {
    const kind = viewer.role === Role.admin ? 'admin' : viewer.role === Role.viewer ? 'ok' : 'warn';
    const label = viewer.role === Role.admin
      ? Strings.roleAdmin
      : viewer.role === Role.viewer
        ? Strings.roleViewer
        : Strings.rolePending;
    return el('div', { class: 'summary-row' }, [
      el('dt', { text: Strings.settingsRole }),
      el('dd', {}, [badge(label, kind)]),
    ]);
  }

  function row(label, value, mono = false) {
    if (value === null || value === undefined) return null;
    return el('div', { class: 'summary-row' }, [
      el('dt', { text: label }),
      el('dd', { class: mono ? 'mono' : '', text: value }),
    ]);
  }

  return { node, update };
}
