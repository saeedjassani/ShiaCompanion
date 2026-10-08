import 'package:flutter/widgets.dart';
import 'package:intl/number_symbols_data.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

export 'app_localizations.dart';

/// The app's translated strings, for code that has no [BuildContext] to look
/// them up from - notifications, home screen widgets, share text.
///
/// Kept in step with the app language by [LanguageProvider]. Widgets should
/// use `context.l10n` instead, which also rebuilds them when the language
/// changes.
class L10n {
  L10n._();

  static AppLocalizations _current = AppLocalizationsEn();

  static AppLocalizations get current => _current;

  static set current(AppLocalizations value) => _current = value;
}

/// [text] with its digits 0-9 written the way the app language writes
/// numbers - ٠-٩ in Arabic, ۰-۹ in Persian - for numbers the app puts
/// together itself (prayer times, Hijri dates, counters). Anything formatted
/// through intl's `DateFormat`/`NumberFormat`, or passed to a string as an
/// `int` placeholder, already gets them. English text comes back unchanged.
String localizeDigits(String text, [AppLocalizations? l10n]) {
  final zero =
      numberFormatSymbols[(l10n ?? L10n.current).localeName]?.ZERO_DIGIT;
  if (zero == null || zero == '0') return text;
  final offset = zero.codeUnitAt(0) - 0x30;
  return String.fromCharCodes([
    for (final unit in text.codeUnits)
      unit >= 0x30 && unit <= 0x39 ? unit + offset : unit,
  ]);
}

extension AppLocalizationsContext on BuildContext {
  /// The strings for the language this part of the tree is shown in.
  ///
  /// Falls back to [L10n.current] where no [AppLocalizations] is in scope -
  /// widget tests that pump a page without the app's delegates - so those
  /// keep seeing English rather than crashing.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? L10n.current;
}

/// [name] - one of the English prayer names the prayer-time code uses as
/// identifiers ("Fajr", "Zuhr", "Midnight"...) - as shown in the app
/// language. Those names key preferences and notifications, so they stay
/// English everywhere but on screen; anything unrecognised is returned as is.
String localizedPrayerName(String name, [AppLocalizations? l10n]) {
  final strings = l10n ?? L10n.current;
  return switch (name) {
    'Fajr' => strings.prayerFajr,
    'Sunrise' => strings.prayerSunrise,
    'Zuhr' => strings.prayerZuhr,
    'Asr' => strings.prayerAsr,
    'Sunset' => strings.prayerSunset,
    'Maghrib' => strings.prayerMaghrib,
    'Isha' => strings.prayerIsha,
    'Midnight' => strings.prayerMidnight,
    _ => name,
  };
}

/// The short name of ISO weekday [weekday] (1 = Monday ... 7 = Sunday).
String shortWeekdayName(int weekday, [AppLocalizations? l10n]) {
  final strings = l10n ?? L10n.current;
  return switch (weekday) {
    DateTime.monday => strings.weekdayShortMon,
    DateTime.tuesday => strings.weekdayShortTue,
    DateTime.wednesday => strings.weekdayShortWed,
    DateTime.thursday => strings.weekdayShortThu,
    DateTime.friday => strings.weekdayShortFri,
    DateTime.saturday => strings.weekdayShortSat,
    _ => strings.weekdayShortSun,
  };
}
