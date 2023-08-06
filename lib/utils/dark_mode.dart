import 'package:flutter/material.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

class DarkModeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  BuildContext context;
  final String _darkModeKey =
      'darkMode'; // Key to store the dark mode preference in SharedPreferences

  bool get isDarkMode => _isDarkMode;

  DarkModeProvider(this.context) {
    _loadDarkModePreference();
  }

  Future<void> _loadDarkModePreference() async {
    await SP.init();
    _isDarkMode = SP.prefs.getBool(_darkModeKey) ??
            MediaQuery.of(context).platformBrightness == Brightness.dark
        ? true
        : false;
    notifyListeners();
  }

  void toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    await SP.prefs.setBool(_darkModeKey, _isDarkMode);
  }
}
