import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'dart:convert';

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();

  factory FavoritesManager() {
    return _instance;
  }

  FavoritesManager._internal();

  static FavoritesManager get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _listener;
  static const String _localStorageKey = "favorites";

  /// Load favorites from appropriate source (SharedPreferences or Firestore)
  Future<void> loadFavorites() async {
    User? user = _auth.currentUser;

    if (user == null) {
      // Load from SharedPreferences for logged-out users
      await _loadFromSharedPreferences();
    } else {
      // Set up real-time listener for logged-in users
      setupRealtimeListener();
    }
  }

  /// Load favorites from SharedPreferences (for logged-out users)
  Future<void> _loadFromSharedPreferences() async {
    try {
      String? favsString = SP.prefs.getString(_localStorageKey);
      favsData = [];

      if (favsString != null && favsString.isNotEmpty) {
        List<dynamic> values = jsonDecode(favsString);
        for (var element in values) {
          favsData!.add(UniversalData(
            element['uid'] as String,
            element['title'] as String,
            element['type'] as int? ?? 0,
          ));
        }
        debugPrint('FavoritesManager: Loaded ${favsData!.length} favorites from SharedPreferences');
      }
    } catch (e) {
      debugPrint('FavoritesManager: Error loading from SharedPreferences: $e');
      favsData = [];
    }
  }

  /// Save favorites to SharedPreferences (for logged-out users)
  Future<void> _saveToSharedPreferences() async {
    try {
      if (favsData != null) {
        String encoded = jsonEncode(favsData);
        await SP.prefs.setString(_localStorageKey, encoded);
        debugPrint('FavoritesManager: Saved ${favsData!.length} favorites to SharedPreferences');
      }
    } catch (e) {
      debugPrint('FavoritesManager: Error saving to SharedPreferences: $e');
    }
  }

  /// Setup real-time listener for favorites (Firestore for logged-in users)
  void setupRealtimeListener() {
    User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('FavoritesManager: No user logged in, skipping Firestore listener setup');
      return;
    }

    // Cancel any existing listener
    _listener?.cancel();

    // Set up real-time listener
    _listener = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .listen(
      (snapshot) {
        favsData = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final uid = doc.id;
          final title = data['title'] as String? ?? '';
          final type = data['type'] as int? ?? 0;
          favsData!.add(UniversalData(uid, title, type));
        }
        debugPrint('FavoritesManager: Updated favsData with ${favsData!.length} items from Firestore');
      },
      onError: (error) {
        debugPrint('FavoritesManager: Error listening to favorites: $error');
      },
    );
  }

  /// Add a favorite
  Future<void> addFavorite(UniversalData item) async {
    if (!favsData!.contains(item)) {
      favsData!.add(item);
    }

    User? user = _auth.currentUser;
    if (user == null) {
      // Save to SharedPreferences for logged-out users
      await _saveToSharedPreferences();
      debugPrint('FavoritesManager: Added favorite ${item.uid} (local)');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(item.uid)
          .set({
        'title': item.title,
        'type': item.type,
      });
      debugPrint('FavoritesManager: Added favorite ${item.uid} (Firestore)');
    } catch (e) {
      debugPrint('FavoritesManager: Error adding favorite: $e');
      rethrow;
    }
  }

  /// Remove a favorite
  Future<void> removeFavorite(UniversalData item) async {
    favsData!.remove(item);

    User? user = _auth.currentUser;
    if (user == null) {
      // Save to SharedPreferences for logged-out users
      await _saveToSharedPreferences();
      debugPrint('FavoritesManager: Removed favorite ${item.uid} (local)');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(item.uid)
          .delete();
      debugPrint('FavoritesManager: Removed favorite ${item.uid} (Firestore)');
    } catch (e) {
      debugPrint('FavoritesManager: Error removing favorite: $e');
      rethrow;
    }
  }

  /// Check if item is favorited
  bool isFavorite(UniversalData item) {
    return favsData!.contains(item);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(UniversalData item) async {
    if (favsData!.contains(item)) {
      await removeFavorite(item);
    } else {
      await addFavorite(item);
    }
  }

  /// Delete all favorites for a user (used on account deletion)
  Future<void> deleteAllFavorites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('FavoritesManager: Deleted all Firestore favorites for user $userId');
    } catch (e) {
      debugPrint('FavoritesManager: Error deleting all favorites: $e');
      rethrow;
    }
  }

  /// Dispose listener
  void dispose() {
    _listener?.cancel();
    debugPrint('FavoritesManager: Disposed listener');
  }
}
