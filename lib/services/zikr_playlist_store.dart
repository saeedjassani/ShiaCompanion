import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/zikr_playlist.dart';
import '../utils/shared_preferences.dart';

/// The reader's audio playlists, kept on this device only.
///
/// Everything lives under one SharedPreferences key as a JSON list, so an
/// edit is a single atomic write and the list order is the order the reader
/// arranged them in.
class ZikrPlaylistStore extends ChangeNotifier {
  ZikrPlaylistStore._();

  static final ZikrPlaylistStore instance = ZikrPlaylistStore._();

  static const String storageKey = 'zikr_playlists_v1';

  /// Set once the starter playlists below have been added, so a reader who
  /// deletes one does not see it come back.
  static const String seededKey = 'zikr_playlists_seeded_v1';

  /// Starter playlists every reader gets once, to edit or delete like their
  /// own. Only zikrs with a recording belong here - see `"audio": true` in
  /// assets/zikr.json.
  static final List<ZikrPlaylist> defaultPlaylists = List.unmodifiable([
    ZikrPlaylist(
      id: 'default-morning',
      name: 'Morning',
      zikrUids: const ['E18', 'G4'], // Dua Ahad, Ziyarat Ashura
      updatedAt: DateTime.utc(2026, 9, 25),
    ),
    ZikrPlaylist(
      id: 'default-thursday',
      name: 'Thursday',
      // Dua Kumayl, Ziyarat Warith
      zikrUids: const ['E31', 'G54'],
      updatedAt: DateTime.utc(2026, 9, 25),
    ),
    ZikrPlaylist(
      id: 'default-friday',
      name: 'Friday',
      // Dua Nudbah, Ziyarat of Imam al-Mahdi on Friday
      zikrUids: const ['E34', 'J3'],
      updatedAt: DateTime.utc(2026, 9, 25),
    ),
  ]);

  List<ZikrPlaylist>? _playlists;

  List<ZikrPlaylist> get playlists => _playlists ??= _read();

  ZikrPlaylist? byId(String id) {
    for (final playlist in playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// Drops the in-memory copy so the next read goes back to storage. For
  /// tests, which swap the SharedPreferences contents underneath.
  @visibleForTesting
  void resetForTest() => _playlists = null;

  List<ZikrPlaylist> _read() {
    if (!SP.isInitialized) return const [];
    final stored = _readStored();
    if (SP.prefs.getBool(seededKey) ?? false) return stored;

    final ids = {for (final playlist in stored) playlist.id};
    final seeded = List<ZikrPlaylist>.unmodifiable([
      ...stored,
      for (final playlist in defaultPlaylists)
        if (!ids.contains(playlist.id)) playlist,
    ]);
    unawaited(SP.prefs.setString(
      storageKey,
      jsonEncode(seeded.map((playlist) => playlist.toJson()).toList()),
    ));
    unawaited(SP.prefs.setBool(seededKey, true));
    return seeded;
  }

  List<ZikrPlaylist> _readStored() {
    final encoded = SP.prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return List.unmodifiable(decoded
          .whereType<Map>()
          .map((entry) =>
              ZikrPlaylist.fromJson(Map<String, dynamic>.from(entry)))
          .where((playlist) => playlist.id.isNotEmpty));
    } catch (error) {
      debugPrint('Unable to read zikr playlists: $error');
      return const [];
    }
  }

  Future<void> _write(List<ZikrPlaylist> next) async {
    _playlists = List.unmodifiable(next);
    notifyListeners();
    if (!SP.isInitialized) return;
    await SP.prefs.setString(
      storageKey,
      jsonEncode(next.map((playlist) => playlist.toJson()).toList()),
    );
  }

  Future<ZikrPlaylist> create(String name, {List<String> zikrUids = const []}) {
    final now = DateTime.now().toUtc();
    final playlist = ZikrPlaylist(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      name: name.trim(),
      zikrUids: List.unmodifiable(_dedupe(zikrUids)),
      updatedAt: now,
    );
    return _write([...playlists, playlist]).then((_) => playlist);
  }

  Future<void> rename(String id, String name) {
    return _update(id, (playlist) => playlist.copyWith(name: name.trim()));
  }

  Future<void> delete(String id) {
    return _write(playlists.where((playlist) => playlist.id != id).toList());
  }

  /// Appends [uid] to the playlist. A zikr already in it is left where it is:
  /// a playlist plays each recitation once.
  Future<void> addZikr(String id, String uid) {
    return _update(id, (playlist) {
      if (playlist.zikrUids.contains(uid)) return playlist;
      return playlist.copyWith(zikrUids: [...playlist.zikrUids, uid]);
    });
  }

  Future<void> removeAt(String id, int index) {
    return _update(id, (playlist) {
      if (index < 0 || index >= playlist.zikrUids.length) return playlist;
      return playlist.copyWith(
        zikrUids: [...playlist.zikrUids]..removeAt(index),
      );
    });
  }

  /// Moves the item at [oldIndex] so it ends up at [newIndex].
  Future<void> move(String id, int oldIndex, int newIndex) {
    return _update(id, (playlist) {
      final uids = [...playlist.zikrUids];
      if (oldIndex < 0 || oldIndex >= uids.length) return playlist;
      newIndex = newIndex.clamp(0, uids.length - 1);
      uids.insert(newIndex, uids.removeAt(oldIndex));
      return playlist.copyWith(zikrUids: uids);
    });
  }

  Future<void> _update(String id, ZikrPlaylist Function(ZikrPlaylist) edit) {
    var changed = false;
    final next = [
      for (final playlist in playlists)
        if (playlist.id == id)
          () {
            final edited = edit(playlist);
            if (identical(edited, playlist)) return playlist;
            changed = true;
            return edited.copyWith(updatedAt: DateTime.now().toUtc());
          }()
        else
          playlist,
    ];
    return changed ? _write(next) : Future.value();
  }

  static List<String> _dedupe(Iterable<String> uids) {
    final seen = <String>{};
    return [for (final uid in uids) if (seen.add(uid)) uid];
  }
}
