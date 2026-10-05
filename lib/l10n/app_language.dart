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
  });

  /// ISO 639-1 code, as used in ARB file names, asset folders and [Locale].
  final String code;

  final String englishName;

  /// The language's name in itself, which is what a picker shows: someone
  /// looking for Urdu recognises اردو whatever language the app is in.
  final String nativeName;

  final bool isRtl;

  Locale get locale => Locale(code);

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
  ),
  AppLanguage(
    code: 'fa',
    englishName: 'Persian',
    nativeName: 'فارسی',
    isRtl: true,
  ),
  AppLanguage(
    code: 'ar',
    englishName: 'Arabic',
    nativeName: 'العربية',
    isRtl: true,
  ),
  AppLanguage(
    code: 'gu',
    englishName: 'Gujarati',
    nativeName: 'ગુજરાતી',
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
