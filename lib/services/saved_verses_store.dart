import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shia_companion/models/saved_verse.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

export 'package:shia_companion/models/saved_verse.dart';

/// Where saved verses were kept before they synced: one JSON list on the
/// device, never uploaded.
///
/// Saved verses now live in [RecitationTrackerState] and sync with the rest
/// of the Quran tracker, so this only survives to be read once and emptied -
/// [RecitationTrackerManager] moves whatever it finds here into the synced
/// state on its first load, then [clear]s it.
class SavedVersesStore {
  SavedVersesStore._();

  static final SavedVersesStore instance = SavedVersesStore._();

  static const String _storageKey = 'quran_saved_verses_v1';

  /// Every verse still stored on the device, corrupt rows dropped.
  List<SavedVerse> readAll() {
    if (!SP.isInitialized) return const [];

    final encoded = SP.prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];

      return List.unmodifiable(decoded
          .whereType<Map>()
          .map((entry) => SavedVerse.fromJson(Map<String, dynamic>.from(entry)))
          .where((verse) => verse.isValid));
    } catch (error) {
      debugPrint('Unable to read saved verses: $error');
      return const [];
    }
  }

  Future<void> clear() {
    if (!SP.isInitialized) return Future.value();
    return SP.prefs.remove(_storageKey);
  }
}
