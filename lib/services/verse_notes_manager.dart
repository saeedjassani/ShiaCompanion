import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/verse_note.dart';
import '../utils/quran_index.dart';
import '../utils/shared_preferences.dart';
import 'verse_notes_sync_policy.dart';

export '../models/verse_note.dart';

/// The reader's notes on Quran verses, synced the same way
/// ZikrBookmarksManager syncs zikr bookmarks: SharedPreferences for an
/// instant local read, one Firestore document per user for cross-device
/// sync, and a pending-operations queue so a note written offline is never
/// lost.
///
/// Its own document rather than a field on each saved verse: every write
/// replaces the whole document, so an older build that knows saved verses
/// but not notes would wipe out every note the next time it saved a verse.
/// A note does not save its verse either - the two lists are kept apart, as
/// someone may well want to annotate a verse they would not bookmark.
class VerseNotesManager extends ChangeNotifier {
  static final VerseNotesManager _instance = VerseNotesManager._internal();

  factory VerseNotesManager() => _instance;

  VerseNotesManager._internal();

  static VerseNotesManager get instance => _instance;

  static const String _guestStorageKey = 'verse_notes_guest';
  static const String _guestImportPendingKey =
      'verse_notes_guest_import_pending';
  static const String _notesCollection = 'verse_notes';
  static const String _notesDocId = 'state';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Future<void>? _loadFuture;
  Future<void> _storageWriteQueue = Future.value();

  /// Serializes remote transactions: two in flight at once can commit in
  /// either order, so a save and the unsave right after it could land
  /// reversed.
  Future<void> _remoteQueue = Future.value();
  VerseNotesState _state = VerseNotesState.empty;
  VerseNotesState _pendingGuestImportState = VerseNotesState.empty;
  String? _pendingGuestImportUserId;
  String? _loadedUserId;
  bool _isImportingGuestState = false;
  bool _isReplayingPendingOperations = false;
  bool _hasLoaded = false;

