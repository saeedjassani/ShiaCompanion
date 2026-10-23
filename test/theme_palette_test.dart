import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/theme/app_palette.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/theme_palette.dart';

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SP.init();
}

/// Lets the provider's constructor finish reading prefs.
Future<ThemePaletteProvider> _loaded() async {
  final provider = ThemePaletteProvider();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  test('a fresh install is brown', () async {
    await _prefs({});
    expect((await _loaded()).palette, AppPalette.brown);
  });

  test('reads the stored color, and falls back to brown on one it lacks',
      () async {
    await _prefs({'themePalette': 'green'});
    expect((await _loaded()).palette, AppPalette.green);

    await _prefs({'themePalette': 'sparkly'});
    expect(ThemePaletteProvider.readStored(), AppPalette.brown);
  });

  test('saves the chosen color and tells listeners', () async {
    await _prefs({});
    final provider = await _loaded();
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setPalette(AppPalette.teal);
    await provider.setPalette(AppPalette.teal);

    expect(notified, 1);
    expect(provider.palette, AppPalette.teal);
    expect(SP.prefs.getString('themePalette'), 'teal');
  });

  test('labels say what the setting shows', () {
    expect(AppPalette.brown.label(), 'Brown');
    expect(AppPalette.clear.label(), 'Clear');
    expect(AppPalette.gray.label(), 'Gray');
  });
}
