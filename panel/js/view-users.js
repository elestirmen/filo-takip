// Panel kullanıcıları (yalnızca yönetici).
//
// Yetki iki düğümden okunur ve ikisini de sunucu tutar:
//   * /admins/{uid}            -> yönetici
//   * /webUsers/{uid}.approved -> izleyici
// Yönetici kendi yetkisini bu ekrandan düşüremez; veritabanı kuralı da buna
// izin vermez. Yetkisiz kalmış bir kurulumun çıkış yolu Firebase Console'dur.

import { Role } from './models.js';
import { Strings } from './strings.js';
import { matchesUserSearch, sortUsersForAdmin } from './admin-rules.js';
import { badge, clear, confirmDialog, el, emptyState, runAction, select, textInput } from './ui.js';
import { formatTimestamp } from './time-format.js';

export function createUsersPage(backend) {
  let state = null;
  let signature = null;

  const search = textInput({ placeholder: Strings.search });
  search.addEventListener('input', () => drawBody());

  const tableBody = el('tbody');
  const emptyHost = el('div');

  const node = el('section', { class: 'page' }, [
    el('div', { class: 'page-head' }, [
      el('h2', { class: 'page-title', text: Strings.usersTitle }),
      el('div', { class: 'page-tools' }, [search]),
    ]),
    el('p', { class: 'page-hint', text: Strings.usersHint }),
    el('div', { class: 'table-card' }, [
      el('div', { class: 'table-scroll' }, [
        el('table', { class: 'table' }, [
          el('thead', {}, [
            el('tr', {}, [
              el('th', { text: Strings.colUser }),
              el('th', { text: Strings.colEmail }),
              el('th', { text: Strings.colRole }),
              el('th', { text: Strings.colGroup }),
              el('th', { text: Strings.colCreated }),
              el('th', { class: 'col-actions', text: Strings.colActions }),
            ]),
          ]),
          tableBody,
        ]),
      ]),
      emptyHost,
    ]),
  ]);

  // Bu sayfada zamana bağlı hiçbir şey yok ama arayüz düzenli aralıkla
  // tazeleniyor. Her tikte tabloyu yeniden kurmak, açık duran grup listesini
  // kapatırdı; bu yüzden veri gerçekten değişmediyse çizim atlanır.
  function update(next) {
    state = next;
    const nextSignature = JSON.stringify([
      state.users.map((user) => [user.uid, user.email, user.displayName, user.groupId, user.approved]),
      [...state.adminUids].sort(),
      state.groups.map((group) => group.groupId),
    ]);
    if (nextSignature === signature) return;
    signature = nextSignature;
    drawBody();
  }

  function roleOf(user) {
    if (state.adminUids.has(user.uid)) return Role.admin;
    return user.approved ? Role.viewer : Role.pending;
  }

  function roleBadge(role) {
    switch (role) {
      case Role.admin:
        return badge(Strings.roleAdmin, 'admin');
      case Role.viewer:
        return badge(Strings.roleViewer, 'ok');
      default:
        return badge(Strings.rolePending, 'warn');
    }
  }

  function drawBody() {
    if (state === null) return;
    const rows = sortUsersForAdmin(state.users, state.adminUids).filter((user) =>
      matchesUserSearch(user, search.value),
    );

    clear(tableBody);
    clear(emptyHost);

    if (state.users.length === 0) {
      emptyHost.append(emptyState(Strings.noUsers, Strings.noUsersHint));
      return;
    }
    if (rows.length === 0) {
      emptyHost.append(emptyState(Strings.noSearchResult));
      return;
    }

    for (const user of rows) {
      const role = roleOf(user);
      const isSelf = user.uid === state.viewer.uid;
      tableBody.append(
        el('tr', { class: role === Role.pending ? 'row-pending' : '' }, [
          el('td', {}, [
            el('div', { class: 'cell-stack' }, [
              el('span', { class: 'cell-strong', text: user.label }),
              isSelf ? badge(Strings.youBadge, 'neutral') : null,
            ]),
          ]),
          el('td', { text: user.email }),
          el('td', {}, [roleBadge(role)]),
          el('td', {}, [groupControl(user, role, isSelf)]),
          el('td', { text: user.createdAt > 0 ? formatTimestamp(user.createdAt) : '—' }),
          el('td', { class: 'col-actions' }, [actions(user, role, isSelf)]),
        ]),
      );
    }
  }

  // Yönetici için grup anlamsızdır: zaten tüm araçları görür.
  function groupControl(user, role, isSelf) {
    if (role === Role.admin) return el('span', { class: 'muted', text: '—' });

    const picker = select(
      [
        { value: '', label: Strings.groupNone },
        ...state.groups.map((group) => ({ value: group.groupId, label: group.groupId })),
      ],
      user.groupId ?? '',
    );
    picker.classList.add('input-small');
    picker.disabled = isSelf;
    picker.addEventListener('change', async () => {
      const value = picker.value.length > 0 ? picker.value : null;
      picker.disabled = true;
      await runAction(null, () => backend.setUserGroup(user.uid, value), Strings.userGroupAssigned);
      picker.disabled = isSelf;
    });
    return picker;
  }

  function actions(user, role, isSelf) {
    if (isSelf) return el('span', { class: 'muted', text: Strings.selfRoleLocked });

    const buttons = [];

    if (role !== Role.admin) {
      buttons.push(
        el('button', {
          type: 'button',
          class: `btn btn-small ${user.approved ? 'btn-ghost' : 'btn-primary'}`,
          onclick: (event) =>
            runAction(
              event.currentTarget,
              () => backend.setUserApproved(user.uid, !user.approved),
              user.approved ? Strings.userRevoked : Strings.userApproved,
            ),
        }, user.approved ? Strings.revoke : Strings.approve),
      );
    }

    buttons.push(
      el('button', {
        type: 'button',
        class: 'btn btn-small btn-ghost',
        onclick: () => confirmAdminChange(user, role),
      }, role === Role.admin ? Strings.removeAdmin : Strings.makeAdmin),
    );

    buttons.push(
      el('button', {
        type: 'button',
        class: 'btn btn-small btn-danger',
        onclick: () => confirmDelete(user),
      }, Strings.delete),
    );

    return el('div', { class: 'row-actions' }, buttons);
  }

  async function confirmAdminChange(user, role) {
    const makeAdmin = role !== Role.admin;
    const confirmed = await confirmDialog({
      title: makeAdmin ? Strings.makeAdminTitle : Strings.removeAdminTitle,
      message: `${user.label} (${user.email}) — ${makeAdmin ? Strings.makeAdminMessage : Strings.removeAdminMessage}`,
      confirmLabel: makeAdmin ? Strings.makeAdmin : Strings.removeAdmin,
      danger: !makeAdmin,
    });
    if (!confirmed) return;
    await runAction(null, () => backend.setUserAdmin(user.uid, makeAdmin), Strings.userRoleChanged);
  }

  async function confirmDelete(user) {
    const confirmed = await confirmDialog({
      title: Strings.deleteUserTitle,
      message: `${user.label} (${user.email}) — ${Strings.deleteUserMessage}`,
      confirmLabel: Strings.delete,
      danger: true,
    });
    if (!confirmed) return;
    await runAction(null, () => backend.deleteUser(user.uid), Strings.userDeleted);
  }

  return { node, update };
}
