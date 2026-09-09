# Firebase kurulum kontrol listesi

> **Acele etmene gerek yok.** Uygulama varsayılan olarak simülasyon kipinde
> çalışıyor ve Firebase olmadan da derlenip açılıyor (bkz. README). Bu liste
> gerçek arka uca geçmek istediğinde işine yarayacak.

Bu adımları **senin** yapman gerekiyor; uygulama tarafındaki kod hazır.
Sıralama önemli — özellikle 2. adım 3. adımdan önce yapılmalı.

Uygulamanın Android paket adı: **`com.filo.harita_takip`**
Bu ad `google-services.json` içine gömülür; 3. adımdan sonra değiştirmek
dosyayı yeniden indirmeyi gerektirir.

---

## 1. Firebase projesini oluştur

- <https://console.firebase.google.com> → **Proje ekle**
- Proje adı: örn. `filo-takip`
- Google Analytics: **kapalı** (bu uygulama kullanmıyor)

## 2. Realtime Database'i aç — Android uygulamasını eklemeden ÖNCE

- Sol menü **Build → Realtime Database** → **Veritabanı oluştur**
- Konum: **europe-west1 (Belçika)** — Türkiye'ye en düşük gecikmeli seçenek
- Başlangıç modu: **Kilitli modda başlat**
  (kuralları Aşama 1'de `database.rules.json` ile yayınlayacağız)

> Neden önce? `google-services.json` dosyasındaki `firebase_url` alanı ancak
> veritabanı zaten varsa dolar. Sonra açarsan dosyayı tekrar indirmen gerekir,
> yoksa uygulama açılışta "database URL not specified" hatası verir.

## 3. Android uygulamasını projeye ekle

- Proje genel bakış → **Android simgesi**
- **Android paket adı:** `com.filo.harita_takip`
- Uygulama takma adı: serbest. **SHA-1 gerekmiyor** (anonim ve e-posta/şifre
  girişi için zorunlu değil).
- **`google-services.json` dosyasını indir** ve şuraya koy:

      android/app/google-services.json

- Konsoldaki kalan adımları (Gradle satırları) **atla** — proje içinde zaten
  yapılandırıldı.

## 4. Giriş sağlayıcılarını etkinleştir

- **Authentication → Başlayın**
- **Sign-in method** sekmesi:
  - **Anonim** → Etkinleştir  ← sürücüler bunu kullanır
  - **E-posta/Şifre** → Etkinleştir ← yönetici bunu kullanır
    (alttaki "E-posta bağlantısı" seçeneği kapalı kalsın)

## 5. Yönetici hesabını elle oluştur

- **Authentication → Users → Kullanıcı ekle**
- E-posta ve şifre gir (bu bilgiler uygulamada **hiçbir yerde gömülü değil**)
- Oluşan satırdaki **UID** değerini kopyala

## 6. `admins` düğümünü yaz

- **Realtime Database → Veriler**
- Kökün yanındaki **+** → alt düğüm adı: `admins`
- Onun altına: ad = 5. adımdaki **UID**, değer = `true`

Sonuç şöyle görünmeli:

```json
{
  "admins": {
    "SENIN_YONETICI_UID_DEGERIN": true
  }
}
```

> Yönetici yetkisi yalnızca bu düğümden okunur. Uygulamada gömülü şifre veya
> hash yok, cihazda saklanan bir "yönetici" bayrağı da yok.

## 7. Güvenlik kurallarını yayınla

Projedeki [database.rules.json](database.rules.json) dosyasının içeriğini
**Realtime Database → Kurallar** ekranına yapıştır ve **Yayınla** de.

## 8. Doğrula

```bash
flutter run --dart-define=BACKEND=firebase
```

Beklenen: uygulama açılır, kısa bir "Oturum açılıyor…" ekranından sonra dört
sekmeli arayüz gelir. Sağ üstteki turuncu **DEMO** şeridi **kaybolmuş**
olmalı. **Ayarlar** sekmesinde "Anonim oturum (sürücü)" yazmalı ve bir uid
görünmeli. Aynı uid, Firebase Console → Authentication → Users listesinde de
belirmelidir.

---

## Sorun giderme

| Belirti | Sebep |
| --- | --- |
| Gradle: `File google-services.json is missing` | 3. adım yapılmadı ya da dosya yanlış klasörde |
| Açılışta "Firebase bağlantısı kurulamadı" | `google-services.json` içindeki paket adı uygulamanınkiyle uyuşmuyor |
| Açılışta "Oturum açılamadı" | 4. adımda anonim sağlayıcı etkinleştirilmedi |
| Çalışırken "database URL not specified" | RTDB, `google-services.json` indirildikten sonra oluşturulmuş — dosyayı yeniden indir |
