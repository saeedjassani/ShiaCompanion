import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shia_companion/utils/shared_preferences.dart';

class DarkModeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final String _darkModeKey =
      'darkMode'; // Key to store the dark mode preference in SharedPreferences

  bool get isDarkMode => _isDarkMode;

  DarkModeProvider() {
    _loadDarkModePreference();
  }

  Future<void> _loadDarkModePreference() async {
    await SP.init();
    final storedPreference = SP.prefs.getBool(_darkModeKey);
    final platformBrightness =
        ui.PlatformDispatcher.instance.platformBrightness;

    _isDarkMode =
        storedPreference ?? platformBrightness == Brightness.dark;
    notifyListeners();
  }

  void toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    await SP.prefs.setBool(_darkModeKey, _isDarkMode);
  }
}
