import 'dart:async';

import 'package:flutter/foundation.dart';

import 'activity_stats_store.dart';
import 'favorites_manager.dart';
import 'prayer_preferences_sync_service.dart';
import 'preferences_sync_service.dart';
import 'qaza_tracker_manager.dart';
import 'recitation_tracker_manager.dart';
import 'saved_verses_manager.dart';
import 'verse_notes_manager.dart';
import 'zikr_bookmarks_manager.dart';

/// Everything kept in step with the signed-in account, loaded together: at
/// start-up (Home) and after a sign-in or sign-out (Settings).
class SyncedData {
  const SyncedData._();

  /// Loads each manager's data and pulls the synced preferences, all at
  /// once, resolving when every one has finished.
  ///
  /// They read separate documents and none waits on another, so side by
  /// side they take as long as the slowest rather than the sum - one after
  /// another, eight reads of up to 8 seconds each held up the Azan schedule
  /// and the home screen widgets behind them for over a minute on a bad
  /// connection. One that fails is logged and the others carry on.
  static Future<void> pullAll({bool force = false}) async {
    // Not waited for: stats are already correct on this device, and a
    // Firestore write only completes once the server acknowledges it.
    unawaited(ActivityStatsStore.instance.pullAndMerge());
    await Future.wait([
      _guarded('favorites',
          () => FavoritesManager.instance.loadFavorites(force: force)),
      _guarded(
          'qaza', () => QazaTrackerManager.instance.loadQaza(force: force)),
      _guarded(
          'recitations',
          () =>
              RecitationTrackerManager.instance.loadRecitations(force: force)),
      _guarded('saved verses',
          () => SavedVersesManager.instance.loadSavedVerses(force: force)),
      _guarded('bookmarks',
          () => ZikrBookmarksManager.instance.loadBookmarks(force: force)),
      _guarded('verse notes',
          () => VerseNotesManager.instance.loadNotes(force: force)),
      _guarded('preferences', PreferencesSyncService.instance.pullOrSeed),
      _guarded('prayer preferences',
          PrayerPreferencesSyncService.instance.pullOrSeed),
    ]);
  }

  static Future<void> _guarded(
      String name, Future<void> Function() load) async {
    try {
      await load();
    } catch (error) {
      debugPrint('Unable to load synced $name: $error');
    }
  }
}
