import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/shared_preferences.dart';
import 'zikr_bookmark_store.dart';
import 'zikr_bookmarks_sync_policy.dart';

/// Where the reader left off in each zikr, synced the same way
/// SavedVersesManager syncs saved verses: SharedPreferences for an instant
/// local read, one Firestore document per user for cross-device sync, and a
/// pending-operations queue so a bookmark placed offline is never lost.
///
/// Only bookmarks that know their line sync - see [ZikrBookmarksState]. One
/// that does not stays in [ZikrBookmarkStore] on this device until it is
/// opened, learns its line and is saved again through here; [bookmarkFor]
/// reads both, so the reader never has to know which a bookmark is in.
///
/// Its own document, for the reason saved verses have theirs: every write
/// replaces the whole document, so sharing one would let either feature - or
/// an older build that knows only one of them - wipe out the other.
class ZikrBookmarksManager extends ChangeNotifier {
  static final ZikrBookmarksManager _instance =
      ZikrBookmarksManager._internal();

  factory ZikrBookmarksManager() => _instance;

  ZikrBookmarksManager._internal();

  static ZikrBookmarksManager get instance => _instance;

  static const String _guestStorageKey = 'zikr_bookmarks_guest';
  static const String _guestImportPendingKey =
      'zikr_bookmarks_guest_import_pending';
  static const String _bookmarksCollection = 'zikr_bookmarks';
  static const String _bookmarksDocId = 'state';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Future<void>? _loadFuture;
  Future<void> _storageWriteQueue = Future.value();

  /// Serializes remote transactions: two in flight at once can commit in
  /// either order, so a save and the unsave right after it could land
  /// reversed.
  Future<void> _remoteQueue = Future.value();
  ZikrBookmarksState _state = ZikrBookmarksState.empty;
  ZikrBookmarksState _pendingGuestImportState = ZikrBookmarksState.empty;
  String? _pendingGuestImportUserId;
  String? _loadedUserId;
  bool _isImportingGuestState = false;
  bool _isReplayingPendingOperations = false;
  bool _hasLoaded = false;

