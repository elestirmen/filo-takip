/// Zaman biçimlendirme. Saf fonksiyonlar; "şu an" değeri her zaman dışarıdan
/// verilir ki cihaz saati ile sunucu zamanı karışmasın.
library;

import 'package:intl/intl.dart';

import 'strings.dart';

final DateFormat _fullFormat = DateFormat('dd.MM.yyyy HH:mm:ss');

/// `dd.MM.yyyy HH:mm:ss`. Konum geçmişi listesinde kullanılır.
String formatTimestamp(int millis) {
  if (millis <= 0) return Strings.timeNever;
  return _fullFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));
}

/// "Az önce", "3 dakika önce", "2 saat önce", "4 gün önce".
///
/// [nowMs] `FleetRepository.nowMs()` değeridir.
String relativeTime(int millis, {required int nowMs}) {
  if (millis <= 0) return Strings.timeNever;

  final int diff = nowMs - millis;
  // Sunucu zamanı cihazınkinden birkaç saniye ileri olabilir.
  if (diff < 0) return Strings.timeJustNow;

  final int seconds = diff ~/ 1000;
  if (seconds < 60) return Strings.timeJustNow;

  final int minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes ${Strings.timeMinutesAgo}';

  final int hours = minutes ~/ 60;
  if (hours < 24) return '$hours ${Strings.timeHoursAgo}';

  final int days = hours ~/ 24;
  return '$days ${Strings.timeDaysAgo}';
}

/// "52 km/s" — ondalık gösterilmez, hız zaten yaklaşık bir değerdir.
String formatSpeed(double speedKmh) {
  final int rounded = speedKmh.isFinite ? speedKmh.round() : 0;
  return '$rounded ${Strings.unitSpeed}';
}
