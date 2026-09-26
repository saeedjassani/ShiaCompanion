import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../constants.dart' show items;
import '../models/zikr_audio_track.dart';
import '../models/zikr_playlist.dart';
import 'analytics_service.dart';
import 'exclusive_audio.dart';
import 'zikr_audio_index.dart';

/// One recording in a playing queue, with the zikr it belongs to.
@immutable
class PlaylistQueueEntry {
  const PlaylistQueueEntry({
    required this.zikrUid,
    required this.zikrTitle,
    required this.track,
  });

  final String zikrUid;
  final String zikrTitle;
  final ZikrAudioTrack track;

  /// What the lock screen and the now-playing bar call this recording: the
  /// track's own label when the zikr has several, otherwise the zikr title.
  String get title => track.label ?? zikrTitle;
}

/// Plays a [ZikrPlaylist] as one continuous background audio queue - every
/// recording of every zikr in it, back to back, with next/previous on the
/// lock screen and notification.
///
/// A singleton rather than a widget's state, unlike the zikr page's
/// `ZikrAudioPlayer`: the whole point of a playlist is that it keeps going
/// while the reader leaves the page, opens a zikr, or locks the phone.
class PlaylistAudioService extends ChangeNotifier {
  PlaylistAudioService._();

  static final PlaylistAudioService instance = PlaylistAudioService._();

  AudioPlayer? _player;
  ZikrPlaylist? _playlist;
  List<PlaylistQueueEntry> _queue = const [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isStarting = false;

  AudioPlayer? get player => _player;
  ZikrPlaylist? get playlist => _playlist;
  List<PlaylistQueueEntry> get queue => _queue;
  bool get isActive => _player != null;
  bool get isStarting => _isStarting;
  bool get isPlaying => _player?.playing ?? false;
  bool get isRepeating => _player?.loopMode == LoopMode.all;

  int? get currentIndex => _player?.currentIndex;

  PlaylistQueueEntry? get current {
    final index = currentIndex;
    if (index == null || index < 0 || index >= _queue.length) return null;
    return _queue[index];
  }

  /// Every recording of every zikr in [zikrUids], in order. Zikrs with no
  /// recording are skipped rather than failing the whole queue.
  static List<PlaylistQueueEntry> buildQueue(
    List<String> zikrUids, {
    required List<ZikrAudioTrack> Function(String uid) tracksFor,
    required String Function(String uid) titleFor,
  }) {
    return [
      for (final uid in zikrUids)
        for (final track in tracksFor(uid))
          PlaylistQueueEntry(
              zikrUid: uid, zikrTitle: titleFor(uid), track: track),
    ];
  }

  static String _indexTitle(String uid) {
    final title = items[uid]?.toString().trim() ?? '';
    return title.isEmpty ? uid : title;
  }

  /// Starts [playlist] from its [startZikrIndex]th zikr. Returns false, and
  /// leaves any current playback alone, when nothing in it can be played.
  Future<bool> play(ZikrPlaylist playlist, {int startZikrIndex = 0}) async {
    if (_isStarting) return false;
    _isStarting = true;
    notifyListeners();
    try {
      final audio = ZikrAudioIndex.instance;
      await audio.load();
      final queue = buildQueue(
        playlist.zikrUids,
        tracksFor: audio.tracksFor,
        titleFor: _indexTitle,
      );
      if (queue.isEmpty) return false;

      final startUid =
          startZikrIndex >= 0 && startZikrIndex < playlist.zikrUids.length
              ? playlist.zikrUids[startZikrIndex]
              : null;
      final initialIndex = startUid == null
          ? 0
          : queue
              .indexWhere((entry) => entry.zikrUid == startUid)
              .clamp(0, queue.length - 1);

      await ExclusiveAudio.claim(this, _release);
      await _disposePlayer();

      final player = AudioPlayer();
      _player = player;
      _playlist = playlist;
      _queue = List.unmodifiable(queue);
      _subscriptions
        ..add(player.playerStateStream.listen((_) => notifyListeners()))
        ..add(player.currentIndexStream.listen((_) => notifyListeners()))
        ..add(player.playbackEventStream.listen(
          (_) {},
          onError: (Object error, StackTrace _) => _skipBrokenTrack(error),
        ));

      await player.setAudioSources(
        [
          for (var i = 0; i < queue.length; i++)
            AudioSource.uri(
              Uri.parse(queue[i].track.url),
              tag: MediaItem(
                id: 'playlist:${playlist.id}#$i',
                title: queue[i].title,
                album: playlist.name,
                artist: queue[i].track.artist,
              ),
            ),
        ],
        initialIndex: initialIndex,
      );
      unawaited(AnalyticsService.feature(
        'zikr_playlist_play',
        label: 'Zikr playlist played',
        parameters: {'track_count': queue.length},
      ));
      unawaited(player.play());
      return true;
    } catch (error) {
      debugPrint('Playlist failed to start: $error');
      await stop();
      return false;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  /// A recording that has moved or vanished from the bucket should cost that
  /// one track, not stop the whole morning's queue.
  void _skipBrokenTrack(Object error) {
    debugPrint('Playlist track failed: $error');
    final player = _player;
    if (player == null) return;
    if (player.hasNext) {
      unawaited(player.seekToNext().then((_) => player.play()));
    } else {
      unawaited(stop());
    }
  }

  Future<void> togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      await player.pause();
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero, index: 0);
    }
    await player.play();
  }

  Future<void> next() async {
    final player = _player;
    if (player == null || !player.hasNext) return;
    await player.seekToNext();
  }

  /// Restarts the current recording, or goes back one when it has barely
  /// begun - the way every music player's back button works.
  Future<void> previous() async {
    final player = _player;
    if (player == null) return;
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
      return;
    }
    await player.seekToPrevious();
  }

  Future<void> skipTo(int queueIndex) async {
    final player = _player;
    if (player == null || queueIndex < 0 || queueIndex >= _queue.length) {
      return;
    }
    await player.seek(Duration.zero, index: queueIndex);
    if (!player.playing) await player.play();
  }

  Future<void> seek(Duration position) async => _player?.seek(position);

  Future<void> toggleRepeat() async {
    final player = _player;
    if (player == null) return;
    await player.setLoopMode(
      player.loopMode == LoopMode.all ? LoopMode.off : LoopMode.all,
    );
    notifyListeners();
  }

  Future<void> stop() async {
    ExclusiveAudio.relinquish(this);
    await _release();
  }

  /// Called by [ExclusiveAudio] when the zikr page's player takes over.
  Future<void> _release() async {
    await _disposePlayer();
    _playlist = null;
    _queue = const [];
    notifyListeners();
  }

  Future<void> _disposePlayer() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}
