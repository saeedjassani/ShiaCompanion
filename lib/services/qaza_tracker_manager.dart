import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/qaza_tracker_state.dart';
import '../services/analytics_service.dart';
import '../services/qaza_tracker_sync_policy.dart';
import '../utils/shared_preferences.dart';

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
  static const String _qazaCollection = 'qaza_tracker';
  static const String _qazaDocId = 'state';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Future<void>? _loadQazaFuture;
  Future<void> _storageWriteQueue = Future.value();
  QazaTrackerState _state = QazaTrackerState.empty;
  QazaTrackerState _pendingGuestImportState = QazaTrackerState.empty;
  String? _pendingGuestImportUserId;
  String? _loadedUserId;
  bool _isImportingGuestState = false;
  bool _isReplayingPendingOperations = false;
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

  String _guestImportMergedStorageKey(String userId) =>
      'qaza_tracker_guest_import_merged_$userId';

  Future<void> loadQaza() async {
    if (_loadQazaFuture != null) {
      return _loadQazaFuture!;
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
      debugPrint('QazaTrackerManager: Loaded guest qaza tracker');
      return;
    }

    final cachedState = _loadStateFromStorageKey(_userStorageKey(user.uid));
    if (!cachedState.isEmpty) {
      _updateState(cachedState);
    }

    final remoteRead = await _loadRemoteState(user.uid);
    final shouldImportGuestState = (isGuestToUserTransition ||
            SP.prefs.getBool(_guestImportPendingKey) == true) &&
        !guestState.isEmpty;
    final cachedStateIncludesGuestImport =
        SP.prefs.getBool(_guestImportMergedStorageKey(user.uid)) == true;
    final pendingOperations = _loadPendingOperations(user.uid);

    if (!remoteRead.succeeded) {
      final visibleState = cachedState.isEmpty
          ? (shouldImportGuestState ? guestState : QazaTrackerState.empty)
          : cachedState;
      _updateState(visibleState);
      await _saveUserStateToSharedPreferences(user.uid, visibleState);
      if (shouldImportGuestState && cachedState.isEmpty) {
        await _setGuestImportMergedIntoCache(user.uid, true);
      }
      if (shouldImportGuestState) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
      }
      _loadedUserId = user.uid;
      setupRealtimeListener();
      return;
    }

    if (!remoteRead.exists) {
      final seedState = cachedState.plus(
        shouldImportGuestState && !cachedStateIncludesGuestImport
            ? guestState
            : QazaTrackerState.empty,
      );
      _updateState(seedState);
      await _saveUserStateToSharedPreferences(user.uid, seedState);
      if (shouldImportGuestState) {
        await _setGuestImportMergedIntoCache(user.uid, true);
      }

      try {
        await _saveRemoteStateForUser(user.uid, seedState);
        await _clearPendingOperations(user.uid, pendingOperations);
        if (shouldImportGuestState) {
          await _clearGuestState();
          await _setGuestImportMergedIntoCache(user.uid, false);
        }
      } catch (error) {
        _pendingGuestImportUserId =
            shouldImportGuestState ? user.uid : _pendingGuestImportUserId;
        _pendingGuestImportState =
            shouldImportGuestState ? guestState : _pendingGuestImportState;
        debugPrint('QazaTrackerManager: Error creating qaza state: $error');
      }

      _loadedUserId = user.uid;
      setupRealtimeListener();
      return;
    }

    var visibleState = remoteRead.state;
    if (shouldImportGuestState) {
      visibleState = visibleState.plus(guestState);
    }
    visibleState = applyPendingQazaOperations(
      visibleState,
      pendingOperations,
    );

    _updateState(visibleState);
    await _saveUserStateToSharedPreferences(user.uid, visibleState);
    if (shouldImportGuestState) {
      await _setGuestImportMergedIntoCache(user.uid, true);
    }

    if (shouldImportGuestState) {
      try {
        await _addRemoteStateForUser(user.uid, guestState);
        await _clearGuestState();
        await _setGuestImportMergedIntoCache(user.uid, false);
        _pendingGuestImportUserId = null;
        _pendingGuestImportState = QazaTrackerState.empty;
      } catch (error) {
        _pendingGuestImportUserId = user.uid;
        _pendingGuestImportState = guestState;
        debugPrint('QazaTrackerManager: Error importing guest qaza: $error');
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

  void _updateState(QazaTrackerState nextState) {
    _state = nextState;
    notifyListeners();
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

  Future<void> _saveStateToStorageKey(
    String storageKey,
    QazaTrackerState state,
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
          'QazaTrackerManager: Error saving state to $storageKey: $error',
        );
      }
    });
  }

  Future<void> _saveGuestState(
    QazaTrackerState state, {
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
    QazaTrackerState state,
  ) {
    return _saveStateToStorageKey(_userStorageKey(userId), state);
  }

  Future<void> _clearGuestState() async {
    await _enqueueStorageWrite(() async {
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
    });
  }

  Future<void> _setGuestImportMergedIntoCache(
    String userId,
    bool value,
  ) {
    return _enqueueStorageWrite(() async {
      if (value) {
        await SP.prefs.setBool(_guestImportMergedStorageKey(userId), true);
      } else {
        await SP.prefs.remove(_guestImportMergedStorageKey(userId));
      }
    });
  }

  Future<_RemoteQazaRead> _loadRemoteState(String userId) async {
    try {
      final snapshot = await _qazaDoc(userId).get();
      return _RemoteQazaRead.success(
        exists: snapshot.exists,
        state: _decodeRemoteState(snapshot.data()?['entries']),
      );
    } catch (error) {
      debugPrint('QazaTrackerManager: Error loading remote state: $error');
      return _RemoteQazaRead.failure();
    }
  }

  QazaTrackerState _decodeRemoteState(dynamic entries) {
    return QazaTrackerState.fromJson(entries);
  }

  List<PendingQazaOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];

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
      return const [];
    }
  }

  Future<void> _recordPendingOperation(
    String userId,
    PendingQazaOperation operation,
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
    PendingQazaOperation operation,
  ) {
    return _enqueueStorageWrite(() async {
      final operations = _loadPendingOperations(userId)
          .where((pending) => pending.id != operation.id)
          .toList(growable: false);
      await _writePendingOperations(userId, operations);
    });
  }

  Future<void> _clearPendingOperations(
    String userId,
    Iterable<PendingQazaOperation> operationsToClear,
  ) {
    final idsToClear = operationsToClear.map((operation) => operation.id).toSet();
    if (idsToClear.isEmpty) return Future.value();

    return _enqueueStorageWrite(() async {
      final operations = _loadPendingOperations(userId)
          .where((pending) => !idsToClear.contains(pending.id))
          .toList(growable: false);
      await _writePendingOperations(userId, operations);
    });
  }

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

  Future<void> _saveRemoteStateForUser(
    String userId,
    QazaTrackerState state,
  ) {
    return _qazaDoc(userId).set({
      'version': 1,
      'entries': state.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addRemoteStateForUser(
    String userId,
    QazaTrackerState addition,
  ) async {
    if (addition.isEmpty) return;
    await _firestore.runTransaction((transaction) async {
      final ref = _qazaDoc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? _decodeRemoteState(snapshot.data()?['entries'])
          : QazaTrackerState.empty;
      final nextState = current.plus(addition);
      transaction.set(ref, {
        'version': 1,
        'entries': nextState.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _applyRemoteOperationForUser(
    String userId,
    PendingQazaOperation operation,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _qazaDoc(userId);
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? _decodeRemoteState(snapshot.data()?['entries'])
          : QazaTrackerState.empty;
      final nextState = applyPendingQazaOperation(current, operation);
      transaction.set(ref, {
        'version': 1,
        'entries': nextState.toJson(),
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
    _listener = _qazaDoc(user.uid).snapshots().listen(
      (snapshot) async {
        if (_auth.currentUser?.uid != user.uid ||
            snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        var remoteState = _decodeRemoteState(snapshot.data()?['entries']);
        if (_pendingGuestImportUserId == user.uid &&
            !_pendingGuestImportState.isEmpty &&
            !_isImportingGuestState) {
          _isImportingGuestState = true;
          try {
            await _addRemoteStateForUser(user.uid, _pendingGuestImportState);
            remoteState = remoteState.plus(_pendingGuestImportState);
            await _clearGuestState();
            await _setGuestImportMergedIntoCache(user.uid, false);
            _pendingGuestImportUserId = null;
            _pendingGuestImportState = QazaTrackerState.empty;
          } catch (error) {
            debugPrint(
              'QazaTrackerManager: Deferred guest import failed: $error',
            );
          } finally {
            _isImportingGuestState = false;
          }
        }

        await _storageWriteQueue;
        final pendingOperations = _loadPendingOperations(user.uid);
        final visibleState = applyPendingQazaOperations(
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
        debugPrint('QazaTrackerManager: Error listening to qaza: $error');
      },
    );
  }

  Future<void> _replayPendingOperations(
    String userId,
    List<PendingQazaOperation> operations,
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
        'QazaTrackerManager: Pending operation replay failed: $error',
      );
    } finally {
      _isReplayingPendingOperations = false;
    }
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
    if (_state.countFor(type).remaining <= 0) return Future.value();
    return _applyOperation(
      PendingQazaOperation.markCompleted(
        id: _newOperationId(),
        type: type,
      ),
    );
  }

  Future<void> undoCompleted(QazaEntryType type) {
    if (_state.countFor(type).completed <= 0) return Future.value();
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

  String _newOperationId() {
    final sequence = _operationSequence++;
    return '${DateTime.now().microsecondsSinceEpoch}_$sequence';
  }

  Future<void> _applyOperation(PendingQazaOperation operation) async {
    // Every qaza mutation funnels through here, so one hook covers adding a
    // missed prayer, marking one done, undoing and bulk edits alike.
    unawaited(AnalyticsService.feature(
      'qaza_updated',
      label: 'Qaza tracker updated',
      parameters: {'operation': operation.kind.key},
    ));
    final nextState = applyPendingQazaOperation(_state, operation);
    final appliedDelta = QazaTrackerDelta.between(_state, nextState);
    if (appliedDelta.isZero) return;

    _updateState(nextState);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestState(nextState, markForImport: true);
      debugPrint('QazaTrackerManager: Updated guest qaza tracker');
      return;
    }

    try {
      await Future.wait([
        _saveUserStateToSharedPreferences(user.uid, nextState),
        _recordPendingOperation(user.uid, operation),
      ]);
      await _applyRemoteOperationForUser(user.uid, operation);
      await _clearPendingOperation(user.uid, operation);
      debugPrint('QazaTrackerManager: Updated qaza tracker in Firestore');
    } catch (error) {
      debugPrint('QazaTrackerManager: Error syncing qaza tracker: $error');
    }
  }

  Future<void> deleteAllQazaData(String userId) async {
    try {
      await _qazaDoc(userId).delete();
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
    required this.state,
  }) : succeeded = true;

  _RemoteQazaRead.failure()
      : succeeded = false,
        exists = false,
        state = QazaTrackerState.empty;

  final bool succeeded;
  final bool exists;
  final QazaTrackerState state;
}
