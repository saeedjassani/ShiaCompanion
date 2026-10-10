import 'package:flutter/widgets.dart';

/// A language the app knows how to present, whether or not anything has been
/// translated into it yet.
///
/// Being listed here only says how to show the language - its name, which way
/// it reads. Whether it is actually offered depends on what has shipped:
/// app text needs a `lib/l10n/app_<code>.arb`, zikr translations need an
/// `assets/zikr_i18n/<code>/index.json` (see docs/TRANSLATIONS.md). Until
/// then the language is simply absent from the pickers.
@immutable
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.isRtl = false,
    this.zeroDigit = '0',
    String? formattingLocale,
  }) : _formattingLocale = formattingLocale;

  /// ISO 639-1 code, as used in ARB file names, asset folders and [Locale].
  final String code;

  final String englishName;

  /// The language's name in itself, which is what a picker shows: someone
  /// looking for Urdu recognises اردو whatever language the app is in.
  final String nativeName;

  final bool isRtl;

  /// The digit zero as the language writes numbers; the other nine follow
  /// it in Unicode (٠-٩ in Arabic, ۰-۹ in Persian and Urdu, ૦-૯ in
  /// Gujarati). intl's own data writes Urdu and Gujarati in 0-9, so the app
  /// sets this rather than reading it from there.
  final String zeroDigit;

  final String? _formattingLocale;

  /// The intl locale dates and numbers are written in - [code] unless the
  /// language's everyday digits need another one: intl's plain `ar` writes
  /// 0-9, `ar_EG` the Arabic-Indic ٠-٩ Arabic readers expect.
  String get formattingLocale => _formattingLocale ?? code;

  Locale get locale => Locale(code);

  /// [text] with its digits 0-9 written in this language's digits.
  String nativeDigits(String text) {
    final offset = zeroDigit.codeUnitAt(0) - 0x30;
    if (offset == 0) return text;
    return String.fromCharCodes([
      for (final unit in text.codeUnits)
        unit >= 0x30 && unit <= 0x39 ? unit + offset : unit,
    ]);
  }

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;
}

const String englishLanguageCode = 'en';

const AppLanguage englishLanguage = AppLanguage(
  code: englishLanguageCode,
  englishName: 'English',
  nativeName: 'English',
);

/// Every language the app is prepared for, English first.
const List<AppLanguage> appLanguages = [
  englishLanguage,
  AppLanguage(
    code: 'ur',
    englishName: 'Urdu',
    nativeName: 'اردو',
    isRtl: true,
    zeroDigit: '\u06F0',
  ),
  AppLanguage(
    code: 'fa',
    englishName: 'Persian',
    nativeName: 'فارسی',
    isRtl: true,
    zeroDigit: '\u06F0',
  ),
  AppLanguage(
    code: 'ar',
    englishName: 'Arabic',
    nativeName: 'العربية',
    isRtl: true,
    zeroDigit: '\u0660',
    formattingLocale: 'ar_EG',
  ),
  AppLanguage(
    code: 'gu',
    englishName: 'Gujarati',
    nativeName: 'ગુજરાતી',
    zeroDigit: '\u0AE6',
  ),
];

/// The catalog entry for [code], or null for a language the app does not
/// know.
AppLanguage? appLanguageFor(String? code) {
  if (code == null) return null;
  for (final language in appLanguages) {
    if (language.code == code) return language;
  }
  return null;
}
