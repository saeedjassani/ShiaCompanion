import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Map<String, String>? _bookTitleLookup;
  Future<void>? _loadFavoritesFuture;
  bool _isLoading = false;
  bool _hasLoadedFavorites = false;

  bool get isLoading => _isLoading;
  bool get hasLoadedFavorites => _hasLoadedFavorites;

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

  Future<void> loadFavorites() async {
    if (_loadFavoritesFuture != null) {
      return _loadFavoritesFuture!;
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
    final guestFavorites = await _loadGuestFavorites();
    final user = _auth.currentUser;

    _listener?.cancel();

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

    final remoteFavorites = await _loadRemoteFavorites(user.uid);
    final legacyRealtimeFavorites =
        await _loadLegacyRealtimeFavorites(user.uid);
    final mergedFavorites = _mergeFavorites([
      ...userCachedFavorites,
      ...remoteFavorites,
      ...legacyRealtimeFavorites,
      ...guestFavorites,
    ]);
    final resolvedFavorites = await _resolveTitles(
      mergedFavorites,
      fallbacks: [
        ...userCachedFavorites,
        ...remoteFavorites,
        ...legacyRealtimeFavorites,
        ...guestFavorites,
      ],
    );

    _updateFavoritesData(resolvedFavorites);
    await _saveUserFavoritesToSharedPreferences(user.uid, resolvedFavorites);

    final remoteAlreadyUpToDate =
        _haveSameFavoriteKeys(remoteFavorites, mergedFavorites);
    if (!remoteAlreadyUpToDate) {
      await _saveRemoteFavoritesForUser(user.uid, resolvedFavorites);
    }

    if (guestFavorites.isNotEmpty || legacyRealtimeFavorites.isNotEmpty) {
      await _clearGuestFavorites();
      await _deleteLegacyRealtimeFavorites(user.uid);
    }

    setupRealtimeListener();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _updateFavoritesData(List<UniversalData> nextFavorites) {
    favsData = nextFavorites;
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

  Future<void> _saveFavoritesToStorageKey(
    String storageKey,
    List<UniversalData> favorites,
  ) async {
    try {
      if (favorites.isEmpty) {
        await SP.prefs.remove(storageKey);
        return;
      }

      await SP.prefs.setString(
        storageKey,
        jsonEncode(_sanitizeFavorites(favorites)),
      );
    } catch (e) {
      debugPrint('FavoritesManager: Error saving favorites to $storageKey: $e');
    }
  }

  Future<void> _saveGuestFavorites(List<UniversalData> favorites) {
    return _saveFavoritesToStorageKey(_guestStorageKey, favorites);
  }

  Future<void> _saveUserFavoritesToSharedPreferences(
    String userId,
    List<UniversalData> favorites,
  ) {
    return _saveFavoritesToStorageKey(_userStorageKey(userId), favorites);
  }

  Future<void> _clearGuestFavorites() async {
    await SP.prefs.remove(_guestStorageKey);
  }

  Future<List<UniversalData>> _loadRemoteFavorites(String userId) async {
    try {
      final snapshot = await _favoritesDoc(userId).get();
      return _decodeRemoteFavorites(snapshot.data()?['entries']);
    } catch (e) {
      debugPrint('FavoritesManager: Error loading remote favorites: $e');
      return const [];
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

  bool _haveSameFavoriteKeys(
    Iterable<UniversalData> first,
    Iterable<UniversalData> second,
  ) {
    final firstKeys =
        _sanitizeFavorites(first).map((entry) => entry.favoriteKey).toSet();
    final secondKeys =
        _sanitizeFavorites(second).map((entry) => entry.favoriteKey).toSet();
    return setEquals(firstKeys, secondKeys);
  }

  Future<List<UniversalData>> _resolveTitles(
    List<UniversalData> favorites, {
    Iterable<UniversalData> fallbacks = const [],
  }) async {
    if (favorites.isEmpty) return const [];

    final fallbackTitles = <String, String>{};
    for (final entry in [
      ...fallbacks,
      ...(favsData ?? const <UniversalData>[]),
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

    _listener?.cancel();
    _listener = _favoritesDoc(user.uid).snapshots().listen(
      (snapshot) async {
        final remoteFavorites =
            _decodeRemoteFavorites(snapshot.data()?['entries']);
        final resolvedFavorites = await _resolveTitles(
          remoteFavorites,
          fallbacks: favsData ?? const <UniversalData>[],
        );

        _updateFavoritesData(resolvedFavorites);
        await _saveUserFavoritesToSharedPreferences(
            user.uid, resolvedFavorites);
        debugPrint(
          'FavoritesManager: Updated favsData with ${resolvedFavorites.length} items from Firestore',
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
      'version': 2,
      'entries': normalizedFavorites
          .map((entry) => {'uid': entry.canonicalUid, 'type': entry.type})
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addFavorite(UniversalData item) async {
    final normalizedItem = (await _resolveTitles(
      [_normalizeFavorite(item)],
      fallbacks: [item],
    ))
        .first;
    final nextFavorites = _sanitizeFavorites([
      ...(favsData ?? const <UniversalData>[]),
      normalizedItem,
    ]);

    _updateFavoritesData(nextFavorites);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestFavorites(nextFavorites);
      debugPrint(
        'FavoritesManager: Added favorite ${normalizedItem.canonicalUid} (guest)',
      );
      return;
    }

    await _saveUserFavoritesToSharedPreferences(user.uid, nextFavorites);
    try {
      await _saveRemoteFavoritesForUser(user.uid, nextFavorites);
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
    final nextFavorites = List<UniversalData>.from(
      favsData ?? const <UniversalData>[],
    )..remove(normalizedItem);

    _updateFavoritesData(nextFavorites);

    final user = _auth.currentUser;
    if (user == null) {
      await _saveGuestFavorites(nextFavorites);
      debugPrint(
        'FavoritesManager: Removed favorite ${normalizedItem.canonicalUid} (guest)',
      );
      return;
    }

    await _saveUserFavoritesToSharedPreferences(user.uid, nextFavorites);
    try {
      await _saveRemoteFavoritesForUser(user.uid, nextFavorites);
      debugPrint(
        'FavoritesManager: Removed favorite ${normalizedItem.canonicalUid} (Firestore)',
      );
    } catch (e) {
      debugPrint('FavoritesManager: Error removing favorite: $e');
      rethrow;
    }
  }

  bool isFavorite(UniversalData item) {
    return (favsData ?? const <UniversalData>[])
        .contains(_normalizeFavorite(item));
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
      await SP.prefs.remove(_userStorageKey(userId));

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
