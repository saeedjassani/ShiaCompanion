import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/favorites_sync_policy.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

class FavoritesManager extends ChangeNotifier {
  static final FavoritesManager _instance = FavoritesManager._internal();

  factory FavoritesManager() {
    return _instance;
  }

  FavoritesManager._internal();

  static FavoritesManager get instance => _instance;

  static const String _guestStorageKey = 'favorites_guest';
  static const String _legacySharedStorageKey = 'favorites';
  static const String _legacyLifecycleStorageKey = 'new_favs';
  static const String _legacyRealtimeFavoritesPath = 'new_favs';
  static const String _favoritesCollection = 'favorites';
  static const String _favoritesDocId = 'index';
  static const String _guestImportPendingKey = 'favorites_guest_import_pending';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Map<String, String>? _bookTitleLookup;
  Future<void>? _loadFavoritesFuture;
  Future<void> _storageWriteQueue = Future.value();
  List<UniversalData> _favorites = const [];
  List<UniversalData> _pendingGuestFavorites = const [];
  String? _pendingGuestImportUserId;
  String? _loadedUserId;
  bool _isImportingGuestFavorites = false;
  bool _isReplayingPendingOperations = false;
  bool _isReplayingPendingOrder = false;
  int _mutationVersion = 0;
  bool _isLoading = false;
  bool _hasLoadedFavorites = false;

  bool get isLoading => _isLoading;
  bool get hasLoadedFavorites => _hasLoadedFavorites;
  List<UniversalData> get favorites => _favorites;

