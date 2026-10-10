import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart';

import 'app_language.dart';
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
/// numbers - ٠-٩ in Arabic, ۰-۹ in Persian and Urdu, ૦-૯ in Gujarati - for
/// numbers the app puts together itself (Hijri dates, counters). Anything
/// formatted through intl's `DateFormat`/`NumberFormat`, or passed to a
/// string as a formatted `int` placeholder, already gets them. English text
/// comes back unchanged.
String localizeDigits(String text, [AppLocalizations? l10n]) =>
    appLanguageFor((l10n ?? L10n.current).localeName)?.nativeDigits(text) ??
    text;

/// [text] with any Arabic-Indic, Persian/Urdu or Gujarati digits read as
/// 0-9, for parsing what someone typed ("۳۳:۳۳") on a keyboard in their own
/// script.
String asciiDigits(String text) => String.fromCharCodes([
      for (final unit in text.codeUnits)
        if (unit >= 0x0660 && unit <= 0x0669)
          unit - 0x0660 + 0x30
        else if (unit >= 0x06F0 && unit <= 0x06F9)
          unit - 0x06F0 + 0x30
        else if (unit >= 0x0AE6 && unit <= 0x0AEF)
          unit - 0x0AE6 + 0x30
        else
          unit,
    ]);

/// An "am"/"pm" at the end of a clock time the app wrote itself.
final RegExp _clockSuffix =
    RegExp(r'\s*\b([ap])\.?m\.?$', caseSensitive: false);

/// A clock time the app wrote itself ("05:12 pm", from the prayer-time
/// code) in the app language: its digits, and its am/pm the language's own
/// ("۰۵:۱۲ ب.د." in Urdu). English comes back unchanged.
String localizeClockTime(String time, [AppLocalizations? l10n]) {
  final strings = l10n ?? L10n.current;
  if (strings.localeName == 'en') return time;
  final localized = time.trim().replaceFirstMapped(
        _clockSuffix,
        (match) =>
            ' ${match.group(1)!.toLowerCase() == 'a' ? strings.timeAm : strings.timePm}',
      );
  return localizeDigits(localized, strings);
}

/// Makes intl's `DateFormat` and `NumberFormat` write [language] the way the
/// rest of the app does: in its own digits (intl's data writes Urdu and
/// Gujarati in 0-9) and with [strings]' am/pm (intl's Urdu has "a"/"p").
///
/// Patches intl's shared symbol tables in place, so every formatter - the
/// app's, the generated strings', Material's - picks it up. Run again after
/// Material's localizations load ([IntlSymbolsDelegate]), since their first
/// load replaces intl's date symbols with Flutter's own copies.
void applyIntlSymbols(AppLanguage language, AppLocalizations strings) {
  if (language.code == 'en') return;
  for (final name in {language.code, language.formattingLocale}) {
    final numbers = numberFormatSymbols[name];
    if (numbers is NumberSymbols && numbers.ZERO_DIGIT != language.zeroDigit) {
      numberFormatSymbols[name] = _withZeroDigit(numbers, language.zeroDigit);
    }
    if (!DateFormat.localeExists(name)) continue;
    final dates = DateFormat(null, name).dateSymbols;
    dates.ZERODIGIT = language.zeroDigit;
    dates.AMPMS = [strings.timeAm, strings.timePm];
  }
}

NumberSymbols _withZeroDigit(NumberSymbols symbols, String zeroDigit) =>
    NumberSymbols(
      NAME: symbols.NAME,
      DECIMAL_SEP: symbols.DECIMAL_SEP,
      GROUP_SEP: symbols.GROUP_SEP,
      PERCENT: symbols.PERCENT,
      ZERO_DIGIT: zeroDigit,
      PLUS_SIGN: symbols.PLUS_SIGN,
      MINUS_SIGN: symbols.MINUS_SIGN,
      EXP_SYMBOL: symbols.EXP_SYMBOL,
      PERMILL: symbols.PERMILL,
      INFINITY: symbols.INFINITY,
      NAN: symbols.NAN,
      DECIMAL_PATTERN: symbols.DECIMAL_PATTERN,
      SCIENTIFIC_PATTERN: symbols.SCIENTIFIC_PATTERN,
      PERCENT_PATTERN: symbols.PERCENT_PATTERN,
      CURRENCY_PATTERN: symbols.CURRENCY_PATTERN,
      DEF_CURRENCY_CODE: symbols.DEF_CURRENCY_CODE,
    );

/// Re-applies [applyIntlSymbols] whenever the app's locale loads. Listed
/// after `GlobalMaterialLocalizations.delegate`, whose first load swaps
/// intl's date symbols for Flutter's own (and so drops the patch); the
/// delegates load in order, so this one always has the last word.
class IntlSymbolsDelegate extends LocalizationsDelegate<IntlSymbolsDelegate> {
  const IntlSymbolsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<IntlSymbolsDelegate> load(Locale locale) {
    final language = appLanguageFor(locale.languageCode);
    if (language != null) {
      applyIntlSymbols(language, lookupAppLocalizations(language.locale));
    }
    return SynchronousFuture(this);
  }

  @override
  bool shouldReload(IntlSymbolsDelegate old) => false;
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
