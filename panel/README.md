# Filo Takip — Yönetim Paneli

`filo-takip.perinet.org` adresinde yayınlanan web paneli. Android
uygulamasıyla **aynı Realtime Database'i** okur; araç kaydı ve konum
gönderimi yalnızca uygulamadan yapılır, panel yönetim ve izleme içindir.

Derleme adımı, paket yöneticisi ve bağımlılık yoktur: tarayıcının kendi ES
modülleri kullanılır. Bir dosyayı düzenleyip sayfayı yenilemek yeter.

## Yetkiye göre görünüm

Panelin tek kuralı: **görünümü rol belirler.** Rol, oturum açan hesabın
veritabanındaki iki düğümünden okunur; tarayıcıda saklanan bir bayrak yoktur.

| Rol | Nereden okunur | Ne görür |
| --- | --- | --- |
| **Yönetici** | `admins/{uid}` düğümü varsa | Harita, Araçlar, Gruplar, Kullanıcılar, Ayarlar. Tüm araçlar, tüm alanlar, tüm ayarlar. |
| **İzleyici** | `webUsers/{uid}.approved` doğruysa | Harita ve Ayarlar. Yalnızca atandığı grubun ve o grubun görebildiği grupların onaylı araçları; gizlenen alanlar "Gizli" görünür. |
| **Onay bekliyor** | ikisi de yoksa | Yalnızca bekleme ekranı. Hiçbir araç görünmez. |

Kayıt akışı, uygulamadaki araç kaydının aynısıdır: giriş ekranındaki
"Kayıt olun" bağlantısıyla açılan hesap **onaysız doğar**, yönetici
Kullanıcılar sekmesinden onaylayıp bir gruba atayana kadar hiçbir şey
göremez. Yönetici onayladığı anda açık duran bekleme ekranı kendiliğinden
izleyici görünümüne döner; sayfayı yenilemek gerekmez.

Hangi izleyicinin hangi aracı göreceğini `js/visibility-rules.js` belirler.
Uygulamadaki `lib/core/visibility_rules.dart` ile aynı mantıktır: kendi grubu
+ grubun `visibleGroups` listesi, yalnızca onaylı araçlar. Alan gizleme
(`showSpeed`, `showDriverName`) **bakılan aracın** grubuna göre uygulanır.

> Bu kurallar bir **arayüz** filtresidir, güvenlik sınırı değildir. Asıl sınır
> [database.rules.json](../database.rules.json) dosyasıdır; aşağıdaki
> "Güvenlik notu" bölümüne bakın.

## Harita

Sağ üstteki seçiciden iki katman arasında geçilir; seçim tarayıcıda hatırlanır.

| Katman | Kaynak | Not |
| --- | --- | --- |
| Sokak | OpenStreetMap | Uygulamadaki harita ile aynı karolar |
| Uydu | Esri World Imagery | Üstüne yer adı etiketleri bindirilir, yoksa okunmaz |

İkisi de anahtarsız ve ücretsizdir ama **atıf göstermek koşuluyla**; katman
tanımlarındaki `attribution` alanları boş bırakılmamalıdır
(`js/config.js` -> `mapLayers`).

Araçlar durum renginde damla biçimli iğnelerle, içlerinde araç silueti ve
yanlarında plaka etiketiyle gösterilir. Seçili araç büyür ve öne alınır.

## Filo takip özellikleri

| Özellik | Nerede | Not |
| --- | --- | --- |
| Canlı harita | Harita | Sokak/uydu katmanı, durum renkli araç iğneleri, grup filtresi |
| Geçmiş rota oynatma | Harita → bir araç → Konum geçmişi | Rota çizilir, zaman çubuğuyla oynatılır, duraklar işaretlenir |
| Yol/durak raporu | Oynatma paneli ve Raporlar | Katedilen yol, hareket/duruş süresi, durak sayısı, ortalama hız |
| Filo raporu + CSV | Raporlar | Tüm araçlar tek tabloda; Excel için noktalı virgüllü CSV |
| Hız aşımı uyarısı | Gruplar → hız sınırı | Sınırı aşan araç uyarı üretir; 0 ise sınır yok |
| Çevrimdışı uyarısı | kendiliğinden | Araç 5 dakika güncellenmezse bir kez uyarır |
| Bölge (geofence) uyarısı | Harita → Bölgeler | Daire biçimli bölgeye giriş/çıkışta uyarı |

### Uyarıların sınırı

Uyarılar **yalnızca panel açıkken** üretilir. Sunucu tarafında bir izleyici
yoktur; sekme kapalıyken olan bir hız aşımı fark edilmez. Bunun için bir
Cloud Function ya da benzeri bir sunucu bileşeni gerekir.

Uyarı **geçiş anında** bir kez üretilir, durum sürdüğü sürece değil: sınırı
aşan araç aştığı anda uyarır, altına inip tekrar aşarsa yeniden uyarır. Aksi
hâlde panel saniyede bir aynı uyarıyı yağdırırdı.

