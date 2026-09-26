import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_stats.dart';
import '../utils/shared_preferences.dart';
import 'recitation_tracker_manager.dart';

/// Where [ActivityStatsStore] keeps the account's copy. An interface so tests
/// can stand in for Firestore.
abstract class ActivityStatsRemote {
  String? get currentUserId;

  /// Every device's activity for [userId], keyed by device id, or null when
  /// nothing has been synced yet.
  Future<Map<String, DeviceActivity>?> fetch(String userId);

  /// Writes this device's entry only - never the whole document - so two
  /// devices syncing at once cannot overwrite each other's history.
  Future<void> push(String userId, String deviceId, DeviceActivity activity);

  Future<void> delete(String userId);
}

class FirestoreActivityStatsRemote implements ActivityStatsRemote {
  const FirestoreActivityStatsRemote();

  bool get _isLive => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('activity');

  @override
  String? get currentUserId =>
      _isLive ? FirebaseAuth.instance.currentUser?.uid : null;

  @override
  Future<Map<String, DeviceActivity>?> fetch(String userId) async {
    final snapshot =
        await _doc(userId).get().timeout(const Duration(seconds: 8));
    final devices = snapshot.data()?['devices'];
    if (devices is! Map) return null;
    final result = <String, DeviceActivity>{};
    devices.forEach((id, encoded) {
      if (encoded is! String) return;
      try {
        result[id.toString()] = DeviceActivity.fromJson(jsonDecode(encoded));
      } catch (_) {
        // One unreadable device entry must not hide every other device's.
      }
    });
    return result;
  }

