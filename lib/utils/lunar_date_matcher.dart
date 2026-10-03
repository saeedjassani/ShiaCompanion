import 'package:hijri/hijri_calendar.dart';

/// A real-world (civil) day together with the Hijri date in effect on it.
///
/// The Hijri date includes the user's moon-sighting correction (the
/// `adjust_hijri_date` setting), which shifts *which lunar date* a day is -
/// but never *which weekday* it is. So a recurring weekday pattern ("*-*-5",
/// Friday) is always read off [civilDate], never off [hijri]: a
/// `HijriCalendar` built from an offset date carries that offset's weekday,
/// which is how Dua Simat once showed up on Saturdays. Matching only accepts
/// a [LunarDay], so there is no way to hand it a bare, shifted Hijri date.
class LunarDay {
  LunarDay(DateTime date, {int hijriOffsetDays = 0})
      : civilDate = date.isUtc
            ? DateTime.utc(date.year, date.month, date.day)
            : DateTime(date.year, date.month, date.day) {
    hijri = HijriCalendar.fromDate(
      civilDate.add(Duration(days: hijriOffsetDays)),
    );
  }

  /// The day on the wall calendar, at midnight.
  final DateTime civilDate;

  /// The Hijri date in effect on [civilDate], moon-sighting offset applied.
  late final HijriCalendar hijri;

  /// [civilDate]'s weekday, 0=Sunday through 6=Saturday.
  int get weekday => civilDate.weekday % 7;
}

List<String> _patternsFromValue(Object? value) {
  if (value is String) {
    return value
        .split(',')
        .map((pattern) => pattern.trim())
        .where((pattern) => pattern.isNotEmpty)
        .toList();
  }

  if (value is Iterable) {
    return value
        .expand((pattern) => _patternsFromValue(pattern))
        .where((pattern) => pattern.isNotEmpty)
        .toList();
  }

  return const [];
}

/// Checks if [day] (or, for an "N" pattern, [night]) matches [pattern].
///
/// Pattern formats:
/// - "MM-DD": Fixed date (e.g., "09-09" for 9th Zilhajj)
/// - "MM-*": Any day within one lunar month (e.g., "09-*" for every day of
///   Ramazan) — use this for practices tied to a whole month rather than a
///   single date.
/// - "MM-*-D": Recurring weekly within one lunar month (e.g., "10-*-0" for
///   every Sunday of Zilqad)
/// - "*-*-D": Recurring weekly in every lunar month (e.g., "*-*-5" for every
///   Friday, year-round) — use this for weekday-only duas that aren't tied
///   to a particular Hijri month, instead of repeating "MM-*-D" 12 times.
///   Day values: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
/// - "MM-*-D#K" / "*-*-D#K": Only the K-th such weekday (1-5) of the lunar
///   month (e.g., "07-*-4#1" for the first Thursday of Rajab). Counted by
///   Hijri day: days 1-7 hold the first of each weekday, 8-14 the second,
///   and so on.
/// - "*-*": Every day, year-round (e.g. Dua-e-Ahad, Ziyarat Ashura) — the
///   daily recitations Today's Recitation always lists.
/// - "N" + any of the above: the *night* leading into that day (Maghrib
///   through Fajr) rather than the day itself (e.g., "N12-09" for the Night
///   of Arafah, the eve of 9th Zilhajj — distinct from "12-09", the Day of
///   Arafah; "N*-*-5" for Thursday night, the night leading into Friday;
///   "N07-*-5#1" for Laylat al-Raghaib, the night into Rajab's first Friday).
///   Only matches while a [night] is open — see [resolveNightLunarDay].
///
/// Weekdays always come from the civil date (see [LunarDay]), so a
/// moon-sighting correction never moves a weekday recitation.
bool matchesLunarDatePattern(
  String pattern, {
  required LunarDay day,
  LunarDay? night,
}) {
  final trimmed = pattern.trim();
  if (trimmed.startsWith('N')) {
    if (night == null) return false;
    return _matchesDatePattern(trimmed.substring(1), night);
  }
  return _matchesDatePattern(trimmed, day);
}

