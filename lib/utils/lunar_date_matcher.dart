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
/// - "MM-*-D": Recurring weekly (e.g., "10-*-0" for every Sunday of Zilqad)
///   Day values: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
///
/// Returns true if the current date matches the pattern.
bool matchesLunarDatePattern(String pattern, {HijriCalendar? currentDate}) {
  currentDate ??= HijriCalendar.now();

  final parts = pattern.trim().split('-');
  if (parts.length < 2) return false;

  final month = int.tryParse(parts[0]);
  if (month == null || month < 1 || month > 12) return false;

  // Check if it's a recurring pattern (MM-*-D)
  if (parts.length >= 3 && parts[1] == '*') {
    if (currentDate.hMonth != month) return false;

    final dayOfWeek = int.tryParse(parts[2]);
    if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) return false;

    return _sundayBasedWeekday(currentDate) == dayOfWeek;
  }

  // Fixed date pattern (MM-DD)
  if (parts.length >= 2) {
    final day = int.tryParse(parts[1]);
    if (day == null || day < 1 || day > 30) return false;

    return currentDate.hMonth == month && currentDate.hDay == day;
  }

  return false;
}

/// Checks if any pattern in the list matches the current lunar date.
bool matchesAnyLunarPattern(
  Iterable<String>? patterns, {
  HijriCalendar? currentDate,
}) {
  if (patterns == null || patterns.isEmpty) return false;
  currentDate ??= HijriCalendar.now();
  return patterns.any(
    (pattern) => matchesLunarDatePattern(pattern, currentDate: currentDate),
  );
}

/// Returns a list of zikr UIDs that match the current lunar date.
List<String> getTodaysZikrs(
  Map<String, dynamic> zikrData, {
  HijriCalendar? currentDate,
}) {
  final today = <String>[];
  currentDate ??= HijriCalendar.now();

  zikrData.forEach((uid, value) {
    if (value is! Map<String, dynamic>) return;

    final patterns = _patternsFromValue(value['day']);
    if (patterns.isEmpty) return;

    if (matchesAnyLunarPattern(patterns, currentDate: currentDate)) {
      today.add(uid);
    }
  });

  return today;
}
