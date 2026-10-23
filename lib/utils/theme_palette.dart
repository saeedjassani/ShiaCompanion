import 'package:flutter/foundation.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/theme/app_palette.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// The Color setting ([AppPalette]). Brown unless someone picks another.
class ThemePaletteProvider extends ChangeNotifier {
  static const String prefsKey = 'themePalette';

  AppPalette _palette = AppPalette.brown;

  AppPalette get palette => _palette;

  ThemePaletteProvider() {
    _load();
  }

  Future<void> _load() async {
    await SP.init();
    final next = readStored();
    if (next == _palette) return;
    _palette = next;
    notifyListeners();
  }

  /// What the stored preferences say; [SP] must be initialised.
  static AppPalette readStored() =>
      AppPalette.parse(SP.prefs.getString(prefsKey)) ?? AppPalette.brown;

  Future<void> setPalette(AppPalette palette) async {
    if (palette == _palette) return;
    _palette = palette;
    notifyListeners();

    if (!SP.isInitialized) await SP.init();
    await SP.prefs.setString(prefsKey, palette.name);
    await HomeScreenWidgetService.instance.publishPalette(palette);
  }
}
