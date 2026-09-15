// Giriş, kayıt ve "onay bekliyor" ekranları.
//
// Kayıt akışı, uygulamadaki araç kaydının aynısıdır: hesap onaysız doğar,
// yönetici onaylayıp bir gruba atayana kadar hiçbir araç görünmez.

import { Strings } from './strings.js';
import { clear, el, field, textInput, toast } from './ui.js';
import { isValidEmail, normalizeDriverName } from './normalize.js';

// Demo kipinde hangi hesapla ne görüneceğini ekranda söyler; yoksa panelin
// rol davranışını denemek için dosyaları okumak gerekirdi.
function demoHint(backend) {
  if (!backend.isDemo) return null;
  return el('div', { class: 'notice notice-demo' }, [
    el('p', { class: 'notice-title', text: Strings.demoNoticeTitle }),
    el('p', { text: Strings.demoNotice }),
    el('p', { class: 'notice-sub', text: Strings.demoAccountsHint }),
    el('ul', { class: 'notice-list' }, [
      el('li', { text: Strings.demoAdminAccount }),
      el('li', { text: Strings.demoViewerAccount }),
      el('li', { text: Strings.demoPendingAccount }),
    ]),
  ]);
}

export function renderAuthScreen(backend) {
  let mode = 'login';
  const host = el('div', { class: 'auth-screen' });

  const draw = () => {
    clear(host);
    host.append(mode === 'login' ? loginCard() : registerCard());
  };

  const errorLine = () => el('p', { class: 'form-error', role: 'alert' });

  const submitButton = (label) =>
    el('button', { type: 'submit', class: 'btn btn-primary btn-block' }, label);

  const loginCard = () => {
    const email = textInput({ type: 'email', autocomplete: 'username' });
    const password = textInput({ type: 'password', autocomplete: 'current-password' });
    const error = errorLine();
    const button = submitButton(Strings.loginButton);

    const form = el('form', {
      class: 'auth-form',
      onsubmit: async (event) => {
        event.preventDefault();
        error.textContent = '';
        if (!isValidEmail(email.value)) {
          error.textContent = email.value.trim() ? Strings.emailInvalid : Strings.emailRequired;
          email.focus();
          return;
        }
        if (password.value.length === 0) {
          error.textContent = Strings.passwordRequired;
          password.focus();
          return;
        }
        button.disabled = true;
        button.textContent = Strings.loginBusy;
        try {
          await backend.signIn(email.value, password.value);
          // Başarılı girişte görünümü viewer akışı değiştirir.
        } catch (failure) {
          error.textContent = failure?.message ?? Strings.errorSignInFailed;
          button.disabled = false;
          button.textContent = Strings.loginButton;
        }
      },
    }, [
      field(Strings.loginEmailLabel, email),
      field(Strings.loginPasswordLabel, password),
      error,
      button,
    ]);

    return card(Strings.loginTitle, form, {
      switchLabel: Strings.registerSwitch,
      onSwitch: () => {
        mode = 'register';
        draw();
      },
    });
  };

  const registerCard = () => {
    const name = textInput({ autocomplete: 'name' });
    const email = textInput({ type: 'email', autocomplete: 'username' });
    const password = textInput({ type: 'password', autocomplete: 'new-password' });
    const error = errorLine();
    const button = submitButton(Strings.registerButton);

    const form = el('form', {
      class: 'auth-form',
      onsubmit: async (event) => {
        event.preventDefault();
        error.textContent = '';
        const displayName = normalizeDriverName(name.value);
        if (displayName.length === 0) {
          error.textContent = Strings.nameRequired;
          name.focus();
          return;
        }
        if (displayName.length < 3) {
          error.textContent = Strings.nameTooShort;
          name.focus();
          return;
        }
        if (!isValidEmail(email.value)) {
          error.textContent = email.value.trim() ? Strings.emailInvalid : Strings.emailRequired;
          email.focus();
          return;
        }
        if (password.value.length < 6) {
          error.textContent = password.value.length === 0
            ? Strings.passwordRequired
            : Strings.passwordTooShort;
          password.focus();
          return;
        }
        button.disabled = true;
        button.textContent = Strings.registerBusy;
        try {
          await backend.register({ email: email.value, password: password.value, displayName });
        } catch (failure) {
          error.textContent = failure?.message ?? Strings.errorSignInFailed;
          button.disabled = false;
          button.textContent = Strings.registerButton;
        }
      },
    }, [
      field(Strings.registerNameLabel, name),
      field(Strings.loginEmailLabel, email),
      field(Strings.loginPasswordLabel, password, Strings.passwordTooShort),
      el('p', { class: 'form-hint', text: Strings.registerHint }),
      error,
      button,
    ]);

    return card(Strings.registerTitle, form, {
      switchLabel: Strings.loginSwitch,
      onSwitch: () => {
        mode = 'login';
        draw();
      },
    });
  };

  const card = (title, form, { switchLabel, onSwitch }) =>
    el('div', { class: 'auth-card' }, [
      el('div', { class: 'auth-brand' }, [
        el('span', { class: 'brand-mark', 'aria-hidden': 'true' }),
        el('div', {}, [
          el('h1', { class: 'auth-title', text: title }),
          el('p', { class: 'auth-subtitle', text: Strings.loginSubtitle }),
        ]),
      ]),
      form,
      el('button', { type: 'button', class: 'link-btn', onclick: onSwitch }, switchLabel),
      demoHint(backend),
    ]);

  draw();
  return host;
}

// Onay bekleyen hesap. Yönetici onayladığı anda viewer akışı yeni bir rol
// yayar ve panel kendiliğinden izleyici görünümüne geçer.
export function renderPendingScreen(viewer, backend) {
  return el('div', { class: 'auth-screen' }, [
    el('div', { class: 'auth-card' }, [
      el('div', { class: 'state-icon state-icon-wait', 'aria-hidden': 'true' }),
      el('h1', { class: 'auth-title', text: Strings.pendingTitle }),
      el('p', { class: 'auth-subtitle', text: Strings.pendingMessage }),
      el('dl', { class: 'summary-rows' }, [
        infoRow(Strings.settingsEmail, viewer.email),
        infoRow(Strings.settingsRole, Strings.rolePending),
      ]),
      el('button', {
        type: 'button',
        class: 'btn btn-ghost btn-block',
        onclick: async () => {
          try {
            await backend.signOut();
          } catch (error) {
            toast(error?.message ?? Strings.errorSignOutFailed, 'error');
          }
        },
      }, Strings.logoutButton),
    ]),
  ]);
}

function infoRow(label, value) {
  return el('div', { class: 'summary-row' }, [
    el('dt', { text: label }),
    el('dd', { text: value }),
  ]);
}
