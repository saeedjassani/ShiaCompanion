import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../constants.dart' show items;
import '../l10n/l10n.dart';
import '../models/zikr_audio_track.dart';
import '../models/zikr_playlist.dart';
import '../utils/network_utils.dart';
import 'analytics_service.dart';
import 'audio_download_store.dart';
import 'exclusive_audio.dart';
import 'zikr_audio_index.dart';
import 'zikr_translations.dart';

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
  String get title => track.displayLabel ?? zikrTitle;
}

/// How [PlaylistAudioService.play] went, so the page can say why nothing
/// happened - or that only part of the playlist is playing.
enum PlaylistStartResult {
  started,

  /// Offline, so only the downloaded recitations are queued.
  startedDownloadedOnly,

  /// Nothing in the playlist has a recording at all.
  nothingToPlay,

  /// Offline, and none of the playlist's recitations are downloaded.
  offlineNothingDownloaded,

  /// The player could not start.
  failed;

  bool get isStarted => this == started || this == startedDownloadedOnly;

  /// What to tell the reader about this start, or null when there is nothing
  /// to say because it simply started.
  String? get message {
    final strings = L10n.current;
    return switch (this) {
      started => null,
      startedDownloadedOnly => strings.playlistOfflinePartial,
      nothingToPlay => strings.playlistNothingToPlay,
      offlineNothingDownloaded => strings.playlistOfflineNothingDownloaded,
      failed => strings.playlistStartFailed,
    };
  }
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

  /// Zikrs of the current run already counted by [_countPlayingZikr], so a
  /// zikr with several recordings, a pause and resume, or a repeat of the
  /// whole queue counts it once per run rather than once per event.
  final Set<String> _countedZikrUids = {};

  /// Whether a playlist is loaded - playing, paused or finished - and so
  /// whether the floating now-playing capsule is up. Changes only when one
  /// starts or stops, unlike this service's own notifications, which come
  /// with every change of play state, so whole pages can afford to follow
  /// it to leave room for the capsule.
  final ValueNotifier<bool> visible = ValueNotifier(false);

  @override
  void notifyListeners() {
    visible.value = _player != null && _queue.isNotEmpty;
    super.notifyListeners();
  }

  /// Prefix of the id [playZikr] gives the one-zikr queue it plays, which is
  /// not one of the reader's playlists.
  static const String singleZikrIdPrefix = 'zikr:';

  AudioPlayer? get player => _player;
  ZikrPlaylist? get playlist => _playlist;

  /// The zikr playing on its own, by [playZikr], rather than in a playlist -
  /// so "Open playlist" opens that zikr instead.
  String? get singleZikrUid {
    final id = _playlist?.id;
    if (id == null || !id.startsWith(singleZikrIdPrefix)) return null;
    return id.substring(singleZikrIdPrefix.length);
  }

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

  /// How many zikrs the queue plays. Not [queue]'s length: a zikr with
  /// several recordings (a salat and the dua after it) is still one entry in
  /// the playlist the reader sees.
  int get zikrCount => _queue.map((entry) => entry.zikrUid).toSet().length;

  /// The 1-based position of the playing zikr among [zikrCount], or null
  /// when nothing is playing.
  int? get zikrPosition {
    final index = currentIndex;
    if (index == null || index < 0 || index >= _queue.length) return null;
    final seen = <String>{};
    for (var i = 0; i <= index; i++) {
      seen.add(_queue[i].zikrUid);
    }
    return seen.length;
  }

  /// The recordings [tracksFor] gives for every zikr in [zikrUids], in order
  /// - for a playlist, the ones the reader chose. Zikrs with no recording are
  /// skipped rather than failing the whole queue.
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

  /// Narrows [queue] to what can play offline, keeping [startIndex] on the
  /// same recitation or the next downloaded one after it. Returns the new
  /// queue and start index.
  static (List<PlaylistQueueEntry>, int) downloadedOnly(
    List<PlaylistQueueEntry> queue,
    int startIndex, {
    required bool Function(ZikrAudioTrack track) isDownloaded,
  }) {
    final kept = <PlaylistQueueEntry>[];
    var newStart = -1;
    for (var i = 0; i < queue.length; i++) {
      if (!isDownloaded(queue[i].track)) continue;
      if (newStart < 0 && i >= startIndex) newStart = kept.length;
      kept.add(queue[i]);
    }
    return (kept, newStart < 0 ? 0 : newStart);
  }

