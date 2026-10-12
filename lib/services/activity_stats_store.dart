import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

/// A copy of this install's device id kept where a phone backup does not
/// reach, so a device set up from another's backup - which carries the
/// SharedPreferences, device id and all - can tell it is not that device.
abstract class InstallMarker {
  /// The id written last, or null when there is none. Throws when this
  /// platform has nowhere to keep one.
  Future<String?> read();

  Future<void> write(String deviceId);
}

/// A small file outside every backup: on Android in the app's files
/// directory, which `backup_rules.xml` and `data_extraction_rules.xml`
/// exclude it from; on iOS in Caches, which is never backed up or moved to a
/// new phone. iOS may clear Caches when storage runs low, which reads as a
/// new install - harmless, since [ActivityStatsStore] then files this
/// device's history under its old id rather than losing or doubling it.
class FileInstallMarker implements InstallMarker {
  const FileInstallMarker();

  /// Also named in android/app/src/main/res/xml/backup_rules.xml and
  /// data_extraction_rules.xml.
  static const String fileName = 'activity_stats_install';

  Future<File> _file() async {
    if (kIsWeb) throw UnsupportedError('no install marker on the web');
    final Directory directory = switch (defaultTargetPlatform) {
      TargetPlatform.android => await getApplicationSupportDirectory(),
      TargetPlatform.iOS => await getApplicationCacheDirectory(),
      _ => throw UnsupportedError('no install marker on this platform'),
    };
    return File('${directory.path}/$fileName');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return (await file.readAsString()).trim();
  }

