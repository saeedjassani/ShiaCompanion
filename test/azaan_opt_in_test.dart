import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/models/azaan_option.dart';

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
  });

  group('answering the question', () {
    test('turning azan on in setup enables exactly the prayers picked',
        () async {
      await withPrefs({});

      await AzaanOptInService.answer(
          const ['fajr_notification', 'asr_notification']);

      expect(AzaanOptInService.isEnabled, isTrue);
      expect(
        AzaanOptInService.allPrayerKeys
            .where((k) => SP.prefs.getBool(k) == true)
            .toSet(),
        {'fajr_notification', 'asr_notification'},
      );
      expect(AzaanOptInService.hasBeenAsked, isTrue);
    });

    test('"Not now" leaves azan off and counts as answered', () async {
      await withPrefs({});

      await AzaanOptInService.answer(const []);

      expect(AzaanOptInService.isEnabled, isFalse);
      expect(AzaanOptInService.hasBeenAsked, isTrue);
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
    });

    test('is recognised by a sound chosen in Settings', () async {
      await withPrefs({azaanPreferenceKey: 'makkah'});

      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isTrue);
    });

    test('a second launch is not mistaken for an upgrade', () async {
      // buildNumber is written on a fresh install's own first launch, before
      // its setup may have got as far as the Azan step.
      await withPrefs({'buildNumber': 100});

      await AzaanOptInService.adoptChoiceFromExistingInstall();

      expect(AzaanOptInService.hasBeenAsked, isFalse);
    });
  });

  group('what iOS users are told', () {
    test('a Full Azan banner on iOS says to tap; nothing else does', () {
      const tapHint = 'Tap to hear the full azan';
      expect(
        prayerNotificationBody('Fajr', AzaanOptions.azaan, isIOS: true),
        "It's time for fajr · $tapHint",
      );
      expect(
        prayerNotificationBody('Fajr', AzaanOptions.azaan,
            isIOS: false, playsAutomatically: true),
        "It's time for fajr",
      );
      // The Takbir clip already plays in full on iOS, so there is nothing to
      // tap for.
      expect(
        prayerNotificationBody('Fajr', AzaanOptions.takbir, isIOS: true),
        "It's time for fajr",
      );
    });
  });

  group('Android without exact alarms', () {
    // The Azan can only start by itself from an exact alarm; without one
    // Android 12+ refuses (and throws) starting its player in the background.
    test('Full Azan and Custom Audio notifications carry the Takbir instead',
        () {
      for (final option in [AzaanOptions.azaan, AzaanOptions.custom]) {
        expect(
          androidNotificationSoundOption(option, playsAutomatically: false).id,
          AzaanOptions.takbir.id,
        );
        // With exact alarms the player is the sound; the notification stays
        // as it is (silent - see _androidPrayerNotificationDetails).
        expect(
          androidNotificationSoundOption(option, playsAutomatically: true).id,
          option.id,
        );
      }
    });

    test('other sounds are untouched either way', () {
      for (final option in [
        AzaanOptions.takbir,
        AzaanOptions.systemDefault,
        AzaanOptions.silent,
      ]) {
        for (final autoplay in [true, false]) {
          expect(
            androidNotificationSoundOption(option, playsAutomatically: autoplay)
                .id,
            option.id,
          );
        }
      }
    });

    test('the banner says to tap, as it does on iOS', () {
      expect(
        prayerNotificationBody('Fajr', AzaanOptions.azaan,
            isIOS: false, playsAutomatically: false),
        "It's time for fajr · Tap to hear the full azan",
      );
      expect(
        prayerNotificationBody('Zuhr', AzaanOptions.custom,
            isIOS: false, playsAutomatically: false),
        "It's time for zuhr · Tap to play your audio",
      );
      expect(
        prayerNotificationBody('Fajr', AzaanOptions.takbir,
            isIOS: false, playsAutomatically: false),
        "It's time for fajr",
      );
    });
  });
}
