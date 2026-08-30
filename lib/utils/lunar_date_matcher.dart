import 'package:hijri/hijri_calendar.dart';

int _sundayBasedWeekday(HijriCalendar date) {
  final weekday = date.wkDay ?? date.weekDay();
  return weekday == DateTime.sunday ? 0 : weekday;
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

/// Checks if a given lunar date matches the provided day pattern.
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
/// - "NMM-DD": The *night* leading into MM-DD (Maghrib through Fajr), rather
///   than the day itself (e.g., "N12-09" for the Night of Arafah, the eve of
///   9th Zilhajj — distinct from "12-09", the Day of Arafah). Only matches
///   when [nightDate] is supplied — see [resolveNightAdjustedHijriDate].
///
/// Returns true if the current date matches the pattern.
bool matchesLunarDatePattern(
  String pattern, {
  HijriCalendar? currentDate,
  HijriCalendar? nightDate,
}) {
  currentDate ??= HijriCalendar.now();

  final trimmed = pattern.trim();
  final isNight = trimmed.startsWith('N');
  if (isNight) {
    if (nightDate == null) return false;
    return _matchesDatePattern(trimmed.substring(1), nightDate);
  }

  return _matchesDatePattern(trimmed, currentDate);
}

bool _matchesDatePattern(String datePattern, HijriCalendar date) {
  final parts = datePattern.split('-');
  if (parts.length < 2) return false;

  final isAnyMonth = parts[0] == '*';
  final month = isAnyMonth ? null : int.tryParse(parts[0]);
  if (!isAnyMonth && (month == null || month < 1 || month > 12)) return false;

  // Recurring weekday pattern (MM-*-D or *-*-D)
  if (parts.length >= 3 && parts[1] == '*') {
    if (!isAnyMonth && date.hMonth != month) return false;

    final dayOfWeek = int.tryParse(parts[2]);
    if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) return false;

    return _sundayBasedWeekday(date) == dayOfWeek;
  }

  // A bare month with no day, fixed or wildcard, needs a real lunar month.
  if (isAnyMonth) return false;
  if (parts.length == 2) {
    // Whole-month pattern (MM-*)
    if (parts[1] == '*') {
      return date.hMonth == month;
    }

    // Fixed date pattern (MM-DD)
    final day = int.tryParse(parts[1]);
    if (day == null || day < 1 || day > 30) return false;

    return date.hMonth == month && date.hDay == day;
  }

  return false;
}

/// Checks if any pattern in the list matches the current lunar date.
bool matchesAnyLunarPattern(
  Iterable<String>? patterns, {
  HijriCalendar? currentDate,
  HijriCalendar? nightDate,
}) {
  if (patterns == null || patterns.isEmpty) return false;
  currentDate ??= HijriCalendar.now();
  return patterns.any(
    (pattern) => matchesLunarDatePattern(
      pattern,
      currentDate: currentDate,
      nightDate: nightDate,
    ),
  );
}

/// Returns a list of zikr UIDs that match the current lunar date.
///
/// [nightDate], when supplied, lets "N"-prefixed patterns (see
/// [matchesLunarDatePattern]) match against the currently-open Shab (night)
/// window rather than the plain calendar date.
List<String> getTodaysZikrs(
  Map<String, dynamic> zikrData, {
  HijriCalendar? currentDate,
  HijriCalendar? nightDate,
}) {
  final today = <String>[];
  currentDate ??= HijriCalendar.now();

  zikrData.forEach((uid, value) {
    if (value is! Map<String, dynamic>) return;

    final patterns = _patternsFromValue(value['day']);
    if (patterns.isEmpty) return;

    if (matchesAnyLunarPattern(
      patterns,
      currentDate: currentDate,
      nightDate: nightDate,
    )) {
      today.add(uid);
    }
  });

  return today;
}
