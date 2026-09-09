import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/widgets/turkish_upper_case_formatter.dart';

TextEditingValue _value(String text) {
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

void main() {
  const TurkishUpperCaseFormatter formatter = TurkishUpperCaseFormatter();

  test('yazılan metni Türkçe kurallarıyla büyütür', () {
    final TextEditingValue result = formatter.formatEditUpdate(
      _value('40 ab'),
      _value('40 abi'),
    );
    expect(result.text, '40 ABİ');
  });

  test('ı harfini I yapar', () {
    expect(formatter.formatEditUpdate(_value(''), _value('ısı')).text, 'ISI');
  });

  test('imleç konumunu korur', () {
    const TextEditingValue input = TextEditingValue(
      text: '40 abc',
      selection: TextSelection.collapsed(offset: 3),
    );
    final TextEditingValue result = formatter.formatEditUpdate(
      _value('40 ab'),
      input,
    );
    expect(result.text, '40 ABC');
    expect(result.selection.baseOffset, 3);
  });

  test('zaten büyük metni değiştirmez', () {
    expect(
      formatter.formatEditUpdate(_value(''), _value('40 ABC 123')).text,
      '40 ABC 123',
    );
  });
}
