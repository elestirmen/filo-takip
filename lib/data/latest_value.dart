import 'dart:async';

/// Son değeri saklayan yayın (broadcast) akışı.
///
/// Neden gerekli: `StreamBuilder` sekme değiştiğinde ya da ekran yeniden
/// kurulduğunda yeniden abone olur. Düz bir broadcast akışında yeni abone
/// bir sonraki olaya kadar veri göremez ve ekran boş görünür. Burada yeni
/// aboneye önce elde tutulan son değer verilir.
///
/// [LatestValue.pending] ile kurulursa ilk gerçek veri gelene kadar hiçbir
/// şey yayılmaz; böylece `StreamBuilder` "yükleniyor" durumunda kalır ve
/// ekranlar "hiç araç yok" ile "henüz gelmedi" durumlarını karıştırmaz.
///
/// Hatalar bilerek bu akışa konulmaz; hata akışı ayrıdır ve tek seferliktir
/// (bkz. `FleetRepository.errors`). Böylece eski bir hata her yeni aboneye
/// tekrar tekrar gösterilmez.
class LatestValue<T> {
  /// Başlangıç değeri hazır olan akış: yeni aboneler hemen veri alır.
  LatestValue(this._latest) : _hasValue = true;

  /// İlk gerçek veri gelene kadar yayın yapmayan akış.
  /// [fallback] yalnızca [latest] için kullanılır, akışa konmaz.
  LatestValue.pending(T fallback) : _latest = fallback, _hasValue = false;

  final StreamController<T> _controller = StreamController<T>.broadcast();
  T _latest;
  bool _hasValue;

  /// Son değer; henüz veri gelmediyse başlangıç/yedek değer.
  T get latest => _latest;

  /// En az bir gerçek veri geldi mi.
  bool get hasValue => _hasValue;

  void add(T value) {
    _latest = value;
    _hasValue = true;
    if (!_controller.isClosed) _controller.add(value);
  }

  Stream<T> get stream {
    return Stream<T>.multi((MultiStreamController<T> controller) {
      if (_hasValue) controller.add(_latest);
      final StreamSubscription<T> subscription = _controller.stream.listen(
        controller.add,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  Future<void> close() => _controller.close();
}
