import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/quran_index.dart';
import '../utils/shared_preferences.dart';
import 'saved_verses_store.dart';
import 'saved_verses_sync_policy.dart';

/// The Quran verses the reader kept, synced the same way
/// [RecitationTrackerManager] syncs recitations: SharedPreferences for an
/// instant local read, one Firestore document per user for cross-device
/// sync, and a pending-operations queue so a save made offline is never lost.
///
/// Its own document rather than a field on the recitation tracker's: the two
/// have nothing to do with each other, and every write here replaces the
/// whole document, so sharing one would let either feature - or an older
/// build that knows only one of them - wipe out the other.
class SavedVersesManager extends ChangeNotifier {
  static final SavedVersesManager _instance = SavedVersesManager._internal();

  factory SavedVersesManager() => _instance;

  SavedVersesManager._internal();

  static SavedVersesManager get instance => _instance;

  static const String _guestStorageKey = 'saved_verses_guest';
  static const String _guestImportPendingKey =
      'saved_verses_guest_import_pending';
  static const String _savedVersesCollection = 'saved_verses';
  static const String _savedVersesDocId = 'state';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Future<void>? _loadFuture;
  Future<void> _storageWriteQueue = Future.value();

  /// Serializes remote transactions: two in flight at once can commit in
  /// either order, so a save and the unsave right after it could land
  /// reversed.
  Future<void> _remoteQueue = Future.value();
  SavedVersesState _state = SavedVersesState.empty;
  SavedVersesState _pendingGuestImportState = SavedVersesState.empty;
  String? _pendingGuestImportUserId;
  String? _loadedUserId;
  bool _isImportingGuestState = false;
  bool _isReplayingPendingOperations = false;
  bool _hasLoaded = false;

