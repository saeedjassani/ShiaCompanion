import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system locale (null)', () async {
    final provider = LocaleProvider();
    // Allow async _loadLocalePreference to complete
    await Future<void>.delayed(Duration.zero);

    expect(provider.locale, isNull);
    expect(provider.isSystemDefault, isTrue);
  });

  test('loads stored locale from preferences', () async {
    SharedPreferences.setMockInitialValues({
      LocaleProvider.localeKey: 'fr',
    });

    final provider = LocaleProvider();
    await Future<void>.delayed(Duration.zero);

    expect(provider.locale, equals(const Locale('fr')));
    expect(provider.isSystemDefault, isFalse);
  });

  test('setting locale notifies listeners and updates preference', () async {
    final provider = LocaleProvider();
    await Future<void>.delayed(Duration.zero);

    var notified = false;
    provider.addListener(() {
      notified = true;
    });

    await provider.setLocale(const Locale('fr'));

    expect(notified, isTrue);
    expect(provider.locale, equals(const Locale('fr')));
    expect(provider.isSystemDefault, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocaleProvider.localeKey), equals('fr'));

    // Reset back to system default
    await provider.setLocale(null);
    expect(provider.locale, isNull);
    expect(provider.isSystemDefault, isTrue);
    expect(prefs.getString(LocaleProvider.localeKey), isNull);
  });
}
