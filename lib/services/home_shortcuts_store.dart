import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/shared_preferences.dart';
import 'preferences_sync_service.dart';

/// Which features sit in Home's Shortcuts grid, in order: up to
/// [maxShortcuts] of them, chosen in the editor sheet, with All features
/// always added after them by the grid itself.
///
/// Stored as [HomeMenuItem.analyticsId]s - ids that survive a relabel - in
/// SharedPreferences, and synced to the account through
/// [PreferencesSyncService] like the other reading preferences.
class HomeShortcutsStore extends ChangeNotifier {
  HomeShortcutsStore._();

  static final HomeShortcutsStore instance = HomeShortcutsStore._();

  static const String prefsKey = 'home_shortcuts';
  static const int maxShortcuts = 7;

  /// What a fresh install, or one that never opened the editor, shows.
  static const List<String> defaultIds = [
    'duas',
    'ziyarats',
    'today_s_recitations',
    'munajaat',
    'calendar_prayer_times',
    'tasbeeh_counter',
    'qibla_finder',
  ];

  /// The chosen ids, or [defaultIds] when nothing has been chosen. Ids the
  /// current build does not know (an item only on Android, one from a newer
  /// version) are kept here and simply skipped when the grid resolves them.
  List<String> get ids {
    if (!SP.isInitialized) return defaultIds;
    final stored = SP.prefs.getStringList(prefsKey);
    return stored == null ? defaultIds : List.unmodifiable(stored);
  }

  /// Whether the reader has ever saved their own choice.
  bool get isCustomized =>
      SP.isInitialized && SP.prefs.getStringList(prefsKey) != null;

  /// Saves [ids] here and on the reader's other devices.
  Future<void> save(List<String> ids) async {
    final cleaned = normalize(ids);
    await _store(cleaned);
    unawaited(PreferencesSyncService.instance.pushHomeShortcuts(cleaned));
  }

  /// Applies a choice synced from another device, without pushing it back.
  Future<void> applySynced(List<String> ids) => _store(normalize(ids));

  Future<void> _store(List<String> ids) async {
    if (listEquals(ids, this.ids) && isCustomized) return;
    if (!SP.isInitialized) await SP.init();
    await SP.prefs.setStringList(prefsKey, ids);
    notifyListeners();
  }

  /// Drops blanks and repeats and caps the list at [maxShortcuts], so a bad
  /// write (or a synced list from a build with a different cap) can never
  /// overflow the grid.
  @visibleForTesting
  static List<String> normalize(Iterable<String> ids) {
    final seen = <String>{};
    return List.unmodifiable([
      for (final id in ids)
        if (id.trim().isNotEmpty && seen.add(id)) id,
    ].take(maxShortcuts));
  }
}
