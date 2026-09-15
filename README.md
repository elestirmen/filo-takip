# Filo Takip

Şirket araçlarındaki telefonların konumunu Firebase Realtime Database'e yazan
ve haritada canlı gösteren Flutter uygulaması.

- **Sürücü**: anonim Firebase oturumu açar. Aracın kimliği doğrudan `auth.uid`
  değeridir; ayrı bir cihaz kimliği yoktur.
- **Yönetici**: e-posta + şifre ile giriş yapar. Yetki, veritabanındaki
  `admins/{uid}` düğümünün varlığından okunur.

## İki çalışma kipi

Uygulama iki arka uçtan biriyle çalışır; seçim derleme sırasında yapılır.

| Kip | Komut | Ne yapar |
| --- | --- | --- |
| **Simülasyon** (varsayılan) | `flutter run` | Bellek içi sahte veri. Firebase projesi, `google-services.json` ve internet gerekmez. |
| **Gerçek** | `flutter run --dart-define=BACKEND=firebase` | Firebase Auth + Realtime Database. |

Simülasyon kipinde ekranın sağ üst köşesinde turuncu **DEMO** şeridi ve
Ayarlar sekmesinde bir uyarı kartı görünür; hangi kipte olduğun her zaman
bellidir. Veriler yalnızca bellektedir, uygulama kapanınca sıfırlanır.

Simülasyon yöneticisi girişi: `yonetici@ornek.com` / `123456`
(yalnızca simülasyonda geçerlidir, gerçek arka uçta karşılığı yoktur).

Sahte filo, haritanın varsayılan merkezi çevresinde 6 araç içerir: hareket eden, duran, çevrimdışı,
onay bekleyen ve grupsuz örnekler ile üç grup (Merkez, Kaman, Mucur). Araçlar
5 saniyede bir hareket eder.

## Kurulum

```bash
flutter pub get
flutter run
```

Gerçek Firebase'e geçmek için yapılması gerekenler: [KURULUM.md](KURULUM.md).
`android/app/google-services.json` dosyası depoda yoktur; onu Firebase
Console'dan sen indirirsin. Dosya yoksa Gradle eklentisi uygulanmaz ve proje
yine derlenir — sadece gerçek kip çalışmaz.

## Konum takibi

Kalıcı bildirimli bir ön plan servisi (`flutter_foreground_task`) araç
konumunu 5 saniyede bir yazar. Servis **ayrı bir isolate'te** çalışır ve
uygulamanın belleğine erişemez:

* Gerçek kipte kendi Firebase bağlantısını kurup doğrudan veritabanına yazar.
* Simülasyon kipinde sahte veri ana isolate'te durduğu için konumu ona
  gönderir; bu yüzden simülasyonda takip yalnızca uygulama açıkken işlenir.

İzin akışı kademelidir: önce ön plan konumu, sonra ayrı bir açıklamayla arka
plan konumu. Reddedilirse harita çalışmaya devam eder, yalnızca konum
gönderimi kapalı kalır. Servis yalnızca kayıtlı bir araç varken çalışır;
araç kaydı silinirse kendiliğinden durur.

Servis isolate'inde Activity olmadığı için konum, Play Services'in fused
sağlayıcısı yerine doğrudan Android `LocationManager` üzerinden okunur
(gerekçe [location_task_handler.dart](lib/services/location_task_handler.dart)
içinde yazılı).

## Web paneli

`filo-takip.perinet.org` adresinde yayınlanan yönetim paneli
[panel/](panel/) klasöründedir. Aynı Realtime Database'i okur; araç kaydı ve
konum gönderimi yalnızca uygulamadan yapılır.

Görünümü rol belirler ve rol veritabanından okunur:

| Rol | Nereden okunur | Ne görür |
| --- | --- | --- |
| Yönetici | `admins/{uid}` var | Harita, Araçlar, Gruplar, Kullanıcılar, Ayarlar |
| İzleyici | `webUsers/{uid}.approved` doğru | Yalnızca kendi grubunun araçları, salt-okunur |
| Onay bekliyor | ikisi de yok | Yalnızca bekleme ekranı |

Panel de uygulama gibi iki kiple çalışır: `panel/js/config.js` boşken demo
verisi, Firebase yapılandırması girilince gerçek veritabanı. Derleme adımı
yoktur, tarayıcının ES modülleri kullanılır.

```bash
docker compose -f /opt/filo-takip/panel/deploy/docker-compose.yml up -d
cd panel && node --test        # saf mantık testleri
```

Ayrıntılar, demo hesapları ve yayınlama adımları: [panel/README.md](panel/README.md).

## Güvenlik kuralları

[database.rules.json](database.rules.json) dosyası Realtime Database kurallarını
içerir. Firebase Console -> Realtime Database -> Kurallar ekranına yapıştırılıp
yayınlanır.

## Proje düzeni

```
lib/
  main.dart          açılış, arka uç seçimi, anonim oturum (AuthGate)
  core/              strings.dart (tüm Türkçe metinler), tema, ayarlar,
                     saf yardımcılar (normalize.dart, db_parse.dart)
  models/            düz Dart modelleri, elle yazılmış fromMap/toMap
  data/              arka uç: FleetRepository + SessionService arayüzleri,
                     firebase_* gerçek, fake_* simülasyon uygulamaları
  services/          arka plan konum servisi
  screens/           harita, kayıt, yönetim, ayarlar
  widgets/           paylaşılan küçük widget'lar
test/                saf mantık birim testleri (Firebase gerektirmez)
panel/               web yönetim paneli (statik, derlemesiz) — panel/README.md
```

Kod üretimi (`build_runner`, `freezed`, `json_serializable`) **kullanılmaz**.
