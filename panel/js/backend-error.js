// Arka uç hataları tek tip olarak taşınır ki görünüm katmanı Firebase'in
// hata kodlarını bilmek zorunda kalmasın.
//
// lib/data/backend_exception.dart dosyasının karşılığı: mesaj her zaman
// kullanıcıya gösterilebilecek Türkçe bir metindir.

export class BackendError extends Error {
  constructor(message, cause) {
    super(message);
    this.name = 'BackendError';
    this.cause = cause;
  }
}
