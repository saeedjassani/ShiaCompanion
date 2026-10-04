import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/recitation_tracker_state.dart';
import '../services/analytics_service.dart';
import '../services/recitation_tracker_sync_policy.dart';
import '../utils/shared_preferences.dart';

/// Tracks recitations logged under a label ("Family", "Personal", ...),
/// synced the same way [QazaTrackerManager] syncs qaza: SharedPreferences for
/// an instant local read, one Firestore document per user for cross-device
/// sync, and a pending-operations queue so a log made offline is never lost.
///
/// One document per user rather than one per entry keeps this cheap to read:
/// the whole history is one `.get()` (or one realtime listener attach), not
/// one read per entry.
///
/// Keeping it cheap to write and store takes two more things. Writes are
/// merge writes of only what changed - see [_writeRemote] - never a
/// read-modify-write transaction, which would download the whole history for
/// every surah logged. And the doc's `state` map is exempt from indexing (see
/// firestore.indexes.json): nothing queries it, and Firestore's default of
/// indexing every field of every entry costs about twenty times the entries'
/// own size and caps a reader's history at a few thousand sessions.
class RecitationTrackerManager extends ChangeNotifier {
  static final RecitationTrackerManager _instance =
      RecitationTrackerManager._internal();

  factory RecitationTrackerManager() => _instance;

  RecitationTrackerManager._internal();

  static RecitationTrackerManager get instance => _instance;