bool _matchesDatePattern(String datePattern, LunarDay day) {
  final date = day.hijri;
  final parts = datePattern.split('-');
  if (parts.length < 2) return false;

  final isAnyMonth = parts[0] == '*';
  final month = isAnyMonth ? null : int.tryParse(parts[0]);
  if (!isAnyMonth && (month == null || month < 1 || month > 12)) return false;

  // Recurring weekday pattern (MM-*-D or *-*-D)
  if (parts.length >= 3 && parts[1] == '*') {
    if (!isAnyMonth && date.hMonth != month) return false;

    if (parts.length != 3) return false;
    final weekdayParts = parts[2].split('#');
    if (weekdayParts.length > 2) return false;

    final dayOfWeek = int.tryParse(weekdayParts[0]);
    if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) return false;
    if (day.weekday != dayOfWeek) return false;

    // "#K": only the K-th occurrence of that weekday in the lunar month.
    if (weekdayParts.length == 2) {
      final ordinal = int.tryParse(weekdayParts[1]);
      if (ordinal == null || ordinal < 1 || ordinal > 5) return false;
      return (date.hDay - 1) ~/ 7 + 1 == ordinal;
    }
    return true;
  }

  // Every day ("*-*"). Any other any-month pattern needs a real lunar month.
  if (isAnyMonth) return parts.length == 2 && parts[1] == '*';
  if (parts.length == 2) {
    // Whole-month pattern (MM-*)
    if (parts[1] == '*') {
      return date.hMonth == month;
    }

    // Fixed date pattern (MM-DD)
    final dayOfMonth = int.tryParse(parts[1]);
    if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 30) return false;

    return date.hMonth == month && date.hDay == dayOfMonth;
  }

  return false;
}

/// Checks if any pattern in the list matches [day] (or [night]).
bool matchesAnyLunarPattern(
  Iterable<String>? patterns, {
  required LunarDay day,
  LunarDay? night,
}) {
  if (patterns == null || patterns.isEmpty) return false;
  return patterns.any(
    (pattern) => matchesLunarDatePattern(pattern, day: day, night: night),
  );
}

/// How specific [pattern] is, from 0 (once a year: a date or night like
/// "09-19"/"N09-19", or "07-*-5#1", one weekday of one month) through 1
/// (within one lunar month, e.g. "09-*" or "11-*-0", or once a month,
/// "*-*-5#1") and 2 (a weekday every month, "*-*-D") to 3 (every day,
/// "*-*"). Today's Recitation lists the most specific occasions first, so
/// the Night of Qadr comes before Friday's duas, which come before the
/// daily ones.
int lunarPatternSpecificity(String pattern) {
  var trimmed = pattern.trim();
  if (trimmed.startsWith('N')) trimmed = trimmed.substring(1);
  final parts = trimmed.split('-');
  final isOrdinal = trimmed.contains('#');
  if (parts.first == '*') {
    if (parts.length < 3) return 3;
    return isOrdinal ? 1 : 2;
  }
  if (parts.length >= 2 && parts[1] == '*') return isOrdinal ? 0 : 1;
  return 0;
}

/// Returns the zikr UIDs whose `day` patterns match [day] (or, for "N"
/// patterns, the currently open [night]), each mapped to the
/// [lunarPatternSpecificity] of its most specific matching pattern.
Map<String, int> matchTodaysZikrs(
  Map<String, dynamic> zikrData, {
  required LunarDay day,
  LunarDay? night,
}) {
  final matches = <String, int>{};

  zikrData.forEach((uid, value) {
    if (value is! Map<String, dynamic>) return;

    for (final pattern in _patternsFromValue(value['day'])) {
      if (!matchesLunarDatePattern(pattern, day: day, night: night)) continue;
      final specificity = lunarPatternSpecificity(pattern);
      final best = matches[uid];
      if (best == null || specificity < best) matches[uid] = specificity;
    }
  });

  return matches;
}

/// Returns a list of zikr UIDs that match [day] (or [night]). See
/// [matchTodaysZikrs].
List<String> getTodaysZikrs(
  Map<String, dynamic> zikrData, {
  required LunarDay day,
  LunarDay? night,
}) {
  return matchTodaysZikrs(zikrData, day: day, night: night).keys.toList();
}
