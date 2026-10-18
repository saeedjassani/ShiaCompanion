import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../services/location_service.dart';
import '../services/zikr_translations.dart';
import 'shared_preferences.dart';
import 'urdu_font.dart';

/// The two language choices a reader makes:
///
/// * the **app language** - menus, buttons, settings, notifications - backed
///   by the `lib/l10n/app_<code>.arb` files, and
/// * the **translation language** - what a zikr's translation lines,
///   instructions and merits are shown in - backed by
///   `assets/zikr_i18n/<code>/`.
///
/// Zikr titles come from `assets/zikr_i18n/<code>/index.json` too, but they
/// name things in menus and lists, so they follow the app language.
///
/// They are separate because they are separate needs: plenty of readers are
/// happy with English menus but want a dua's meaning in Urdu. The translation
/// language follows the app language until the reader picks one of its own.
///
/// A language is only ever offered once something has been translated into
/// it, so with English alone shipped neither choice appears anywhere.
class LanguageProvider extends ChangeNotifier with WidgetsBindingObserver {
  LanguageProvider({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle {
    WidgetsBinding.instance.addObserver(this);
    _applyAppLanguage();
    unawaited(_load());
  }

  static const String appLanguagePrefsKey = 'app_language';
  static const String translationLanguagePrefsKey = 'translation_language';

  final AssetBundle _bundle;

  /// The reader's explicit app language, or null to follow the device.
  String? _appLanguageChoice;

  /// The reader's explicit translation language, or null to follow the app
  /// language.
  String? _translationLanguageChoice;

  Set<String> _translationLanguageCodes = const {englishLanguageCode};

  /// Languages whose app text has shipped, English first.
  static List<AppLanguage> get appTextLanguages {
    final codes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    return [
      for (final language in appLanguages)
        if (codes.contains(language.code)) language,
    ];
  }

  /// Languages whose zikr translations have shipped, English first.
  List<AppLanguage> get translationLanguages => [
        for (final language in appLanguages)
          if (_translationLanguageCodes.contains(language.code)) language,
      ];

  String? get appLanguageChoice => _appLanguageChoice;

  String? get translationLanguageChoice => _translationLanguageChoice;

  /// The language the device is set to, if app text has shipped in it,
  /// otherwise English: what the app is shown in while the reader has made
  /// no choice of their own.
  AppLanguage get deviceLanguage => _deviceLanguage();

  static AppLanguage _deviceLanguage() {
    final available = appTextLanguages;
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      for (final language in available) {
        if (language.code == locale.languageCode) return language;
      }
    }
    return englishLanguage;
  }

  /// The language the app is actually shown in: the reader's choice if it
  /// has shipped, otherwise [deviceLanguage].
  AppLanguage get appLanguage => _appLanguageFor(_appLanguageChoice);

  static AppLanguage _appLanguageFor(String? choice) {
    for (final language in appTextLanguages) {
      if (language.code == choice) return language;
    }
    return _deviceLanguage();
  }

  Locale get locale => appLanguage.locale;

  /// The language zikrs are read in. Outside English, what nobody has
  /// translated into it yet is left out rather than shown in English - the
  /// reader sees the Arabic alone.
  AppLanguage get translationLanguage =>
      _translationLanguageFor(_translationLanguageChoice ?? appLanguage.code);

  /// The translation language a reader who follows the app language gets,
  /// whatever translation language they have picked at the moment.
  AppLanguage get appFollowingTranslationLanguage =>
      _translationLanguageFor(appLanguage.code);

  /// Whether the app shows Urdu - its menus and zikr titles, or its zikr
  /// translations - and so is set in [UrduFont].
  bool get usesUrduFont =>
      usesUrduFontFor(appLanguage.code, translationLanguage.code);

  /// Urdu text is set in [UrduFont] unless the app itself is in Persian or
  /// Arabic: the theme's font is the menus' font too, and theirs must stay
  /// Naskh. (The font has no Latin or Gujarati letters, so English and
  /// Gujarati menus are untouched by it.)
  static bool usesUrduFontFor(String appCode, String translationCode) =>
      appCode == _urduCode ||
      (translationCode == _urduCode &&
          appCode != 'fa' &&
          appCode != arabicLanguageCode);

  static const String _urduCode = 'ur';

  /// Whether the languages saved last time want [UrduFont], read before the
  /// app starts so it can load the font ahead of the first frame. [SP] must
  /// be initialized.
  static bool savedLanguagesUseUrduFont() {
    final app = _appLanguageFor(SP.prefs.getString(appLanguagePrefsKey)).code;
    final translation = SP.prefs.getString(translationLanguagePrefsKey) ?? app;
    return usesUrduFontFor(app, translation);
  }

  void _loadFonts() {
    if (usesUrduFont) unawaited(UrduFont.ensureLoaded());
  }

  AppLanguage _translationLanguageFor(String code) =>
      _translationLanguageCodes.contains(code)
          ? appLanguageFor(code) ?? englishLanguage
          : englishLanguage;

  Future<void> _load() async {
    await SP.init();
    _appLanguageChoice = SP.prefs.getString(appLanguagePrefsKey);
    _translationLanguageChoice =
        SP.prefs.getString(translationLanguagePrefsKey);
    _translationLanguageCodes =
        await ZikrTranslations.instance.availableLanguageCodes(_bundle);
    _applyAppLanguage();
    await _applyZikrLanguages();
    notifyListeners();
  }

  /// Sets the app language; null goes back to following the device.
  Future<void> setAppLanguage(String? code) async {
    if (code == _appLanguageChoice) return;
    _appLanguageChoice = code;
    // The zikr titles first: the rebuild the new locale sets off redraws
    // every title on screen, and must find them in the new language.
    await _applyZikrLanguages();
    _applyAppLanguage();
    notifyListeners();
    unawaited(LocationService.instance.relabelForAppLanguage());
    await _persist(appLanguagePrefsKey, code);
  }

  /// Sets the translation language; null goes back to following the app
  /// language.
  Future<void> setTranslationLanguage(String? code) async {
    if (code == _translationLanguageChoice) return;
    _translationLanguageChoice = code;
    notifyListeners();
    await _applyZikrLanguages();
    await _persist(translationLanguagePrefsKey, code);
  }

  void _applyAppLanguage() {
    _loadFonts();
    final language = appLanguage;
    L10n.current = lookupAppLocalizations(language.locale);
    // Dates and numbers formatted anywhere in the app follow the app
    // language too. English leaves intl's default alone, exactly as it was
    // before the app had any other language. The symbol data is bundled with
    // intl and loads synchronously; the returned future is only API shape.
    if (language.code == englishLanguageCode) {
      Intl.defaultLocale = null;
    } else {
      final formatting = language.formattingLocale;
      unawaited(initializeDateFormatting(formatting));
      Intl.defaultLocale = formatting;
      // The generated strings and Material format their numbers with the
      // plain language code (`ar`), not the default locale, so that code
      // gets the formatting locale's symbols too.
      final symbols = numberFormatSymbols[formatting];
      if (formatting != language.code && symbols != null) {
        numberFormatSymbols[language.code] = symbols;
      }
      // And both get the language's own digits and am/pm, which intl's data
      // lacks for Urdu and Gujarati.
      applyIntlSymbols(language, L10n.current);
    }
  }

  /// Loads the zikr titles in the app language and the zikr content in the
  /// translation language. Both are settled before either loads, so a
  /// language change mid-load cannot mix them.
  Future<void> _applyZikrLanguages() async {
    _loadFonts();
    final titles = appFollowingTranslationLanguage.code;
    final content = translationLanguage.code;
    final translations = ZikrTranslations.instance;
    await translations.setTitleLanguage(titles, _bundle);
    await translations.setLanguage(content, _bundle);
  }

  Future<void> _persist(String key, String? code) async {
    if (!SP.isInitialized) return;
    if (code == null) {
      await SP.prefs.remove(key);
    } else {
      await SP.prefs.setString(key, code);
    }
  }

  /// Following the device, a change of device language is a change of app
  /// language.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_appLanguageChoice != null) return;
    unawaited(_followDeviceLanguage());
  }

  Future<void> _followDeviceLanguage() async {
    await _applyZikrLanguages();
    _applyAppLanguage();
    notifyListeners();
    unawaited(LocationService.instance.relabelForAppLanguage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
