import 'package:hijri/hijri_calendar.dart';

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

  final parts = pattern.split('-');
  if (parts.length < 2) return false;

  final month = int.tryParse(parts[0]);
  if (month == null || month < 1 || month > 12) return false;

  // Check if it's a recurring pattern (MM-*-D)
  if (parts.length >= 3 && parts[1] == '*') {
    if (currentDate.hMonth != month) return false;

    final dayOfWeek = int.tryParse(parts[2]);
    if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) return false;

    // Get the day of week for current date (1=Sunday through 7=Saturday in hijri calendar)
    // Convert to 0-based (0=Sunday through 6=Saturday)
    final currentDayOfWeek = (currentDate.wkDay ?? 7) - 1;
    if (currentDayOfWeek < 0) return false;

    return currentDayOfWeek == dayOfWeek;
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
bool matchesAnyLunarPattern(List<String>? patterns) {
  if (patterns == null || patterns.isEmpty) return false;
  return patterns.any((pattern) => matchesLunarDatePattern(pattern));
}

/// Returns a list of zikr UIDs that match the current lunar date.
List<String> getTodaysZikrs(Map<String, dynamic> zikrData) {
  final today = <String>[];

  zikrData.forEach((uid, value) {
    if (value is! Map<String, dynamic>) return;

    final day = value['day'];
    if (day == null) return;

    if (day is String) {
      if (matchesLunarDatePattern(day)) {
        today.add(uid);
      }
    } else if (day is List) {
      if (matchesAnyLunarPattern(day.cast<String>())) {
        today.add(uid);
      }
    }
  });

  return today;
}
