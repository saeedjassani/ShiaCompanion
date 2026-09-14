import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/prayer_notifications_sheet.dart';
import 'package:shia_companion/widgets/prayer_times_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    lat = null;
    long = null;
  });

  group('prayer notification preferences', () {
    test('soundPreferenceKeyForPrayer normalizes names including dhuhr/zuhr', () {
      expect(soundPreferenceKeyForPrayer('Fajr'), 'fajr_notification_sound');
      expect(soundPreferenceKeyForPrayer('Zuhr'), 'dhuhr_notification_sound');
      expect(soundPreferenceKeyForPrayer('Dhuhr'), 'dhuhr_notification_sound');
      expect(soundPreferenceKeyForPrayer('Isha'), 'isha_notification_sound');
    });

    test('getAzaanOptionForPrayer falls back to getSelectedAzaan by default', () {
      expect(hasCustomAzaanPreferenceForPrayer('Fajr'), isFalse);
      expect(getAzaanOptionForPrayer('Fajr').id, getSelectedAzaan().id);
    });

    test('saveAzaanPreferenceForPrayer saves and resets per-prayer sound', () async {
      await saveAzaanPreferenceForPrayer('Fajr', 'takbir');
      expect(hasCustomAzaanPreferenceForPrayer('Fajr'), isTrue);
      expect(getAzaanOptionForPrayer('Fajr').id, 'takbir');

      // Reset to app default
      await saveAzaanPreferenceForPrayer('Fajr', 'app_default');
      expect(hasCustomAzaanPreferenceForPrayer('Fajr'), isFalse);
      expect(getAzaanOptionForPrayer('Fajr').id, getSelectedAzaan().id);
    });

    test('supports silent notification sound option', () async {
      await saveAzaanPreferenceForPrayer('Asr', 'silent');
      expect(getAzaanOptionForPrayer('Asr').id, 'silent');
    });

    test(
        'getAzaanOptionForPrayer falls back rather than resolving to custom',
        () async {
      // There is only one custom audio file on disk, backing the global
      // azaan preference — a per-prayer 'custom' override has no file of its
      // own to point at, so it must fall back to the app default rather than
      // silently scheduling a notification with no sound.
      await saveAzaanPreferenceForPrayer('Fajr', 'custom');
      expect(getAzaanOptionForPrayer('Fajr').id, isNot('custom'));
      expect(getAzaanOptionForPrayer('Fajr').id, getSelectedAzaan().id);
    });
  });

  group('PrayerNotificationsSheet widget', () {
    testWidgets('renders all 8 prayers and applies Obligatory Only preset',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPrayerNotificationsSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Prayer Notifications'), findsOneWidget);
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Sunrise'), findsOneWidget);
      expect(find.text('Zuhr'), findsOneWidget);
      expect(find.text('Asr'), findsOneWidget);
      expect(find.text('Sunset'), findsOneWidget);
      expect(find.text('Maghrib'), findsOneWidget);
      expect(find.text('Isha'), findsOneWidget);
      expect(find.text('Midnight'), findsOneWidget);

      // Tap Obligatory Only preset
      await tester.tap(find.text('Obligatory Only'));
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Fajr')), isTrue);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Zuhr')), isTrue);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Asr')), isTrue);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Maghrib')), isTrue);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Isha')), isTrue);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Sunrise')), isFalse);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Sunset')), isFalse);
      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Midnight')), isFalse);
    });

    testWidgets('Mute All turns off all prayers', (tester) async {
      await SP.prefs.setBool(notificationPreferenceKeyForPrayer('Fajr'), true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPrayerNotificationsSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mute All'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      for (final prayer in kPrayerNotificationList) {
        expect(
          SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayer)),
          isFalse,
        );
      }
    });

    testWidgets('per-prayer sound picker excludes Custom Audio',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPrayerNotificationsSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Obligatory Only'));
      await tester.pumpAndSettle();

      // Fajr is now enabled and shows its sound row ("Default (...)") first
      // in the list — tap it to open the per-prayer sound picker.
      await tester.tap(find.textContaining('Default').first);
      await tester.pumpAndSettle();

      expect(find.text('Fajr Notification Sound'), findsOneWidget);
      expect(find.text('App Default'), findsOneWidget);
      // Custom Audio has no per-prayer file of its own to point at (there is
      // only the one file backing the global azaan preference), so it must
      // not be offered here.
      expect(find.text('Custom Audio'), findsNothing);
    });
  });

  group('PrayerTimesCard notification toggle', () {
    testWidgets('shows bell icon and toggles notification on tap with SnackBar',
        (tester) async {
      lat = 32.02;
      long = 44.34;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrayerTimesCard(
              date: DateTime(2026, 9, 13),
              showNotificationControls: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially off, should show notifications_off_outlined
      expect(find.byIcon(Icons.notifications_off_outlined), findsWidgets);

      // Tap the first toggle (Fajr)
      await tester.tap(find.byIcon(Icons.notifications_off_outlined).first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(SP.prefs.getBool(notificationPreferenceKeyForPrayer('Fajr')), isTrue);
      expect(find.textContaining('Fajr reminder enabled'), findsOneWidget);
    });
  });
}
