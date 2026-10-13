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

  /// Set once the first starter playlists (Morning, Thursday, Friday) have
  /// been added, so a reader who deletes one does not see it come back.
  static const String seededKey = 'zikr_playlists_seeded_v1';

  /// Set once the second set has been handed out too: Friday split into
  /// morning and afternoon, Thursday renamed Thursday Night, and Daily Quran,
  /// Mahe Ramazan Nights, Mahe Ramazan Suhoor and Shaban added.
  static const String seededV2Key = 'zikr_playlists_seeded_v2';

  static final DateTime _v1Date = DateTime.utc(2026, 9, 25);
  static final DateTime _v2Date = DateTime.utc(2026, 10, 13);

  static final ZikrPlaylist _fridayMorning = ZikrPlaylist(
    id: 'default-friday-morning',
    name: 'Friday Morning',
    // Dua Nudba, Ziyarat of Imam al-Mahdi on Friday, Surah Al-Jumu'ah
    zikrUids: const ['E34', 'J3', 'A66'],
    updatedAt: _v2Date,
  );

  static final ZikrPlaylist _fridayAfternoon = ZikrPlaylist(
    id: 'default-friday-afternoon',
    name: 'Friday Afternoon',
    // Dua Simat, Salawat of Abul Hasan al-Zarrab al-Isfahani: both for the
    // last hours before Maghrib
    zikrUids: const ['E26', 'E144'],
    updatedAt: _v2Date,
  );

  /// Added for every reader in the second set, wherever they stood.
  static final List<ZikrPlaylist> _v2Additions = List.unmodifiable([
    ZikrPlaylist(
      id: 'default-daily-quran',
      name: 'Daily Quran',
      // Surahs Ya-Sin, Ar-Rahman, Al-Waqi'ah, Al-Mulk
      zikrUids: const ['A40', 'A59', 'A60', 'A71'],
      updatedAt: _v2Date,
    ),
    ZikrPlaylist(
      id: 'default-ramazan-nights',
      name: 'Mahe Ramazan Nights',
      // Dua Iftitah, Ya Uddati
      zikrUids: const ['AA10', 'AA13'],
      updatedAt: _v2Date,
    ),
    ZikrPlaylist(
      id: 'default-ramazan-suhoor',
      name: 'Mahe Ramazan Suhoor',
      // Dua Sahar (Ya Mafza'i), Dua Baha, Dua Abu Hamza Thumali
      zikrUids: const ['AA14', 'AA11', 'AA12'],
      updatedAt: _v2Date,
    ),
    ZikrPlaylist(
      id: 'default-shaban',
      name: 'Shaban',
      // Daily Salawat of Shaban, Munajat Shabaniyah
      zikrUids: const ['Y3', 'Y4'],
      updatedAt: _v2Date,
    ),
  ]);

  /// Starter playlists every reader gets once, to edit or delete like their
  /// own. Only zikrs with a recording belong here - see
  /// assets/zikr_audio.json.
  static final List<ZikrPlaylist> defaultPlaylists = List.unmodifiable([
    ZikrPlaylist(
      id: 'default-morning',
      name: 'Morning',
      // Dua Ahad, Ziyarat Ashura, Ziyarat Aal-e-Yasin, Ziyarat Jamia Kabira
      zikrUids: const ['E18', 'G4', 'G1', 'G13'],
      updatedAt: _v1Date,
    ),
    _v2Additions.first,
    ZikrPlaylist(
      id: 'default-thursday',
      name: 'Thursday Night',
      // Dua Kumayl, Ziyarat Warith, a short Ziyarat of Imam Husayn (a.s.)
      zikrUids: const ['E31', 'G6', 'G54'],
      updatedAt: _v1Date,
    ),
    _fridayMorning,
    _fridayAfternoon,
    ..._v2Additions.skip(1),
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
    if (SP.prefs.getBool(seededV2Key) ?? false) return stored;

    final seeded =
        List<ZikrPlaylist>.unmodifiable((SP.prefs.getBool(seededKey) ?? false)
            ? upgradeFromFirstSet(stored)
            : [
                ...stored,
                for (final playlist in defaultPlaylists)
                  if (!stored.any((mine) => mine.id == playlist.id)) playlist,
              ]);
    unawaited(SP.prefs.setString(
      storageKey,
      jsonEncode(seeded.map((playlist) => playlist.toJson()).toList()),
    ));
    unawaited(SP.prefs.setBool(seededKey, true));
    unawaited(SP.prefs.setBool(seededV2Key, true));
    return seeded;
  }

  /// Brings a reader who got the first set up to the second. An untouched
  /// Friday becomes Friday Morning and Friday Afternoon in its place; one they
  /// edited or deleted stays as they left it, and gets no split. Thursday is
  /// renamed Thursday Night unless they renamed it themselves. The new
  /// playlists go after everything else.
  @visibleForTesting
  static List<ZikrPlaylist> upgradeFromFirstSet(List<ZikrPlaylist> stored) {
    final upgraded = [
      for (final playlist in stored)
        if (playlist.id == 'default-friday' &&
            playlist.name == 'Friday' &&
            playlist.updatedAt.isAtSameMomentAs(_v1Date)) ...[
          _fridayMorning,
          _fridayAfternoon,
        ] else if (playlist.id == 'default-thursday' &&
            playlist.name == 'Thursday')
          playlist.copyWith(name: 'Thursday Night')
        else
          playlist,
    ];
    return [
      ...upgraded,
      for (final playlist in _v2Additions)
        if (!upgraded.any((mine) => mine.id == playlist.id)) playlist,
    ];
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

  Future<ZikrPlaylist> create(
    String name, {
    List<String> zikrUids = const [],
    Map<String, List<String>> trackFiles = const {},
  }) {
    final now = DateTime.now().toUtc();
    final playlist = ZikrPlaylist(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      name: name.trim(),
      zikrUids: List.unmodifiable(_dedupe(zikrUids)),
      updatedAt: now,
    ).copyWith(trackFiles: trackFiles);
    return _write([...playlists, playlist]).then((_) => playlist);
  }

  Future<void> rename(String id, String name) {
    return _update(id, (playlist) => playlist.copyWith(name: name.trim()));
  }

  Future<void> delete(String id) {
    return _write(playlists.where((playlist) => playlist.id != id).toList());
  }

  /// Appends [uid] to the playlist, with [trackFile] as its recording when
  /// the reader added one particular recording of it. A zikr already in it is
  /// left as it is: a playlist plays each recitation once. (Choosing more of
  /// its recordings is [setTrackFiles].)
  Future<void> addZikr(String id, String uid, {String? trackFile}) {
    return _update(id, (playlist) {
      if (playlist.zikrUids.contains(uid)) return playlist;
      return playlist.copyWith(
        zikrUids: [...playlist.zikrUids, uid],
        trackFiles: trackFile == null
            ? null
            : {
                ...playlist.trackFiles,
                uid: [trackFile]
              },
      );
    });
  }

  /// Sets which recordings of [uid] the playlist plays, by
  /// [ZikrAudioTrack.file]. An empty [trackFiles] goes back to the first.
  Future<void> setTrackFiles(String id, String uid, List<String> trackFiles) {
    return _update(id, (playlist) {
      if (listEquals(playlist.trackFiles[uid], trackFiles)) return playlist;
      return playlist.copyWith(
        trackFiles: {...playlist.trackFiles, uid: trackFiles},
      );
    });
  }

  Future<void> removeAt(String id, int index) {
    return _update(id, (playlist) {
      if (index < 0 || index >= playlist.zikrUids.length) return playlist;
      final uid = playlist.zikrUids[index];
      return playlist.copyWith(
        zikrUids: [...playlist.zikrUids]..removeAt(index),
        // Re-adding it later starts from its first recording again.
        trackFiles: {...playlist.trackFiles}..remove(uid),
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
    return [
      for (final uid in uids)
        if (seen.add(uid)) uid
    ];
  }
}