Liste kalıcı değildir, sayfa yenilenince sıfırlanır. Tarayıcı bildirimleri
isteğe bağlıdır ve izin yalnızca kullanıcı açtığında istenir.

### Rapor hesabının eşikleri

Gerçek GPS verisi gürültülüdür; `js/trip-report.js` üç eşikle ayıklar:

* 8 metrenin altındaki adımlar titreme sayılır, yola eklenmez,
* 250 km/s üstü adımlar veri hatası sayılır, elenir,
* 3 dakikadan uzun duruşlar durak olur.

Bir aralığın hareket mi duruş mu olduğuna **katedilen mesafe** karar verir,
anlık hız alanı değil. Uç noktaların hızına bakmak, hareketten duruşa geçen
aralıkta molayı hareket süresine yazıp ortalama hızı bozuyordu.

## Demo kipi

`js/config.js` içindeki Firebase yapılandırması boş olduğu sürece panel demo
kipinde açılır: uygulamadaki sahte filonun aynısı (6 araç, 3 grup, 5 saniyede
bir hareket) bellekte üretilir, hiçbir dış isteğe çıkılmaz ve hiçbir veri
yazılmaz. Sayfa yenilenince her şey başlangıç durumuna döner.

Sağ üstteki turuncu **DEMO** rozeti hangi kipte olduğunu her zaman gösterir.

Demo hesapları — üç rolü de denemek için:

| Hesap | Şifre | Rol |
| --- | --- | --- |
| `yonetici@ornek.com` | `123456` | Yönetici |
| `izleyici@ornek.com` | `123456` | İzleyici (Merkez grubu) |
| `bekleyen@ornek.com` | `123456` | Onay bekliyor |

İzleyici hesabıyla girildiğinde Merkez ve Kaman araçları görünür, Mucur ve
grupsuz araçlar görünmez; Kaman araçlarının sürücü adı "Gizli" yazar. Aynı
filoya yönetici hesabıyla bakınca hepsi görünür.

Açık oturum sayfa yenilendiğinde kaybolmaz: demo kipinde açık hesabın uid'i
`localStorage`'da tutulur (şifre değil), gerçek kipte bunu Firebase Auth
kendisi yapar. Filo verisi ise her yenilemede sıfırlanır — o bellekte durur.

## Gerçek Firebase'e geçiş

1. [KURULUM.md](../KURULUM.md) adımlarını bitirin (proje, Realtime Database,
   sağlayıcılar, ilk yönetici).
2. Firebase Console → **Proje ayarları** → **Uygulamalarınız** → **Web
   uygulaması ekle** (`</>` simgesi). SHA-1 ya da barındırma gerekmez.
3. Çıkan `firebaseConfig` değerlerini `js/config.js` dosyasına yapıştırın.
   Beş alanın beşi de dolu olmalı; biri eksikse panel demo kipinde kalır.
4. **Authentication → Settings → Authorized domains** listesine
   `filo-takip.perinet.org` ekleyin, yoksa giriş `auth/unauthorized-domain`
   hatası verir.
5. Güncellenmiş [database.rules.json](../database.rules.json) dosyasını
   Realtime Database → Kurallar ekranına yapıştırıp **Yayınla** deyin.
   Paneli eklerken kurallara iki değişiklik girdi:
   - **`webUsers`** düğümü: kullanıcı yalnızca kendi `email`, `displayName`
     ve `createdAt` alanlarını yazabilir; `approved` ve `groupId` alanlarına
     yalnızca yönetici dokunur. Bu, araç düğümündeki desenin aynısıdır.
   - **`admins`** düğümü artık yöneticilere yazılabilir (eskiden tamamen
     kapalıydı), böylece yetki Console'a girmeden verilip alınabiliyor. Kural
     bir yöneticinin **kendi** düğümünü silmesini engeller; yine de son
     yöneticiyi başka bir yönetici düşürebilir. Kurtarma yolu her zaman
     Firebase Console'dur.

`apiKey` gizli bir değer değildir; Firebase web yapılandırması istemciye
açıktır, erişimi kurallar belirler.

## Yayınlama

Sunucudaki desen: her site `nginx:alpine` ile `npm-net` ağında durur, dışarıya
port açmaz; 80/443'ü Nginx Proxy Manager karşılar.

```bash
docker compose -f /opt/filo-takip/panel/deploy/docker-compose.yml up -d
```

Sonra iki adım elle yapılır:

1. **DNS**: Cloudflare'de `perinet.org` bölgesine `filo-takip` adında bir
   kayıt ekleyin (diğer alt alanlarla aynı hedef).
2. **Nginx Proxy Manager** (`:81`) → Proxy Hosts → Add:
   - Domain: `filo-takip.perinet.org`
   - Forward: `filo-takip-web`, port `80`
   - Websockets kapalı, **Block Common Exploits** açık
   - SSL sekmesi: Let's Encrypt sertifikası, **Force SSL** açık