  DocumentReference<Map<String, dynamic>> _favoritesDoc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_favoritesCollection)
        .doc(_favoritesDocId);
  }

  DatabaseReference _legacyRealtimeFavoritesRef(String userId) {
    return _database.ref().child(_legacyRealtimeFavoritesPath).child(userId);
  }

  String _userStorageKey(String userId) => 'favorites_user_$userId';

  String _pendingOperationsStorageKey(String userId) =>
      'favorites_pending_operations_$userId';

  String _pendingOrderStorageKey(String userId) =>
      'favorites_pending_order_$userId';

  /// True when the in-memory favorites already belong to the current user and
  /// nothing has torn down the live listener that keeps them fresh.
  ///
  /// A reload is not free: it re-reads the remote index document and cancels
  /// and re-attaches the snapshot listener, and Firestore bills a read for
  /// each. Screens that merely want to be sure favorites exist before they
  /// draw — the favorites page, the home page — used to pay that on every
  /// visit, even though the listener already had them up to date.
  bool get _isLoadedForCurrentUser {
    if (!_hasLoadedFavorites) return false;

    final userId = _auth.currentUser?.uid;
    if (_loadedUserId != userId) return false;

    // A signed-in load leaves a listener behind. Without one the cached state
    // can drift from the account, so reload rather than trust it.
    return userId == null || _listener != null;
  }

  /// Loads favorites, reusing what is already loaded when it is still valid.
  ///
  /// Pass [force] after an auth change, or anywhere else the remote document
  /// has to be re-read and merged rather than assumed current.
  Future<void> loadFavorites({bool force = false}) async {
    if (_loadFavoritesFuture != null) {
      return _loadFavoritesFuture!;
    }

    if (!force && _isLoadedForCurrentUser) {
      return;
    }

    final completer = Completer<void>();
    _loadFavoritesFuture = completer.future;
    _setLoading(true);

    try {
      await _loadFavoritesInternal();
      _hasLoadedFavorites = true;
      notifyListeners();
      completer.complete();
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
      rethrow;
    } finally {
      _loadFavoritesFuture = null;
      _setLoading(false);
    }
  }

  Future<void> _loadFavoritesInternal() async {
    await _storageWriteQueue;
    final guestFavorites = await _loadGuestFavorites();
    final user = _auth.currentUser;
    final isGuestToUserTransition =
        _hasLoadedFavorites && _loadedUserId == null && user != null;

    await _listener?.cancel();
    _listener = null;

    if (user == null) {
      final resolvedGuestFavorites = await _resolveTitles(
        guestFavorites,
        fallbacks: guestFavorites,
      );
      _updateFavoritesData(resolvedGuestFavorites);
      await _saveGuestFavorites(resolvedGuestFavorites);
      debugPrint(
        'FavoritesManager: Loaded ${resolvedGuestFavorites.length} guest favorites',
      );
      _loadedUserId = null;
      return;
    }

    final userCachedFavorites = _loadFavoritesFromStorageKey(
      _userStorageKey(user.uid),
    );
    if (userCachedFavorites.isNotEmpty) {
      final resolvedCachedFavorites = await _resolveTitles(
        userCachedFavorites,
        fallbacks: [
          ...userCachedFavorites,
          ...guestFavorites,
        ],
      );
      _updateFavoritesData(resolvedCachedFavorites);
    }

    final remoteRead = await _loadRemoteFavorites(user.uid);
    final legacyRealtimeFavorites = remoteRead.succeeded && remoteRead.exists
        ? const <UniversalData>[]
        : await _loadLegacyRealtimeFavorites(user.uid);
    final shouldImportGuestFavorites = isGuestToUserTransition ||
        SP.prefs.getBool(_guestImportPendingKey) == true;
    final decision = resolveSignedInFavorites(
      remoteReadSucceeded: remoteRead.succeeded,
      remoteExists: remoteRead.exists,
      remoteFavorites: remoteRead.favorites,
      cachedFavorites: userCachedFavorites,
      guestFavorites: guestFavorites,
      legacyFavorites: legacyRealtimeFavorites,
      shouldImportGuestFavorites: shouldImportGuestFavorites,
    );
    late List<PendingFavoriteOperation> pendingOperations;
    late List<UniversalData> resolvedFavorites;
    while (true) {
      await _storageWriteQueue;
      final versionBeforeResolution = _mutationVersion;
      pendingOperations = _loadPendingOperations(user.uid);
      final favoritesWithPendingOperations = applyPendingFavoriteOperations(
        decision.visibleFavorites,
        pendingOperations,
      );
      resolvedFavorites = await _resolveTitles(
        _applyPendingOrder(user.uid, favoritesWithPendingOperations),
        fallbacks: [
          ...userCachedFavorites,
          ...remoteRead.favorites,
          ...legacyRealtimeFavorites,
          ...guestFavorites,
        ],
      );
      if (versionBeforeResolution == _mutationVersion) break;
    }

    _updateFavoritesData(resolvedFavorites);
    await _saveUserFavoritesToSharedPreferences(user.uid, resolvedFavorites);

    var remoteMigrationSucceeded = remoteRead.succeeded;
    if (decision.remoteSeed != null) {
      try {
        await _saveRemoteFavoritesForUser(user.uid, _favorites);
        for (final operation in pendingOperations) {
          await _clearPendingOperation(
            user.uid,
            operation.favorite,
            shouldExist: operation.shouldExist,
          );
        }
      } catch (error) {
        remoteMigrationSucceeded = false;
        debugPrint('FavoritesManager: Error creating favorites index: $error');
      }
    } else if (decision.guestFavoritesToImport.isNotEmpty) {
      try {
        await _addRemoteFavoritesForUser(
          user.uid,
          decision.guestFavoritesToImport,
        );
      } catch (error) {
        remoteMigrationSucceeded = false;
        _pendingGuestImportUserId = user.uid;
        _pendingGuestFavorites = decision.guestFavoritesToImport;
        debugPrint('FavoritesManager: Error importing guest favorites: $error');
      }
    } else if (!remoteRead.succeeded && shouldImportGuestFavorites) {
      _pendingGuestImportUserId = user.uid;
      _pendingGuestFavorites = guestFavorites;
    }

    if (remoteRead.succeeded && decision.remoteSeed == null) {
      if (pendingOperations.isNotEmpty) {
        await _replayPendingOperations(user.uid, pendingOperations);
      }
      await _replayPendingOrder(user.uid);
    } else if (decision.remoteSeed != null && remoteMigrationSucceeded) {
      // The seed write already published the current order.
      await _clearPendingOrder(user.uid, _mutationVersion);
    }

    if (decision.canCleanUpLegacyData && remoteMigrationSucceeded) {
      await _clearGuestFavorites();
      await _deleteLegacyRealtimeFavorites(user.uid);
      _pendingGuestImportUserId = null;
      _pendingGuestFavorites = const [];
    }

    _loadedUserId = user.uid;
    setupRealtimeListener();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _updateFavoritesData(
    List<UniversalData> nextFavorites, {
    bool isUserMutation = false,
  }) {
    if (isUserMutation) _mutationVersion++;
    _favorites = List.unmodifiable(_sanitizeFavorites(nextFavorites));
    HomeScreenWidgetService.instance.updateFavorites(_favorites);
    HomeScreenWidgetService.instance.publishFavoritesSoon();
    notifyListeners();
  }

  Future<List<UniversalData>> _loadGuestFavorites() async {
    final guestFavorites = _loadFavoritesFromStorageKey(_guestStorageKey);
    final legacySharedFavorites = _loadFavoritesFromStorageKey(
      _legacySharedStorageKey,
    );
    final legacyLifecycleFavorites = _loadFavoritesFromStorageKey(
      _legacyLifecycleStorageKey,
    );
    final mergedFavorites = _mergeFavorites([
      ...guestFavorites,
      ...legacySharedFavorites,
      ...legacyLifecycleFavorites,
    ]);

    if (SP.prefs.containsKey(_legacySharedStorageKey) ||
        SP.prefs.containsKey(_legacyLifecycleStorageKey)) {
      await _saveGuestFavorites(mergedFavorites);
      await SP.prefs.remove(_legacySharedStorageKey);
      await SP.prefs.remove(_legacyLifecycleStorageKey);
    }

    return mergedFavorites;
  }

  List<UniversalData> _loadFavoritesFromStorageKey(String storageKey) {
    final encoded = SP.prefs.getString(storageKey);
    return _decodeFavorites(encoded);
  }

  List<UniversalData> _decodeFavorites(String? encoded) {
    if (encoded == null || encoded.isEmpty || encoded == 'null') {
      return const [];
    }

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];
      return _sanitizeFavorites(parsed.map((value) {
        if (value is! Map) return null;
        final uid = value['uid']?.toString() ?? '';
        if (uid.trim().isEmpty) return null;
        final title = value['title']?.toString() ?? '';
        final type = value['type'] is int
            ? value['type'] as int
            : int.tryParse(value['type']?.toString() ?? '') ?? 0;
        if (!_isSupportedFavoriteType(type)) return null;
        return UniversalData(uid, title, type);
      }));
    } catch (e) {
      debugPrint('FavoritesManager: Error decoding favorites: $e');
      return const [];
    }
  }

  List<PendingFavoriteOperation> _loadPendingOperations(String userId) {
    final encoded = SP.prefs.getString(_pendingOperationsStorageKey(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];
      final operations = <String, PendingFavoriteOperation>{};
      for (final value in parsed) {
        if (value is! Map) continue;
        final uid = value['uid']?.toString().trim() ?? '';
        final type = value['type'] is int
            ? value['type'] as int
            : int.tryParse(value['type']?.toString() ?? '') ?? -1;
        final shouldExist = value['shouldExist'];
        if (uid.isEmpty ||
            !_isSupportedFavoriteType(type) ||
            shouldExist is! bool) {
          continue;
        }
        final favorite = _normalizeFavorite(UniversalData(
          uid,
          value['title']?.toString() ?? '',
          type,
        ));
        operations.remove(favorite.favoriteKey);
        operations[favorite.favoriteKey] = PendingFavoriteOperation(
          favorite: favorite,
          shouldExist: shouldExist,
        );
      }
      return operations.values.toList(growable: false);
    } catch (error) {
      debugPrint('FavoritesManager: Error decoding pending operations: $error');
      return const [];
    }
  }

  Future<void> _recordPendingOperation(
    String userId,
    UniversalData favorite, {
    required bool shouldExist,
  }) {
    return _enqueueStorageWrite(() async {
      final operations = {
        for (final operation in _loadPendingOperations(userId))
          operation.favorite.favoriteKey: operation,
      };
      operations.remove(favorite.favoriteKey);
      operations[favorite.favoriteKey] = PendingFavoriteOperation(
        favorite: favorite,
        shouldExist: shouldExist,
      );
      await _writePendingOperations(userId, operations.values);
    });
  }

  Future<void> _clearPendingOperation(
    String userId,
    UniversalData favorite, {
    required bool shouldExist,
  }) {
    return _enqueueStorageWrite(() async {
      final operations = {
        for (final operation in _loadPendingOperations(userId))
          operation.favorite.favoriteKey: operation,
      };
      final current = operations[favorite.favoriteKey];
      if (current?.shouldExist != shouldExist) return;
      operations.remove(favorite.favoriteKey);
      await _writePendingOperations(userId, operations.values);
    });
  }

  /// Firestore stores the entries in order, but a reorder that has not reached
  /// the server yet has to be reapplied to whatever the server hands back.
  List<UniversalData> _applyPendingOrder(
    String userId,
    List<UniversalData> favorites,
  ) {
    final pendingOrder = _loadPendingOrder(userId);
    if (pendingOrder == null) return favorites;
    return applyFavoriteOrder(favorites, pendingOrder.orderedKeys);
  }

  PendingFavoriteOrder? _loadPendingOrder(String userId) {
    final encoded = SP.prefs.getString(_pendingOrderStorageKey(userId));
    final order = decodePendingFavoriteOrder(encoded);
    if (order == null && encoded != null && encoded.isNotEmpty) {
      debugPrint('FavoritesManager: Discarded an unreadable pending order');
    }
    return order;
  }

  Future<void> _recordPendingOrder(
    String userId,
    PendingFavoriteOrder order,
  ) {
    return _enqueueStorageWrite(() async {
      await SP.prefs.setString(
        _pendingOrderStorageKey(userId),
        encodePendingFavoriteOrder(order),
      );
    });
  }

  /// Drops the marker only when no newer reorder has replaced it, so a reorder
  /// still waiting on the network survives an older write finishing late.
  Future<void> _clearPendingOrder(String userId, int version) {
    return _enqueueStorageWrite(() async {
      if (!shouldClearPendingFavoriteOrder(_loadPendingOrder(userId), version)) {
        return;
      }
      await SP.prefs.remove(_pendingOrderStorageKey(userId));
    });
  }

  Future<void> _replayPendingOrder(String userId) async {
    if (_isReplayingPendingOrder) return;
    await _storageWriteQueue;
    final pendingOrder = _loadPendingOrder(userId);
    if (pendingOrder == null) return;

    _isReplayingPendingOrder = true;
    try {
      await _saveRemoteFavoritesForUser(userId, _favorites);
      await _clearPendingOrder(userId, pendingOrder.version);
    } catch (error) {
      debugPrint('FavoritesManager: Pending order replay failed: $error');
    } finally {
      _isReplayingPendingOrder = false;
    }
  }

  Future<void> _writePendingOperations(
    String userId,
    Iterable<PendingFavoriteOperation> operations,
  ) async {
    final values = operations
        .map((operation) => {
              ..._remoteEntry(operation.favorite),
              'title': operation.favorite.title,
              'shouldExist': operation.shouldExist,
            })
        .toList(growable: false);
    if (values.isEmpty) {
      await SP.prefs.remove(_pendingOperationsStorageKey(userId));
      return;
    }
    await SP.prefs.setString(
      _pendingOperationsStorageKey(userId),
      jsonEncode(values),
    );
  }

  Future<void> _saveFavoritesToStorageKey(
    String storageKey,
    List<UniversalData> favorites,
  ) {
    final encodedFavorites = _sanitizeFavorites(favorites);
    return _enqueueStorageWrite(() async {
      try {
        if (encodedFavorites.isEmpty) {
          await SP.prefs.remove(storageKey);
          return;
        }

        await SP.prefs.setString(
          storageKey,
          jsonEncode(encodedFavorites),
        );
      } catch (e) {
        debugPrint(
            'FavoritesManager: Error saving favorites to $storageKey: $e');
      }
    });
  }

  Future<void> _enqueueStorageWrite(Future<void> Function() write) {
    final operation = _storageWriteQueue.then((_) => write());
    _storageWriteQueue = operation.catchError((Object error) {
      debugPrint('FavoritesManager: Storage write failed: $error');
    });
    return operation;
  }

  Future<void> _saveGuestFavorites(
    List<UniversalData> favorites, {
    bool markForImport = false,
  }) async {
    await _saveFavoritesToStorageKey(_guestStorageKey, favorites);
    if (markForImport) {
      await _enqueueStorageWrite(
        () => SP.prefs.setBool(_guestImportPendingKey, true),
      );
    }
  }

  Future<void> _saveUserFavoritesToSharedPreferences(
    String userId,
    List<UniversalData> favorites,
  ) {
    return _saveFavoritesToStorageKey(_userStorageKey(userId), favorites);
  }

  Future<void> _clearGuestFavorites() async {
    await _enqueueStorageWrite(() async {
      await SP.prefs.remove(_guestStorageKey);
      await SP.prefs.remove(_guestImportPendingKey);
    });
  }

  Future<_RemoteFavoritesRead> _loadRemoteFavorites(String userId) async {
    try {
      final snapshot = await _favoritesDoc(userId).get();
      return _RemoteFavoritesRead.success(
        exists: snapshot.exists,
        favorites: _decodeRemoteFavorites(snapshot.data()?['entries']),
      );
    } catch (e) {
      debugPrint('FavoritesManager: Error loading remote favorites: $e');
      return const _RemoteFavoritesRead.failure();
    }
  }

  List<UniversalData> _decodeRemoteFavorites(dynamic entries) {
    if (entries is! List) return const [];

    return _sanitizeFavorites(entries.map((value) {
      if (value is! Map) return null;
      final uid = value['uid']?.toString() ?? '';
      if (uid.trim().isEmpty) return null;
      final type = value['type'] is int
          ? value['type'] as int
          : int.tryParse(value['type']?.toString() ?? '') ?? 0;
      return UniversalData(uid, '', type);
    }));
  }

  Future<List<UniversalData>> _loadLegacyRealtimeFavorites(
    String userId,
  ) async {
    try {
      final snapshot = await _legacyRealtimeFavoritesRef(userId).get();
      final rawValue = snapshot.value;
      if (rawValue is! String) return const [];
      return _decodeFavorites(rawValue);
    } catch (e) {
      debugPrint(
        'FavoritesManager: Error loading legacy RTDB favorites: $e',
      );
      return const [];
    }
  }

  Future<void> _deleteLegacyRealtimeFavorites(String userId) async {
    try {
      final snapshot = await _legacyRealtimeFavoritesRef(userId).get();
      if (!snapshot.exists) return;
      await _legacyRealtimeFavoritesRef(userId).remove();
    } catch (e) {
      debugPrint(
        'FavoritesManager: Error deleting legacy RTDB favorites: $e',
      );
    }
  }

  bool _isSupportedFavoriteType(int type) {
    return type == 0 || type == 1;
  }

  List<UniversalData> _sanitizeFavorites(Iterable<dynamic> source) {
    final favorites = <UniversalData>[];
    final seenKeys = <String>{};

    for (final entry in source) {
      if (entry is! UniversalData) continue;
      final normalized = _normalizeFavorite(entry);
      if (!_isSupportedFavoriteType(normalized.type) ||
          normalized.canonicalUid.isEmpty ||
          !seenKeys.add(normalized.favoriteKey)) {
        continue;
      }
      favorites.add(normalized);
    }

    return favorites;
  }

  UniversalData _normalizeFavorite(UniversalData item) {
    final canonicalUid = item.canonicalUid;
    final trimmedTitle = item.title.trim();
    final resolvedTitle = item.type == 0
        ? items[canonicalUid]?.toString().trim() ?? trimmedTitle
        : trimmedTitle;
    return UniversalData(canonicalUid, resolvedTitle, item.type);
  }

  List<UniversalData> _mergeFavorites(Iterable<UniversalData> source) {
    return _sanitizeFavorites(source);
  }

  Future<List<UniversalData>> _resolveTitles(
    List<UniversalData> favorites, {
    Iterable<UniversalData> fallbacks = const [],
  }) async {
    if (favorites.isEmpty) return const [];

    final fallbackTitles = <String, String>{};
    for (final entry in [
      ...fallbacks,
      ..._favorites,
    ]) {
      final normalized = _normalizeFavorite(entry);
      final title = normalized.title.trim();
      if (title.isEmpty) continue;
      fallbackTitles[normalized.favoriteKey] = title;
    }

    final needsBookTitles = favorites.any((entry) => entry.type == 1);
    final bookTitles = needsBookTitles
        ? await _loadBookTitleLookup()
        : const <String, String>{};

    return favorites.map((entry) {
      final normalized = _normalizeFavorite(entry);
      final fallbackTitle =
          fallbackTitles[normalized.favoriteKey] ?? normalized.title.trim();
      final resolvedTitle = switch (normalized.type) {
        0 => items[normalized.canonicalUid]?.toString().trim(),
        1 => bookTitles[normalized.canonicalUid]?.trim(),
        _ => null,
      };

      return UniversalData(
        normalized.canonicalUid,
        (resolvedTitle?.isNotEmpty ?? false)
            ? resolvedTitle!
            : (fallbackTitle.isNotEmpty
                ? fallbackTitle
                : normalized.canonicalUid),
        normalized.type,
      );
    }).toList();
  }

  Future<Map<String, String>> _loadBookTitleLookup() async {
    if (_bookTitleLookup != null) return _bookTitleLookup!;

    try {
      final encodedBooks = await rootBundle.loadString('assets/books.json');
      final parsed = jsonDecode(encodedBooks);
      if (parsed is! List) return const {};

      _bookTitleLookup = {
        for (final entry in parsed)
          if (entry is Map &&
              entry['slug']?.toString().trim().isNotEmpty == true &&
              entry['title']?.toString().trim().isNotEmpty == true)
            entry['slug'].toString(): entry['title'].toString(),
      };
    } catch (e) {
      debugPrint('FavoritesManager: Error loading book titles: $e');
      _bookTitleLookup = {};
    }

    return _bookTitleLookup!;
  }

  void setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'FavoritesManager: No user logged in, skipping Firestore listener setup',
      );
      return;
    }

    unawaited(_listener?.cancel());
    _listener = _favoritesDoc(user.uid).snapshots().listen(
      (snapshot) async {
        if (_auth.currentUser?.uid != user.uid ||
            snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        var remoteFavorites =
            _decodeRemoteFavorites(snapshot.data()?['entries']);
        if (_pendingGuestImportUserId == user.uid &&
            _pendingGuestFavorites.isNotEmpty &&
            !_isImportingGuestFavorites) {
          _isImportingGuestFavorites = true;
          try {
            await _addRemoteFavoritesForUser(
              user.uid,
              _pendingGuestFavorites,
            );
            remoteFavorites = _mergeFavorites([
              ...remoteFavorites,
              ..._pendingGuestFavorites,
            ]);
            await _clearGuestFavorites();
            _pendingGuestImportUserId = null;
            _pendingGuestFavorites = const [];
          } catch (error) {
            debugPrint(
                'FavoritesManager: Deferred guest import failed: $error');
          } finally {
            _isImportingGuestFavorites = false;
          }
        }

        await _storageWriteQueue;
        final pendingOperations = _loadPendingOperations(user.uid);
        remoteFavorites = applyPendingFavoriteOperations(
          remoteFavorites,
          pendingOperations,
        );
        remoteFavorites = _applyPendingOrder(user.uid, remoteFavorites);
        final versionBeforeResolution = _mutationVersion;

        final resolvedFavorites = await _resolveTitles(
          remoteFavorites,
          fallbacks: _favorites,
        );
        if (versionBeforeResolution != _mutationVersion) return;

        _updateFavoritesData(resolvedFavorites);
        await _saveUserFavoritesToSharedPreferences(
            user.uid, resolvedFavorites);
        if (pendingOperations.isNotEmpty) {
          unawaited(_replayPendingOperations(user.uid, pendingOperations));
        }
        unawaited(_replayPendingOrder(user.uid));
        debugPrint(
          'FavoritesManager: Loaded ${resolvedFavorites.length} favorites from Firestore',
        );
      },
      onError: (error) {
        debugPrint('FavoritesManager: Error listening to favorites: $error');
      },
    );
  }

  Future<void> _saveRemoteFavoritesForUser(
    String userId,
    List<UniversalData> favorites,
  ) async {
    final normalizedFavorites = _sanitizeFavorites(favorites);
    await _favoritesDoc(userId).set({
      'version': 3,
      'entries': normalizedFavorites.map(_remoteEntry).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addRemoteFavoritesForUser(
    String userId,
    Iterable<UniversalData> favorites,
  ) async {
    final entries = _sanitizeFavorites(favorites).map(_remoteEntry).toList();
    if (entries.isEmpty) return;
    await _favoritesDoc(userId).set({
      'version': 3,
      'entries': FieldValue.arrayUnion(entries),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeRemoteFavoriteForUser(
    String userId,
    UniversalData favorite,
  ) {
    return _favoritesDoc(userId).set({
      'version': 3,
      'entries': FieldValue.arrayRemove([_remoteEntry(favorite)]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _replayPendingOperations(
    String userId,
    Iterable<PendingFavoriteOperation> operations,
  ) async {
    if (_isReplayingPendingOperations) return;
    _isReplayingPendingOperations = true;
    try {
      for (final operation in operations) {
        if (operation.shouldExist) {
          await _addRemoteFavoritesForUser(userId, [operation.favorite]);
        } else {
          await _removeRemoteFavoriteForUser(userId, operation.favorite);
        }
        await _clearPendingOperation(
          userId,
          operation.favorite,
          shouldExist: operation.shouldExist,
        );
      }
    } catch (error) {
      debugPrint('FavoritesManager: Pending favorite replay failed: $error');
    } finally {
      _isReplayingPendingOperations = false;
    }
  }

  Map<String, Object> _remoteEntry(UniversalData favorite) => {
        'uid': favorite.canonicalUid,
        'type': favorite.type,
      };

  Future<void> addFavorite(UniversalData item) async {
    final normalizedItem = _normalizeFavorite(item);
    final immediateItem = normalizedItem.title.trim().isNotEmpty
        ? normalizedItem
        : UniversalData(
            normalizedItem.canonicalUid,
            item.title.trim().isNotEmpty
                ? item.title.trim()
                : normalizedItem.canonicalUid,
            normalizedItem.type,
          );
    if (isFavorite(immediateItem)) return;

    unawaited(AnalyticsService.feature(
      'favorite_added',
      label: 'Favorite added',
      parameters: {'content_type': normalizedItem.type},
    ));

    final nextFavorites = _sanitizeFavorites([
      ..._favorites,
      immediateItem,
    ]);

    _updateFavoritesData(nextFavorites, isUserMutation: true);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestFavorites(nextFavorites, markForImport: true);
      debugPrint(
        'FavoritesManager: Added favorite ${normalizedItem.canonicalUid} (guest)',
      );
      return;
    }

    try {
      await Future.wait([
        _saveUserFavoritesToSharedPreferences(user.uid, nextFavorites),
        _recordPendingOperation(
          user.uid,
          normalizedItem,
          shouldExist: true,
        ),
      ]);
      await _addRemoteFavoritesForUser(user.uid, [normalizedItem]);
      await _clearPendingOperation(
        user.uid,
        normalizedItem,
        shouldExist: true,
      );
      debugPrint(
        'FavoritesManager: Added favorite ${normalizedItem.canonicalUid} (Firestore)',
      );
    } catch (e) {
      debugPrint('FavoritesManager: Error adding favorite: $e');
      rethrow;
    }
  }

  Future<void> removeFavorite(UniversalData item) async {
    final normalizedItem = _normalizeFavorite(item);
    if (!isFavorite(normalizedItem)) return;

    unawaited(AnalyticsService.feature(
      'favorite_removed',
      label: 'Favorite removed',
      parameters: {'content_type': normalizedItem.type},
    ));

    final nextFavorites = List<UniversalData>.from(_favorites)
      ..remove(normalizedItem);

    _updateFavoritesData(nextFavorites, isUserMutation: true);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestFavorites(nextFavorites, markForImport: true);
      debugPrint(
        'FavoritesManager: Removed favorite ${normalizedItem.canonicalUid} (guest)',
      );
      return;
    }

    try {
      await Future.wait([
        _saveUserFavoritesToSharedPreferences(user.uid, nextFavorites),
        _recordPendingOperation(
          user.uid,
          normalizedItem,
          shouldExist: false,
        ),
      ]);
      await _removeRemoteFavoriteForUser(user.uid, normalizedItem);
      await _clearPendingOperation(
        user.uid,
        normalizedItem,
        shouldExist: false,
      );
      debugPrint(
        'FavoritesManager: Removed favorite ${normalizedItem.canonicalUid} (Firestore)',
      );
    } catch (e) {
      debugPrint('FavoritesManager: Error removing favorite: $e');
      rethrow;
    }
  }

  /// Moves the favorite at [fromIndex] so that it ends up at [toIndex] in the
  /// resulting list, matching the indices `ReorderableListView.onReorderItem`
  /// reports.
  Future<void> moveFavorite(int fromIndex, int toIndex) async {
    final reordered = List<UniversalData>.from(_favorites);
    if (fromIndex < 0 || fromIndex >= reordered.length) return;
    final destination = toIndex.clamp(0, reordered.length - 1);
    if (destination == fromIndex) return;

    unawaited(AnalyticsService.feature(
      'favorite_reordered',
      label: 'Favorites reordered',
    ));

    reordered.insert(destination, reordered.removeAt(fromIndex));
    _updateFavoritesData(reordered, isUserMutation: true);

    final nextFavorites = _favorites;
    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestFavorites(nextFavorites, markForImport: true);
      debugPrint('FavoritesManager: Reordered favorites (guest)');
      return;
    }

    final pendingOrder = PendingFavoriteOrder(
      version: _mutationVersion,
      orderedKeys: [
        for (final favorite in nextFavorites) favorite.favoriteKey,
      ],
    );

    try {
      await Future.wait([
        _saveUserFavoritesToSharedPreferences(user.uid, nextFavorites),
        _recordPendingOrder(user.uid, pendingOrder),
      ]);
      await _saveRemoteFavoritesForUser(user.uid, nextFavorites);
      await _clearPendingOrder(user.uid, pendingOrder.version);
      debugPrint('FavoritesManager: Reordered favorites (Firestore)');
    } catch (e) {
      debugPrint('FavoritesManager: Error reordering favorites: $e');
      rethrow;
    }
  }

  bool isFavorite(UniversalData item) {
    return _favorites.contains(_normalizeFavorite(item));
  }

  Future<void> toggleFavorite(UniversalData item) async {
    if (isFavorite(item)) {
      await removeFavorite(item);
    } else {
      await addFavorite(item);
    }
  }

  Future<void> deleteAllFavorites(String userId) async {
    try {
      await _favoritesDoc(userId).delete();
      await _deleteLegacyRealtimeFavorites(userId);
      await _enqueueStorageWrite(() async {
        await SP.prefs.remove(_userStorageKey(userId));
        await SP.prefs.remove(_pendingOperationsStorageKey(userId));
        await SP.prefs.remove(_pendingOrderStorageKey(userId));
      });

      if (_auth.currentUser?.uid == userId) {
        _updateFavoritesData([]);
      }

      debugPrint('FavoritesManager: Deleted all favorites for user $userId');
    } catch (e) {
      debugPrint('FavoritesManager: Error deleting all favorites: $e');
      rethrow;
    }
  }

  void dispose() {
    _listener?.cancel();
    debugPrint('FavoritesManager: Disposed listener');
    super.dispose();
  }
}

class _RemoteFavoritesRead {
  const _RemoteFavoritesRead.success({
    required this.exists,
    required this.favorites,
  }) : succeeded = true;

  const _RemoteFavoritesRead.failure()
      : succeeded = false,
        exists = false,
        favorites = const [];

  final bool succeeded;
  final bool exists;
  final List<UniversalData> favorites;
}
