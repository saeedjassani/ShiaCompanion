import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/azaan_opt_in_dialog.dart';

/// How the question gets put to the user. Injectable so tests can answer it
/// without pumping a dialog.
typedef AzaanOptInPrompt = Future<bool> Function(BuildContext context);

/// Owns the one-time "may we play the azan at prayer times?" question.
///
/// Azan used to switch itself on the first time the app ran: the per-prayer
/// preferences were written with Fajr, Zuhr and Maghrib already true, and the
/// scheduler picked them up on the same launch. Nothing is enabled here until
/// the user says so.
///
/// The whole flow hangs off one pref, [askedKey]. It is set the moment an
/// answer is given — either answer — so the question is asked at most once, and
/// it is backfilled for installs that predate it by
/// [adoptChoiceFromExistingInstall], so upgrading users are neither re-asked
/// nor switched off.
class AzaanOptInService {
  const AzaanOptInService._();

  /// Set once the user has answered, whichever way they answered.
  static const String askedKey = 'azaan_opt_in_asked';

  /// Every prayer that can raise a notification, as preference keys.
  ///
  /// [getPrayerNotificationPrayerNames] derives the same set from the prayer
  /// time object; this list is the form the preferences layer works in, and is
  /// usable before any prayer times exist.
  static const List<String> allPrayerKeys = <String>[
    'fajr_notification',
    'sunrise_notification',
    'dhuhr_notification',
    'asr_notification',
    'sunset_notification',
    'maghrib_notification',
    'isha_notification',
    'midnight_notification',
  ];

  /// What gets switched on when the user opts in without naming prayers — the
  /// same three the app used to enable by itself. The rest stay off and are a
  /// tap away on the prayer times card.
  static const List<String> defaultEnabledPrayerKeys = <String>[
    'fajr_notification',
    'dhuhr_notification',
    'maghrib_notification',
  ];

  /// Preferences only a build predating the opt-in could have written.
  ///
  /// The per-prayer keys are the signal: every previous version wrote all eight
  /// on its first launch, and no code path writes them now until the user has
  /// answered. The azan sound choice is a second witness — it is only ever
  /// written from Settings, so a fresh install cannot have one.
  ///
  /// Deliberately *not* `buildNumber`: a fresh install writes that on its own
  /// first launch, so treating it as a marker would adopt a genuinely new user
  /// as an upgrading one the moment they opened the app twice — and someone
  /// whose first launch had no location fix yet, and so was never asked, would
  /// then never be asked at all.
  static const List<String> _priorInstallMarkerKeys = <String>[
    ...allPrayerKeys,
    azaanPreferenceKey,
  ];

  /// Whether the user has already answered the question.
  static bool get hasBeenAsked =>
      SP.isInitialized && SP.prefs.getBool(askedKey) == true;

  /// Whether any prayer currently raises a notification.
  static bool get isEnabled =>
      SP.isInitialized &&
      allPrayerKeys.any((key) => SP.prefs.getBool(key) == true);

  /// Treats an install that already ran an older build as having answered.
  ///
  /// Those users made their choice — silently on our side, but they have lived
  /// with it, muted the prayers they did not want and possibly picked a sound.
  /// Re-asking would be noise, and defaulting them to off would silently take
  /// away notifications they rely on, so their current state simply stands.
  ///
  /// Call once per launch, right after preferences are loaded.
  static Future<void> adoptChoiceFromExistingInstall() async {
    if (!SP.isInitialized || hasBeenAsked) return;
    if (!_priorInstallMarkerKeys.any(SP.prefs.containsKey)) return;

    await SP.prefs.setBool(askedKey, true);
  }

  /// Whether this launch should put the question to the user.
  ///
  /// [hasLocation] gates it because the question is only meaningful once we can
  /// actually compute prayer times; without a fix we stay quiet and ask on a
  /// later launch rather than burning the one chance we get.
  static bool shouldAsk({required bool hasLocation}) {
    if (kIsWeb || !SP.isInitialized) return false;
    return !hasBeenAsked && hasLocation;
  }

  /// Asks the question and records the answer. Returns what the user chose.
  ///
  /// Scheduling is left to the caller: on first run the startup path reschedules
  /// straight after this anyway, once it knows whether exact alarms are allowed.
  static Future<bool> ask(
    BuildContext context, {
    AzaanOptInPrompt prompt = showAzaanOptInDialog,
  }) async {
    final enabled = await prompt(context);
    await _apply(enabled, reschedule: false);
    return enabled;
  }

  /// Turns azan on or off from Settings, and reschedules to match.
  static Future<void> setEnabled(bool enabled) =>
      _apply(enabled, reschedule: true);

  static Future<void> _apply(bool enabled, {required bool reschedule}) async {
    await SP.prefs.setBool(askedKey, true);
    for (final key in allPrayerKeys) {
      await SP.prefs
          .setBool(key, enabled && defaultEnabledPrayerKeys.contains(key));
    }

    // Only now, and only for a user who wants azan. Asking the OS for
    // notification permission we have no use for spends the single prompt
    // Android and iOS allow on nothing.
    if (enabled) {
      await requestNotificationPermissions();
    }
    if (reschedule) {
      await setUpNotifications();
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    if (!SP.isInitialized) return;
    await SP.prefs.remove(askedKey);
    for (final key in allPrayerKeys) {
      await SP.prefs.remove(key);
    }
  }
}
