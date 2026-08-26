import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// Azan used to switch itself on the first time the app ran. These pin the
/// replacement: nothing is enabled until the user says so, the question is
/// asked at most once, and an install that predates the question keeps
/// whatever it already had.
void main() {
  setUp(() async {
    // No coordinates, so setUpNotifications returns before it touches the
    // notification plugin — these tests are about the preferences, not the
    // scheduler.
    lat = null;
    long = null;
  });

  Future<void> withPrefs(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    await SP.init();
  }

  bool anyPrayerEnabled() =>
      AzaanOptInService.allPrayerKeys.any((k) => SP.prefs.getBool(k) == true);

  group('a fresh install', () {
    test('does not enable azan by itself', () async {
      await withPrefs({});
      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isFalse);
      expect(AzaanOptInService.isEnabled, isFalse);
      expect(anyPrayerEnabled(), isFalse);
      // Not even written as false: an absent key is how a later launch still
      // recognises an install that has never been asked.
      expect(
        AzaanOptInService.allPrayerKeys.any(SP.prefs.containsKey),
        isFalse,
      );
    });

    test('is asked once there is a location to compute times from', () async {
      await withPrefs({});
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isTrue);
    });

    test('is not asked before a location is known', () async {
      await withPrefs({});
      expect(AzaanOptInService.shouldAsk(hasLocation: false), isFalse);
    });
  });

  group('answering the question', () {
    testWidgets('accepting turns on the default prayers', (tester) async {
      await withPrefs({});
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));

      final enabled = await AzaanOptInService.ask(
        context,
        prompt: (_) async => true,
      );

      expect(enabled, isTrue);
      expect(AzaanOptInService.isEnabled, isTrue);
      expect(
        AzaanOptInService.allPrayerKeys
            .where((k) => SP.prefs.getBool(k) == true)
            .toSet(),
        AzaanOptInService.defaultEnabledPrayerKeys.toSet(),
      );
      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isFalse);
    });

    testWidgets('declining leaves azan off and is not asked again',
        (tester) async {
      await withPrefs({});
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));

      final enabled = await AzaanOptInService.ask(
        context,
        prompt: (_) async => false,
      );

      expect(enabled, isFalse);
      expect(AzaanOptInService.isEnabled, isFalse);
      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isFalse);
    });

    test('Settings is the way back for anyone who declined', () async {
      await withPrefs({AzaanOptInService.askedKey: true});
      expect(AzaanOptInService.isEnabled, isFalse);

      await AzaanOptInService.setEnabled(true);
      expect(AzaanOptInService.isEnabled, isTrue);

      await AzaanOptInService.setEnabled(false);
      expect(AzaanOptInService.isEnabled, isFalse);
      expect(anyPrayerEnabled(), isFalse);
    });
  });

  group('an install that predates the question', () {
    test('keeps the prayers it already had and is never asked', () async {
      await withPrefs({
        'fajr_notification': true,
        'dhuhr_notification': false,
        'maghrib_notification': true,
        'isha_notification': true,
      });

      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isFalse);
      expect(AzaanOptInService.isEnabled, isTrue);
      // The exact selection survives — including the prayer this user had
      // deliberately muted.
      expect(SP.prefs.getBool('fajr_notification'), isTrue);
      expect(SP.prefs.getBool('dhuhr_notification'), isFalse);
      expect(SP.prefs.getBool('isha_notification'), isTrue);
    });

    test('is not switched back on when it had azan fully muted', () async {
      await withPrefs({
        for (final key in AzaanOptInService.allPrayerKeys) key: false,
      });

      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.isEnabled, isFalse);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isFalse);
    });

    test('is recognised by a sound chosen in Settings', () async {
      await withPrefs({azaanPreferenceKey: 'makkah'});

      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isFalse);
    });

    test('a second launch is not mistaken for an upgrade', () async {
      // buildNumber is written on a fresh install's own first launch. Someone
      // whose first launch had no location fix, and so was never asked, must
      // still get the question on the launch that finally has one.
      await withPrefs({'buildNumber': 100});

      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isFalse);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isTrue);
    });
  });
}