  bool get hasLoaded => _hasLoaded;
  VerseNotesState get state => _state;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_notesCollection)
        .doc(_notesDocId);
  }

  String _userStorageKey(String userId) => 'verse_notes_user_$userId';

  String _pendingOperationsStorageKey(String userId) =>
      'verse_notes_pending_operations_$userId';

  /// True when the in-memory state already belongs to the current user and
  /// the live listener that keeps it fresh is still attached, so a page visit
  /// costs nothing rather than a remote read.
  bool get _isLoadedForCurrentUser {
    if (!_hasLoaded) return false;

    final userId = _auth.currentUser?.uid;
    if (_loadedUserId != userId) return false;

    return userId == null || _listener != null;
  }

  Future<void> loadNotes({bool force = false}) async {
    if (_loadFuture != null) return _loadFuture!;
    if (!force && _isLoadedForCurrentUser) return;

    final completer = Completer<void>();
    _loadFuture = completer.future;

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
          ? (shouldImportGuestState ? guestState : VerseNotesState.empty)
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
        applyPendingVerseNoteOperations(visibleState, pendingOperations);

    _updateState(visibleState);
    await _saveUserState(user.uid, visibleState);

    if (shouldImportGuestState) {
      try {
        await _mergeRemoteStateForUser(user.uid, guestState);
        await _clearGuestState();
        _pendingGuestImportUserId = null;
        _pendingGuestImportState = VerseNotesState.empty;
      } catch (error) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
        debugPrint('VerseNotesManager: Error importing guest state: $error');
      }
    }

    if (pendingOperations.isNotEmpty) {
      unawaited(_replayPendingOperations(user.uid, pendingOperations));
    }

    _loadedUserId = user.uid;
    setupRealtimeListener();
  }

  void _updateState(VerseNotesState nextState) {
    _state = nextState;
    notifyListeners();
  }

  VerseNotesState _loadStateFromStorageKey(String storageKey) {
    final encoded = SP.prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return VerseNotesState.empty;
    try {
      return VerseNotesState.fromJson(jsonDecode(encoded));
    } catch (error) {
      debugPrint('VerseNotesManager: Error decoding state: $error');
      return VerseNotesState.empty;
    }
  }

  Future<void> _saveStateToStorageKey(
    String storageKey,
    VerseNotesState state,
  ) {
    return _enqueueStorageWrite(() async {
      if (state.isEmpty) {
        await SP.prefs.remove(storageKey);
        return;
      }
      await SP.prefs.setString(storageKey, jsonEncode(state.toJson()));
    });
  }

  Future<void> _saveGuestState(VerseNotesState state) async {
    await _saveStateToStorageKey(_guestStorageKey, state);
    await _enqueueStorageWrite(() async {
      if (state.isEmpty) {
        await SP.prefs.remove(_guestImportPendingKey);
      } else {
        await SP.prefs.setBool(_guestImportPendingKey, true);
      }
    });
  }

  Future<void> _saveUserState(String userId, VerseNotesState state) {
    return _saveStateToStorageKey(_userStorageKey(userId), state);
  }

  Future<void> _clearGuestState() {
    return _enqueueStorageWrite(() async {
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
    });
  }

  Future<_RemoteVerseNotesRead> _loadRemoteState(String userId) async {
    try {
      final snapshot =
          await _doc(userId).get().timeout(const Duration(seconds: 8));
      return _RemoteVerseNotesRead.success(
        VerseNotesState.fromJson(snapshot.data()?['state']),
      );
    } catch (error) {
      debugPrint('VerseNotesManager: Error loading remote state: $error');
      return _RemoteVerseNotesRead.failure();
    }
  }

  List<PendingVerseNoteOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];

      // Keyed by id, last one wins: a note written, edited and deleted
      // leaves only the deletion to replay.
      final operations = <String, PendingVerseNoteOperation>{};
      for (final value in parsed) {
        final operation = PendingVerseNoteOperation.fromJson(value);
        if (operation == null) continue;
        operations[operation.id] = operation;
      }
      return operations.values.toList(growable: false);
    } catch (error) {
      debugPrint(
          'VerseNotesManager: Error decoding pending operations: $error');
      return const [];
    }
  }

  Future<void> _recordPendingOperation(
    String userId,
    PendingVerseNoteOperation operation,
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
    PendingVerseNoteOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      // Only the exact version that was synced: if the reader edited the
      // same note again while this one was in flight, that newer
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
    List<PendingVerseNoteOperation> operations,
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
      debugPrint('VerseNotesManager: Storage write failed: $error');
    });
    return operation;
  }

  Future<void> _writeRemote(
    String userId,
    VerseNotesState Function(VerseNotesState current) change, {
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
    VerseNotesState Function(VerseNotesState current) change,
  ) {
    return _firestore.runTransaction((transaction) async {
      final ref = _doc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? VerseNotesState.fromJson(snapshot.data()?['state'])
          : VerseNotesState.empty;
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
    VerseNotesState addition,
  ) async {
    if (addition.isEmpty) return;
    await _writeRemote(userId, (current) => current.plus(addition));
  }

  /// With [onlyIfPending], skips [operation] if, by the time its turn comes,
  /// it is no longer the queued version for its item - a replay working from
  /// an older copy of the queue must not undo a change made since.
  Future<void> _applyRemoteOperationForUser(
    String userId,
    PendingVerseNoteOperation operation, {
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
      (current) => applyPendingVerseNoteOperation(current, operation),
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

        var remoteState = VerseNotesState.fromJson(snapshot.data()?['state']);
        if (_pendingGuestImportUserId == user.uid &&
            !_pendingGuestImportState.isEmpty &&
            !_isImportingGuestState) {
          _isImportingGuestState = true;
          try {
            await _mergeRemoteStateForUser(user.uid, _pendingGuestImportState);
            remoteState = remoteState.plus(_pendingGuestImportState);
            await _clearGuestState();
            _pendingGuestImportUserId = null;
            _pendingGuestImportState = VerseNotesState.empty;
          } catch (error) {
            debugPrint(
              'VerseNotesManager: Deferred guest import failed: $error',
            );
          } finally {
            _isImportingGuestState = false;
          }
        }

        await _storageWriteQueue;
        final pendingOperations = _loadPendingOperations(user.uid);
        final visibleState =
            applyPendingVerseNoteOperations(remoteState, pendingOperations);
        _updateState(visibleState);
        await _saveUserState(user.uid, visibleState);

        if (pendingOperations.isNotEmpty) {
          unawaited(_replayPendingOperations(user.uid, pendingOperations));
        }
      },
      onError: (error) {
        debugPrint('VerseNotesManager: Error listening: $error');
      },
    );
  }

  Future<void> _replayPendingOperations(
    String userId,
    List<PendingVerseNoteOperation> operations,
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
      debugPrint('VerseNotesManager: Pending operation replay failed: $error');
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

  /// The reader's note on [verse], if they wrote one.
  VerseNote? noteFor(VerseKey verse) => _state.noteFor(verse);

  /// Keeps [note] as its verse's note, replacing any earlier one. A note
  /// left empty deletes it instead.
  Future<void> save(VerseNote note) async {
    if (note.text.trim().isEmpty) return remove(note.verse);
    if (!note.isValid) return;

    // Written here, now, it is the newest note, even if another device with
    // its clock running ahead stamped the one it replaces later.
    final existing = _state.notes[note.key];
    final stamped = existing != null &&
            !note.updatedAt.isAfter(existing.updatedAt)
        ? note.copyWith(
            updatedAt: existing.updatedAt.add(const Duration(milliseconds: 1)),
          )
        : note;
    await _applyOperation(PendingVerseNoteOperation.save(stamped));
  }

  /// Deletes the reader's note on [verse].
  Future<void> remove(VerseKey verse) async {
    final existing = _state.noteFor(verse);
    if (existing == null) return;

    // Never earlier than the note itself, or a deletion made here could lose
    // to a note another device's fast clock dated in the future.
    final now = DateTime.now().toUtc();
    await _applyOperation(PendingVerseNoteOperation.remove(
      existing.key,
      existing.updatedAt.isAfter(now) ? existing.updatedAt : now,
    ));
  }

  Future<void> _applyOperation(PendingVerseNoteOperation operation) async {
    final nextState = applyPendingVerseNoteOperation(_state, operation);
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
      await _applyRemoteOperationForUser(user.uid, operation);
      await _clearPendingOperation(user.uid, operation);
    } catch (error) {
      debugPrint('VerseNotesManager: Error syncing: $error');
    }
  }

  Future<void> deleteAllNotes(String userId) async {
    await _doc(userId).delete();
    await _enqueueStorageWrite(() async {
      await SP.prefs.remove(_userStorageKey(userId));
      await SP.prefs.remove(_pendingOperationsStorageKey(userId));
    });
    if (_auth.currentUser?.uid == userId) {
      _updateState(VerseNotesState.empty);
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
    _state = VerseNotesState.empty;
    _pendingGuestImportState = VerseNotesState.empty;
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

class _RemoteVerseNotesRead {
  _RemoteVerseNotesRead.success(this.state) : succeeded = true;

  _RemoteVerseNotesRead.failure()
      : succeeded = false,
        state = VerseNotesState.empty;

  final bool succeeded;
  final VerseNotesState state;
}
