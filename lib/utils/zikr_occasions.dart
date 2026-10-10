import 'package:intl/intl.dart' show DateFormat;

import '../l10n/l10n.dart';
import 'lunar_date_matcher.dart';

/// When a zikr is recited, in words, from its `day` patterns (see
/// [matchesLunarDatePattern]): "Every day", "Saturdays", "On 20 Safar", "On
/// 17 and 29 Safar, 11 and 23 Dhul Qa'dah", "Nights of 21–30 Ramazan".
///
/// The lists show it under an occasion dua's title (docs/DESIGN_SPEC.md,
/// "Lists"). Each kind of occasion is one clause, the most frequent first,
/// with " · " between clauses: "Fridays · On 1 Shawwal, 10 and 18 Dhul
/// Hijjah". Null when there are no patterns, or none it can read.
String? describeZikrOccasions(
  Iterable<String> patterns, [
  AppLocalizations? l10n,
]) {
  final s = l10n ?? L10n.current;
  final occasions =
      patterns.map(_Occasion.parse).whereType<_Occasion>().toList();
  if (occasions.isEmpty) return null;

  final clauses = <String>[];

  if (occasions.any((o) => o.isEveryDay && !o.night)) {
    clauses.add(s.occasionEveryDay);
  }
  if (occasions.any((o) => o.isEveryDay && o.night)) {
    clauses.add(s.occasionEveryNight);
  }

  // Every week, whatever the month.
  final weekly = _weekdays(occasions.where(
      (o) => o.month == null && o.isWeekly && o.ordinal == null && !o.night));
  if (weekly.isNotEmpty) {
    clauses.add(joinList(
        [for (final w in weekly) s.occasionWeekly(weekdayName(w))], s));
  }
  final weeklyNights = _weekdays(occasions.where(
      (o) => o.month == null && o.isWeekly && o.ordinal == null && o.night));
  if (weeklyNights.isNotEmpty) {
    clauses.add(joinList([
      for (final w in weeklyNights)
        s.occasionWeeklyNight(weekdayName(_dayBefore(w)))
    ], s));
  }
  for (final o
      in occasions.where((o) => o.month == null && o.ordinal != null)) {
    final weekday = weekdayName(o.weekday!);
    clauses.add(o.night
        ? s.occasionNthWeekdayNightMonthly('${o.ordinal}', weekday)
        : s.occasionNthWeekdayMonthly('${o.ordinal}', weekday));
  }

  // Within one month: the whole of it, or some of its weekdays.
  final months = {
    for (final o in occasions)
      if (o.month != null && o.day == null) o.month!
  }.toList()
    ..sort();
  for (final month in months) {
    final name = zikrMonthName(month, s);
    final inMonth = occasions.where((o) => o.month == month && o.day == null);
    if (inMonth.any((o) => o.isWholeMonth && !o.night)) {
      clauses.add(s.occasionThroughMonth(name));
    }
    if (inMonth.any((o) => o.isWholeMonth && o.night)) {
      clauses.add(s.occasionMonthNights(name));
    }
    for (final w in _weekdays(
        inMonth.where((o) => o.isWeekly && o.ordinal == null && !o.night))) {
      clauses.add(s.occasionWeeklyInMonth(weekdayName(w), name));
    }
    for (final w in _weekdays(
        inMonth.where((o) => o.isWeekly && o.ordinal == null && o.night))) {
      clauses
          .add(s.occasionWeeklyNightInMonth(weekdayName(_dayBefore(w)), name));
    }
    for (final o in inMonth.where((o) => o.ordinal != null)) {
      final weekday = weekdayName(o.weekday!);
      clauses.add(o.night
          ? s.occasionNthWeekdayNight('${o.ordinal}', weekday, name)
          : s.occasionNthWeekday('${o.ordinal}', weekday, name));
    }
  }

  // Dates. A date kept both night and day ("N11-25" and "11-25") reads as
  // one "Night and day of 25 Dhul Qa'dah".
  final days = <int, Set<int>>{};
  final nights = <int, Set<int>>{};
  for (final o in occasions.where((o) => o.day != null)) {
    (o.night ? nights : days).putIfAbsent(o.month!, () => {}).add(o.day!);
  }
  final both = <int, Set<int>>{};
  for (final month in days.keys) {
    final shared = days[month]!.intersection(nights[month] ?? const {});
    if (shared.isEmpty) continue;
    both[month] = shared;
    days[month]!.removeAll(shared);
    nights[month]!.removeAll(shared);
  }
  int count(Map<int, Set<int>> dates) =>
      dates.values.fold(0, (sum, set) => sum + set.length);
  if (count(days) > 0) clauses.add(s.occasionOnDates(_dates(days, s)));
  if (count(both) > 0) {
    clauses.add(s.occasionNightAndDayOf(count(both), _dates(both, s)));
  }
  if (count(nights) > 0) {
    clauses.add(s.occasionNightsOf(count(nights), _dates(nights, s)));
  }

  return clauses.isEmpty ? null : clauses.join(' · ');
}

