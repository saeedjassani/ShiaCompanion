import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/setup/first_run_setup_page.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/services/first_run_setup.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/services/whats_new_service.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/sign_in_flow.dart';
import 'package:shia_companion/utils/theme_mode.dart';

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SP.init();
}

void main() {
  group('who gets setup', () {
    test('a fresh install, until it is finished', () async {
      await _prefs({});

      expect(await FirstRunSetup.resolveOnLaunch(isWeb: false), isTrue);
      expect(await FirstRunSetup.resolveOnLaunch(isWeb: false), isTrue);

      await FirstRunSetup.markDone();
      expect(await FirstRunSetup.resolveOnLaunch(isWeb: false), isFalse);
    });

    test('a half-finished setup is not mistaken for an old install', () async {
      await _prefs({});
      expect(await FirstRunSetup.resolveOnLaunch(isWeb: false), isTrue);

      // What steps 1-4 write, before the app is closed at step 5.
      await SP.prefs.setDouble('lat', 51.5);
      await SP.prefs.setBool(AzaanOptInService.askedKey, true);
      await SP.prefs.setString(ThemeModeProvider.prefsKey, 'dark');

      expect(await FirstRunSetup.resolveOnLaunch(isWeb: false), isTrue);
    });

    for (final marker in <String, Object>{
      'lat': 24.8,
      WhatsNewService.lastSeenBuildKey: 120,
      AzaanOptInService.askedKey: true,
      'fajr_notification': false,
      azaanPreferenceKey: 'makkah',
      ThemeModeProvider.legacyDarkModeKey: true,
      'arabic_font': 'Qalam',
    }.entries) {
      test('not an install that has run before (${marker.key})', () async {
        await _prefs({marker.key: marker.value});
        expect(await FirstRunSetup.resolveOnLaunch(isWeb: false), isFalse);
        expect(SP.prefs.getString(FirstRunSetup.stateKey), FirstRunSetup.done);
      });
    }

    test(
        'an earlier install keeps transliteration on, a new one starts without',
        () async {
      await _prefs({'lat': 24.8});
      await FirstRunSetup.resolveOnLaunch(isWeb: false);
      expect(SP.prefs.getBool(FirstRunSetup.transliterationKey), isTrue);

      await _prefs({'lat': 24.8, FirstRunSetup.transliterationKey: false});
      await FirstRunSetup.resolveOnLaunch(isWeb: false);
      expect(SP.prefs.getBool(FirstRunSetup.transliterationKey), isFalse);

      await _prefs({});
      await FirstRunSetup.resolveOnLaunch(isWeb: false);
      expect(SP.prefs.containsKey(FirstRunSetup.transliterationKey), isFalse);
    });

    test('never on the web', () async {
      await _prefs({});
      expect(await FirstRunSetup.resolveOnLaunch(isWeb: true), isFalse);
      expect(SP.prefs.containsKey(FirstRunSetup.stateKey), isFalse);
    });
  });

  group('the setup flow', () {
    late ThemeModeProvider themeMode;
    late int done;

    setUp(() async {
      await _prefs({FirstRunSetup.stateKey: FirstRunSetup.pending});
      lat = null;
      long = null;
      city = null;
      arabicFont = 'Qalam';
      arabicFontSize = 32;
      LocationService.instance.resetForTest();
      themeMode = ThemeModeProvider();
      done = 0;
    });

    Future<void> pumpSetup(
      WidgetTester tester, {
      Future<Object?> Function(BuildContext, SignInProvider)? signIn,
    }) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: themeMode,
        child: Consumer<ThemeModeProvider>(
          builder: (context, provider, _) => MaterialApp(
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: provider.themeMode,
            home: FirstRunSetupPage(
              onDone: () => done++,
              signIn: signIn ?? (_, __) async => null,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('Skip setup ends it with every default', (tester) async {
      await pumpSetup(tester);
      expect(find.text('Assalamu alaykum'), findsOneWidget);

      await tapText(tester, 'Skip setup');

      expect(done, 1);
      expect(SP.prefs.getString(FirstRunSetup.stateKey), FirstRunSetup.done);
      // Answered as "Not now", so nothing asks again.
      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.isEnabled, isFalse);
      expect(SP.prefs.containsKey('arabic_font'), isFalse);
      expect(themeMode.themeMode, ThemeMode.system);
    });

    testWidgets('walks through every step, applying each choice',
        (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Prayer times for your city'), findsOneWidget);
      await tapText(tester, 'Skip');

      expect(find.text('Step 2 of 5'), findsOneWidget);
      // No location was set, so no times: just the five switches, with
      // Fajr, Zuhr and Maghrib on.
      expect(find.byType(Switch), findsNWidgets(5));
      await tester.tap(find.bySemanticsLabel('Azan for Asr'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Turn on azan');

      expect(
        AzaanOptInService.allPrayerKeys
            .where((k) => SP.prefs.getBool(k) == true)
            .toSet(),
        {
          'fajr_notification',
          'dhuhr_notification',
          'asr_notification',
          'maghrib_notification',
        },
      );

      expect(find.text('How should Arabic look?'), findsOneWidget);
      await tester.tap(find.text('Scheherazade'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.bySemanticsLabel('Bigger Arabic'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Bigger Arabic'));
      await tester.pumpAndSettle();
      expect(find.text('34'), findsOneWidget);
      await tapText(tester, 'Continue');

      expect(SP.prefs.getString('arabic_font'), 'Scheherazade');
      expect(SP.prefs.getDouble('ara_font_size'), 34);

      expect(find.text('Light or dark?'), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeMode.themeMode, ThemeMode.dark);
      await tapText(tester, 'Continue');

      expect(find.text('Keep everything safe'), findsOneWidget);
      // The last step has nothing to skip to; Maybe later is the way on.
      expect(find.text('Skip'), findsNothing);
      await tapText(tester, 'Maybe later');

      expect(done, 1);
      expect(SP.prefs.getString(FirstRunSetup.stateKey), FirstRunSetup.done);
      expect(SP.prefs.getString(ThemeModeProvider.prefsKey), 'dark');
    });

    testWidgets('Skip puts back what a step had changed', (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Skip'); // Location
      await tapText(tester, 'Skip'); // Azan, as Not now

      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.isEnabled, isFalse);

      await tester.tap(find.text('Scheherazade'));
      await tester.pumpAndSettle();
      expect(arabicFont, 'Scheherazade');
      await tapText(tester, 'Skip');
      expect(arabicFont, 'Qalam');

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Skip');
      expect(themeMode.themeMode, ThemeMode.system);
    });

    testWidgets('back goes to the step before', (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Skip');
      expect(find.text('Step 2 of 5'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(done, 0);
    });

    testWidgets('signing in finishes setup', (tester) async {
      final asked = <SignInProvider>[];
      await pumpSetup(tester, signIn: (_, provider) async {
        asked.add(provider);
        return 'a user';
      });
      await tapText(tester, 'Get started');
      for (var i = 0; i < 4; i++) {
        await tapText(tester, 'Skip');
      }

      await tapText(tester, 'Continue with Google');

      expect(asked, [SignInProvider.google]);
      expect(done, 1);
    });

    testWidgets('a cancelled sign-in stays on the step', (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      for (var i = 0; i < 4; i++) {
        await tapText(tester, 'Skip');
      }

      await tapText(tester, 'Continue with Google');

      expect(done, 0);
      expect(find.text('Keep everything safe'), findsOneWidget);
    });
  });

  testWidgets('the gate opens on the app once setup is done', (tester) async {
    await _prefs({FirstRunSetup.stateKey: FirstRunSetup.pending});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => ThemeModeProvider(),
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const FirstRunGate(
          showSetup: true,
          child: Text('The app'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('The app'), findsNothing);

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(find.text('The app'), findsOneWidget);
    expect(find.text('Assalamu alaykum'), findsNothing);
  });
}
