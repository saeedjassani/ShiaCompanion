import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import '../models/city.dart';
import 'timezone_database.dart';

/// How far [city]'s clock is from the phone's at [instant] (by default, now):
/// positive when the city is ahead. Null when its time zone is unknown.
///
/// Compared by offset, not by zone name: Najaf picked on a phone set to
/// Asia/Riyadh reads the same time, and that is all that matters here.
Duration? cityClockDifference(City city, [DateTime? instant]) {
  if (city.timeZone.isEmpty) return null;
  final zone = tryGetLocation(city.timeZone);
  if (zone == null) return null;
  return zoneClockDifference(zone, instant);
}

/// As [cityClockDifference], for a zone already looked up.
Duration zoneClockDifference(tz.Location zone, [DateTime? instant]) {
  final moment = instant ?? DateTime.now();
  return tz.TZDateTime.from(moment, zone).timeZoneOffset -
      _phoneOffsetAt(moment);
}

/// The phone's UTC offset at [instant]. Not `instant.toLocal()`: on a
/// [tz.TZDateTime] that means the timezone package's own idea of local, which
/// is UTC wherever nothing has set it (the web, for one).
Duration _phoneOffsetAt(DateTime instant) =>
    DateTime.fromMillisecondsSinceEpoch(instant.millisecondsSinceEpoch)
        .timeZoneOffset;

/// "2 hr ahead of your phone", "30 min behind your phone"; null when there is
/// no difference.
String? clockDifferenceLabel(Duration? difference, [AppLocalizations? l10n]) {
  final s = l10n ?? L10n.current;
  if (difference == null || difference == Duration.zero) return null;
  final minutes = difference.inMinutes.abs();
  final amount = [
    if (minutes >= 60) s.cityClockHours(minutes ~/ 60),
    if (minutes % 60 != 0) s.cityClockMinutes(minutes % 60),
  ].join(' ');
  return difference.isNegative
      ? s.cityClockBehind(amount)
      : s.cityClockAhead(amount);
}
