import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/qaza_tracker_state.dart';
import '../services/activity_stats_store.dart';
import '../services/analytics_service.dart';
import '../services/qaza_tracker_sync_policy.dart';
import '../utils/shared_preferences.dart';

/// Keeps the qaza counts, locally and (when signed in) in Firestore.
///
/// Every change is an operation ("one fewer Asr owed") with a unique id. A
/// signed-in change is applied to the visible state at once, queued in
/// SharedPreferences, and then folded into the remote document by
/// [_flushPendingOperations]. The remote document records the ids it has
/// applied (see [QazaRemoteDoc]), so an operation is applied at most once no
/// matter how often it is retried - after a crash, an overlapping snapshot or
/// a burst of taps like "Prayed a full day".
class QazaTrackerManager extends ChangeNotifier {
  static final QazaTrackerManager _instance = QazaTrackerManager._internal();

  factory QazaTrackerManager() {
    return _instance;
  }

  QazaTrackerManager._internal();

  static QazaTrackerManager get instance => _instance;

  static const String _guestStorageKey = 'qaza_tracker_guest';
  static const String _guestImportPendingKey =
      'qaza_tracker_guest_import_pending';
  static const String _guestImportIdKey = 'qaza_tracker_guest_import_id';
  static const String _qazaCollection = 'qaza_tracker';
  static const String _qazaDocId = 'state';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tells this install's operation ids apart from another device's ones
  /// created in the same microsecond.
  final String _deviceNonce =
      Random().nextInt(0x100000000).toRadixString(36).padLeft(7, '0');

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Future<void>? _loadQazaFuture;
  Future<void> _storageWriteQueue = Future.value();

  /// Serializes remote writes, so two flushes never race on the document.
  Future<void> _remoteQueue = Future.value();

  /// Each user's not-yet-synced operations, in the order they were made. The
  /// in-memory list is the source of truth once loaded; SharedPreferences
  /// mirrors it so the queue survives a restart.
  final Map<String, List<PendingQazaOperation>> _pendingByUser = {};

  QazaTrackerState _state = QazaTrackerState.empty;
  String? _loadedUserId;

  /// Whether [_state] belongs to [_loadedUserId]. Until then (and while the
  /// signed-in user differs from the loaded one) changes are ignored rather
  /// than applied on top of someone else's counts.
  bool _stateReady = false;
  bool _isLoading = false;
  bool _hasLoadedQaza = false;
  int _operationSequence = 0;

  bool get isLoading => _isLoading;
  bool get hasLoadedQaza => _hasLoadedQaza;
  QazaTrackerState get state => _state;

