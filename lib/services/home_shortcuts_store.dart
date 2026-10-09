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
  static const int maxShortcuts = 11;

  /// What a phone shows before anyone opens the editor: two rows with
  /// All features. Today's Recitations is not among them: Home's Today
  /// section leads to it.
  static const List<String> defaultIds = [
    'duas',
    'ziyarats',
    'taqeebat_e_namaz',
    'namaz',
    'calendar_prayer_times',
    'tasbeeh_counter',
    'qibla_finder',
  ];

  /// What a tablet or desktop shows before anyone opens the editor: the
  /// phone's defaults and four more, filling three rows with All features.
  static const List<String> wideDefaultIds = [
    ...defaultIds,
    'qaza_tracker',
    'playlists',
    'library',
    'aamaal',
  ];

  /// The chosen ids, or the phone's [defaultIds] when nothing has been
  /// chosen; see [idsFor] for what a given screen shows.
  List<String> get ids => idsFor(wide: false);

  /// The chosen ids, or the defaults for a [wide] screen or a phone when
  /// nothing has been chosen. A choice is one list for every screen size:
  /// saving one, on any device, replaces both sets of defaults. Ids the
  /// current build does not know (an item only on Android, one from a newer
  /// version) are kept here and simply skipped when the grid resolves them.
  List<String> idsFor({required bool wide}) {
    final defaults = wide ? wideDefaultIds : defaultIds;
    if (!SP.isInitialized) return defaults;
    final stored = SP.prefs.getStringList(prefsKey);
    return stored == null ? defaults : List.unmodifiable(stored);
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