Panel dosyaları konteynere salt-okunur bağlanır; `js/` ya da `css/` altını
düzenleyip tarayıcıyı yenilemek yeter.

`deploy/nginx.conf` değişirse konteyneri **yeniden oluşturmak** gerekir —
yeniden başlatmak ya da `nginx -s reload` yetmez. Bu dosya tek dosya olarak
bind-mount edildiği için bağlama inode'a bağlıdır; düzenleyici dosyayı
değiştirmek yerine yenisiyle değiştirdiğinde konteyner eski içeriği görmeye
devam eder:

```bash
docker compose -f /opt/filo-takip/panel/deploy/docker-compose.yml up -d --force-recreate
```

## Testler

Node'un kendi test koşucusu kullanılır; tarayıcı ya da Firebase gerekmez:

```bash
cd /opt/filo-takip/panel && node --test
```

İki dosya var:

* **`test/rules.test.js`** — saf mantık: görünürlük kuralları, durum eşikleri,
  sıralama, grup adı doğrulama ve demo arka ucun yazma yolları. Hiçbir
  bağımlılığı yoktur, her zaman çalışır.
* **`test/views.test.js`** — görünüm katmanı: panel gerçek bir DOM'da kurulur,
  üç rolle giriş yapılır ve her rolün gördüğü ekran doğrulanır (izleyiciye
  yönetim sekmesi sızıyor mu, gizlenen alan "Gizli" çıkıyor mu, onay bekleyen
  hesap araç görüyor mu). Tek isteğe bağlı bağımlılık olan `jsdom` kurulu
  değilse **atlanır**:

  ```bash
  cd /opt/filo-takip/panel && npm install --no-save jsdom && node --test
  ```

  Leaflet jsdom'da çalışmadığı için harita sahte bir katmanla değiştirilir;
  haritanın kendisi tarayıcıda denenir.

## Güvenlik notu

`database.rules.json` dosyasında `vehicles` düğümü **giriş yapmış herkese**
okutulur. Bu panelden önce de böyleydi (anonim giriş açık olduğu için
uygulamayı kuran herkes aynı veriyi okuyabiliyordu), ama panelde artık açık
bir kayıt ekranı da var: e-posta/şifre sağlayıcısı herkese kayıt izni verir.
Kayıt olan kişi panelde hiçbir araç göremez, ancak veritabanı API'sini
doğrudan çağırarak araç listesini okuyabilir.

Bunu kapatmak isterseniz `vehicles` düğümünün okuma kuralını şununla
değiştirin:

```json
".read": "auth != null && (root.child('vehicles').child(auth.uid).exists() || root.child('admins').child(auth.uid).exists() || root.child('webUsers').child(auth.uid).child('approved').val() == true)"
```

Böylece yalnızca kayıtlı sürücüler, yöneticiler ve onaylı izleyiciler filoyu
okuyabilir. **Önce uygulamada deneyin:** kaydı olmayan yeni bir sürücü
cihazında harita ekranı artık boş liste yerine "Araç listesi alınamadı"
hatası gösterir; bu davranış kabul edilebilirse kural sıkılaştırılabilir.

## Dosya düzeni

```
panel/
  index.html         sayfa kabuğu; Leaflet ve app.js buradan yüklenir
  css/panel.css      tek stil dosyası, açık ve koyu tema
  vendor/            Leaflet 1.9.4 (yerel kopya, CDN'e bağımlılık yok)
  js/
    config.js        arka uç seçimi + Firebase yapılandırması  <-- düzenlenir
    strings.js       tüm Türkçe metinler
    db-parse.js      RTDB ham değerlerini güvenli okuma
    normalize.js     grup adı ve ad normalizasyonu, Türkçe büyük harf
    time-format.js   göreli zaman, tarih, hız biçimleri
    models.js        Vehicle, GroupConfig, LocationSample, WebUser, Viewer
    vehicle-status.js   durum eşikleri ve renkleri
    visibility-rules.js kim hangi aracı görür
    admin-rules.js      sıralama, sayım, ad doğrulama, arama
    emitter.js       son değeri saklayan küçük yayın kanalı
    backend.js       arka uç seçimi (demo / firebase)
    backend-demo.js  bellek içi sahte filo
    backend-firebase.js  Firebase Auth + Realtime Database
    ui.js            DOM yardımcıları, bildirim, kip pencere
    map-view.js      Leaflet sarmalayıcı
    view-*.js        ekranlar
    app.js           açılış ve rol yönlendirmesi
  test/              rules.test.js (bağımlılıksız) + views.test.js (jsdom, isteğe bağlı)
  deploy/            docker-compose.yml + nginx.conf
```

`js/` altındaki dosyaların çoğu `lib/` altındaki Dart dosyalarının
karşılığıdır ve aynı adı taşır; biri değişince diğerine de bakın.
