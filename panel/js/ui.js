// Küçük DOM yardımcıları: eleman kurma, bildirim şeridi ve kip pencereleri.
//
// Panelde çerçeve (React, Vue…) kullanılmıyor; bu dosya o boşluğu dolduran
// en küçük katmandır. Metinler her zaman textContent ile yazılır, innerHTML
// kullanılmaz: plaka ve sürücü adı kullanıcıdan gelen veridir.

import { Strings } from './strings.js';

// el('div', {class: 'card', onclick: fn}, [child, 'metin'])
export function el(tag, props = {}, children = []) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value === null || value === undefined || value === false) continue;
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (key === 'html') throw new Error('innerHTML kullanılmaz');
    else if (key === 'dataset') Object.assign(node.dataset, value);
    else if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2), value);
    } else if (value === true) node.setAttribute(key, '');
    else node.setAttribute(key, String(value));
  }
  appendChildren(node, children);
  return node;
}

function appendChildren(node, children) {
  const list = Array.isArray(children) ? children : [children];
  for (const child of list) {
    if (child === null || child === undefined || child === false) continue;
    node.append(typeof child === 'string' || typeof child === 'number' ? String(child) : child);
  }
  return node;
}

export function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
  return node;
}

// Alt köşede beliren kısa bildirim. kind: 'info' | 'success' | 'error'
export function toast(message, kind = 'info') {
  const host = document.getElementById('toast-host');
  const node = el('div', { class: `toast toast-${kind}`, role: 'status', text: message });
  host.append(node);
  window.setTimeout(() => {
    node.classList.add('toast-leaving');
    window.setTimeout(() => node.remove(), 250);
  }, 3600);
}

// Kip pencere. actions, düğme tanımlarının listesidir; her düğme kapatma
// fonksiyonunu alır. Pencere Esc ve arka plan tıklamasıyla da kapanır.
export function openModal({ title, body, actions = [], wide = false, onClose }) {
  const host = document.getElementById('modal-host');
  const previouslyFocused = document.activeElement;

  const close = () => {
    document.removeEventListener('keydown', onKeyDown);
    overlay.remove();
    if (previouslyFocused instanceof HTMLElement) previouslyFocused.focus();
    if (typeof onClose === 'function') onClose();
  };

  const onKeyDown = (event) => {
    if (event.key === 'Escape') close();
  };

  const footer = el('div', { class: 'modal-actions' });
  for (const action of actions) {
    footer.append(
      el('button', {
        type: 'button',
        class: `btn ${action.class ?? 'btn-ghost'}`,
        onclick: () => action.onClick(close),
      }, action.label),
    );
  }

  const dialog = el('div', { class: `modal ${wide ? 'modal-wide' : ''}`, role: 'dialog', 'aria-modal': 'true' }, [
    el('div', { class: 'modal-head' }, [
      el('h2', { class: 'modal-title', text: title }),
      el('button', { type: 'button', class: 'icon-btn', 'aria-label': Strings.close, onclick: close }, '×'),
    ]),
    el('div', { class: 'modal-body' }, [body]),
    actions.length > 0 ? footer : null,
  ]);

  const overlay = el('div', {
    class: 'modal-overlay',
    onclick: (event) => {
      if (event.target === overlay) close();
    },
  }, [dialog]);

  host.append(overlay);
  document.addEventListener('keydown', onKeyDown);
  // İlk odak pencerenin içinde kalsın.
  const focusable = dialog.querySelector('input, select, textarea, button.btn');
  if (focusable instanceof HTMLElement) focusable.focus();
  return close;
}

// Evet/hayır penceresi. Söz, kullanıcı onaylarsa true döner.
export function confirmDialog({ title, message, confirmLabel, danger = false }) {
  return new Promise((resolve) => {
    let answered = false;
    const finish = (value, close) => {
      answered = true;
      close();
      resolve(value);
    };
    openModal({
      title,
      body: el('p', { class: 'modal-message', text: message }),
      actions: [
        { label: Strings.cancel, class: 'btn-ghost', onClick: (close) => finish(false, close) },
        {
          label: confirmLabel,
          class: danger ? 'btn-danger' : 'btn-primary',
          onClick: (close) => finish(true, close),
        },
      ],
      onClose: () => {
        if (!answered) resolve(false);
      },
    });
  });
}

// Bir düğmeyi işlem süresince kilitler; hata mesajını bildirim şeridine verir.
export async function runAction(button, action, successMessage) {
  if (button instanceof HTMLButtonElement) button.disabled = true;
  try {
    await action();
    if (successMessage) toast(successMessage, 'success');
    return true;
  } catch (error) {
    toast(error?.message ?? Strings.errorSaveFailed, 'error');
    return false;
  } finally {
    if (button instanceof HTMLButtonElement) button.disabled = false;
  }
}

// Boş liste / boş sonuç kartı.
export function emptyState(title, hint) {
  return el('div', { class: 'empty-state' }, [
    el('p', { class: 'empty-title', text: title }),
    hint ? el('p', { class: 'empty-hint', text: hint }) : null,
  ]);
}

export function badge(text, kind = 'neutral') {
  return el('span', { class: `badge badge-${kind}`, text });
}

// Renkli nokta + metin; durum göstergelerinde kullanılır.
export function statusDot(color, text) {
  return el('span', { class: 'status' }, [
    el('span', { class: 'status-dot', style: `background:${color}` }),
    el('span', { text }),
  ]);
}

// Etiketli form alanı.
export function field(labelText, control, hint) {
  return el('label', { class: 'field' }, [
    el('span', { class: 'field-label', text: labelText }),
    control,
    hint ? el('span', { class: 'field-hint', text: hint }) : null,
  ]);
}

export function textInput({ type = 'text', value = '', placeholder = '', autocomplete }) {
  return el('input', { class: 'input', type, value, placeholder, autocomplete });
}

// Açılır liste. options: [{value, label}] — value null ise boş dize taşınır.
export function select(options, selectedValue) {
  const node = el('select', { class: 'input' });
  for (const option of options) {
    const value = option.value ?? '';
    node.append(
      el('option', { value, selected: value === (selectedValue ?? '') }, option.label),
    );
  }
  return node;
}

export function checkbox(labelText, checked) {
  const input = el('input', { type: 'checkbox', checked });
  return {
    input,
    node: el('label', { class: 'checkbox' }, [input, el('span', { text: labelText })]),
  };
}
