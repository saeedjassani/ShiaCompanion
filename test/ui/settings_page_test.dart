import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/pages/account_page.dart';
import 'package:shia_companion/pages/settings_page.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/app_text_scale.dart';
import 'package:shia_companion/utils/language_provider.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/theme_mode.dart';

import 'firebase_test_doubles.dart';

const _profile = AccountProfile(
  name: 'Zahra Ali',
  initials: 'ZA',
  email: 'zahra@example.com',
  provider: 'Google',
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
  });

  testWidgets('signed out, the first card asks to sign in', (tester) async {
    await _pump(tester, const SettingsPage());

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Keep your favorites safe'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Free. Takes a few seconds.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in, the first card says who and that it is backed up',
      (tester) async {
    await _pump(
      tester,
      SettingsPage(profile: _profile, checkBackup: () async => true),
    );

    expect(find.text('Zahra Ali'), findsOneWidget);
    expect(find.text('zahra@example.com'), findsOneWidget);
    expect(find.text('Backed up'), findsOneWidget);
    expect(find.text('Keep your favorites safe'), findsNothing);
  });

  testWidgets('says so when the backup cannot be confirmed', (tester) async {
    await _pump(
      tester,
      SettingsPage(profile: _profile, checkBackup: () async => false),
    );

    expect(find.text('Offline · backs up when you reconnect'), findsOneWidget);
  });

  testWidgets('each row shows its current value', (tester) async {
    await _pump(tester, const SettingsPage());

    for (final label in [
      'APPEARANCE',
      'PRAYER TIMES',
      'READING',
      'SUPPORT',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Theme'), -200);
    expect(find.text('Same as phone'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('5 times'), findsOneWidget);
  });

  testWidgets('Theme opens the three choices and applies one',
      (tester) async {
    late ThemeModeProvider themes;
    await _pump(tester, const SettingsPage(),
        onThemes: (provider) => themes = provider);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Light or dark, as your phone is set'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(themes.themeMode, ThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget, reason: 'the row shows it');
  });

  testWidgets('Adjust Hijri date moves the date and shows by how much',
      (tester) async {
    await _pump(tester, const SettingsPage());

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust Hijri date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 day ahead'));
    await tester.pumpAndSettle();

    expect(SP.prefs.getInt('adjust_hijri_date'), 1);
    expect(find.text('1 day ahead'), findsOneWidget);
  });

  testWidgets('App text size opens a slider', (tester) async {
    await _pump(tester, const SettingsPage());

    await tester.tap(find.text('App text size'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Makes all text bigger or smaller, including zikr.'),
        findsOneWidget);
  });

  testWidgets('Text & reading opens the reader\'s reading settings',
      (tester) async {
    await _pump(tester, const SettingsPage());

    await tester.ensureVisible(find.text('Text & reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text & reading'));
    await tester.pumpAndSettle();
    expect(find.text('Arabic size'), findsOneWidget);
    expect(find.text('Keep screen on'), findsOneWidget);
  });

  testWidgets('reflows at 1.5x text on a small phone', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      SettingsPage(profile: _profile, checkBackup: () async => true),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  void Function(ThemeModeProvider)? onThemes,
}) async {
  if (tester.view.physicalSize == const Size(2400, 1800)) {
    // A phone rather than the test default's 800 x 600 window.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = ThemeModeProvider();
          onThemes?.call(provider);
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => AppTextScaleProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
