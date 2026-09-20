import 'package:flutter/material.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  static const String localeKey = 'app_language_code';

  Locale? get locale => _locale;
  bool get isSystemDefault => _locale == null;

  LocaleProvider() {
    _loadLocalePreference();
  }

  Future<void> _loadLocalePreference() async {
    await SP.init();
    final storedCode = SP.prefs.getString(localeKey);
    if (storedCode != null && storedCode.isNotEmpty && storedCode != 'system') {
      _locale = Locale(storedCode);
    } else {
      _locale = null;
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();

    if (newLocale == null) {
      await SP.prefs.remove(localeKey);
    } else {
      await SP.prefs.setString(localeKey, newLocale.languageCode);
    }
  }
}