  static const String _guestStorageKey = 'recitation_tracker_guest';
  static const String _guestImportPendingKey =
      'recitation_tracker_guest_import_pending';
  static const String _recitationCollection = 'recitation_tracker';
  static const String _recitationDocId = 'state';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Future<void>? _loadFuture;
  Future<void> _storageWriteQueue = Future.value();
  RecitationTrackerState _state = RecitationTrackerState.empty;
  RecitationTrackerState _pendingGuestImportState = RecitationTrackerState.empty;
  String? _pendingGuestImportUserId;
  String? _loadedUserId;
  bool _isImportingGuestState = false;
  Future<void>? _pushInFlight;
  bool _pushAgain = false;
  bool _isLoading = false;
  bool _hasLoaded = false;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  RecitationTrackerState get state => _state;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_recitationCollection)
        .doc(_recitationDocId);
  }

  String _userStorageKey(String userId) => 'recitation_tracker_user_$userId';

  String _pendingOperationsStorageKey(String userId) =>
      'recitation_tracker_pending_operations_$userId';

  /// True when the in-memory state already belongs to the current user and
  /// the live listener that keeps it fresh is still attached — see
  /// [QazaTrackerManager] for why this guard exists: it is the difference
  /// between a page visit costing a remote read and costing nothing.
  bool get _isLoadedForCurrentUser {
    if (!_hasLoaded) return false;

    final userId = _auth.currentUser?.uid;
    if (_loadedUserId != userId) return false;

    return userId == null || _listener != null;
  }

  Future<void> loadRecitations({bool force = false}) async {
    if (_loadFuture != null) return _loadFuture!;
    if (!force && _isLoadedForCurrentUser) return;

    final completer = Completer<void>();
    _loadFuture = completer.future;
    _setLoading(true);

    try {
      await _loadInternal();
      _hasLoaded = true;
      notifyListeners();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _loadFuture = null;
      _setLoading(false);
    }
  }

  Future<void> _loadInternal() async {
    await _storageWriteQueue;
    final guestState = _loadStateFromStorageKey(_guestStorageKey);
    final user = _auth.currentUser;
    final isGuestToUserTransition =
        _hasLoaded && _loadedUserId == null && user != null;

    await _listener?.cancel();
    _listener = null;

    if (user == null) {
      _updateState(guestState);
      _loadedUserId = null;
      debugPrint('RecitationTrackerManager: Loaded guest state');
      return;
    }

    final cachedState = _loadStateFromStorageKey(_userStorageKey(user.uid));
    if (!cachedState.isEmpty) _updateState(cachedState);

    final remoteRead = await _loadRemoteState(user.uid);
    final shouldImportGuestState = (isGuestToUserTransition ||
            SP.prefs.getBool(_guestImportPendingKey) == true) &&
        !guestState.isEmpty;
    final pendingOperations = _loadPendingOperations(user.uid);

    if (!remoteRead.succeeded) {
      final visibleState = cachedState.isEmpty
          ? (shouldImportGuestState ? guestState : RecitationTrackerState.empty)
          : cachedState;
      _updateState(visibleState);
      await _saveUserStateToSharedPreferences(user.uid, visibleState);
      if (shouldImportGuestState) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
      }
      _loadedUserId = user.uid;
      setupRealtimeListener();
      return;
    }

    var visibleState = remoteRead.state;
    if (shouldImportGuestState) visibleState = visibleState.plus(guestState);
    visibleState = applyPendingRecitationOperations(
      visibleState,
      pendingOperations,
    );

    _updateState(visibleState);
    await _saveUserStateToSharedPreferences(user.uid, visibleState);

    if (shouldImportGuestState) {
      try {
        await _mergeRemoteStateForUser(user.uid, guestState);
        await _clearGuestState();
        _pendingGuestImportUserId = null;
        _pendingGuestImportState = RecitationTrackerState.empty;
      } catch (error) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
        debugPrint('RecitationTrackerManager: Error importing guest state: $error');
      }
    }

    if (pendingOperations.isNotEmpty) unawaited(_pushPending(user.uid));

    _loadedUserId = user.uid;
    setupRealtimeListener();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _updateState(RecitationTrackerState nextState) {
    _state = nextState;
    notifyListeners();
  }

  RecitationTrackerState _loadStateFromStorageKey(String storageKey) {
    return _decodeState(SP.prefs.getString(storageKey));
  }

  RecitationTrackerState _decodeState(String? encoded) {
    if (encoded == null || encoded.isEmpty || encoded == 'null') {
      return RecitationTrackerState.empty;
    }
    try {
      return RecitationTrackerState.fromJson(jsonDecode(encoded));
    } catch (error) {
      debugPrint('RecitationTrackerManager: Error decoding state: $error');
      return RecitationTrackerState.empty;
    }
  }

  Future<void> _saveStateToStorageKey(
    String storageKey,
    RecitationTrackerState state,
  ) {
    return _enqueueStorageWrite(() async {
      try {
        if (state.isEmpty) {
          await SP.prefs.remove(storageKey);
          return;
        }
        await SP.prefs.setString(storageKey, jsonEncode(state.toJson()));
      } catch (error) {
        debugPrint(
          'RecitationTrackerManager: Error saving state to $storageKey: $error',
        );
      }
    });
  }

  Future<void> _saveGuestState(
    RecitationTrackerState state, {
    bool markForImport = false,
  }) async {
    await _saveStateToStorageKey(_guestStorageKey, state);
    await _enqueueStorageWrite(() async {
      if (markForImport && !state.isEmpty) {
        await SP.prefs.setBool(_guestImportPendingKey, true);
      } else if (state.isEmpty) {
        await SP.prefs.remove(_guestImportPendingKey);
      }
    });
  }

  Future<void> _saveUserStateToSharedPreferences(
    String userId,
    RecitationTrackerState state,
  ) {
    return _saveStateToStorageKey(_userStorageKey(userId), state);
  }

  Future<void> _clearGuestState() async {
    await _enqueueStorageWrite(() async {
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
    });
  }

  Future<_RemoteRecitationRead> _loadRemoteState(String userId) async {
    try {
      final snapshot =
          await _doc(userId).get().timeout(const Duration(seconds: 8));
      return _RemoteRecitationRead.success(
        state: RecitationTrackerState.fromJson(snapshot.data()?['state']),
      );
    } catch (error) {
      debugPrint('RecitationTrackerManager: Error loading remote state: $error');
      return _RemoteRecitationRead.failure();
    }
  }

  List<PendingRecitationOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];

      // Keyed by id, last one wins: the reader re-logs the same entry id as
      // its range grows, and only the newest range is worth replaying.
      final operations = <String, PendingRecitationOperation>{};
      for (final value in parsed) {
        final operation = PendingRecitationOperation.fromJson(value);
        if (operation == null) continue;
        operations[operation.id] = operation;
      }
      return operations.values.toList(growable: false);
    } catch (error) {
      debugPrint(
        'RecitationTrackerManager: Error decoding pending operations: $error',
      );
      return const [];
    }
  }

  Future<void> _recordPendingOperation(
    String userId,
    PendingRecitationOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      // Replaces an older queued version of the same entry rather than
      // queueing both, so a long reading session leaves one operation per
      // surah to sync, not one per scroll.
      final operations = [
        ..._loadPendingOperations(userId)
            .where((pending) => pending.id != operation.id),
        operation,
      ];
      await _writePendingOperations(userId, operations);
    });
  }

  Future<void> _clearPendingOperations(
    String userId,
    List<PendingRecitationOperation> synced,
  ) {
    return _enqueueStorageWrite(() async {
      // Only the exact versions that were synced: if the reader re-logged an
      // entry with a wider range while this write was in flight, that newer
      // version still has to go up.
      final syncedById = {
        for (final operation in synced)
          operation.id: jsonEncode(operation.toJson()),
      };
      final operations = _loadPendingOperations(userId)
          .where((pending) =>
              syncedById[pending.id] != jsonEncode(pending.toJson()))
          .toList(growable: false);
      await _writePendingOperations(userId, operations);
    });
  }

  Future<void> _writePendingOperations(
    String userId,
    List<PendingRecitationOperation> operations,
  ) async {
    if (operations.isEmpty) {
      await SP.prefs.remove(_pendingOperationsStorageKey(userId));
      return;
    }
    await SP.prefs.setString(
      _pendingOperationsStorageKey(userId),
      jsonEncode(operations.map((operation) => operation.toJson()).toList()),
    );
  }

  Future<void> _enqueueStorageWrite(Future<void> Function() write) {
    final operation = _storageWriteQueue.then((_) => write());
    _storageWriteQueue = operation.catchError((Object error) {
      debugPrint('RecitationTrackerManager: Storage write failed: $error');
    });
    return operation;
  }

  /// Merges [addition] into the remote doc. Writing the same entry ids and
  /// labels again changes nothing, so an import replayed after a dropped
  /// connection can never double-count.
  ///
  /// Bounded, unlike [_pushPending]: this is awaited while the tracker loads,
  /// and a write's future does not complete until the server has it - offline,
  /// not until the connection is back. The write stays queued in Firestore's
  /// own cache either way, and a timed-out import is retried from the
  /// listener.
  Future<void> _mergeRemoteStateForUser(
    String userId,
    RecitationTrackerState addition,
  ) async {
    if (addition.isEmpty) return;
    await _writeRemote(userId, [
      for (final label in addition.customLabels)
        PendingRecitationOperation.addLabel(label),
      for (final entry in addition.entries.values)
        PendingRecitationOperation.add(entry),
    ]).timeout(const Duration(seconds: 8));
  }

  /// Applies [operations] to the remote doc as one merge write.
  ///
  /// No transaction and no read first: [recitationRemoteChangesFor] folds the
  /// queue into field writes that land the same however often they are
  /// replayed, and a merge write touches only those fields, so whatever
  /// another device wrote meanwhile is left alone.
  Future<void> _writeRemote(
    String userId,
    Iterable<PendingRecitationOperation> operations,
  ) {
    final changes = recitationRemoteChangesFor(operations);
    if (changes.isEmpty) return Future.value();
    final entries = <String, Object>{
      for (final entry in changes.entries.values) entry.id: entry.toJson(),
      for (final id in changes.removedEntryIds) id: FieldValue.delete(),
    };
    return _doc(userId).set({
      'version': 2,
      'state': {
        // Never written empty: in a merge write an empty map replaces the
        // whole map, which would wipe every entry rather than leave them be.
        if (entries.isNotEmpty) 'entries': entries,
        if (changes.labels.isNotEmpty)
          'labels': FieldValue.arrayUnion(changes.labels.toList()),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'RecitationTrackerManager: No user logged in, skipping listener setup',
      );
      return;
    }

    unawaited(_listener?.cancel());
    _listener = _doc(user.uid).snapshots().listen(
      (snapshot) async {
        if (_auth.currentUser?.uid != user.uid ||
            snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        var remoteState = RecitationTrackerState.fromJson(
          snapshot.data()?['state'],
        );
        if (_pendingGuestImportUserId == user.uid &&
            !_pendingGuestImportState.isEmpty &&
            !_isImportingGuestState) {
          _isImportingGuestState = true;
          try {
            await _mergeRemoteStateForUser(user.uid, _pendingGuestImportState);
            remoteState = remoteState.plus(_pendingGuestImportState);
            await _clearGuestState();
            _pendingGuestImportUserId = null;
            _pendingGuestImportState = RecitationTrackerState.empty;
          } catch (error) {
            debugPrint(
              'RecitationTrackerManager: Deferred guest import failed: $error',
            );
          } finally {
            _isImportingGuestState = false;
          }
        }

        await _storageWriteQueue;
        final pendingOperations = _loadPendingOperations(user.uid);
        final visibleState = applyPendingRecitationOperations(
          remoteState,
          pendingOperations,
        );
        _updateState(visibleState);
        await _saveUserStateToSharedPreferences(user.uid, visibleState);

        if (pendingOperations.isNotEmpty) unawaited(_pushPending(user.uid));
      },
      onError: (error) {
        debugPrint('RecitationTrackerManager: Error listening: $error');
      },
    );
  }

  /// Sends everything queued for [userId] as one write.
  ///
  /// One write at a time: a call made while one is in flight - leaving a juz
  /// logs every surah in it at once - is folded into a single follow-up write
  /// once it lands, rather than racing it. Offline, the in-flight write simply
  /// waits for the connection, holding everything queued behind it.
  Future<void> _pushPending(String userId) {
    final inFlight = _pushInFlight;
    if (inFlight != null) {
      _pushAgain = true;
      return inFlight;
    }
    return _pushInFlight =
        _pushPendingNow(userId).whenComplete(() => _pushInFlight = null);
  }

  Future<void> _pushPendingNow(String userId) async {
    try {
      do {
        _pushAgain = false;
        await _storageWriteQueue;
        if (_auth.currentUser?.uid != userId) return;
        final operations = _loadPendingOperations(userId);
        if (operations.isEmpty) return;
        await _writeRemote(userId, operations);
        await _clearPendingOperations(userId, operations);
      } while (_pushAgain);
    } catch (error) {
      debugPrint(
        'RecitationTrackerManager: Pending operation sync failed: $error',
      );
    }
  }

  /// Logs [fromAyah]–[toAyah] of [surah] as recited under [label] (trimmed;
  /// not persisted if empty, or if the range is invalid), defaulting to now.
  ///
  /// Pass [id] to upsert an existing entry rather than create a new one —
  /// the reader uses this to keep extending the same session's entry as
  /// someone keeps scrolling, rather than logging a fresh one every time the
  /// debounce fires.
  ///
  /// With [syncRemote] false the change is applied and saved on the device
  /// (and queued) but not sent to Firestore yet - the reader logs that way
  /// while someone is still scrolling and syncs once, on leaving, so a long
  /// recitation costs one remote write for the whole visit, however many
  /// surahs it covered, instead of one per pause. Anything left queued is
  /// sent by [syncPendingOperations] or on the next load.
  ///
  /// Completes once the change is saved on the device; the remote write goes
  /// up in the background.
  ///
  /// Never counted as feature usage: it is recorded automatically by
  /// reading, not something the reader chose to do.
  Future<void> logRecitation({
    required String label,
    required int surah,
    required int fromAyah,
    required int toAyah,
    DateTime? recitedAt,
    String? id,
    bool readInJuz = false,
    bool syncRemote = true,
  }) {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) return Future.value();
    if (surah < 1 || fromAyah < 1 || toAyah < fromAyah) return Future.value();

    final entryId = id ?? _newEntryId();
    final existing = _state.entries[entryId];
    if (existing != null &&
        existing.label == trimmedLabel &&
        existing.surah == surah &&
        existing.fromAyah == fromAyah &&
        existing.toAyah == toAyah &&
        existing.readInJuz == readInJuz) {
      // Nothing new to record - but a range logged locally earlier may still
      // be waiting to go up.
      if (syncRemote) unawaited(syncPendingOperations());
      return Future.value();
    }

    final entry = RecitationEntry(
      id: entryId,
      label: trimmedLabel,
      recitedAt: recitedAt ?? DateTime.now(),
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
      readInJuz: readInJuz,
    );
    return _applyOperation(
      PendingRecitationOperation.add(entry),
      syncRemote: syncRemote,
    );
  }

  /// Sends whatever is still queued for the signed-in user to Firestore, as
  /// one write.
  Future<void> syncPendingOperations() {
    final user = _auth.currentUser;
    if (user == null) return Future.value();
    return _pushPending(user.uid);
  }

  Future<void> removeEntry(String entryId) {
    if (!_state.entries.containsKey(entryId)) return Future.value();
    unawaited(AnalyticsService.feature(
      'recitation_entry_removed',
      label: 'Recitation entry removed',
    ));
    return _applyOperation(PendingRecitationOperation.remove(entryId));
  }

  /// Registers a new recitation track with no history yet, so it can show up
  /// as a "start reading" card before its first entry. A no-op for a name
  /// already known (including the reserved [unlabeledRecitationLabel]).
  Future<void> addLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == unlabeledRecitationLabel) {
      return Future.value();
    }
    if (_state.customLabels.contains(trimmed)) return Future.value();
    unawaited(AnalyticsService.feature(
      'recitation_track_added',
      label: 'Recitation track added',
    ));
    return _applyOperation(PendingRecitationOperation.addLabel(trimmed));
  }

  String _newEntryId() => 'r_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _applyOperation(
    PendingRecitationOperation operation, {
    bool syncRemote = true,
  }) async {
    final nextState = applyPendingRecitationOperation(_state, operation);
    if (identical(nextState, _state)) return;
    _updateState(nextState);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestState(nextState, markForImport: true);
      debugPrint('RecitationTrackerManager: Updated guest state');
      return;
    }

    try {
      await Future.wait([
        _saveUserStateToSharedPreferences(user.uid, nextState),
        _recordPendingOperation(user.uid, operation),
      ]);
    } catch (error) {
      debugPrint('RecitationTrackerManager: Error saving: $error');
      return;
    }
    // Saved and queued on the device, which is all a caller waits for. The
    // write goes up in the background, folded into one with anything else
    // queued - leaving a juz logs every surah in it at once.
    if (syncRemote) unawaited(_pushPending(user.uid));
  }

  Future<void> deleteAllRecitationData(String userId) async {
    try {
      await _doc(userId).delete();
      await _enqueueStorageWrite(() async {
        await SP.prefs.remove(_userStorageKey(userId));
        await SP.prefs.remove(_pendingOperationsStorageKey(userId));
      });

      if (_auth.currentUser?.uid == userId) {
        _updateState(RecitationTrackerState.empty);
      }

      debugPrint('RecitationTrackerManager: Deleted data for user $userId');
    } catch (error) {
      debugPrint('RecitationTrackerManager: Error deleting data: $error');
      rethrow;
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    super.dispose();
  }
}

class _RemoteRecitationRead {
  _RemoteRecitationRead.success({required this.state}) : succeeded = true;

  _RemoteRecitationRead.failure()
      : succeeded = false,
        state = RecitationTrackerState.empty;

  final bool succeeded;
  final RecitationTrackerState state;
}
