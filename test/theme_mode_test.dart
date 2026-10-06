import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/theme_mode.dart';

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SP.init();
}

/// Lets the provider's constructor finish reading prefs.
Future<ThemeModeProvider> _loaded() async {
  final provider = ThemeModeProvider();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  group('a fresh install', () {
    test('follows the phone', () async {
      await _prefs({});
      expect(ThemeModeProvider.readStored(), ThemeMode.system);
      expect((await _loaded()).themeMode, ThemeMode.system);
    });
  });

  group('an install from before the Theme setting keeps its Dark mode switch',
      () {
    test('on stays Dark', () async {
      await _prefs({'darkMode': true});
      expect(ThemeModeProvider.readStored(), ThemeMode.dark);
    });

    test('off stays Light', () async {
      await _prefs({'darkMode': false});
      expect(ThemeModeProvider.readStored(), ThemeMode.light);
    });
  });

  test('the new setting wins over the old flag', () async {
    await _prefs({'themeMode': 'system', 'darkMode': true});
    expect(ThemeModeProvider.readStored(), ThemeMode.system);
  });

  test('an unreadable value falls back to the old flag', () async {
    await _prefs({'themeMode': 'sepia', 'darkMode': true});
    expect(ThemeModeProvider.readStored(), ThemeMode.dark);
  });

  group('setThemeMode', () {
    test('stores the choice and notifies', () async {
      await _prefs({});
      final provider = await _loaded();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setThemeMode(ThemeMode.dark);

      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, 1);
      expect(SP.prefs.getString('themeMode'), 'dark');
      expect(ThemeModeProvider.readStored(), ThemeMode.dark);
    });

    test('keeps the old flag in step, and drops it for Same as phone',
        () async {
      await _prefs({'darkMode': true});
      final provider = await _loaded();

      await provider.setThemeMode(ThemeMode.light);
      expect(SP.prefs.getBool('darkMode'), isFalse);

      await provider.setThemeMode(ThemeMode.system);
      expect(SP.prefs.containsKey('darkMode'), isFalse);
      expect(SP.prefs.getString('themeMode'), 'system');
    });

    test('choosing the current mode changes nothing', () async {
      await _prefs({});
      final provider = await _loaded();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setThemeMode(ThemeMode.system);

      expect(notified, 0);
      expect(SP.prefs.containsKey('themeMode'), isFalse);
    });
  });

  test('labels say what the setting shows', () {
    expect(ThemeModeProvider.label(ThemeMode.light), 'Light');
    expect(ThemeModeProvider.label(ThemeMode.dark), 'Dark');
    expect(ThemeModeProvider.label(ThemeMode.system), 'Same as phone');
  });
}
