import 'package:flutter/services.dart';

import '../core/normalize.dart';

/// Yazılan metni anında Türkçe kurallarına göre büyük harfe çevirir.
///
/// `TextCapitalization.characters` yalnızca klavyeye ipucu verir ve Dart'ın
/// locale tanımayan `toUpperCase()` metodunu kullanır; bu da `i` harfini `I`
/// yapardı. Plaka alanında doğrusu `İ` olmalı.
class TurkishUpperCaseFormatter extends TextInputFormatter {
  const TurkishUpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = turkishUpperCase(newValue.text);
    // Uzunluk değişirse imleç konumu kayar; böyle bir durumda dokunma.
    if (upper.length != newValue.text.length) return newValue;
    return TextEditingValue(
      text: upper,
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}
