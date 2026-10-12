import 'package:hijri/hijri_calendar.dart';

import 'moon_sighting.dart';

/// Month starts that replace the Umm al-Qura table's, keyed as
/// [HijriCalendar.setAdjustments] wants them; empty for Umm al-Qura as
/// published.
Map<int, int> _monthStarts = const {};

/// The month starts [useHijriMonthStarts] last set; empty for Umm al-Qura
/// as published.
Map<int, int> get hijriMonthStartsInEffect => _monthStarts;

/// Makes [starts] (see [predictedHijriMonthStarts]) the months every Hijri
/// date in the app is counted in; empty for Umm al-Qura as published.
void useHijriMonthStarts(Map<int, int> starts) => _monthStarts = starts;

/// The Hijri date of the civil day [date] (only its year, month and day
/// count), in the month starts in effect, moved [offsetDays] days for a
/// manual moon-sighting correction.
///
/// Every Hijri date the app shows or matches against goes through here (or
/// through [LunarDay], which does), so all of them agree on which day it is.
/// The weekday of the result is that of the shifted day; read weekdays off
/// the civil date instead (see [LunarDay]).
HijriCalendar hijriForCivilDate(DateTime date, {int offsetDays = 0}) {
  // Calendar arithmetic, not Duration: a day the clocks go back on is 25
  // hours long, so midnight plus 24 hours is still that day.
  final shifted = DateTime.utc(date.year, date.month, date.day + offsetDays);
  final hijri = HijriCalendar();
  if (_monthStarts.isNotEmpty) hijri.setAdjustments(_monthStarts);
  hijri.gregorianToHijri(shifted.year, shifted.month, shifted.day);
  return hijri;
}

/// Caches [predictedHijriMonthStarts] for one place, so moving about a town
/// doesn't redo the sums.
class HijriMonthStartsCache {
  ({double latitude, double longitude, int month})? _key;
  Map<int, int> _starts = const {};

  /// The month starts predicted for ([latitude], [longitude]) around [now],
  /// worked out again only for a place a tenth of a degree (about 10 km)
  /// away or in a new month.
  Map<int, int> forPlace({
    required double latitude,
    required double longitude,
    required DateTime now,
  }) {
    final key = (
      latitude: (latitude * 10).roundToDouble() / 10,
      longitude: (longitude * 10).roundToDouble() / 10,
      month: now.year * 12 + now.month,
    );
    if (key != _key) {
      _starts = predictedHijriMonthStarts(
        latitude: key.latitude,
        longitude: key.longitude,
        around: now,
      );
      _key = key;
    }
    return _starts;
  }
}