/// Whether [patterns] name an every-day recitation ("*-*"), which the lists
/// never mark as Today: it always is.
bool isEveryDayOccasion(Iterable<String> patterns) =>
    patterns.map(_Occasion.parse).any((o) => o != null && o.isEveryDay);

/// [items] as one phrase: "Thursdays and Fridays", "11, 15 and 23".
String joinList(List<String> items, [AppLocalizations? l10n]) {
  final s = l10n ?? L10n.current;
  if (items.length < 2) return items.join();
  return s.listAnd(
    items.sublist(0, items.length - 1).join(s.listSeparator),
    items.last,
  );
}

/// The name of Hijri month [month] as the zikr titles spell it ("Ramazan",
/// "Dhul Qa'dah"), unlike [hijriMonthName]'s calendar spelling.
String zikrMonthName(int month, [AppLocalizations? l10n]) {
  final s = l10n ?? L10n.current;
  return switch (month) {
    1 => s.zikrMonth1,
    2 => s.zikrMonth2,
    3 => s.zikrMonth3,
    4 => s.zikrMonth4,
    5 => s.zikrMonth5,
    6 => s.zikrMonth6,
    7 => s.zikrMonth7,
    8 => s.zikrMonth8,
    9 => s.zikrMonth9,
    10 => s.zikrMonth10,
    11 => s.zikrMonth11,
    _ => s.zikrMonth12,
  };
}

/// The full name of [weekday] (0 = Sunday ... 6 = Saturday, as the `day`
/// patterns count) in the app language.
String weekdayName(int weekday) =>
    // 16 June 2024 was a Sunday.
    DateFormat('EEEE').format(DateTime(2024, 6, 16 + weekday));

/// The weekday a night pattern's night falls after: "N*-*-5", the night
/// leading into Friday, is Thursday night.
int _dayBefore(int weekday) => (weekday + 6) % 7;

List<int> _weekdays(Iterable<_Occasion> occasions) =>
    {for (final o in occasions) o.weekday!}.toList()..sort();

/// "17 and 29 Safar, 11 and 23 Dhul Qa'dah": each month's days, a run of
/// three or more days in a row as a range ("21–30 Ramazan").
String _dates(Map<int, Set<int>> dates, AppLocalizations s) {
  final months = dates.keys.where((m) => dates[m]!.isNotEmpty).toList()..sort();
  return [
    for (final month in months)
      s.occasionDaysOfMonth(
        joinList(_runs(dates[month]!.toList()..sort(), s), s),
        zikrMonthName(month, s),
      ),
  ].join(s.listSeparator);
}

List<String> _runs(List<int> days, AppLocalizations s) {
  final parts = <String>[];
  var start = 0;
  while (start < days.length) {
    var end = start;
    while (end + 1 < days.length && days[end + 1] == days[end] + 1) {
      end++;
    }
    if (end - start >= 2) {
      parts.add(localizeDigits('${days[start]}–${days[end]}', s));
    } else {
      for (var i = start; i <= end; i++) {
        parts.add(localizeDigits('${days[i]}', s));
      }
    }
    start = end + 1;
  }
  return parts;
}

/// One `day` pattern, parsed the way [matchesLunarDatePattern] reads it.
class _Occasion {
  const _Occasion({
    required this.night,
    this.month,
    this.day,
    this.weekday,
    this.ordinal,
  });

  /// The night leading into the day ("N" patterns).
  final bool night;

  /// 1-12, or null for every month.
  final int? month;

  /// A fixed day of [month].
  final int? day;

  /// 0 = Sunday ... 6 = Saturday.
  final int? weekday;

  /// Only the K-th such weekday of the month ("#K").
  final int? ordinal;

  bool get isEveryDay => month == null && day == null && weekday == null;
  bool get isWholeMonth => month != null && day == null && weekday == null;
  bool get isWeekly => weekday != null;

  static _Occasion? parse(String raw) {
    var pattern = raw.trim();
    final night = pattern.startsWith('N');
    if (night) pattern = pattern.substring(1);

    final parts = pattern.split('-');
    if (parts.length < 2 || parts.length > 3) return null;
    final anyMonth = parts[0] == '*';
    final month = anyMonth ? null : int.tryParse(parts[0]);
    if (!anyMonth && (month == null || month < 1 || month > 12)) return null;

    if (parts.length == 3) {
      if (parts[1] != '*') return null;
      final weekdayParts = parts[2].split('#');
      if (weekdayParts.length > 2) return null;
      final weekday = int.tryParse(weekdayParts[0]);
      if (weekday == null || weekday < 0 || weekday > 6) return null;
      int? ordinal;
      if (weekdayParts.length == 2) {
        ordinal = int.tryParse(weekdayParts[1]);
        if (ordinal == null || ordinal < 1 || ordinal > 5) return null;
      }
      return _Occasion(
          night: night, month: month, weekday: weekday, ordinal: ordinal);
    }

    if (parts[1] == '*') return _Occasion(night: night, month: month);
    if (anyMonth) return null;
    final day = int.tryParse(parts[1]);
    if (day == null || day < 1 || day > 30) return null;
    return _Occasion(night: night, month: month, day: day);
  }
}