  bool get hasLoaded => _hasLoaded;
  SavedVersesState get state => _state;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_savedVersesCollection)
        .doc(_savedVersesDocId);
  }

  String _userStorageKey(String userId) => 'saved_verses_user_$userId';

  String _pendingOperationsStorageKey(String userId) =>
      'saved_verses_pending_operations_$userId';

  /// True when the in-memory state already belongs to the current user and
  /// the live listener that keeps it fresh is still attached, so a page visit
  /// costs nothing rather than a remote read.
  bool get _isLoadedForCurrentUser {
    if (!_hasLoaded) return false;

    final userId = _auth.currentUser?.uid;
    if (_loadedUserId != userId) return false;

    return userId == null || _listener != null;
  }

  Future<void> loadSavedVerses({bool force = false}) async {
    if (_loadFuture != null) return _loadFuture!;
    if (!force && _isLoadedForCurrentUser) return;

    final completer = Completer<void>();
    _loadFuture = completer.future;

    try {
      await _loadInternal();
      await _importDeviceSavedVerses();
      _hasLoaded = true;
      notifyListeners();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _loadFuture = null;
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
          ? (shouldImportGuestState ? guestState : SavedVersesState.empty)
          : cachedState;
      _updateState(visibleState);
      await _saveUserState(user.uid, visibleState);
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
    visibleState =
        applyPendingSavedVerseOperations(visibleState, pendingOperations);

    _updateState(visibleState);
    await _saveUserState(user.uid, visibleState);

    if (shouldImportGuestState) {
      try {
        await _mergeRemoteStateForUser(user.uid, guestState);
        await _clearGuestState();
        _pendingGuestImportUserId = null;
        _pendingGuestImportState = SavedVersesState.empty;
      } catch (error) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
        debugPrint('SavedVersesManager: Error importing guest state: $error');
      }
    }

    if (pendingOperations.isNotEmpty) {
      unawaited(_replayPendingOperations(user.uid, pendingOperations));
    }

    _loadedUserId = user.uid;
    setupRealtimeListener();
  }

  void _updateState(SavedVersesState nextState) {
    _state = nextState;
    notifyListeners();
  }

  SavedVersesState _loadStateFromStorageKey(String storageKey) {
    final encoded = SP.prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return SavedVersesState.empty;
    try {
      return SavedVersesState.fromJson(jsonDecode(encoded));
    } catch (error) {
      debugPrint('SavedVersesManager: Error decoding state: $error');
      return SavedVersesState.empty;
    }
  }

  Future<void> _saveStateToStorageKey(
    String storageKey,
    SavedVersesState state,
  ) {
    return _enqueueStorageWrite(() async {
      if (state.isEmpty) {
        await SP.prefs.remove(storageKey);
        return;
      }
      await SP.prefs.setString(storageKey, jsonEncode(state.toJson()));
    });
  }

  Future<void> _saveGuestState(SavedVersesState state) async {
    await _saveStateToStorageKey(_guestStorageKey, state);
    await _enqueueStorageWrite(() async {
      if (state.isEmpty) {
        await SP.prefs.remove(_guestImportPendingKey);
      } else {
        await SP.prefs.setBool(_guestImportPendingKey, true);
      }
    });
  }

  Future<void> _saveUserState(String userId, SavedVersesState state) {
    return _saveStateToStorageKey(_userStorageKey(userId), state);
  }

  Future<void> _clearGuestState() {
    return _enqueueStorageWrite(() async {
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
    });
  }

  Future<_RemoteSavedVersesRead> _loadRemoteState(String userId) async {
    try {
      final snapshot =
          await _doc(userId).get().timeout(const Duration(seconds: 8));
      return _RemoteSavedVersesRead.success(
        SavedVersesState.fromJson(snapshot.data()?['state']),
      );
    } catch (error) {
      debugPrint('SavedVersesManager: Error loading remote state: $error');
      return _RemoteSavedVersesRead.failure();
    }
  }

  List<PendingSavedVerseOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];

      // Keyed by id, last one wins: a save and a later unsave of the same
      // verse leave only the unsave to replay.
      final operations = <String, PendingSavedVerseOperation>{};
      for (final value in parsed) {
        final operation = PendingSavedVerseOperation.fromJson(value);
        if (operation == null) continue;
        operations[operation.id] = operation;
      }
      return operations.values.toList(growable: false);
    } catch (error) {
      debugPrint(
          'SavedVersesManager: Error decoding pending operations: $error');
      return const [];
    }
  }

  Future<void> _recordPendingOperation(
    String userId,
    PendingSavedVerseOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      final operations = [
        ..._loadPendingOperations(userId)
            .where((pending) => pending.id != operation.id),
        operation,
      ];
      await _writePendingOperations(userId, operations);
    });
  }

  Future<void> _clearPendingOperation(
    String userId,
    PendingSavedVerseOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      // Only the exact version that was synced: if the reader flipped the
      // same verse again while this one was in flight, that newer operation
      // still has to go up.
      final synced = jsonEncode(operation.toJson());
      final operations = _loadPendingOperations(userId)
          .where((pending) =>
              pending.id != operation.id ||
              jsonEncode(pending.toJson()) != synced)
          .toList(growable: false);
      await _writePendingOperations(userId, operations);
    });
  }

  Future<void> _writePendingOperations(
    String userId,
    List<PendingSavedVerseOperation> operations,
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
      debugPrint('SavedVersesManager: Storage write failed: $error');
    });
    return operation;
  }

  Future<void> _writeRemote(
    String userId,
    SavedVersesState Function(SavedVersesState current) change, {
    bool Function()? stillWanted,
  }) {
    final write = _remoteQueue.then((_) async {
      if (stillWanted != null && !stillWanted()) return;
      await _runRemoteTransaction(userId, change);
    });
    _remoteQueue = write.catchError((Object _) {});
    return write;
  }

  Future<void> _runRemoteTransaction(
    String userId,
    SavedVersesState Function(SavedVersesState current) change,
  ) {
    return _firestore.runTransaction((transaction) async {
      final ref = _doc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? SavedVersesState.fromJson(snapshot.data()?['state'])
          : SavedVersesState.empty;
      transaction.set(ref, {
        'version': 1,
        'state': change(current).toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Merges [addition] into the remote doc inside a transaction, so an
  /// import replayed after a dropped connection can never duplicate.
  Future<void> _mergeRemoteStateForUser(
    String userId,
    SavedVersesState addition,
  ) async {
    if (addition.isEmpty) return;
    await _writeRemote(userId, (current) => current.plus(addition));
  }

  /// With [onlyIfPending], skips [operation] if, by the time its turn comes,
  /// it is no longer the queued version for its item - a replay working from
  /// an older copy of the queue must not undo a change made since.
  Future<void> _applyRemoteOperationForUser(
    String userId,
    PendingSavedVerseOperation operation, {
    bool onlyIfPending = false,
  }) {
    final synced = jsonEncode(operation.toJson());
    return _writeRemote(
      userId,
      stillWanted: onlyIfPending
          ? () => _loadPendingOperations(userId).any((pending) =>
              pending.id == operation.id &&
              jsonEncode(pending.toJson()) == synced)
          : null,
      (current) => applyPendingSavedVerseOperation(current, operation),
    );
  }

  void setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    unawaited(_listener?.cancel());
    _listener = _doc(user.uid).snapshots().listen(
      (snapshot) async {
        if (_auth.currentUser?.uid != user.uid ||
            snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        var remoteState = SavedVersesState.fromJson(snapshot.data()?['state']);
        if (_pendingGuestImportUserId == user.uid &&
            !_pendingGuestImportState.isEmpty &&
            !_isImportingGuestState) {
          _isImportingGuestState = true;
          try {
            await _mergeRemoteStateForUser(user.uid, _pendingGuestImportState);
            remoteState = remoteState.plus(_pendingGuestImportState);
            await _clearGuestState();
            _pendingGuestImportUserId = null;
            _pendingGuestImportState = SavedVersesState.empty;
          } catch (error) {
            debugPrint(
              'SavedVersesManager: Deferred guest import failed: $error',
            );
          } finally {
            _isImportingGuestState = false;
          }
        }

        await _storageWriteQueue;
        final pendingOperations = _loadPendingOperations(user.uid);
        final visibleState =
            applyPendingSavedVerseOperations(remoteState, pendingOperations);
        _updateState(visibleState);
        await _saveUserState(user.uid, visibleState);

        if (pendingOperations.isNotEmpty) {
          unawaited(_replayPendingOperations(user.uid, pendingOperations));
        }
      },
      onError: (error) {
        debugPrint('SavedVersesManager: Error listening: $error');
      },
    );
  }

  Future<void> _replayPendingOperations(
    String userId,
    List<PendingSavedVerseOperation> operations,
  ) async {
    if (_isReplayingPendingOperations || operations.isEmpty) return;
    _isReplayingPendingOperations = true;
    try {
      for (final operation in operations) {
        await _applyRemoteOperationForUser(
          userId,
          operation,
          onlyIfPending: true,
        );
        await _clearPendingOperation(userId, operation);
      }
    } catch (error) {
      debugPrint('SavedVersesManager: Pending operation replay failed: $error');
    } finally {
      _isReplayingPendingOperations = false;
    }
  }

  /// Sends whatever is still queued for the signed-in user to Firestore.
  Future<void> syncPendingOperations() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _storageWriteQueue;
    final operations = _loadPendingOperations(user.uid);
    if (operations.isEmpty) return;
    await _replayPendingOperations(user.uid, operations);
  }

  /// Keeps [verse], replacing an earlier save of the same one.
  Future<void> save(SavedVerse verse) {
    if (!verse.isValid) return Future.value();
    return _applyOperation(PendingSavedVerseOperation.save(verse));
  }

  Future<void> unsave(VerseKey verse) {
    if (!_state.contains(verse)) return Future.value();
    return _applyOperation(
      PendingSavedVerseOperation.unsave(savedVerseKey(verse)),
    );
  }

  Future<void> _applyOperation(
    PendingSavedVerseOperation operation, {
    bool syncRemote = true,
  }) async {
    final nextState = applyPendingSavedVerseOperation(_state, operation);
    if (identical(nextState, _state)) return;
    _updateState(nextState);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestState(nextState);
      return;
    }

    try {
      await Future.wait([
        _saveUserState(user.uid, nextState),
        _recordPendingOperation(user.uid, operation),
      ]);
      if (!syncRemote) return;
      await _applyRemoteOperationForUser(user.uid, operation);
      await _clearPendingOperation(user.uid, operation);
    } catch (error) {
      debugPrint('SavedVersesManager: Error syncing: $error');
    }
  }

  /// Moves verses saved before saved verses synced - kept on the device only,
  /// by [SavedVersesStore] - into the synced state, once.
  ///
  /// Each goes through the ordinary save path, so it lands in the guest state
  /// or the signed-in account's queue like a verse saved today would. A verse
  /// the synced state already has is left as it is there. The device copy is
  /// only emptied once every verse is saved (and, signed in, queued), so an
  /// interrupted move is simply picked up again on the next load.
  Future<void> _importDeviceSavedVerses() async {
    final onDevice = SavedVersesStore.instance.readAll();
    if (onDevice.isEmpty) return;

    for (final verse in onDevice) {
      if (_state.verses.containsKey(verse.key)) continue;
      await _applyOperation(
        PendingSavedVerseOperation.save(verse),
        syncRemote: false,
      );
    }
    await SavedVersesStore.instance.clear();
    unawaited(syncPendingOperations());
  }

  Future<void> deleteAllSavedVerses(String userId) async {
    await _doc(userId).delete();
    await _enqueueStorageWrite(() async {
      await SP.prefs.remove(_userStorageKey(userId));
      await SP.prefs.remove(_pendingOperationsStorageKey(userId));
    });
    if (_auth.currentUser?.uid == userId) {
      _updateState(SavedVersesState.empty);
    }
  }

  /// Forgets everything held in memory, as a fresh launch would.
  ///
  /// A singleton outlives each widget test, and a write queued inside one
  /// test's fake-async zone can never complete in the next - leaving any
  /// later load waiting on it forever.
  @visibleForTesting
  void resetForTesting() {
    unawaited(_listener?.cancel());
    _listener = null;
    _loadFuture = null;
    _storageWriteQueue = Future.value();
    _state = SavedVersesState.empty;
    _pendingGuestImportState = SavedVersesState.empty;
    _pendingGuestImportUserId = null;
    _loadedUserId = null;
    _isImportingGuestState = false;
    _isReplayingPendingOperations = false;
    _hasLoaded = false;
  }

  @override
  void dispose() {
    _listener?.cancel();
    super.dispose();
  }
}

class _RemoteSavedVersesRead {
  _RemoteSavedVersesRead.success(this.state) : succeeded = true;

  _RemoteSavedVersesRead.failure()
      : succeeded = false,
        state = SavedVersesState.empty;

  final bool succeeded;
  final SavedVersesState state;
}