  @override
  Future<void> write(String deviceId) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(deviceId, flush: true);
  }
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
    bool Function()? syncEnabled,
    InstallMarker installMarker = const FileInstallMarker(),
    this.recitationSource,
  })  : _remote = remote,
        _clock = clock ?? DateTime.now,
        _syncEnabled = syncEnabled ?? _alwaysOn,
        _installMarker = installMarker;

  static final ActivityStatsStore instance = ActivityStatsStore(
    recitationSource: () => RecitationTrackerManager.instance,
  );

  static bool _alwaysOn() => true;

  static const String _deviceIdKey = 'activity_stats_device_id';
  static const String _ownKey = 'activity_stats_own_v1';
  static const String _othersKey = 'activity_stats_others_v1';
  static const String _lastPushKey = 'activity_stats_last_push_ms';
  static const String _dirtyKey = 'activity_stats_dirty';

  /// Set once [InstallMarker] holds this install's id. A backup copies it
  /// along with the id, so with it set and the marker missing or different,
  /// this is a device set up from another's backup. Without it - an install
  /// from before the marker existed - the id is simply adopted.
  static const String _installMarkedKey = 'activity_stats_install_marked';

  /// History restored from another install's backup, by that install's id:
  /// shown with this device's own, and written to the account under the id
  /// it came with, never this device's.
  static const String _inheritedKey = 'activity_stats_inherited_v1';

  /// Enough that a normal day's use - a morning and an evening session - is
  /// one or two writes, however many zikrs are read in between.
  static const Duration minPushInterval = Duration(hours: 6);

  final ActivityStatsRemote _remote;
  final DateTime Function() _clock;
  final bool Function() _syncEnabled;
  final InstallMarker _installMarker;

  /// The account to sync with, or null when signed out or sync is off.
  String? get _syncUserId => _syncEnabled() ? _remote.currentUserId : null;

  /// Null in tests that do not care about Quran recitation.
  final RecitationTrackerManager Function()? recitationSource;

  DeviceActivity _own = const DeviceActivity();
  Map<String, DeviceActivity> _others = const {};
  String? _othersOwner;
  Map<String, DeviceActivity> _inherited = const {};
  bool _loaded = false;
  Future<void>? _installCheck;
  Future<void>? _syncInFlight;
  Future<void>? _pushInFlight;

  DeviceActivity get own {
    _ensureLoaded();
    return _own;
  }

  /// Every device but this one: the account's, and any history restored
  /// from another install's backup.
  Map<String, DeviceActivity> get otherDevices {
    _ensureLoaded();
    if (_inherited.isEmpty) return _others;
    final all = Map<String, DeviceActivity>.of(_others);
    _inherited.forEach((id, activity) {
      final synced = all[id];
      all[id] = synced == null ? activity : synced.merge(activity);
    });
    return all;
  }

  /// The combined view the stats screen renders.
  ActivitySummary summary() {
    _ensureLoaded();
    final recitation = recitationSource?.call().state;
    final now = _clock();
    return ActivitySummary(
      devices: [_own, ...otherDevices.values],
      quranVersesByDay:
          recitation?.dailyVerseCounts(activityRetentionDays) ?? const {},
      quranVersesTotal: recitation?.totalVersesRecited ?? 0,
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
      devices: [next, ...otherDevices.values],
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
    await _checkInstall();
    final userId = _syncUserId;
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
    await _uploadInherited(userId, others);
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
    _ensureLoaded();
    await _checkInstall();
    if (SP.prefs.getBool(_dirtyKey) != true) return;
    final userId = _syncUserId;
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

  /// Writes history restored from another install's backup to the account
  /// under the id it came with, merged with whatever the account already has
  /// there, and adds it to [others]. The account's copy is usually ahead -
  /// the old device kept syncing after the backup was taken - and then
  /// nothing is written at all.
  Future<void> _uploadInherited(
    String userId,
    Map<String, DeviceActivity> others,
  ) async {
    if (_inherited.isEmpty) return;
    final remaining = Map<String, DeviceActivity>.of(_inherited);
    for (final entry in _inherited.entries) {
      final synced = others[entry.key];
      final merged = synced == null
          ? entry.value
          : synced.merge(entry.value).pruned(_clock());
      try {
        if (merged != synced && !merged.isEmpty) {
          await _remote.push(userId, entry.key, merged);
        }
        if (!merged.isEmpty) others[entry.key] = merged;
        remaining.remove(entry.key);
      } catch (error) {
        // Kept, and shown, until a later pull gets it up.
        debugPrint('ActivityStatsStore: inherited push failed: $error');
      }
    }
    await _setInherited(remaining);
  }

  // ---------------------------------------------------------------------------
  // Install identity
  // ---------------------------------------------------------------------------

  /// Once per launch, before anything is synced: makes sure [deviceId] is
  /// this install's own and not one restored from another device's backup,
  /// where two devices sharing an id would each keep replacing the other's
  /// history in the account.
  Future<void> _checkInstall() {
    return _installCheck ??= _checkInstallNow();
  }

  Future<void> _checkInstallNow() async {
    final String? marker;
    try {
      marker = await _installMarker.read();
    } catch (error) {
      // Nowhere to keep a marker (the web, tests): nothing to compare with.
      return;
    }
    final stored = SP.prefs.getString(_deviceIdKey);
    final marked = SP.prefs.getBool(_installMarkedKey) == true;
    if (stored != null && stored.isNotEmpty && marker == stored) return;

    if (stored != null && stored.isNotEmpty && marked) {
      await _startNewIdentity(stored);
    }
    try {
      await _installMarker.write(deviceId);
      await SP.prefs.setBool(_installMarkedKey, true);
    } catch (error) {
      debugPrint('ActivityStatsStore: install marker not written: $error');
    }
  }

  /// This device was set up from [previousId]'s backup: takes a new id, and
  /// keeps the history that came with the backup as [previousId]'s, so it is
  /// neither lost nor counted twice should that device still be in use.
  Future<void> _startNewIdentity(String previousId) async {
    debugPrint('ActivityStatsStore: restored from another install; new id');
    if (!_own.isEmpty) {
      final earlier = _inherited[previousId];
      await _setInherited({
        ..._inherited,
        previousId: earlier == null ? _own : earlier.merge(_own),
      });
    }
    _own = const DeviceActivity();
    notifyListeners();
    // Unmarked until the new id's marker is written: should that fail, the
    // next launch adopts the new id rather than taking yet another.
    await SP.prefs.remove(_installMarkedKey);
    await SP.prefs.remove(_ownKey);
    await SP.prefs.remove(_deviceIdKey);
    await SP.prefs.remove(_lastPushKey);
    await SP.prefs.setBool(_dirtyKey, false);
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
    final rawInherited = SP.prefs.getString(_inheritedKey);
    if (rawInherited != null) {
      try {
        final decoded = jsonDecode(rawInherited);
        if (decoded is Map) {
          _inherited = {
            for (final entry in decoded.entries)
              entry.key.toString(): DeviceActivity.fromJson(entry.value),
          };
        }
      } catch (_) {
        _inherited = const {};
      }
    }
  }

  Future<void> _setInherited(Map<String, DeviceActivity> inherited) async {
    if (mapEquals(inherited, _inherited)) return;
    _inherited = Map.unmodifiable(inherited);
    notifyListeners();
    if (inherited.isEmpty) {
      await SP.prefs.remove(_inheritedKey);
      return;
    }
    await SP.prefs.setString(
      _inheritedKey,
      jsonEncode({
        for (final entry in inherited.entries) entry.key: entry.value.toJson(),
      }),
    );
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
    _inherited = const {};
    _loaded = false;
    _installCheck = null;
  }
}
