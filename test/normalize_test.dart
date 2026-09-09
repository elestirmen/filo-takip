import 'package:flutter_test/flutter_test.dart';
import 'package:harita_takip/core/normalize.dart';

void main() {
  group('turkishUpperCase', () {
    test('i harfini İ yapar (Dart varsayılanı I yapardı)', () {
      expect(turkishUpperCase('istanbul'), 'İSTANBUL');
    });

    test('ı harfini I yapar', () {
      expect(turkishUpperCase('ısparta'), 'ISPARTA');
    });

    test('diğer Türkçe harfleri doğru çevirir', () {
      expect(turkishUpperCase('çğöşü'), 'ÇĞÖŞÜ');
    });

    test('zaten büyük harfleri bozmaz', () {
      expect(turkishUpperCase('40 ABC 123'), '40 ABC 123');
    });

    test('boş metni boş bırakır', () {
      expect(turkishUpperCase(''), '');
    });
  });

  group('normalizePlate', () {
    test('büyük harfe çevirir ve fazla boşlukları teke indirir', () {
      expect(normalizePlate('  40 abc  123 '), '40 ABC 123');
    });

    test('sekme ve satır sonlarını da boşluk sayar', () {
      expect(normalizePlate('40\tabc\n123'), '40 ABC 123');
    });

    test('boşluksuz plakayı olduğu gibi büyütür', () {
      expect(normalizePlate('40abc123'), '40ABC123');
    });

    test('aynı plakanın farklı yazımları aynı sonuca gelir', () {
      expect(normalizePlate(' 06 dp 1234 '), normalizePlate('06  DP  1234'));
    });
  });

  group('normalizeDriverName', () {
    test('baş ve sondaki boşlukları atar', () {
      expect(normalizeDriverName('  Ahmet Yıldız  '), 'Ahmet Yıldız');
    });

    test('aradaki tekrarlı boşlukları teke indirir', () {
      expect(normalizeDriverName('Ahmet    Yıldız'), 'Ahmet Yıldız');
    });

    test('büyük/küçük harfe dokunmaz', () {
      expect(normalizeDriverName('ahmet YILDIZ'), 'ahmet YILDIZ');
    });
  });

  group('normalizeGroupName', () {
    test('veritabanı anahtarında yasak karakterleri atar', () {
      expect(normalizeGroupName(r'Merkez.$#[]/'), 'Merkez');
    });

    test('boşlukları düzenler', () {
      expect(normalizeGroupName('  Kaman   Şubesi '), 'Kaman Şubesi');
    });

    test('yalnızca yasak karakterden oluşan ad boşa düşer', () {
      expect(normalizeGroupName('///'), '');
    });

    test('Türkçe harfleri korur', () {
      expect(normalizeGroupName('Çiçekdağı'), 'Çiçekdağı');
    });
  });

  group('parseGroupList', () {
    test('virgülle ayırır ve boşlukları temizler', () {
      expect(parseGroupList('Merkez, Kaman ,Mucur'), <String>[
        'Merkez',
        'Kaman',
        'Mucur',
      ]);
    });

    test('boş parçaları atar', () {
      expect(parseGroupList('Merkez,, ,Kaman'), <String>['Merkez', 'Kaman']);
    });

    test('yinelenenleri tekilleştirir, sırayı korur', () {
      expect(parseGroupList('Kaman, Merkez, Kaman'), <String>[
        'Kaman',
        'Merkez',
      ]);
    });

    test('tamamen boş metin boş liste verir', () {
      expect(parseGroupList('   '), <String>[]);
    });

    test('yasak karakterli adları temizleyerek alır', () {
      expect(parseGroupList('Mer/kez, Ka.man'), <String>['Merkez', 'Kaman']);
    });
  });

  group('formatGroupList / parseGroupList gidiş dönüşü', () {
    test('biçimlendirilen metin aynı listeye çözülür', () {
      const List<String> groups = <String>['Merkez', 'Kaman', 'Mucur'];
      expect(parseGroupList(formatGroupList(groups)), groups);
    });

    test('boş liste boş metne dönüşür', () {
      expect(formatGroupList(const <String>[]), '');
    });
  });
}