  bool get hasLoaded => _hasLoaded;
  ZikrBookmarksState get state => _state;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_bookmarksCollection)
        .doc(_bookmarksDocId);
  }

  String _userStorageKey(String userId) => 'zikr_bookmarks_user_$userId';

  String _pendingOperationsStorageKey(String userId) =>
      'zikr_bookmarks_pending_operations_$userId';

  /// True when the in-memory state already belongs to the current user and
  /// the live listener that keeps it fresh is still attached, so a page visit
  /// costs nothing rather than a remote read.
  bool get _isLoadedForCurrentUser {
    if (!_hasLoaded) return false;

    final userId = _auth.currentUser?.uid;
    if (_loadedUserId != userId) return false;

    return userId == null || _listener != null;
  }

  Future<void> loadBookmarks({bool force = false}) async {
    if (_loadFuture != null) return _loadFuture!;
    if (!force && _isLoadedForCurrentUser) return;

    final completer = Completer<void>();
    _loadFuture = completer.future;

    try {
      await _loadInternal();
      await _importDeviceBookmarks();
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
          ? (shouldImportGuestState ? guestState : ZikrBookmarksState.empty)
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
        applyPendingZikrBookmarkOperations(visibleState, pendingOperations);

    _updateState(visibleState);
    await _saveUserState(user.uid, visibleState);

    if (shouldImportGuestState) {
      try {
        await _mergeRemoteStateForUser(user.uid, guestState);
        await _clearGuestState();
        _pendingGuestImportUserId = null;
        _pendingGuestImportState = ZikrBookmarksState.empty;
      } catch (error) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
        debugPrint('ZikrBookmarksManager: Error importing guest state: $error');
      }
    }

    if (pendingOperations.isNotEmpty) {
      unawaited(_replayPendingOperations(user.uid, pendingOperations));
    }

    _loadedUserId = user.uid;
    setupRealtimeListener();
  }

  void _updateState(ZikrBookmarksState nextState) {
    _state = nextState;
    notifyListeners();
  }

  ZikrBookmarksState _loadStateFromStorageKey(String storageKey) {
    final encoded = SP.prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return ZikrBookmarksState.empty;
    try {
      return ZikrBookmarksState.fromJson(jsonDecode(encoded));
    } catch (error) {
      debugPrint('ZikrBookmarksManager: Error decoding state: $error');
      return ZikrBookmarksState.empty;
    }
  }

  Future<void> _saveStateToStorageKey(
    String storageKey,
    ZikrBookmarksState state,
  ) {
    return _enqueueStorageWrite(() async {
      if (state.isEmpty) {
        await SP.prefs.remove(storageKey);
        return;
      }
      await SP.prefs.setString(storageKey, jsonEncode(state.toJson()));
    });
  }

  Future<void> _saveGuestState(ZikrBookmarksState state) async {
    await _saveStateToStorageKey(_guestStorageKey, state);
    await _enqueueStorageWrite(() async {
      if (state.isEmpty) {
        await SP.prefs.remove(_guestImportPendingKey);
      } else {
        await SP.prefs.setBool(_guestImportPendingKey, true);
      }
    });
  }

  Future<void> _saveUserState(String userId, ZikrBookmarksState state) {
    return _saveStateToStorageKey(_userStorageKey(userId), state);
  }

  Future<void> _clearGuestState() {
    return _enqueueStorageWrite(() async {
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
    });
  }

  Future<_RemoteZikrBookmarksRead> _loadRemoteState(String userId) async {
    try {
      final snapshot =
          await _doc(userId).get().timeout(const Duration(seconds: 8));
      return _RemoteZikrBookmarksRead.success(
        ZikrBookmarksState.fromJson(snapshot.data()?['state']),
      );
    } catch (error) {
      debugPrint('ZikrBookmarksManager: Error loading remote state: $error');
      return _RemoteZikrBookmarksRead.failure();
    }
  }

  List<PendingZikrBookmarkOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];

      // Keyed by id, last one wins: a bookmark saved, moved and removed
      // leaves only the removal to replay.
      final operations = <String, PendingZikrBookmarkOperation>{};
      for (final value in parsed) {
        final operation = PendingZikrBookmarkOperation.fromJson(value);
        if (operation == null) continue;
        operations[operation.id] = operation;
      }
      return operations.values.toList(growable: false);
    } catch (error) {
      debugPrint(
          'ZikrBookmarksManager: Error decoding pending operations: $error');
      return const [];
    }
  }

  Future<void> _recordPendingOperation(
    String userId,
    PendingZikrBookmarkOperation operation,
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
    PendingZikrBookmarkOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      // Only the exact version that was synced: if the reader moved the
      // same bookmark again while this one was in flight, that newer
      // operation still has to go up.
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
    List<PendingZikrBookmarkOperation> operations,
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
      debugPrint('ZikrBookmarksManager: Storage write failed: $error');
    });
    return operation;
  }

  Future<void> _writeRemote(
    String userId,
    ZikrBookmarksState Function(ZikrBookmarksState current) change, {
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
    ZikrBookmarksState Function(ZikrBookmarksState current) change,
  ) {
    return _firestore.runTransaction((transaction) async {
      final ref = _doc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? ZikrBookmarksState.fromJson(snapshot.data()?['state'])
          : ZikrBookmarksState.empty;
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
    ZikrBookmarksState addition,
  ) async {
    if (addition.isEmpty) return;
    await _writeRemote(userId, (current) => current.plus(addition));
  }

  /// With [onlyIfPending], skips [operation] if, by the time its turn comes,
  /// it is no longer the queued version for its item - a replay working from
  /// an older copy of the queue must not undo a change made since.
  Future<void> _applyRemoteOperationForUser(
    String userId,
    PendingZikrBookmarkOperation operation, {
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
      (current) => applyPendingZikrBookmarkOperation(current, operation),
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

        var remoteState =
            ZikrBookmarksState.fromJson(snapshot.data()?['state']);
        if (_pendingGuestImportUserId == user.uid &&
            !_pendingGuestImportState.isEmpty &&
            !_isImportingGuestState) {
          _isImportingGuestState = true;
          try {
            await _mergeRemoteStateForUser(user.uid, _pendingGuestImportState);
            remoteState = remoteState.plus(_pendingGuestImportState);
            await _clearGuestState();
            _pendingGuestImportUserId = null;
            _pendingGuestImportState = ZikrBookmarksState.empty;
          } catch (error) {
            debugPrint(
              'ZikrBookmarksManager: Deferred guest import failed: $error',
            );
          } finally {
            _isImportingGuestState = false;
          }
        }

        await _storageWriteQueue;
        final pendingOperations = _loadPendingOperations(user.uid);
        final visibleState =
            applyPendingZikrBookmarkOperations(remoteState, pendingOperations);
        _updateState(visibleState);
        await _saveUserState(user.uid, visibleState);

        if (pendingOperations.isNotEmpty) {
          unawaited(_replayPendingOperations(user.uid, pendingOperations));
        }
      },
      onError: (error) {
        debugPrint('ZikrBookmarksManager: Error listening: $error');
      },
    );
  }

  Future<void> _replayPendingOperations(
    String userId,
    List<PendingZikrBookmarkOperation> operations,
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
      debugPrint(
          'ZikrBookmarksManager: Pending operation replay failed: $error');
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

  /// The bookmark on the zikr [uid], wherever it is kept: synced, or still
  /// only on this device for want of a line. The later one if both.
  ZikrBookmark? bookmarkFor(String uid) {
    final synced = _state[uid];
    final onDevice = ZikrBookmarkStore.instance.read(uid);
    if (synced == null) return onDevice;
    if (onDevice == null) return synced;
    return onDevice.updatedAt.isAfter(synced.updatedAt) ? onDevice : synced;
  }

  /// Keeps [bookmark] as its zikr's bookmark, replacing any earlier one.
  ///
  /// One without a line cannot sync, so it is kept on this device alone.
  /// One with a line syncs, and takes over from any device-only copy.
  Future<void> save(ZikrBookmark bookmark) async {
    if (bookmark.uid.isEmpty) return;
    if (!ZikrBookmarksState.isSyncable(bookmark)) {
      await ZikrBookmarkStore.instance.save(bookmark);
      return;
    }

    // Changed here, now, it is the newest bookmark, even if another device
    // with its clock running ahead stamped the one it replaces later.
    final existing = _state[bookmark.uid];
    final stamped = existing != null &&
            !bookmark.updatedAt.isAfter(existing.updatedAt)
        ? bookmark.copyWith(
            updatedAt: existing.updatedAt.add(const Duration(milliseconds: 1)),
          )
        : bookmark;
    await ZikrBookmarkStore.instance.remove(bookmark.uid);
    await _applyOperation(PendingZikrBookmarkOperation.save(stamped));
  }

  /// Removes the zikr [uid]'s bookmark, synced and on-device alike.
  Future<void> remove(String uid) async {
    await ZikrBookmarkStore.instance.remove(uid);
    final existing = _state[uid];
    if (existing == null) return;

    // Never earlier than the bookmark itself, or a removal made here could
    // lose to a bookmark another device's fast clock dated in the future.
    final now = DateTime.now().toUtc();
    await _applyOperation(PendingZikrBookmarkOperation.remove(
      uid,
      existing.updatedAt.isAfter(now) ? existing.updatedAt : now,
    ));
  }

  Future<void> _applyOperation(
    PendingZikrBookmarkOperation operation, {
    bool syncRemote = true,
  }) async {
    final nextState = applyPendingZikrBookmarkOperation(_state, operation);
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
      debugPrint('ZikrBookmarksManager: Error syncing: $error');
    }
  }

  /// Moves bookmarks placed before bookmarks synced - kept on the device
  /// only, by [ZikrBookmarkStore] - into the synced state, once.
  ///
  /// Each goes through the ordinary save path, so it lands in the guest state
  /// or the signed-in account's queue like a bookmark placed today would, and
  /// a later one the synced state already has for that zikr is kept over it.
  /// Its device copy is only removed once it is saved (and, signed in,
  /// queued), so an interrupted move is simply picked up again on the next
  /// load. One without a line is left where it is: see [save].
  Future<void> _importDeviceBookmarks() async {
    final onDevice = ZikrBookmarkStore.instance
        .readAll()
        .where(ZikrBookmarksState.isSyncable)
        .toList(growable: false);
    if (onDevice.isEmpty) return;

    for (final bookmark in onDevice) {
      await _applyOperation(
        PendingZikrBookmarkOperation.save(bookmark),
        syncRemote: false,
      );
      await ZikrBookmarkStore.instance.remove(bookmark.uid);
    }
    unawaited(syncPendingOperations());
  }

  Future<void> deleteAllBookmarks(String userId) async {
    await _doc(userId).delete();
    await _enqueueStorageWrite(() async {
      await SP.prefs.remove(_userStorageKey(userId));
      await SP.prefs.remove(_pendingOperationsStorageKey(userId));
    });
    if (_auth.currentUser?.uid == userId) {
      _updateState(ZikrBookmarksState.empty);
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
    _state = ZikrBookmarksState.empty;
    _pendingGuestImportState = ZikrBookmarksState.empty;
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

class _RemoteZikrBookmarksRead {
  _RemoteZikrBookmarksRead.success(this.state) : succeeded = true;

  _RemoteZikrBookmarksRead.failure()
      : succeeded = false,
        state = ZikrBookmarksState.empty;

  final bool succeeded;
  final ZikrBookmarksState state;
}