  @override
  Future<void> push(String userId, String deviceId, DeviceActivity activity) {
    // Each device's history is stored as one JSON string rather than a nested
    // map: Firestore indexes every map field by default, and a year of days
    // is hundreds of index entries per write that nothing ever queries.
    return _doc(userId).set({
      'devices': {deviceId: jsonEncode(activity.toJson())},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String userId) => _doc(userId).delete();
}

/// Personal stats and streaks: zikrs completed, qaza made up and (read from
/// [RecitationTrackerManager], which already keeps and syncs it) Quran
/// recitation.
///
/// Local first. Every reader gets stats and a streak whether or not they ever
/// sign in, recording something never touches the network, and a signed-in
/// account costs at most one Firestore read per cold start and one write per
/// [minPushInterval] - no snapshot listener, which would bill a read for
/// every change on every device.
class ActivityStatsStore extends ChangeNotifier {
  ActivityStatsStore({
    ActivityStatsRemote remote = const FirestoreActivityStatsRemote(),
    DateTime Function()? clock,
    this.recitationSource,
  })  : _remote = remote,
        _clock = clock ?? DateTime.now;

  static final ActivityStatsStore instance = ActivityStatsStore(
    recitationSource: () => RecitationTrackerManager.instance,
  );

  static const String _deviceIdKey = 'activity_stats_device_id';
  static const String _ownKey = 'activity_stats_own_v1';
  static const String _othersKey = 'activity_stats_others_v1';
  static const String _lastPushKey = 'activity_stats_last_push_ms';
  static const String _dirtyKey = 'activity_stats_dirty';

  /// Enough that a normal day's use - a morning and an evening session - is
  /// one or two writes, however many zikrs are read in between.
  static const Duration minPushInterval = Duration(hours: 6);

  final ActivityStatsRemote _remote;
  final DateTime Function() _clock;

  /// Null in tests that do not care about Quran recitation.
  final RecitationTrackerManager Function()? recitationSource;

  DeviceActivity _own = const DeviceActivity();
  Map<String, DeviceActivity> _others = const {};
  String? _othersOwner;
  bool _loaded = false;
  Future<void>? _syncInFlight;
  Future<void>? _pushInFlight;

  DeviceActivity get own {
    _ensureLoaded();
    return _own;
  }

  Map<String, DeviceActivity> get otherDevices {
    _ensureLoaded();
    return _others;
  }

  /// The combined view the stats screen renders.
  ActivitySummary summary() {
    _ensureLoaded();
    final recitation = recitationSource?.call().state;
    final now = _clock();
    return ActivitySummary(
      devices: [_own, ..._others.values],
      quranVersesByDay:
          recitation?.dailyVerseCounts(activityRetentionDays) ?? const {},
      quranVersesTotal: recitation?.entries.values
              .fold<int>(0, (sum, entry) => sum + entry.versesRecited) ??
          0,
      now: now,
    );
  }

  String get deviceId {
    final existing = SP.prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    SP.prefs.setString(_deviceIdKey, id);
    return id;
  }

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  Future<void> recordZikrCompleted(String uid) async {
    if (!SP.isInitialized) return;
    _ensureLoaded();
    final canonical = uid.split('|').last.trim();
    await _updateOwn(_own.recordZikr(canonical, _clock()));
  }

  Future<void> recordQazaCompleted() async {
    if (!SP.isInitialized) return;
    _ensureLoaded();
    await _updateOwn(_own.recordQaza(_clock()));
  }

  /// Takes back one of today's made-up qaza after an undo. An undo of
  /// something marked on an earlier day leaves that day's count alone - the
  /// streak it earned is history by now.
  Future<void> undoQazaCompleted() async {
    if (!SP.isInitialized) return;
    _ensureLoaded();
    await _updateOwn(_own.recordQaza(_clock(), delta: -1));
  }

  Future<void> _updateOwn(DeviceActivity next) async {
    if (next == _own) return;
    // Remembered on the device so a long streak is still "longest" after its
    // first days have been folded into the archive.
    final longest = ActivitySummary(
      devices: [next, ..._others.values],
      now: _clock(),
    ).longestStreak;
    if (longest > next.bestStreak) next = next.copyWith(bestStreak: longest);
    _own = next;
    notifyListeners();
    await SP.prefs.setString(_ownKey, jsonEncode(_own.toJson()));
    await SP.prefs.setBool(_dirtyKey, true);
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Call at startup and after every sign-in/out: the one read. Folds in
  /// other devices' history, reconciles this device's own entry against what
  /// the account already had (a reinstall gets its history back), and pushes
  /// if this device has something the account does not.
  Future<void> pullAndMerge() {
    return _syncInFlight ??= _pullAndMerge().whenComplete(() {
      _syncInFlight = null;
    });
  }

  Future<void> _pullAndMerge() async {
    if (!SP.isInitialized) return;
    _ensureLoaded();
    final userId = _remote.currentUserId;
    if (userId == null) {
      // Another account's devices are not this reader's stats.
      if (_others.isNotEmpty || _othersOwner != null) {
        await _setOthers(const {}, null);
      }
      return;
    }

    final Map<String, DeviceActivity>? remote;
    try {
      remote = await _remote.fetch(userId);
    } catch (error) {
      debugPrint('ActivityStatsStore: pull failed: $error');
      return;
    }

    final id = deviceId;
    final remoteOwn = remote?[id];
    final others = Map<String, DeviceActivity>.of(remote ?? const {})
      ..remove(id);
    await _setOthers(others, userId);

    if (remoteOwn != null) {
      final merged = _own.merge(remoteOwn).pruned(_clock());
      if (merged != _own) {
        _own = merged;
        notifyListeners();
        await SP.prefs.setString(_ownKey, jsonEncode(_own.toJson()));
      }
    }

    if (_own.isEmpty || remoteOwn == _own) {
      await SP.prefs.setBool(_dirtyKey, false);
      return;
    }
    await SP.prefs.setBool(_dirtyKey, true);
    if (remoteOwn == null) {
      // First sync of this device to this account: seed it now, so another
      // device signed in to the same account sees this one's history today.
      await _push(userId);
    } else {
      await pushIfDue();
    }
  }

  /// Call when the app goes to the background. Writes only if something
  /// changed and the last write was at least [minPushInterval] ago; anything
  /// held back goes up on a later pause or the next cold start.
  Future<void> pushIfDue() async {
    if (!SP.isInitialized) return;
    if (SP.prefs.getBool(_dirtyKey) != true) return;
    final userId = _remote.currentUserId;
    if (userId == null) return;
    final lastPush = SP.prefs.getInt(_lastPushKey);
    if (lastPush != null) {
      final since =
          _clock().difference(DateTime.fromMillisecondsSinceEpoch(lastPush));
      if (since < minPushInterval && !since.isNegative) return;
    }
    await _push(userId);
  }

  /// One write at a time: on a slow connection a write can stay unconfirmed
  /// for minutes, and a pause in the meantime must not queue a second copy.
  Future<void> _push(String userId) {
    return _pushInFlight ??=
        _pushNow(userId).whenComplete(() => _pushInFlight = null);
  }

  Future<void> _pushNow(String userId) async {
    try {
      await _remote.push(userId, deviceId, _own);
      await SP.prefs.setInt(_lastPushKey, _clock().millisecondsSinceEpoch);
      await SP.prefs.setBool(_dirtyKey, false);
    } catch (error) {
      // Stays dirty; the device keeps its stats regardless.
      debugPrint('ActivityStatsStore: push failed: $error');
    }
  }

  /// Account deletion. The device's own local stats are left alone: they were
  /// never the account's, and a signed-out reader still has a streak.
  Future<void> deleteSyncedStats(String userId) async {
    try {
      await _remote.delete(userId);
    } catch (_) {
      // Best-effort, like the other synced stores.
    }
    if (SP.isInitialized) await _setOthers(const {}, null);
  }

  // ---------------------------------------------------------------------------
  // Local storage
  // ---------------------------------------------------------------------------

  void _ensureLoaded() {
    if (_loaded || !SP.isInitialized) return;
    _loaded = true;
    _own = _decodeDevice(SP.prefs.getString(_ownKey)).pruned(_clock());
    final raw = SP.prefs.getString(_othersKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['devices'] is Map) {
          _othersOwner = decoded['owner']?.toString();
          _others = {
            for (final entry in (decoded['devices'] as Map).entries)
              entry.key.toString(): DeviceActivity.fromJson(entry.value),
          };
        }
      } catch (_) {
        _others = const {};
      }
    }
  }

  Future<void> _setOthers(
    Map<String, DeviceActivity> others,
    String? owner,
  ) async {
    _others = Map.unmodifiable(others);
    _othersOwner = owner;
    notifyListeners();
    if (others.isEmpty) {
      await SP.prefs.remove(_othersKey);
      return;
    }
    await SP.prefs.setString(
      _othersKey,
      jsonEncode({
        'owner': owner,
        'devices': {
          for (final entry in others.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
  }

  static DeviceActivity _decodeDevice(String? raw) {
    if (raw == null) return const DeviceActivity();
    try {
      return DeviceActivity.fromJson(jsonDecode(raw));
    } catch (_) {
      return const DeviceActivity();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _own = const DeviceActivity();
    _others = const {};
    _othersOwner = null;
    _loaded = false;
  }
}
