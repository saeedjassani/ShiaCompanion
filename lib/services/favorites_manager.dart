import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();

  factory FavoritesManager() {
    return _instance;
  }

  FavoritesManager._internal();

  static FavoritesManager get instance => _instance;

  static const String _localStorageKey = 'favorites';
  static const String _legacyLocalStorageKey = 'new_favs';
  static const String _preferencesCollection = 'preferences';
  static const String _favoritesDocId = 'favorites';
  static const String _legacyFavoritesCollection = 'favorites';
  static const String _holyShrinesUrl =
      'https://alghazienterprises.com/sc/scripts/getHolyShrines.php';
  static const String _islamicChannelsUrl =
      'https://alghazienterprises.com/sc/scripts/getIslamicChannels.php';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  Map<String, String>? _libraryTitleLookup;
  Map<String, String>? _liveStreamTitleLookup;

  DocumentReference<Map<String, dynamic>> _favoritesDoc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_preferencesCollection)
        .doc(_favoritesDocId);
  }

  CollectionReference<Map<String, dynamic>> _legacyFavoritesRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_legacyFavoritesCollection);
  }

  Future<void> loadFavorites() async {
    final localFavorites = await _loadLocalFavorites();
    final user = _auth.currentUser;

    _listener?.cancel();

    if (user == null) {
      final resolvedLocal = await _resolveTitles(
        localFavorites,
        fallbacks: localFavorites,
      );
      favsData = resolvedLocal;
      await _saveFavoritesToSharedPreferences(resolvedLocal);
      debugPrint(
        'FavoritesManager: Loaded ${resolvedLocal.length} favorites from SharedPreferences',
      );
      return;
    }

    final remoteFavorites = await _loadRemoteFavorites(user.uid);
    final mergedFavorites = _mergeFavorites(remoteFavorites, localFavorites);
    final resolvedFavorites = await _resolveTitles(
      mergedFavorites,
      fallbacks: [...remoteFavorites, ...localFavorites],
    );

    favsData = resolvedFavorites;
    await _saveFavoritesToSharedPreferences(resolvedFavorites);

    if (!_haveSameFavoriteKeys(remoteFavorites, mergedFavorites)) {
      await _saveRemoteFavoritesForUser(user.uid, resolvedFavorites);
    }

    setupRealtimeListener();
  }

  Future<List<UniversalData>> _loadLocalFavorites() async {
    final currentEncoded = SP.prefs.getString(_localStorageKey);
    final legacyEncoded = SP.prefs.getString(_legacyLocalStorageKey);
    final currentFavorites = _decodeLocalFavorites(currentEncoded);
    final legacyFavorites = _decodeLocalFavorites(legacyEncoded);
    final mergedFavorites = _mergeFavorites(currentFavorites, legacyFavorites);

    if (legacyEncoded != null) {
      await _saveFavoritesToSharedPreferences(mergedFavorites);
      await SP.prefs.remove(_legacyLocalStorageKey);
    }

    return mergedFavorites;
  }

  List<UniversalData> _decodeLocalFavorites(String? encoded) {
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
        return UniversalData(uid, title, type);
      }));
    } catch (e) {
      debugPrint('FavoritesManager: Error decoding local favorites: $e');
      return const [];
    }
  }

  Future<void> _saveFavoritesToSharedPreferences(
    List<UniversalData> favorites,
  ) async {
    try {
      await SP.prefs.setString(
        _localStorageKey,
        jsonEncode(_sanitizeFavorites(favorites)),
      );
    } catch (e) {
      debugPrint('FavoritesManager: Error saving to SharedPreferences: $e');
    }
  }

  Future<List<UniversalData>> _loadRemoteFavorites(String userId) async {
    try {
      final snapshot = await _favoritesDoc(userId).get();
      final remoteFavorites =
          _decodeRemoteFavorites(snapshot.data()?['entries']);
      final legacyFavorites = await _loadLegacyFirestoreFavorites(userId);
      return _mergeFavorites(remoteFavorites, legacyFavorites);
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

  Future<List<UniversalData>> _loadLegacyFirestoreFavorites(
      String userId) async {
    try {
      final snapshot = await _legacyFavoritesRef(userId).get();
      return _sanitizeFavorites(snapshot.docs.map((doc) {
        final data = doc.data();
        return UniversalData(
          doc.id,
          data['title']?.toString() ?? '',
          data['type'] as int? ?? 0,
        );
      }));
    } catch (e) {
      debugPrint(
          'FavoritesManager: Error loading legacy Firestore favorites: $e');
      return const [];
    }
  }

  List<UniversalData> _sanitizeFavorites(Iterable<dynamic> source) {
    final favorites = <UniversalData>[];
    final seenKeys = <String>{};

    for (final entry in source) {
      if (entry is! UniversalData) continue;
      final normalized = _normalizeFavorite(entry);
      if (normalized.canonicalUid.isEmpty ||
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

  List<UniversalData> _mergeFavorites(
    Iterable<UniversalData> primary,
    Iterable<UniversalData> secondary,
  ) {
    return _sanitizeFavorites([...primary, ...secondary]);
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
      ...(favsData ?? const <UniversalData>[])
    ]) {
      final normalized = _normalizeFavorite(entry);
      final title = normalized.title.trim();
      if (title.isEmpty) continue;
      fallbackTitles[normalized.favoriteKey] = title;
    }

    final needsLibraryTitles = favorites.any((entry) => entry.type == 1);
    final needsLiveStreamTitles = favorites.any((entry) => entry.type == 2);
    final libraryTitles = needsLibraryTitles
        ? await _loadLibraryTitleLookup()
        : const <String, String>{};
    final liveStreamTitles = needsLiveStreamTitles
        ? await _loadLiveStreamTitleLookup()
        : const <String, String>{};

    return favorites.map((entry) {
      final normalized = _normalizeFavorite(entry);
      final fallbackTitle =
          fallbackTitles[normalized.favoriteKey] ?? normalized.title.trim();
      final resolvedTitle = switch (normalized.type) {
        0 => items[normalized.canonicalUid]?.toString().trim(),
        1 => libraryTitles[normalized.canonicalUid]?.trim(),
        2 => liveStreamTitles[normalized.canonicalUid]?.trim(),
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

  Future<Map<String, String>> _loadLibraryTitleLookup() async {
    if (_libraryTitleLookup != null) return _libraryTitleLookup!;

    try {
      final encodedBooks = await rootBundle.loadString('assets/books.json');
      final parsed = jsonDecode(encodedBooks);
      if (parsed is! List) return const {};

      _libraryTitleLookup = {
        for (final entry in parsed)
          if (entry is Map &&
              entry['slug']?.toString().trim().isNotEmpty == true &&
              entry['title']?.toString().trim().isNotEmpty == true)
            entry['slug'].toString(): entry['title'].toString(),
      };
    } catch (e) {
      debugPrint('FavoritesManager: Error loading library titles: $e');
      _libraryTitleLookup = {};
    }

    return _libraryTitleLookup!;
  }

  Future<Map<String, String>> _loadLiveStreamTitleLookup() async {
    if (_liveStreamTitleLookup != null) return _liveStreamTitleLookup!;

    final lookup = <String, String>{};
    try {
      for (final url in const [_holyShrinesUrl, _islamicChannelsUrl]) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;

        final parsed = jsonDecode(response.body);
        if (parsed is! List) continue;

        for (final entry in parsed) {
          if (entry is! Map) continue;
          final link = entry['link']?.toString().trim() ?? '';
          final title = entry['title']?.toString().trim() ?? '';
          if (link.isEmpty || title.isEmpty) continue;
          lookup[link] = title;
        }
      }
    } catch (e) {
      debugPrint('FavoritesManager: Error loading live stream titles: $e');
    }

    _liveStreamTitleLookup = lookup;
    return _liveStreamTitleLookup!;
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

        favsData = resolvedFavorites;
        await _saveFavoritesToSharedPreferences(resolvedFavorites);
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

    favsData = nextFavorites;
    await _saveFavoritesToSharedPreferences(nextFavorites);

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          'FavoritesManager: Added favorite ${normalizedItem.canonicalUid} (local)');
      return;
    }

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

    favsData = nextFavorites;
    await _saveFavoritesToSharedPreferences(nextFavorites);

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'FavoritesManager: Removed favorite ${normalizedItem.canonicalUid} (local)',
      );
      return;
    }

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

      final legacySnapshot = await _legacyFavoritesRef(userId).get();
      for (final doc in legacySnapshot.docs) {
        await doc.reference.delete();
      }

      if (_auth.currentUser?.uid == userId) {
        favsData = [];
        await _saveFavoritesToSharedPreferences(const []);
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
  }
}