  /// The lock screen's title for zikr [uid], in the reader's zikr language.
  static String _indexTitle(String uid) {
    final title = items[uid]?.toString().trim() ?? '';
    return title.isEmpty ? uid : zikrDisplayTitle(uid, title);
  }

  /// Starts [playlist] from its [startZikrIndex]th zikr, leaving any current
  /// playback alone when nothing in it can be played. Offline, only the
  /// downloaded recitations are queued: a streamed one would only fail.
  Future<PlaylistStartResult> play(
    ZikrPlaylist playlist, {
    int startZikrIndex = 0,
  }) async {
    if (_isStarting) return PlaylistStartResult.failed;
    _isStarting = true;
    notifyListeners();
    try {
      final audio = ZikrAudioIndex.instance;
      final downloads = AudioDownloadStore.instance;
      await Future.wait([audio.load(), downloads.load()]);
      var queue = buildQueue(
        playlist.zikrUids,
        tracksFor: (uid) => playlist.tracksFor(uid, audio.tracksFor(uid)),
        titleFor: _indexTitle,
      );
      if (queue.isEmpty) return PlaylistStartResult.nothingToPlay;

      final startUid =
          startZikrIndex >= 0 && startZikrIndex < playlist.zikrUids.length
              ? playlist.zikrUids[startZikrIndex]
              : null;
      final initialIndex = startUid == null
          ? 0
          : queue
              .indexWhere((entry) => entry.zikrUid == startUid)
              .clamp(0, queue.length - 1);
      var startIndex = initialIndex;
      var result = PlaylistStartResult.started;
      if (!NetworkUtils().isOnline) {
        final (kept, keptStart) = downloadedOnly(
          queue,
          initialIndex,
          isDownloaded: downloads.isDownloaded,
        );
        if (kept.isEmpty) return PlaylistStartResult.offlineNothingDownloaded;
        if (kept.length < queue.length) {
          result = PlaylistStartResult.startedDownloadedOnly;
        }
        queue = kept;
        startIndex = keptStart;
      }

      await ExclusiveAudio.claim(this, _release);
      await _disposePlayer();

      final player = AudioPlayer();
      _player = player;
      _playlist = playlist;
      _countedZikrUids.clear();
      _queue = List.unmodifiable(queue);
      _subscriptions
        ..add(player.playerStateStream.listen((_) {
          _countPlayingZikr();
          notifyListeners();
        }))
        ..add(player.currentIndexStream.listen((_) {
          _countPlayingZikr();
          notifyListeners();
        }))
        ..add(player.playbackEventStream.listen(
          (_) {},
          onError: (Object error, StackTrace _) => _skipBrokenTrack(error),
        ));

      await player.setAudioSources(
        [
          for (var i = 0; i < queue.length; i++)
            // A recitation saved for offline plays from the device.
            AudioSource.uri(
              downloads.sourceUri(queue[i].track),
              tag: MediaItem(
                id: 'playlist:${playlist.id}#$i',
                title: queue[i].title,
                album: playlist.displayName,
                artist: queue[i].track.artist,
              ),
            ),
        ],
        initialIndex: startIndex,
      );
      unawaited(AnalyticsService.feature(
        'zikr_playlist_play',
        label: 'Zikr playlist played',
        parameters: {'track_count': queue.length},
      ));
      unawaited(player.play());
      return result;
    } catch (error) {
      debugPrint('Playlist failed to start: $error');
      await stop();
      return PlaylistStartResult.failed;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  /// Plays zikr [uid]'s recitation on its own, through the same background
  /// queue as a playlist: a play link, Siri or a shortcut asks for one dua,
  /// and it should keep going on the lock screen like any playlist does.
  Future<PlaylistStartResult> playZikr(String uid) {
    return play(ZikrPlaylist(
      id: '$singleZikrIdPrefix$uid',
      name: _indexTitle(uid),
      zikrUids: [uid],
      updatedAt: DateTime.now().toUtc(),
    ));
  }

  /// Records which zikr a playlist is actually playing, the first time each
  /// one starts in this run. [play] only says a playlist was started; this is
  /// what says which zikrs people listen to through playlists, including the
  /// ones reached by letting the queue run on or skipping ahead.
  void _countPlayingZikr() {
    final player = _player;
    if (player == null || !player.playing) return;
    final entry = current;
    if (entry == null || !_countedZikrUids.add(entry.zikrUid)) return;
    unawaited(AnalyticsService.zikrPlaylistPlay(
      uid: entry.zikrUid,
      title: entry.zikrTitle,
    ));
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