  DocumentReference<Map<String, dynamic>> _qazaDoc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_qazaCollection)
        .doc(_qazaDocId);
  }

  String _userStorageKey(String userId) => 'qaza_tracker_user_$userId';

  String _pendingOperationsStorageKey(String userId) =>
      'qaza_tracker_pending_operations_$userId';

  String _legacyPendingDeltaStorageKey(String userId) =>
      'qaza_tracker_pending_delta_$userId';

  /// Set by older versions while a guest import was in the user's cache but
  /// not yet in Firestore.
  String _guestImportMergedStorageKey(String userId) =>
      'qaza_tracker_guest_import_merged_$userId';

  /// True when the in-memory qaza state already belongs to the current user
  /// and the live listener that keeps it fresh is still attached.
  ///
  /// See [FavoritesManager] for the reasoning: a reload costs a remote read
  /// plus a listener re-attach, and the qaza page was paying both on every
  /// visit for state the listener already had current.
  bool get _isLoadedForCurrentUser {
    if (!_hasLoadedQaza) return false;

    final userId = _auth.currentUser?.uid;
    if (_loadedUserId != userId) return false;

    return userId == null || _listener != null;
  }

  /// Loads the qaza state, reusing what is already loaded when it is valid.
  ///
  /// Pass [force] after an auth change, where the remote document has to be
  /// re-read and merged rather than assumed current.
  Future<void> loadQaza({bool force = false}) async {
    if (_loadQazaFuture != null) {
      return _loadQazaFuture!;
    }

    if (!force && _isLoadedForCurrentUser) {
      return;
    }

    final completer = Completer<void>();
    _loadQazaFuture = completer.future;
    _setLoading(true);

    try {
      await _loadQazaInternal();
      _hasLoadedQaza = true;
      notifyListeners();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _loadQazaFuture = null;
      _setLoading(false);
    }
  }

  Future<void> _loadQazaInternal() async {
    await _storageWriteQueue;
    final guestState = _loadStateFromStorageKey(_guestStorageKey);
    final user = _auth.currentUser;
    final isGuestToUserTransition =
        _hasLoadedQaza && _loadedUserId == null && user != null;

    await _listener?.cancel();
    _listener = null;

    if (user == null) {
      _updateState(guestState);
      _loadedUserId = null;
      _stateReady = true;
      debugPrint('QazaTrackerManager: Loaded guest qaza tracker');
      return;
    }

    final userId = user.uid;

    // The cache is always written together with the queue, so it already
    // includes every queued operation. From here on _state is this user's,
    // and operations made during the awaits below update it and the queue
    // together.
    _pendingFor(userId);
    _loadedUserId = userId;
    _stateReady = true;
    _updateState(_loadStateFromStorageKey(_userStorageKey(userId)));

    final shouldImportGuestState = (isGuestToUserTransition ||
            SP.prefs.getBool(_guestImportPendingKey) == true) &&
        !guestState.isEmpty;
    if (shouldImportGuestState) {
      await _queueGuestImport(userId, guestState);
    }

    final remoteRead = await _loadRemoteState(userId);
    if (_auth.currentUser?.uid != userId) return;

    if (!remoteRead.succeeded) {
      // Offline: keep showing the cache; the listener syncs once a server
      // snapshot arrives.
      setupRealtimeListener();
      return;
    }

    if (!remoteRead.exists && !_state.isEmpty) {
      await _seedRemoteFromCache(userId);
    } else {
      _showRemote(userId, remoteRead.doc);
    }

    unawaited(_flushPendingOperations(userId));
    setupRealtimeListener();
  }

  /// Creates the remote document from the cached state when it has none
  /// yet - the cache already includes every queued operation, so they are
  /// recorded as applied rather than applied again.
  Future<void> _seedRemoteFromCache(String userId) async {
    final seedState = _state;
    final seedIds = [for (final operation in _pendingFor(userId)) operation.id];
    try {
      await _enqueueRemote(() async {
        await _firestore.runTransaction((transaction) async {
          final ref = _qazaDoc(userId);
          final snapshot = await transaction.get(ref);
          if (snapshot.exists) return;
          final seed = QazaRemoteDoc(
            state: seedState,
            appliedOperationIds: seedIds.length > qazaAppliedOperationIdLimit
                ? seedIds.sublist(seedIds.length - qazaAppliedOperationIdLimit)
                : seedIds,
          );
          transaction.set(ref, {
            ...seed.toData(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      });
    } catch (error) {
      debugPrint('QazaTrackerManager: Error creating qaza state: $error');
    }
  }

  /// Turns a guest's counts into queued operations for [userId], with ids
  /// derived from a persisted import id: if the app dies before the guest
  /// copy is cleared, the next launch re-queues the same ids, which the
  /// queue and the remote document both ignore.
  Future<void> _queueGuestImport(
    String userId,
    QazaTrackerState guestState,
  ) async {
    final importId = SP.prefs.getString(_guestImportIdKey) ??
        '${DateTime.now().microsecondsSinceEpoch}_$_deviceNonce';
    final pending = _pendingFor(userId);
    final queuedIds = {for (final operation in pending) operation.id};
    final added = <PendingQazaOperation>[];
    for (final type in QazaEntryType.values) {
      final count = guestState.countFor(type);
      if (count.isEmpty) continue;
      final operation = PendingQazaOperation.addCounts(
        id: 'guest_${importId}_${type.key}',
        type: type,
        count: count,
      );
      if (queuedIds.contains(operation.id)) continue;
      pending.add(operation);
      added.add(operation);
    }

    // Older versions could leave the guest counts merged into the cache
    // already; adding them again would show them twice until the next sync.
    final cacheIncludesGuest =
        SP.prefs.getBool(_guestImportMergedStorageKey(userId)) == true;
    if (!cacheIncludesGuest) {
      _updateState(applyPendingQazaOperations(_state, added));
    }
    final visibleState = _state;

    await _enqueueStorageWrite(() async {
      await SP.prefs.setString(_guestImportIdKey, importId);
      await _writePendingOperations(userId, pending);
      await _writeState(_userStorageKey(userId), visibleState);
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
      await SP.prefs.remove(_guestImportMergedStorageKey(userId));
      await SP.prefs.remove(_guestImportIdKey);
    });
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _updateState(QazaTrackerState nextState) {
    _state = nextState;
    notifyListeners();
  }

  /// Shows [doc] plus whatever this device has queued that it lacks.
  void _showRemote(String userId, QazaRemoteDoc doc) {
    final pending = _pendingFor(userId);
    final hadApplied = pending.any((operation) => doc.hasApplied(operation.id));
    if (hadApplied) {
      pending.removeWhere((operation) => doc.hasApplied(operation.id));
    }

    final visibleState = visibleQazaState(doc, pending);
    _updateState(visibleState);
    unawaited(_enqueueStorageWrite(() async {
      if (hadApplied) await _writePendingOperations(userId, pending);
      await _writeState(_userStorageKey(userId), visibleState);
    }));
  }

  QazaTrackerState _loadStateFromStorageKey(String storageKey) {
    return _decodeState(SP.prefs.getString(storageKey));
  }

  QazaTrackerState _decodeState(String? encoded) {
    if (encoded == null || encoded.isEmpty || encoded == 'null') {
      return QazaTrackerState.empty;
    }

    try {
      return QazaTrackerState.fromJson(jsonDecode(encoded));
    } catch (error) {
      debugPrint('QazaTrackerManager: Error decoding state: $error');
      return QazaTrackerState.empty;
    }
  }

  /// Writes [state] under [storageKey]. Only call from inside
  /// [_enqueueStorageWrite].
  Future<void> _writeState(String storageKey, QazaTrackerState state) async {
    try {
      if (state.isEmpty) {
        await SP.prefs.remove(storageKey);
        return;
      }
      await SP.prefs.setString(storageKey, jsonEncode(state.toJson()));
    } catch (error) {
      debugPrint(
        'QazaTrackerManager: Error saving state to $storageKey: $error',
      );
    }
  }

  Future<void> _saveGuestState(QazaTrackerState state) {
    return _enqueueStorageWrite(() async {
      await _writeState(_guestStorageKey, state);
      if (state.isEmpty) {
        await SP.prefs.remove(_guestImportPendingKey);
      } else {
        await SP.prefs.setBool(_guestImportPendingKey, true);
      }
    });
  }

  Future<_RemoteQazaRead> _loadRemoteState(String userId) async {
    try {
      final snapshot =
          await _qazaDoc(userId).get().timeout(const Duration(seconds: 8));
      // Offline, get() falls back to Firestore's cache, which can be older
      // than the local state (that already has everything this device did).
      if (snapshot.metadata.isFromCache) return _RemoteQazaRead.failure();
      return _RemoteQazaRead.success(
        exists: snapshot.exists,
        doc: QazaRemoteDoc.fromData(snapshot.data()),
      );
    } catch (error) {
      debugPrint('QazaTrackerManager: Error loading remote state: $error');
      return _RemoteQazaRead.failure();
    }
  }

  /// The live queue for [userId], read from SharedPreferences the first time.
  List<PendingQazaOperation> _pendingFor(String userId) {
    return _pendingByUser.putIfAbsent(
      userId,
      () => _loadPendingOperations(userId),
    );
  }

  List<PendingQazaOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return [];

      final operations = <PendingQazaOperation>[];
      final seenIds = <String>{};
      for (final value in parsed) {
        final operation = PendingQazaOperation.fromJson(value);
        if (operation == null || !seenIds.add(operation.id)) continue;
        operations.add(operation);
      }
      return operations;
    } catch (error) {
      debugPrint(
        'QazaTrackerManager: Error decoding pending operations: $error',
      );
      return [];
    }
  }

  /// Writes the queue as it is when the write runs. Only call from inside
  /// [_enqueueStorageWrite].
  Future<void> _writePendingOperations(
    String userId,
    List<PendingQazaOperation> operations,
  ) async {
    if (operations.isEmpty) {
      await SP.prefs.remove(_pendingOperationsStorageKey(userId));
      return;
    }
    await SP.prefs.setString(
      _pendingOperationsStorageKey(userId),
      jsonEncode(
        operations.map((operation) => operation.toJson()).toList(),
      ),
    );
  }

  Future<void> _enqueueStorageWrite(Future<void> Function() write) {
    final operation = _storageWriteQueue.then((_) => write());
    _storageWriteQueue = operation.catchError((Object error) {
      debugPrint('QazaTrackerManager: Storage write failed: $error');
    });
    return operation;
  }

  Future<void> _enqueueRemote(Future<void> Function() write) {
    final operation = _remoteQueue.then((_) => write());
    _remoteQueue = operation.catchError((Object error) {
      debugPrint('QazaTrackerManager: Remote write failed: $error');
    });
    return operation;
  }

  /// Folds every queued operation for [userId] into the remote document in
  /// one transaction, then drops them from the queue. Operations queued
  /// while it runs are picked up by the next flush, and ids the document
  /// already has are skipped, so overlapping or repeated flushes are safe.
  ///
  /// Never throws: on failure the operations simply stay queued, and the
  /// next snapshot, change or launch retries them.
  Future<void> _flushPendingOperations(String userId) {
    return _enqueueRemote(() async {
      if (_auth.currentUser?.uid != userId) return;
      final pending = _pendingFor(userId);
      final batch = List<PendingQazaOperation>.of(pending);
      if (batch.isEmpty) return;

      try {
        await _flushBatch(userId, batch);
      } catch (error) {
        debugPrint('QazaTrackerManager: Error syncing qaza tracker: $error');
        return;
      }

      final flushedIds = {for (final operation in batch) operation.id};
      pending.removeWhere((operation) => flushedIds.contains(operation.id));
      await _enqueueStorageWrite(
        () => _writePendingOperations(userId, pending),
      );
      debugPrint(
        'QazaTrackerManager: Synced ${batch.length} qaza operation(s)',
      );
    });
  }

  Future<void> _flushBatch(
    String userId,
    List<PendingQazaOperation> batch,
  ) {
    return _firestore.runTransaction((transaction) async {
      final ref = _qazaDoc(userId);
      final snapshot = await transaction.get(ref);
      final current = QazaRemoteDoc.fromData(snapshot.data());
      if (batch.every((operation) => current.hasApplied(operation.id))) {
        return;
      }
      final next = applyQazaOperationsToRemote(current, batch);
      transaction.set(ref, {
        ...next.toData(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'QazaTrackerManager: No user logged in, skipping listener setup',
      );
      return;
    }

    unawaited(_listener?.cancel());
    final userId = user.uid;
    _listener = _qazaDoc(userId).snapshots().listen(
      (snapshot) {
        if (_auth.currentUser?.uid != userId ||
            _loadedUserId != userId ||
            snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        _showRemote(userId, QazaRemoteDoc.fromData(snapshot.data()));
        if (_pendingFor(userId).isNotEmpty) {
          unawaited(_flushPendingOperations(userId));
        }
      },
      onError: (error) {
        debugPrint('QazaTrackerManager: Error listening to qaza: $error');
      },
    );
  }

  Future<void> addMissed(QazaEntryType type) {
    return _applyOperation(
      PendingQazaOperation.addMissed(
        id: _newOperationId(),
        type: type,
      ),
    );
  }

  Future<void> markCompleted(QazaEntryType type) {
    if (!_canApply || _state.countFor(type).remaining <= 0) {
      return Future.value();
    }
    unawaited(ActivityStatsStore.instance.recordQazaCompleted());
    return _applyOperation(
      PendingQazaOperation.markCompleted(
        id: _newOperationId(),
        type: type,
      ),
    );
  }

  Future<void> undoCompleted(QazaEntryType type) {
    if (!_canApply || _state.countFor(type).completed <= 0) {
      return Future.value();
    }
    unawaited(ActivityStatsStore.instance.undoQazaCompleted());
    return _applyOperation(
      PendingQazaOperation.undoCompleted(
        id: _newOperationId(),
        type: type,
      ),
    );
  }

  Future<void> setCount(
    QazaEntryType type, {
    required int remaining,
    required int completed,
  }) {
    return _applyOperation(
      PendingQazaOperation.setCount(
        id: _newOperationId(),
        type: type,
        count: QazaEntryCount(
          remaining: remaining,
          completed: completed,
        ),
      ),
    );
  }

  /// Marks one of each [types] completed, but only if every one of them has
  /// something owed; otherwise nothing is changed and the result is empty.
  /// Returns the types that were marked, so the caller can undo them.
  List<QazaEntryType> markCompletedEach(Iterable<QazaEntryType> types) {
    final marked = types.toList();
    if (!_canApply ||
        marked.any((type) => _state.countFor(type).remaining <= 0)) {
      return const [];
    }
    for (final type in marked) {
      unawaited(markCompleted(type));
    }
    return marked;
  }

  void undoCompletedEach(Iterable<QazaEntryType> types) {
    for (final type in types) {
      unawaited(undoCompleted(type));
    }
  }

  /// Adds [additions] to the owed count of each type, leaving completed
  /// counts untouched. Sent as additions, not new totals, so they stack on
  /// whatever another device changed meanwhile.
  Future<void> addMissedCounts(Map<QazaEntryType, int> additions) {
    final futures = <Future<void>>[];
    for (final entry in additions.entries) {
      if (entry.value <= 0) continue;
      futures.add(_applyOperation(
        PendingQazaOperation.addCounts(
          id: _newOperationId(),
          type: entry.key,
          count: QazaEntryCount(remaining: entry.value),
        ),
      ));
    }
    return Future.wait(futures);
  }

  bool get _canApply => _stateReady && _loadedUserId == _auth.currentUser?.uid;

  String _newOperationId() {
    final sequence = _operationSequence++;
    return '${DateTime.now().microsecondsSinceEpoch}_${sequence}_$_deviceNonce';
  }

  Future<void> _applyOperation(PendingQazaOperation operation) async {
    // Every qaza mutation funnels through here, so one hook covers adding a
    // missed prayer, marking one done, undoing and bulk edits alike.
    unawaited(AnalyticsService.feature(
      'qaza_updated',
      label: 'Qaza tracker updated',
      parameters: {'operation': operation.kind.key},
    ));
    if (!_canApply) {
      debugPrint('QazaTrackerManager: Ignored change before qaza loaded');
      return;
    }
    final nextState = applyPendingQazaOperation(_state, operation);
    if (identical(nextState, _state)) return;

    final user = _auth.currentUser;
    if (user == null) {
      _updateState(nextState);
      await _saveGuestState(nextState);
      debugPrint('QazaTrackerManager: Updated guest qaza tracker');
      return;
    }

    // State and queue change together, synchronously, so a snapshot handled
    // at any later point sees both or neither.
    final userId = user.uid;
    final pending = _pendingFor(userId);
    pending.add(operation);
    _updateState(nextState);
    await _enqueueStorageWrite(() async {
      await _writePendingOperations(userId, pending);
      await _writeState(_userStorageKey(userId), nextState);
    });
    await _flushPendingOperations(userId);
  }

  Future<void> deleteAllQazaData(String userId) async {
    try {
      // Drop the queue first and delete through the remote queue, so a sync
      // already under way cannot recreate the document afterwards.
      _pendingByUser[userId]?.clear();
      await _enqueueRemote(() => _qazaDoc(userId).delete());
      await _enqueueStorageWrite(() async {
        await SP.prefs.remove(_userStorageKey(userId));
        await SP.prefs.remove(_pendingOperationsStorageKey(userId));
        await SP.prefs.remove(_legacyPendingDeltaStorageKey(userId));
        await SP.prefs.remove(_guestImportMergedStorageKey(userId));
      });

      if (_auth.currentUser?.uid == userId) {
        _updateState(QazaTrackerState.empty);
      }

      debugPrint('QazaTrackerManager: Deleted qaza data for user $userId');
    } catch (error) {
      debugPrint('QazaTrackerManager: Error deleting qaza data: $error');
      rethrow;
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    debugPrint('QazaTrackerManager: Disposed listener');
    super.dispose();
  }
}

class _RemoteQazaRead {
  _RemoteQazaRead.success({
    required this.exists,
    required this.doc,
  }) : succeeded = true;

  _RemoteQazaRead.failure()
      : succeeded = false,
        exists = false,
        doc = QazaRemoteDoc.empty;

  final bool succeeded;
  final bool exists;
  final QazaRemoteDoc doc;
}
