import 'package:hijri/hijri_calendar.dart';

import 'l10n.dart';

/// The name of Hijri month [month] (1 = Muharram ... 12 = Dhu al-Hijjah) in
/// the app language. The `hijri` package only knows English, Arabic and
/// Turkish, and follows a global setting of its own, so the app keeps its own
/// names - the English ones exactly as the package spells them.
String hijriMonthName(int month, [AppLocalizations? l10n]) {
  final s = l10n ?? L10n.current;
  return switch (month) {
    1 => s.hijriMonth1,
    2 => s.hijriMonth2,
    3 => s.hijriMonth3,
    4 => s.hijriMonth4,
    5 => s.hijriMonth5,
    6 => s.hijriMonth6,
    7 => s.hijriMonth7,
    8 => s.hijriMonth8,
    9 => s.hijriMonth9,
    10 => s.hijriMonth10,
    11 => s.hijriMonth11,
    _ => s.hijriMonth12,
  };
}

/// The abbreviated name of Hijri month [month], for the calendar widget.
String hijriMonthShortName(int month, [AppLocalizations? l10n]) {
  final s = l10n ?? L10n.current;
  return switch (month) {
    1 => s.hijriMonthShort1,
    2 => s.hijriMonthShort2,
    3 => s.hijriMonthShort3,
    4 => s.hijriMonthShort4,
    5 => s.hijriMonthShort5,
    6 => s.hijriMonthShort6,
    7 => s.hijriMonthShort7,
    8 => s.hijriMonthShort8,
    9 => s.hijriMonthShort9,
    10 => s.hijriMonthShort10,
    11 => s.hijriMonthShort11,
    _ => s.hijriMonthShort12,
  };
}

/// [HijriCalendar.toFormat] with the month name (`MMMM`) and the digits in
/// the app language.
String formatHijri(
  HijriCalendar date,
  String pattern, [
  AppLocalizations? l10n,
]) {
  if (!pattern.contains('MMMM')) {
    return localizeDigits(date.toFormat(pattern), l10n);
  }
  // A marker no format letter can match stands in for the month while the
  // package formats the rest.
  const marker = '\u0000';
  return localizeDigits(
          date.toFormat(pattern.replaceFirst('MMMM', marker)), l10n)
      .replaceFirst(marker, hijriMonthName(date.hMonth, l10n));
}
