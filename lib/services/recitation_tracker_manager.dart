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
  bool _isReplayingPendingOperations = false;
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

    if (pendingOperations.isNotEmpty) {
      unawaited(_replayPendingOperations(user.uid, pendingOperations));
    }

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

      final operations = <PendingRecitationOperation>[];
      final seenIds = <String>{};
      for (final value in parsed) {
        final operation = PendingRecitationOperation.fromJson(value);
        if (operation == null || !seenIds.add(operation.id)) continue;
        operations.add(operation);
      }
      return operations;
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
      final operations = [
        ..._loadPendingOperations(userId),
        operation,
      ];
      await _writePendingOperations(userId, operations);
    });
  }

  Future<void> _clearPendingOperation(
    String userId,
    PendingRecitationOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      final operations = _loadPendingOperations(userId)
          .where((pending) => pending.id != operation.id)
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

  /// Merges [addition] into the remote doc inside a transaction, so an
  /// import replayed after a dropped connection can never double-count.
  Future<void> _mergeRemoteStateForUser(
    String userId,
    RecitationTrackerState addition,
  ) async {
    if (addition.isEmpty) return;
    await _firestore.runTransaction((transaction) async {
      final ref = _doc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? RecitationTrackerState.fromJson(snapshot.data()?['state'])
          : RecitationTrackerState.empty;
      final nextState = current.plus(addition);
      transaction.set(ref, {
        'version': 2,
        'state': nextState.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _applyRemoteOperationForUser(
    String userId,
    PendingRecitationOperation operation,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _doc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? RecitationTrackerState.fromJson(snapshot.data()?['state'])
          : RecitationTrackerState.empty;
      final nextState = applyPendingRecitationOperation(current, operation);
      transaction.set(ref, {
        'version': 2,
        'state': nextState.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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

        if (pendingOperations.isNotEmpty) {
          unawaited(_replayPendingOperations(user.uid, pendingOperations));
        }
      },
      onError: (error) {
        debugPrint('RecitationTrackerManager: Error listening: $error');
      },
    );
  }

  Future<void> _replayPendingOperations(
    String userId,
    List<PendingRecitationOperation> operations,
  ) async {
    if (_isReplayingPendingOperations || operations.isEmpty) return;
    _isReplayingPendingOperations = true;
    try {
      for (final operation in operations) {
        await _applyRemoteOperationForUser(userId, operation);
        await _clearPendingOperation(userId, operation);
      }
    } catch (error) {
      debugPrint(
        'RecitationTrackerManager: Pending operation replay failed: $error',
      );
    } finally {
      _isReplayingPendingOperations = false;
    }
  }

  /// Logs [fromAyah]–[toAyah] of [surah] as recited under [label] (trimmed;
  /// not persisted if empty, or if the range is invalid), defaulting to now.
  ///
  /// Pass [id] to upsert an existing entry rather than create a new one —
  /// the reader uses this to keep extending the same session's entry as
  /// someone keeps scrolling, rather than logging a fresh one every time the
  /// debounce fires.
  Future<void> logRecitation({
    required String label,
    required int surah,
    required int fromAyah,
    required int toAyah,
    DateTime? recitedAt,
    String? id,
  }) {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) return Future.value();
    if (surah < 1 || fromAyah < 1 || toAyah < fromAyah) return Future.value();

    final entry = RecitationEntry(
      id: id ?? _newEntryId(),
      label: trimmedLabel,
      recitedAt: recitedAt ?? DateTime.now(),
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
    );
    return _applyOperation(PendingRecitationOperation.add(entry));
  }

  Future<void> removeEntry(String entryId) {
    if (!_state.entries.containsKey(entryId)) return Future.value();
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
    return _applyOperation(PendingRecitationOperation.addLabel(trimmed));
  }

  String _newEntryId() => 'r_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _applyOperation(PendingRecitationOperation operation) async {
    unawaited(AnalyticsService.feature(
      'recitation_tracker_updated',
      label: 'Recitation tracker updated',
      parameters: {'operation': operation.kind.key},
    ));

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
      await _applyRemoteOperationForUser(user.uid, operation);
      await _clearPendingOperation(user.uid, operation);
      debugPrint('RecitationTrackerManager: Synced to Firestore');
    } catch (error) {
      debugPrint('RecitationTrackerManager: Error syncing: $error');
    }
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
