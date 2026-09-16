import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/prayer_notifications_page.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    // The fingerprint names the local zone, which is otherwise uninitialised
    // outside the app.
    ensureTimeZoneDatabaseInitialized();
    tz.setLocalLocation(tz.UTC);
    // No coordinates, so setUpNotifications returns before it reaches the
    // notification plugin — these are about preferences, not the scheduler.
    lat = null;
    long = null;
  });

  group('per-prayer preference keys', () {
    test('normalize names, treating Zuhr and Dhuhr as one prayer', () {
      expect(notificationPreferenceKeyForPrayer('Fajr'), 'fajr_notification');
      expect(soundPreferenceKeyForPrayer('Zuhr'), 'dhuhr_notification_sound');
      expect(soundPreferenceKeyForPrayer('Dhuhr'), 'dhuhr_notification_sound');
      expect(
        customAudioPathKeyForPrayer('Zuhr'),
        'dhuhr_notification_sound_custom_path',
      );
      expect(
        customAudioPathKeyForPrayer('Isha'),
        'isha_notification_sound_custom_path',
      );
    });

    test('a prayer follows the app default until it is given a sound', () async {
      expect(hasCustomAzaanPreferenceForPrayer('Fajr'), isFalse);
      expect(getAzaanOptionForPrayer('Fajr').id, getSelectedAzaan().id);

      await saveAzaanPreferenceForPrayer('Fajr', 'takbir');
      expect(hasCustomAzaanPreferenceForPrayer('Fajr'), isTrue);
      expect(getAzaanOptionForPrayer('Fajr').id, 'takbir');

      await saveAzaanPreferenceForPrayer('Fajr', 'app_default');
      expect(hasCustomAzaanPreferenceForPrayer('Fajr'), isFalse);
      expect(getAzaanOptionForPrayer('Fajr').id, getSelectedAzaan().id);
    });

    test('silent is selectable per prayer', () async {
      await saveAzaanPreferenceForPrayer('Asr', 'silent');
      expect(getAzaanOptionForPrayer('Asr').id, 'silent');
    });
  });

  group('per-prayer custom audio', () {
    test('resolves to the file that prayer recorded for itself', () async {
      await saveCustomAudioFilePathForPrayer('Maghrib', '/tmp/my-azan.mp3');
      await saveAzaanPreferenceForPrayer('Maghrib', 'custom');

      expect(getAzaanOptionForPrayer('Maghrib').id, 'custom');
      expect(getCustomAudioFilePathForPrayer('Maghrib'), '/tmp/my-azan.mp3');
    });

    test('two prayers can point at two different files', () async {
      await saveCustomAudioFilePathForPrayer('Fajr', '/tmp/quiet.mp3');
      await saveAzaanPreferenceForPrayer('Fajr', 'custom');
      await saveCustomAudioFilePathForPrayer('Isha', '/tmp/loud.mp3');
      await saveAzaanPreferenceForPrayer('Isha', 'custom');

      expect(getCustomAudioFilePathForPrayer('Fajr'), '/tmp/quiet.mp3');
      expect(getCustomAudioFilePathForPrayer('Isha'), '/tmp/loud.mp3');
    });

    test('falls back to the app default when no file backs the choice',
        () async {
      // 'custom' with nothing recorded has no sound to play, so honouring it
      // would schedule a silent notification the user never asked for.
      await saveAzaanPreferenceForPrayer('Fajr', 'custom');

      expect(getCustomAudioFilePathForPrayer('Fajr'), isNull);
      expect(getAzaanOptionForPrayer('Fajr').id, isNot('custom'));
      expect(getAzaanOptionForPrayer('Fajr').id, getSelectedAzaan().id);
    });

    test('a prayer following the default inherits the global custom file',
        () async {
      await saveCustomAudioFilePath('/tmp/global.mp3');
      await saveAzaanPreference('custom');

      // Asr has no sound of its own, so it uses whatever the default points at.
      expect(getCustomAudioFilePathForPrayer('Asr'), '/tmp/global.mp3');
    });

    test('the custom file is part of the schedule fingerprint', () async {
      await SP.prefs.setBool(notificationPreferenceKeyForPrayer('Fajr'), true);
      await saveCustomAudioFilePathForPrayer('Fajr', '/tmp/first.mp3');
      await saveAzaanPreferenceForPrayer('Fajr', 'custom');
      final before = buildPrayerNotificationScheduleFingerprint(
        scheduleDate: DateTime(2026, 9, 16),
      );

      await saveCustomAudioFilePathForPrayer('Fajr', '/tmp/second.mp3');
      final after = buildPrayerNotificationScheduleFingerprint(
        scheduleDate: DateTime(2026, 9, 16),
      );

      // Swapping the file without swapping the option must still force a
      // rebuild, or the old sound stays scheduled.
      expect(after, isNot(before));
    });
  });

  group('the master switch is reversible', () {
    test('restores the exact set it muted, not the default three', () async {
      // A hand-picked selection: two times the defaults would never include.
      await SP.prefs.setBool(notificationPreferenceKeyForPrayer('Isha'), true);
      await SP.prefs
          .setBool(notificationPreferenceKeyForPrayer('Midnight'), true);
      expect(AzaanOptInService.isEnabled, isTrue);

      await AzaanOptInService.setEnabled(false);
      expect(AzaanOptInService.isEnabled, isFalse);

      await AzaanOptInService.setEnabled(true);

      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Isha')),
          isTrue);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Midnight')),
          isTrue);
      // And nothing the user never chose was switched on for them.
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Fajr')),
          isFalse);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Zuhr')),
          isFalse);
    });

    test('falls back to the defaults when there is nothing to restore',
        () async {
      await SP.prefs.setBool(AzaanOptInService.askedKey, true);
      expect(AzaanOptInService.isEnabled, isFalse);

      await AzaanOptInService.setEnabled(true);

      expect(
        AzaanOptInService.allPrayerKeys
            .where((k) => SP.prefs.getBool(k) == true)
            .toSet(),
        AzaanOptInService.defaultEnabledPrayerKeys.toSet(),
      );
    });

    test('per-prayer sounds survive a mute and unmute', () async {
      await SP.prefs.setBool(notificationPreferenceKeyForPrayer('Isha'), true);
      await saveAzaanPreferenceForPrayer('Isha', 'takbir');

      await AzaanOptInService.setEnabled(false);
      await AzaanOptInService.setEnabled(true);

      expect(getAzaanOptionForPrayer('Isha').id, 'takbir');
    });
  });

  group('PrayerNotificationsPage', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: PrayerNotificationsPage()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists every time in chronological order, ungrouped',
        (tester) async {
      await pumpPage(tester);

      for (final prayer in kPrayerNotificationList) {
        expect(find.text(prayer), findsOneWidget, reason: prayer);
      }
      // One flat list: the "prayers vs other times" split would have reordered
      // Sunrise, Sunset and Midnight away from where every other screen puts
      // them.
      expect(find.text('Prayers'), findsNothing);
      expect(find.text('Other times'), findsNothing);
    });

    testWidgets('a switch writes immediately, with no Done button',
        (tester) async {
      await pumpPage(tester);

      expect(find.text('Done'), findsNothing);

      // The first row switch after the master one is Fajr.
      final switches = find.byType(Switch);
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();

      expect(
        SP.prefs.getBool(notificationPreferenceKeyForPrayer('Fajr')),
        isTrue,
      );
      // And the change is announced with a way back out of it.
      expect(find.text('UNDO'), findsOneWidget);
    });

    testWidgets('an explicit change counts as answering the opt-in question',
        (tester) async {
      expect(AzaanOptInService.hasBeenAsked, isFalse);

      await pumpPage(tester);
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      // Otherwise the first-run dialog could still ambush someone who has
      // already configured their notifications by hand.
      expect(AzaanOptInService.hasBeenAsked, isTrue);
      expect(AzaanOptInService.shouldAsk(hasLocation: true), isFalse);
    });
  });
}
