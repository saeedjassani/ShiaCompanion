import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/zikr_audio_track.dart';

/// Every zikr's recordings, from assets/zikr_audio.json - the one place audio
/// is listed. Content files hold only text.
///
/// Loaded on first use (a zikr page or the playlists screen), never at
/// startup, and kept for the life of the process. Even with a recording for
/// every surah and zikr the file is a couple of hundred KB and decodes in
/// milliseconds.
class ZikrAudioIndex {
  ZikrAudioIndex._();

  static final ZikrAudioIndex instance = ZikrAudioIndex._();

  static const String assetPath = 'assets/zikr_audio.json';

  Map<String, List<ZikrAudioTrack>> _tracks = const {};
  Future<void>? _loading;
  bool _isLoaded = false;

  /// Whether [load] has finished, so a screen can skip its loading state.
  bool get isLoaded => _isLoaded;

  /// Loads the index once; later calls return the same future.
  Future<void> load([AssetBundle? bundle]) {
    return _loading ??= _load(bundle ?? rootBundle);
  }

  Future<void> _load(AssetBundle bundle) async {
    try {
      _tracks = parse(json.decode(await bundle.loadString(assetPath)));
      _isLoaded = true;
    } catch (error) {
      // No audio is a degraded page, not a broken one; let a later open retry.
      debugPrint('Unable to load zikr audio index: $error');
      _loading = null;
    }
  }

  /// The uid -> tracks map in [decoded], skipping zikrs with nothing playable.
  static Map<String, List<ZikrAudioTrack>> parse(dynamic decoded) {
    if (decoded is! Map) return const {};
    final tracks = <String, List<ZikrAudioTrack>>{};
    decoded.forEach((uid, raw) {
      final list = ZikrAudioTrack.listFrom(raw);
      if (list.isNotEmpty) tracks[uid.toString()] = List.unmodifiable(list);
    });
    return Map.unmodifiable(tracks);
  }

  /// [uid]'s recordings, or none - including before [load] has finished.
  List<ZikrAudioTrack> tracksFor(String uid) => _tracks[uid] ?? const [];

  /// The zikrs with at least one recording: the ones a playlist can hold.
  Iterable<String> get uids => _tracks.keys;

  @visibleForTesting
  void setForTest(Map<String, List<ZikrAudioTrack>> tracks) {
    _tracks = tracks;
    _loading = Future.value();
    _isLoaded = true;
  }
}
