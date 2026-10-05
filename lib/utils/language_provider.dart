import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../services/zikr_translations.dart';
import 'shared_preferences.dart';

/// The two language choices a reader makes:
///
/// * the **app language** - menus, buttons, settings, notifications - backed
///   by the `lib/l10n/app_<code>.arb` files, and
/// * the **translation language** - what a zikr's translation lines,
///   instructions, merits and title are shown in - backed by
///   `assets/zikr_i18n/<code>/`.
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

  /// The language the app is actually shown in: the reader's choice if it
  /// has shipped, otherwise the device's language if that has, otherwise
  /// English.
  AppLanguage get appLanguage {
    final available = appTextLanguages;
    AppLanguage? shipped(String? code) {
      for (final language in available) {
        if (language.code == code) return language;
      }
      return null;
    }

    final chosen = shipped(_appLanguageChoice);
    if (chosen != null) return chosen;
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      final device = shipped(locale.languageCode);
      if (device != null) return device;
    }
    return englishLanguage;
  }

  Locale get locale => appLanguage.locale;

  /// The language zikr translations are wanted in. Lines nobody has
  /// translated into it yet still show in English.
  AppLanguage get translationLanguage {
    final code = _translationLanguageChoice ?? appLanguage.code;
    return _translationLanguageCodes.contains(code)
        ? appLanguageFor(code) ?? englishLanguage
        : englishLanguage;
  }

  Future<void> _load() async {
    await SP.init();
    _appLanguageChoice = SP.prefs.getString(appLanguagePrefsKey);
    _translationLanguageChoice =
        SP.prefs.getString(translationLanguagePrefsKey);
    _translationLanguageCodes =
        await ZikrTranslations.instance.availableLanguageCodes(_bundle);
    _applyAppLanguage();
    await _applyTranslationLanguage();
    notifyListeners();
  }

  /// Sets the app language; null goes back to following the device.
  Future<void> setAppLanguage(String? code) async {
    if (code == _appLanguageChoice) return;
    _appLanguageChoice = code;
    _applyAppLanguage();
    notifyListeners();
    await _applyTranslationLanguage();
    await _persist(appLanguagePrefsKey, code);
  }

  /// Sets the translation language; null goes back to following the app
  /// language.
  Future<void> setTranslationLanguage(String? code) async {
    if (code == _translationLanguageChoice) return;
    _translationLanguageChoice = code;
    notifyListeners();
    await _applyTranslationLanguage();
    await _persist(translationLanguagePrefsKey, code);
  }

  void _applyAppLanguage() {
    L10n.current = lookupAppLocalizations(appLanguage.locale);
  }

  Future<void> _applyTranslationLanguage() =>
      ZikrTranslations.instance.setLanguage(translationLanguage.code, _bundle);

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
    _applyAppLanguage();
    notifyListeners();
    unawaited(_applyTranslationLanguage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
