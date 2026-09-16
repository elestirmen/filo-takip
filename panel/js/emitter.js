// Son değeri saklayan küçük yayın kanalı. lib/data/latest_value.dart
// dosyasının karşılığıdır: yeni abone, beklemeden son değeri alır.

export class LatestValue {
  constructor(initial) {
    this._value = initial;
    this._listeners = new Set();
  }

  get value() {
    return this._value;
  }

  // Aboneyi ekler ve son değeri hemen verir. Dönen fonksiyon aboneliği bitirir.
  listen(listener) {
    this._listeners.add(listener);
    listener(this._value);
    return () => this._listeners.delete(listener);
  }

  add(value) {
    this._value = value;
    for (const listener of [...this._listeners]) listener(value);
  }
}

// Son değeri saklamayan kanal; tek seferlik olaylar (hata bildirimi) için.
// Yeni bir dinleyici eski hatayı tekrar almaz.
export class EventChannel {
  constructor() {
    this._listeners = new Set();
  }

  listen(listener) {
    this._listeners.add(listener);
    return () => this._listeners.delete(listener);
  }

  add(value) {
    for (const listener of [...this._listeners]) listener(value);
  }
}
