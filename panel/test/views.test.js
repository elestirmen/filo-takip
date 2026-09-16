// Görünüm katmanının testleri: panel gerçek bir DOM'da kurulur, rollerle
// giriş yapılır ve her rolün gördüğü ekran doğrulanır.
//
// Bu dosya tek isteğe bağlı bağımlılığı kullanır. Kurulu değilse testler
// atlanır, `node --test` yine sıfır bağımlılıkla çalışır:
//
//   cd panel && npm install --no-save jsdom && node --test
//
// Leaflet jsdom'da çalışmadığı için global L, çağrıları yutan küçük bir
// sahteyle değiştirilir; amaç haritayı çizmek değil, ekranların istisna
// atmadan kurulduğunu ve rolün doğru görünümü verdiğini görmek.

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PANEL = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

let JSDOM = null;
try {
  ({ JSDOM } = await import('jsdom'));
} catch {
  // jsdom yok; aşağıdaki blok atlanır.
}

const skip = JSDOM === null
  ? 'jsdom kurulu değil (npm install --no-save jsdom)'
  : false;

describe('panel görünümleri', { skip }, () => {
  let window;
  // L.map çağrıldığı anda konteyner belgeye bağlı mıydı? Bağlı değilse
  // Leaflet üzerine satır içi `position: relative` yazar ve harita gerçek
  // tarayıcıda sıfır yükseklikte kalır. jsdom yerleşim hesaplamadığı için
  // bunu ancak böyle yakalayabiliriz.
  let mapContainerConnectedAtInit = null;

  const app = () => window.document.getElementById('app');
  const text = () => app().textContent;
  const $ = (selector) => app().querySelector(selector);
  const $$ = (selector) => [...app().querySelectorAll(selector)];
  const modal = () => window.document.querySelector('#modal-host .modal');
  const tick = (ms = 80) => new Promise((resolve) => setTimeout(resolve, ms));

  const button = (label, scope) =>
    [...(scope ?? app()).querySelectorAll('button')].find(
      (node) => node.textContent.trim() === label,
    ) ?? null;

  function setInput(input, value) {
    input.value = value;
    input.dispatchEvent(new window.Event('input', { bubbles: true }));
  }

  async function signIn(email, password) {
    const inputs = $$('input');
    setInput(inputs.find((input) => input.type === 'email'), email);
    setInput(inputs.find((input) => input.type === 'password'), password);
    $('form').dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
    await tick(400);
  }

  async function signOut() {
    button('Çıkış yap').click();
    await tick(300);
  }

  // Leaflet yerine geçen sahte katman.
  function fakeLayer() {
    return {
      addTo() { return this; },
      on() { return this; },
      remove() {},
      setIcon() {}, setZIndexOffset() {},
      setLatLng(latLng) { this._latLng = latLng; return this; },
      getLatLng() { return this._latLng ?? { lat: 0, lng: 0 }; },
      bindTooltip() { return this; },
      setTooltipContent() { return this; },
      bindPopup(content) { this._popup = content; return this; },
      setPopupContent(content) { this._popup = content; return this; },
      getPopup() { return this._popup ?? null; },
      getBounds() { return {}; },
    };
  }

  before(async () => {
    const dom = new JSDOM(
      `<!DOCTYPE html><html lang="tr"><body>
         <div id="app"></div><div id="toast-host"></div><div id="modal-host"></div>
       </body></html>`,
      { url: 'http://localhost/', pretendToBeVisual: true },
    );
    window = dom.window;

    globalThis.L = {
      map: (container) => {
        mapContainerConnectedAtInit = container.isConnected;
        return {
          on() {}, remove() {}, invalidateSize() {}, setView() {}, panTo() {},
          fitBounds() {}, getZoom: () => 12,
        };
      },
      tileLayer: fakeLayer,
      marker: fakeLayer,
      polyline: fakeLayer,
      divIcon: (options) => options,
      latLngBounds: () => ({}),
    };
    globalThis.window = window;
    globalThis.document = window.document;
    globalThis.HTMLElement = window.HTMLElement;
    globalThis.HTMLButtonElement = window.HTMLButtonElement;
    globalThis.Event = window.Event;

    await import(`${PANEL}/js/app.js`);
    await tick(300);
  });

  // Demo arka ucu araçları 5 saniyede bir hareket ettiren bir zamanlayıcı
  // kurar ve panel de arayüzü düzenli tazeler. Pencere kapatılmazsa bu
  // zamanlayıcılar olay döngüsünü açık tutar ve `node --test` hiç bitmez.
  after(() => window.close());

  // ------------------------------------------------------------ Giriş

  it('giriş ekranı demo uyarısı ve hesaplarıyla açılır', () => {
    assert.ok(text().includes('Panele giriş'));
    assert.ok(text().includes('Demo kipi'));
    assert.ok(text().includes('yonetici@ornek.com'));
  });

  it('kayıt ekranına geçilip geri dönülebilir', () => {
    button('Hesabınız yok mu? Kayıt olun').click();
    assert.ok(text().includes('Yeni hesap'));
    assert.equal($$('input').length, 3);
    button('Zaten hesabınız var mı? Giriş yapın').click();
    assert.ok(text().includes('Panele giriş'));
  });

  it('boş form doğrulama hatası verir', () => {
    $('form').dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
    assert.ok(text().includes('E-posta girin.'));
  });

  // --------------------------------------------------------- Yönetici

  it('yönetici girişi beş sekmeli kabuğu açar', async () => {
    await signIn('yonetici@ornek.com', '123456');
    const tabs = $$('.nav-btn').map((node) => node.textContent.replace(/\d+$/, '').trim());
    assert.deepEqual(tabs, ['Harita', 'Araçlar', 'Gruplar', 'Kullanıcılar', 'Ayarlar']);
    assert.ok($('.badge-admin'), 'yönetici rozeti yok');
    assert.ok(text().includes('DEMO'), 'demo rozeti yok');
  });

  it('harita, konteyner belgeye eklendikten sonra kurulur', () => {
    assert.equal(
      mapContainerConnectedAtInit,
      true,
      'L.map bağlı olmayan elemanla çağrıldı: Leaflet satır içi position yazar '
      + 've harita gerçek tarayıcıda sıfır yükseklikte kalır',
    );
  });

  it('yönetici haritada tüm araçları görür', () => {
    assert.equal($$('.vehicle-row').length, 6);
    assert.ok(text().includes('40 PRS 606'), 'onay bekleyen araç listede yok');
    assert.ok(text().includes('Filo özeti'));
  });

  it('araç seçilince işlem düğmeleri çıkar', () => {
    $$('.vehicle-row')[0].click();
    assert.ok($('.detail-card'));
    const labels = $$('.detail-actions button').map((node) => node.textContent.trim());
    for (const label of ['Grup ata', 'Konum geçmişi', 'Sil']) {
      assert.ok(labels.includes(label), `${label} düğmesi yok`);
    }
  });

  it('araç tablosunda onay bekleyen en üstte durur', async () => {
    $$('.nav-btn')[1].click();
    await tick();
    const rows = $$('tbody tr');
    assert.equal(rows.length, 6);
    assert.ok(rows[0].className.includes('row-pending'));
    assert.ok(rows[0].textContent.includes('40 PRS 606'));
  });

  it('özet kartları doğru sayar', () => {
    const stats = $$('.stat-card').map((node) => node.textContent);
    assert.ok(stats.some((s) => s.includes('6') && s.includes('Toplam')));
    assert.ok(stats.some((s) => s.includes('1') && s.includes('Bekleyen')));
    assert.ok(stats.some((s) => s.includes('3') && s.includes('Grup')));
  });

  it('arama kutusu tabloyu süzer', () => {
    const search = $('.page-tools input');
    setInput(search, 'ayşe');
    assert.equal($$('tbody tr').length, 1);
    setInput(search, 'bulunamaz-plaka');
    assert.ok(text().includes('Aramayla eşleşen kayıt yok.'));
    setInput(search, '');
    assert.equal($$('tbody tr').length, 6);
  });

  it('grup kartları alan gizleme durumunu gösterir', async () => {
    $$('.nav-btn')[2].click();
    await tick();
    const cards = $$('.group-card');
    assert.equal(cards.length, 3);
    const kaman = cards.find((card) => card.textContent.includes('Kaman'));
    assert.ok(kaman.textContent.includes('Gizli'), 'Kaman sürücü adı gizli olmalı');
  });

  it('grup ayarları penceresi açılıp kapanır', () => {
    const card = $$('.group-card').find((node) => node.textContent.includes('Merkez'));
    button('Grup ayarları', card).click();
    assert.ok(modal(), 'pencere açılmadı');
    assert.ok(modal().textContent.includes('Görünür gruplar'));
    assert.ok(modal().querySelectorAll('input[type=checkbox]').length >= 3);
    button('Vazgeç', modal()).click();
    assert.equal(modal(), null, 'pencere kapanmadı');
  });

  it('kullanıcı tablosu üç yetkiyi de gösterir', async () => {
    $$('.nav-btn')[3].click();
    await tick();
    assert.equal($$('tbody tr').length, 3);
    for (const label of ['Yönetici', 'İzleyici', 'Onay bekliyor']) {
      assert.ok(text().includes(label), `${label} rozeti yok`);
    }
  });

  it('yönetici kendi yetkisini bu ekrandan değiştiremez', () => {
    const selfRow = $$('tbody tr').find((row) => row.textContent.includes('Siz'));
    assert.ok(selfRow, 'kendi satırı işaretlenmemiş');
    assert.ok(selfRow.textContent.includes('Kendi yetkinizi bu ekrandan değiştiremezsiniz.'));
  });

  it('ayarlar arka uç ve oturum bilgisini gösterir', async () => {
    $$('.nav-btn')[4].click();
    await tick();
    assert.ok(text().includes('Demo (bellek içi sahte veri)'));
    assert.ok(text().includes('sim-yonetici'));
  });

  // ---------------------------------------------------------- İzleyici

  it('çıkış giriş ekranına döner', async () => {
    await signOut();
    assert.ok(text().includes('Panele giriş'));
  });

  it('izleyici yalnızca Harita ve Ayarlar sekmelerini görür', async () => {
    await signIn('izleyici@ornek.com', '123456');
    assert.deepEqual(
      $$('.nav-btn').map((node) => node.textContent.trim()),
      ['Harita', 'Ayarlar'],
    );
  });

  it('izleyici yalnızca kendi grubunun onaylı araçlarını görür', () => {
    assert.deepEqual(
      $$('.vehicle-plate').map((node) => node.textContent).sort(),
      ['40 ABC 001', '40 DEF 202', '40 GHI 303'],
    );
    assert.ok(!text().includes('40 PRS 606'), 'onay bekleyen araç sızmış');
    assert.ok(!text().includes('40 JKL 404'), 'Mucur aracı sızmış');
  });

  it('gizlenen alan "Gizli" olarak çıkar', () => {
    const row = $$('.vehicle-row').find((node) => node.textContent.includes('40 GHI 303'));
    assert.ok(row.textContent.includes('Gizli'), 'Kaman sürücü adı gizlenmemiş');
  });

  it('izleyiciye işlem düğmesi verilmez', () => {
    $$('.vehicle-row')[0].click();
    assert.ok($('.detail-card'));
    assert.equal($('.detail-actions'), null, 'izleyiciye işlem düğmesi verilmiş');
  });

  // ------------------------------------------------------ Onay bekleyen

  it('onay bekleyen hesap yalnızca bekleme ekranını görür', async () => {
    await signOut();
    await signIn('bekleyen@ornek.com', '123456');
    assert.ok(text().includes('Hesabınız onay bekliyor'));
    assert.equal($$('.nav-btn').length, 0, 'bekleyen hesaba sekme verilmiş');
    assert.ok(!text().includes('40 ABC 001'), 'bekleyen hesaba araç sızmış');
  });
});
