import 'package:flutter/material.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// The Theme setting: Light, Dark or Same as phone.
///
/// Fresh installs follow the phone ([ThemeMode.system]). An install from
/// before the setting existed keeps what its old Dark mode switch held: the
/// `darkMode` flag it wrote maps to Light or Dark, and an install that never
/// touched the switch had no flag - it was already following the phone's
/// brightness at launch, which is what Same as phone does (now live, rather
/// than only at launch).
class ThemeModeProvider extends ChangeNotifier {
  static const String prefsKey = 'themeMode';

  /// The old Dark mode switch's key. Still written alongside [prefsKey] for
  /// Light and Dark (and removed for Same as phone), so a build from before
  /// this setting, should one ever run on the same data again, shows the
  /// same thing.
  static const String legacyDarkModeKey = 'darkMode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeModeProvider() {
    _load();
  }

  Future<void> _load() async {
    await SP.init();
    final next = readStored();
    if (next == _themeMode) return;
    _themeMode = next;
    notifyListeners();
  }

  /// What the stored preferences say, migrating the old switch's flag.
  @visibleForTesting
  static ThemeMode readStored() {
    final stored = parse(SP.prefs.getString(prefsKey));
    if (stored != null) return stored;
    return switch (SP.prefs.getBool(legacyDarkModeKey)) {
      true => ThemeMode.dark,
      false => ThemeMode.light,
      null => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    if (!SP.isInitialized) await SP.init();
    await SP.prefs.setString(prefsKey, mode.name);
    if (mode == ThemeMode.system) {
      await SP.prefs.remove(legacyDarkModeKey);
    } else {
      await SP.prefs.setBool(legacyDarkModeKey, mode == ThemeMode.dark);
    }
  }

  static ThemeMode? parse(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  /// The words the setting shows for [mode].
  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Same as phone',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
