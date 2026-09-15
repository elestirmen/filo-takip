// Grup yönetimi (yalnızca yönetici).
//
// Bir grup üç şeyi belirler: hangi grupları göreceği (visibleGroups) ve kendi
// araçlarının hızıyla sürücü adının başkalarına görünüp görünmeyeceği.
// Uygulamada bu ayarlar virgüllü bir metin kutusuyla girilir; panelde ekran
// geniş olduğu için onay kutusu listesi kullanılır, yazılan veri aynıdır.

import { GroupConfig } from './models.js';
import { Strings } from './strings.js';
import {
  isGroupNameAvailable,
  vehicleCountInGroup,
  viewerCountInGroup,
} from './admin-rules.js';
import { checkbox, clear, confirmDialog, el, emptyState, field, openModal, runAction, textInput } from './ui.js';
import { normalizeGroupName } from './normalize.js';

export function createGroupsPage(backend) {
  let state = null;

  const listHost = el('div', { class: 'card-grid' });

  const node = el('section', { class: 'page' }, [
    el('div', { class: 'page-head' }, [
      el('h2', { class: 'page-title', text: Strings.groupsTitle }),
      el('div', { class: 'page-tools' }, [
        el('button', {
          type: 'button',
          class: 'btn btn-primary',
          onclick: () => openGroupEditor(null),
        }, Strings.createGroup),
      ]),
    ]),
    el('p', { class: 'page-hint', text: Strings.fieldVisibilityHelp }),
    listHost,
  ]);

  function update(next) {
    state = next;
    draw();
  }

  function draw() {
    clear(listHost);
    if (state.groups.length === 0) {
      listHost.append(emptyState(Strings.noGroups, Strings.noGroupsHint));
      return;
    }

    for (const group of state.groups) {
      const vehicleCount = vehicleCountInGroup(state.vehicles, group.groupId);
      const viewers = viewerCountInGroup(state.users, group.groupId);

      listHost.append(
        el('article', { class: 'group-card' }, [
          el('div', { class: 'group-head' }, [
            el('h3', { class: 'group-name', text: group.groupId }),
            el('span', {
              class: 'group-count',
              text: `${vehicleCount} ${Strings.vehicleCountSuffix} · ${viewers} ${Strings.viewerCountSuffix}`,
            }),
          ]),
          el('dl', { class: 'summary-rows' }, [
            row(
              Strings.visibleGroupsLabel,
              group.visibleGroups.length > 0 ? group.visibleGroups.join(', ') : '—',
            ),
            row(Strings.showSpeed, group.showSpeed ? Strings.visible : Strings.hidden),
            row(Strings.showDriverName, group.showDriverName ? Strings.visible : Strings.hidden),
          ]),
          el('div', { class: 'detail-actions' }, [
            el('button', {
              type: 'button',
              class: 'btn btn-small btn-ghost',
              onclick: () => openGroupEditor(group),
            }, Strings.editGroup),
            el('button', {
              type: 'button',
              class: 'btn btn-small btn-danger',
              onclick: () => confirmDelete(group, vehicleCount, viewers),
            }, Strings.delete),
          ]),
        ]),
      );
    }
  }

  function row(label, value) {
    return el('div', { class: 'summary-row' }, [
      el('dt', { text: label }),
      el('dd', { text: value }),
    ]);
  }

  // group null ise yeni grup oluşturulur; doluysa ayarları düzenlenir.
  function openGroupEditor(group) {
    const isNew = group === null;
    const nameInput = textInput({ value: isNew ? '' : group.groupId, placeholder: Strings.groupNameHint });
    const error = el('p', { class: 'form-error', role: 'alert' });

    const speed = checkbox(Strings.showSpeed, isNew ? true : group.showSpeed);
    const driver = checkbox(Strings.showDriverName, isNew ? true : group.showDriverName);

    // Bir grup kendini göremez; kendi araçlarını zaten görür.
    const others = state.groups.filter((item) => isNew || item.groupId !== group.groupId);
    const visibleBoxes = others.map((item) => ({
      groupId: item.groupId,
      control: checkbox(item.groupId, !isNew && group.visibleGroups.includes(item.groupId)),
    }));

    const body = el('div', { class: 'stack' }, [
      isNew
        ? field(Strings.groupNameLabel, nameInput)
        : el('p', { class: 'modal-message', text: group.groupId }),
      el('div', { class: 'field' }, [
        el('span', { class: 'field-label', text: Strings.visibleGroupsLabel }),
        visibleBoxes.length > 0
          ? el('div', { class: 'checkbox-list' }, visibleBoxes.map((item) => item.control.node))
          : el('span', { class: 'field-hint', text: Strings.noGroups }),
        el('span', { class: 'field-hint', text: Strings.visibleGroupsHelp }),
      ]),
      el('div', { class: 'field' }, [
        el('span', { class: 'field-label', text: Strings.editGroup }),
        el('div', { class: 'checkbox-list' }, [speed.node, driver.node]),
        el('span', { class: 'field-hint', text: Strings.fieldVisibilityHelp }),
      ]),
      error,
    ]);

    openModal({
      title: isNew ? Strings.createGroup : Strings.editGroup,
      body,
      actions: [
        { label: Strings.cancel, onClick: (close) => close() },
        {
          label: Strings.save,
          class: 'btn-primary',
          onClick: async (close) => {
            error.textContent = '';
            const groupId = isNew ? normalizeGroupName(nameInput.value) : group.groupId;
            if (isNew) {
              if (groupId.length === 0) {
                error.textContent = Strings.groupNameRequired;
                return;
              }
              if (!isGroupNameAvailable(groupId, state.groups)) {
                error.textContent = Strings.groupNameExists;
                return;
              }
            }

            const config = new GroupConfig({
              groupId,
              visibleGroups: visibleBoxes
                .filter((item) => item.control.input.checked)
                .map((item) => item.groupId),
              showSpeed: speed.input.checked,
              showDriverName: driver.input.checked,
            });

            const ok = await runAction(
              null,
              () => backend.saveGroupConfig(config),
              isNew ? Strings.groupCreated : Strings.groupSaved,
            );
            if (ok) close();
          },
        },
      ],
    });
  }

  async function confirmDelete(group, vehicleCount, viewers) {
    const counts = `${group.groupId}: ${vehicleCount} ${Strings.vehicleCountSuffix}, ${viewers} ${Strings.viewerCountSuffix}.`;
    const confirmed = await confirmDialog({
      title: Strings.deleteGroupTitle,
      message: `${counts} ${Strings.deleteGroupMessage}`,
      confirmLabel: Strings.delete,
      danger: true,
    });
    if (!confirmed) return;
    await runAction(null, () => backend.deleteGroup(group.groupId), Strings.groupDeleted);
  }

  return { node, update };
}
