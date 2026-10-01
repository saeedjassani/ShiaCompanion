import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../constants.dart';
import '../utils/font_preferences.dart';
import '../utils/shared_preferences.dart';

/// Syncs the reading preferences that used to live only in SharedPreferences
/// — Hijri date adjustment, Arabic/English font size, Arabic font, and the
/// recording chosen on each zikr page that has several — to the
/// signed-in account, the same way [FavoritesManager] and
/// [QazaTrackerManager] already sync favorites and qaza.
///
/// Deliberately simpler than those two: a single small document, last write
/// wins, no offline queue. Nothing here is the kind of loss an offline write
/// failing would make painful — the device that made the change keeps it in
/// SharedPreferences regardless of whether the cloud write lands, so a
/// signed-out or offline moment costs a sync, never the setting itself.
class PreferencesSyncService {
  PreferencesSyncService._internal();

  static final PreferencesSyncService _instance =
      PreferencesSyncService._internal();

  static PreferencesSyncService get instance => _instance;

  static const String _hijriDateOffsetField = 'hijriDateOffset';
  static const String _arabicFontSizeField = 'arabicFontSize';
  static const String _englishFontSizeField = 'englishFontSize';
  static const String _arabicFontField = 'arabicFont';

  /// Content uid -> the [ZikrAudioTrack.file] chosen in that zikr's player.
  static const String _audioTracksField = 'audioTracks';

  static const String _audioTrackPrefPrefix = 'zikr_audio_track_';

  /// Where this device keeps the recording chosen for zikr [contentUid].
  static String audioTrackPrefKey(String contentUid) =>
      '$_audioTrackPrefPrefix$contentUid';

  /// Widget tests build [ZikrReadingPreferencesControls] without standing up
  /// Firebase, so every entry point below has to tolerate "no app" rather
  /// than let touching [FirebaseAuth.instance] take the test down with it —
  /// the same reason [AnalyticsService] gates on this before doing anything.
  bool get _isLive => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences');
  }

  /// Call once per sign-in (and once at startup for an already-signed-in
  /// user): applies the account's synced preferences locally, or — the
  /// first time this account syncs at all — seeds the cloud from whatever
  /// is already on this device, so nothing already chosen is lost.
  Future<void> pullOrSeed() async {
    if (!_isLive) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot =
          await _doc(userId).get().timeout(const Duration(seconds: 8));
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

  Future<void> pushHijriDate() =>
      _pushIfSignedIn({_hijriDateOffsetField: hijriDate});

  Future<void> pushArabicFontSize() =>
      _pushIfSignedIn({_arabicFontSizeField: arabicFontSize});

  Future<void> pushEnglishFontSize() =>
      _pushIfSignedIn({_englishFontSizeField: englishFontSize});

  Future<void> pushArabicFont() =>
      _pushIfSignedIn({_arabicFontField: arabicFont});

  /// Remembers [file] as the recording to open zikr [contentUid] on, here
  /// and on the reader's other devices.
  Future<void> setAudioTrack(String contentUid, String file) async {
    if (SP.isInitialized) {
      await SP.prefs.setString(audioTrackPrefKey(contentUid), file);
    }
    // A nested map with merge: true adds this one zikr's entry without
    // replacing the others'.
    await _pushIfSignedIn({
      _audioTracksField: {contentUid: file},
    });
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

  Map<String, Object?> _currentValues() => {
        _hijriDateOffsetField: hijriDate,
        _arabicFontSizeField: arabicFontSize,
        _englishFontSizeField: englishFontSize,
        _arabicFontField: arabicFont,
        _audioTracksField: {
          for (final key in SP.prefs.getKeys())
            if (key.startsWith(_audioTrackPrefPrefix))
              key.substring(_audioTrackPrefPrefix.length):
                  SP.prefs.getString(key),
        },
      };

  Future<void> _applyRemote(Map<String, dynamic> data) async {
    final hijri = data[_hijriDateOffsetField];
    if (hijri is num) {
      hijriDate = hijri.toInt();
      await SP.prefs.setInt('adjust_hijri_date', hijriDate);
    }

    final arabicSize = data[_arabicFontSizeField];
    if (arabicSize is num) {
      arabicFontSize = arabicSize.toDouble();
      await SP.prefs.setDouble('ara_font_size', arabicFontSize);
    }

    final englishSize = data[_englishFontSizeField];
    if (englishSize is num) {
      englishFontSize = englishSize.toDouble();
      await SP.prefs.setDouble('eng_font_size', englishFontSize);
    }

    final font = data[_arabicFontField];
    if (font is String && FontPreferences.validFonts.contains(font)) {
      arabicFont = font;
      await FontPreferences.setSelectedFont(font);
    }

    final tracks = data[_audioTracksField];
    if (tracks is Map) {
      for (final entry in tracks.entries) {
        final file = entry.value;
        if (file is! String || file.isEmpty) continue;
        await SP.prefs.setString(audioTrackPrefKey('${entry.key}'), file);
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
