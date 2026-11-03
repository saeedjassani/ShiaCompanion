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
import 'package:shia_companion/utils/app_text_scale.dart';
import 'package:shia_companion/utils/language_provider.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/sign_in_flow.dart';
import 'package:shia_companion/utils/theme_mode.dart';
import 'package:shia_companion/utils/theme_palette.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';

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

    test('only the first launch of a fresh install counts as fresh', () async {
      // main.dart signs out a sign-in iOS kept in the Keychain from an
      // earlier install on this launch - never on a later one, which may be
      // resuming a setup the person signed in during.
      await _prefs({});
      await FirstRunSetup.resolveOnLaunch(isWeb: false);
      expect(FirstRunSetup.freshInstallThisLaunch, isTrue);

      await FirstRunSetup.resolveOnLaunch(isWeb: false);
      expect(FirstRunSetup.freshInstallThisLaunch, isFalse);
    });

    test('an existing install is never fresh', () async {
      await _prefs({'lat': 24.8});
      await FirstRunSetup.resolveOnLaunch(isWeb: false);
      expect(FirstRunSetup.freshInstallThisLaunch, isFalse);
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
    late AppTextScaleProvider textScale;
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
      textScale = AppTextScaleProvider();
      done = 0;
    });

    Future<void> pumpSetup(
      WidgetTester tester, {
      Future<Object?> Function(BuildContext, SignInProvider)? signIn,
    }) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeMode),
          ChangeNotifierProvider(create: (_) => ThemePaletteProvider()),
          ChangeNotifierProvider.value(value: textScale),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
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
      expect(find.text('Salamun Alaikum'), findsOneWidget);
      // Language and text size come first, so every step reads well.
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('App text size'), findsOneWidget);

      await tapText(tester, 'Skip setup');

      expect(done, 1);
      expect(SP.prefs.getString(FirstRunSetup.stateKey), FirstRunSetup.done);
      // No location, so azan is left unanswered: it is asked once one is
      // set, on Home's prayer card.
      expect(AzaanOptInService.hasBeenAsked, isFalse);
      expect(AzaanOptInService.isEnabled, isFalse);
      expect(SP.prefs.containsKey('arabic_font'), isFalse);
      expect(themeMode.themeMode, ThemeMode.system);
    });

    testWidgets('walks through every step, applying each choice',
        (tester) async {
      // As if an earlier launch had got as far as setting a location.
      lat = 51.5;
      long = -0.12;
      await pumpSetup(tester);
      // The welcome sizes the whole app's text, so every step reads well.
      await tester.ensureVisible(find.bySemanticsLabel('Bigger text'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Bigger text'));
      await tester.pumpAndSettle();
      expect(find.text('110%'), findsOneWidget);
      expect(SP.prefs.getDouble(AppTextScaleProvider.prefsKey), 1.1);
      await tapText(tester, 'Get started');

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Prayer times for your city'), findsOneWidget);
      await tapText(tester, 'Not now');

      expect(find.text('Step 2 of 5'), findsOneWidget);
      // The five switches, with Fajr, Zuhr and Maghrib on.
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
      await tapText(tester, 'Continue');

      expect(SP.prefs.getString('arabic_font'), 'Scheherazade');
      expect(SP.prefs.containsKey('ara_font_size'), isFalse);

      expect(find.text('Light or dark?'), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeMode.themeMode, ThemeMode.dark);
      await tapText(tester, 'Continue');

      expect(find.text('Keep everything safe'), findsOneWidget);
      // On the last step Maybe later already ends setup.
      expect(find.text('Skip setup'), findsNothing);
      await tapText(tester, 'Maybe later');

      expect(done, 1);
      expect(SP.prefs.getString(FirstRunSetup.stateKey), FirstRunSetup.done);
      expect(SP.prefs.getString(ThemeModeProvider.prefsKey), 'dark');
    });

    testWidgets('Arabic as the app language starts the font on Scheherazade',
        (tester) async {
      await _prefs({
        FirstRunSetup.stateKey: FirstRunSetup.pending,
        LanguageProvider.appLanguagePrefsKey: 'ar',
      });
      await pumpSetup(tester);
      expect(arabicFont, 'Scheherazade');
      // Only a default: nothing is saved until the reader chooses or finishes.
      expect(SP.prefs.containsKey('arabic_font'), isFalse);
    });

    testWidgets('Skip setup on a step ends setup, keeping what was chosen',
        (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Not now'); // Location; with none, no Azan step

      await tester.tap(find.text('Scheherazade'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Continue');

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Skip setup');

      expect(done, 1);
      expect(SP.prefs.getString(FirstRunSetup.stateKey), FirstRunSetup.done);
      expect(SP.prefs.getString('arabic_font'), 'Scheherazade');
      expect(themeMode.themeMode, ThemeMode.dark);
      expect(AzaanOptInService.hasBeenAsked, isFalse);
    });

    testWidgets('Skip setup on the Azan step leaves azan off', (tester) async {
      lat = 51.5;
      long = -0.12;
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Not now');
      expect(find.text('Hear the azan at prayer time?'), findsOneWidget);

      await tapText(tester, 'Skip setup');

      expect(done, 1);
      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.isEnabled, isFalse);
    });

    testWidgets('back goes to the step before', (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Not now');
      expect(find.text('Step 2 of 4'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(done, 0);
    });

    testWidgets('without a location there is no Azan step', (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(SP.prefs.getBool(PrayerTimesState.cityPromptDismissedKey), isNull);
      await tapText(tester, 'Not now');

      expect(find.text('Step 2 of 4'), findsOneWidget);
      // Home's card won't ask for a city again; it shows its slim row.
      expect(SP.prefs.getBool(PrayerTimesState.cityPromptDismissedKey), isTrue);
      expect(find.text('Hear the azan at prayer time?'), findsNothing);
      expect(find.text('How should Arabic look?'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tapText(tester, 'Continue');
      }
      await tapText(tester, 'Maybe later');

      expect(done, 1);
      // Left for when a location is set.
      expect(AzaanOptInService.hasBeenAsked, isFalse);
    });

    testWidgets('signing in finishes setup', (tester) async {
      final asked = <SignInProvider>[];
      await pumpSetup(tester, signIn: (_, provider) async {
        asked.add(provider);
        return 'a user';
      });
      await tapText(tester, 'Get started');
      await tapText(tester, 'Not now');
      for (var i = 0; i < 2; i++) {
        await tapText(tester, 'Continue');
      }

      await tapText(tester, 'Continue with Google');

      expect(asked, [SignInProvider.google]);
      expect(done, 1);
    });

    testWidgets('a cancelled sign-in stays on the step', (tester) async {
      await pumpSetup(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Not now');
      for (var i = 0; i < 2; i++) {
        await tapText(tester, 'Continue');
      }

      await tapText(tester, 'Continue with Google');

      expect(done, 0);
      expect(find.text('Keep everything safe'), findsOneWidget);
    });
  });

  testWidgets('the gate opens on the app once setup is done', (tester) async {
    await _prefs({FirstRunSetup.stateKey: FirstRunSetup.pending});
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
        ChangeNotifierProvider(create: (_) => ThemePaletteProvider()),
        ChangeNotifierProvider(create: (_) => AppTextScaleProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
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
    expect(find.text('Salamun Alaikum'), findsNothing);
  });
}
