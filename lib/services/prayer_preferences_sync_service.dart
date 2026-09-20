import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../constants.dart';
import '../services/azaan_opt_in_service.dart';
import '../utils/shared_preferences.dart';
import '../utils/widget_prayer_time_selection.dart';

/// Syncs prayer-time preferences — which prayers notify, the azan sound
/// (default and per-prayer overrides), and which times the widgets show — to
/// the signed-in account, the same way [PreferencesSyncService] syncs the
/// reading preferences.
///
/// Deliberately the same shape as [PreferencesSyncService]: a single small
/// document, last write wins, no offline queue. The device that made a change
/// keeps it in SharedPreferences regardless of whether the cloud write lands,
/// so a signed-out or offline moment costs a sync, never the setting itself.
///
/// What is *not* synced: location (a GPS fix is inherently per-device, not a
/// preference) and custom azan audio files (a local file path means nothing
/// on another device — [getAzaanOptionForPrayer] already falls back to the
/// app default when a "custom" choice has no file behind it, so syncing the
/// bare choice is safe even though the file itself never travels).
class PrayerPreferencesSyncService {
  PrayerPreferencesSyncService._internal();

  static final PrayerPreferencesSyncService _instance =
      PrayerPreferencesSyncService._internal();

  static PrayerPreferencesSyncService get instance => _instance;

  /// The exact SharedPreferences keys for the eight notification toggles,
  /// reused as the Firestore field names too.
  static const List<String> _notificationKeys = AzaanOptInService.allPrayerKeys;

  static const String _askedField = AzaanOptInService.askedKey;
  static const String _azaanSoundField = azaanPreferenceKey;
  static const String _widgetTimesField = widgetPrayerTimesKey;

  /// Base prayer names [soundPreferenceKeyForPrayer] normalizes from, used to
  /// build the per-prayer sound override fields.
  static const List<String> _prayerBaseNames = <String>[
    'fajr',
    'sunrise',
    'dhuhr',
    'asr',
    'sunset',
    'maghrib',
    'isha',
    'midnight',
  ];

  /// Widget tests build pages that touch these preferences without standing up
  /// Firebase, so every entry point below has to tolerate "no app" rather than
  /// let touching [FirebaseAuth.instance] take the test down with it — the
  /// same reason [AnalyticsService] gates on this before doing anything.
  bool get _isLive => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('prayerPreferences');
  }

  /// Call once per sign-in (and once at startup for an already-signed-in
  /// user): applies the account's synced preferences locally, or — the first
  /// time this account syncs at all — seeds the cloud from whatever is
  /// already on this device, so nothing already chosen is lost.
  Future<void> pullOrSeed() async {
    if (!_isLive) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _doc(userId).get();
      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        await _write(userId, _currentValues());
        return;
      }
      await _applyRemote(data);
    } catch (_) {
      // Offline or a transient Firestore error: the device keeps whatever
      // preferences it already had rather than blocking sign-in on a sync.
    }
  }

  /// Pushes one notification toggle plus the opt-in "asked" flag, which every
  /// deliberate change to a single prayer also sets locally.
  Future<void> pushNotificationToggle(String prayerNotificationKey) =>
      _pushIfSignedIn({
        prayerNotificationKey: SP.prefs.getBool(prayerNotificationKey) ?? false,
        _askedField: SP.prefs.getBool(_askedField) ?? false,
      });

  /// Pushes all eight toggles plus the "asked" flag at once — for the
  /// all-or-nothing opt-in switch, which rewrites every prayer together.
  Future<void> pushAzaanOptInBulk() => _pushIfSignedIn({
        for (final key in _notificationKeys) key: SP.prefs.getBool(key) ?? false,
        _askedField: SP.prefs.getBool(_askedField) ?? false,
      });

  /// Pushes the app-wide default azan sound.
  Future<void> pushAzaanSound() {
    final soundId = SP.prefs.getString(_azaanSoundField);
    if (soundId == null) return Future.value();
    return _pushIfSignedIn({_azaanSoundField: soundId});
  }

  /// Pushes one prayer's sound override, or that it now follows the default
  /// again — [prayerName] takes any casing [soundPreferenceKeyForPrayer]
  /// accepts, e.g. `'fajr'` or `'Zuhr'`.
  Future<void> pushPrayerSound(String prayerName) {
    final key = soundPreferenceKeyForPrayer(prayerName);
    return _pushIfSignedIn({key: SP.prefs.getString(key) ?? ''});
  }

  /// Pushes which times the home card and home screen widgets show.
  Future<void> pushWidgetPrayerTimes() {
    final ids = SP.prefs.getStringList(_widgetTimesField) ??
        defaultWidgetPrayerTimeIds;
    return _pushIfSignedIn({_widgetTimesField: ids});
  }

  /// Removes the synced document. Called when an account is deleted, so
  /// "delete my account" genuinely deletes everything it says it does.
  Future<void> deleteSyncedPreferences(String userId) async {
    if (!_isLive) return;
    try {
      await _doc(userId).delete();
    } catch (_) {
      // Best-effort, same as the rest of this service — deletion of the
      // account itself is what matters and is handled by the caller.
    }
  }

  Map<String, Object?> _currentValues() {
    final azaanSound = SP.prefs.getString(_azaanSoundField);
    return {
      for (final key in _notificationKeys) key: SP.prefs.getBool(key) ?? false,
      _askedField: SP.prefs.getBool(_askedField) ?? false,
      if (azaanSound != null) _azaanSoundField: azaanSound,
      for (final name in _prayerBaseNames)
        soundPreferenceKeyForPrayer(name):
            SP.prefs.getString(soundPreferenceKeyForPrayer(name)) ?? '',
      _widgetTimesField:
          SP.prefs.getStringList(_widgetTimesField) ??
              defaultWidgetPrayerTimeIds,
    };
  }

  Future<void> _applyRemote(Map<String, dynamic> data) async {
    for (final key in _notificationKeys) {
      final value = data[key];
      if (value is bool) await SP.prefs.setBool(key, value);
    }

    final asked = data[_askedField];
    if (asked is bool) await SP.prefs.setBool(_askedField, asked);

    final azaanSound = data[_azaanSoundField];
    if (azaanSound is String && azaanSound.isNotEmpty) {
      await SP.prefs.setString(_azaanSoundField, azaanSound);
    }

    for (final name in _prayerBaseNames) {
      final key = soundPreferenceKeyForPrayer(name);
      final value = data[key];
      if (value is! String) continue;
      if (value.isEmpty) {
        await SP.prefs.remove(key);
      } else {
        await SP.prefs.setString(key, value);
      }
    }

    final widgetTimes = data[_widgetTimesField];
    if (widgetTimes is List) {
      final ids = widgetTimes.whereType<String>().toList(growable: false);
      if (ids.isNotEmpty) {
        await SP.prefs.setStringList(_widgetTimesField, ids);
      }
    }
  }

  Future<void> _pushIfSignedIn(Map<String, Object?> fields) async {
    if (!_isLive) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await _write(userId, fields);
  }

  Future<void> _write(String userId, Map<String, Object?> fields) async {
    try {
      await _doc(userId).set(fields, SetOptions(merge: true));
    } catch (_) {
      // Best-effort: this setting is already correct on this device even if
      // the write to the cloud fails.
    }
  }
}
