import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../constants.dart' show items;
import '../l10n/l10n.dart';
import '../models/quran_listening.dart';
import '../models/zikr_audio_track.dart';
import '../models/zikr_playlist.dart';
import '../utils/network_utils.dart';
import '../utils/quran_index.dart';
import '../widgets/app_toast.dart';
import 'analytics_service.dart';
import 'audio_download_store.dart';
import 'audio_playback_speed.dart';
import 'exclusive_audio.dart';
import 'quran_listening_store.dart';
import 'zikr_audio_index.dart';
import 'zikr_translations.dart';

/// One recording in a playing queue, with the zikr it belongs to.
@immutable
class PlaylistQueueEntry {
  const PlaylistQueueEntry({
    required this.zikrUid,
    required this.zikrTitle,
    required this.track,
    this.verse,
    this.daily = false,
  });

  /// One verse of the verse-by-verse Quran. [daily] marks it as part of a
  /// playlist's [quranDailyUid] item, whose verses move the reader's place
  /// in listening through the Quran as they play.
  factory PlaylistQueueEntry.verse(
    VerseKey verse, {
    bool daily = false,
    String? zikrTitle,
  }) {
    final ayah = verse.ayah ?? 1;
    final surahTitle = surahInfoFor(verse.surah)?.displayName ?? '';
    return PlaylistQueueEntry(
      zikrUid: daily ? quranDailyUid : uidForSurah(verse.surah) ?? '',
      zikrTitle: zikrTitle ?? surahTitle,
      track: quranVerseTrack(verse.surah, ayah),
      verse: VerseKey(verse.surah, ayah),
      daily: daily,
    );
  }

  final String zikrUid;
  final String zikrTitle;
  final ZikrAudioTrack track;
  final VerseKey? verse;
  final bool daily;

  /// What the lock screen and the now-playing bar call this recording: the
  /// track's own label when the zikr has several, otherwise the zikr title.
  /// A verse is its surah and number: "Al-Baqarah 2:255".
  String get title {
    final verse = this.verse;
    if (verse != null) {
      final surah = surahInfoFor(verse.surah)?.displayName ?? '';
      return localizeDigits('$surah $verse').trim();
    }
    return track.displayLabel ?? zikrTitle;
  }
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

  /// Offline, and what was asked for is the verse-by-verse Quran, which
  /// only streams.
  offlineNeedsConnection,

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
      offlineNeedsConnection => strings.quranVersesNeedConnection,
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
  VoidCallback? _stopFollowingSpeed;

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

  /// The verse of the verse-by-verse Quran that is playing or paused, so a
  /// surah open in the reader can mark it and keep it in view. Null when
  /// what is loaded is not a verse.
  final ValueNotifier<VerseKey?> playingVerse = ValueNotifier(null);

  @override
  void notifyListeners() {
    visible.value = _player != null && _queue.isNotEmpty;
    playingVerse.value = _player == null ? null : current?.verse;
    super.notifyListeners();
  }

  /// Verses of a [quranDailyUid] item queued at a time; more are added as
  /// the last few come up, so the queue never holds the whole Quran.
  static const int dailyWindow = 120;

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

  /// Whether the queue can be set to repeat. Not with a day's Quran in it:
  /// coming round again would play verses already listened to as if they
  /// were the next ones.
  bool get canRepeat => !_queue.any((entry) => entry.daily);

  /// Whether [verse] is in the queue, so tapping it in the reader can jump
  /// there rather than start something new.
  bool hasVerse(VerseKey verse) =>
      _player != null && _queue.any((entry) => entry.verse == verse);

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
    List<PlaylistQueueEntry> Function()? dailyQuran,
  }) {
    return [
      for (final uid in zikrUids)
        if (uid == quranDailyUid)
          ...?dailyQuran?.call()
        else
          for (final track in tracksFor(uid))
            PlaylistQueueEntry(
              zikrUid: uid,
              zikrTitle: titleFor(uid),
              track: track,
            ),
    ];
  }

  /// Up to [count] verses of the day-by-day Quran from position [from]
  /// ([verseOrdinal]), stopping at an-Nas: the next window starts again at
  /// al-Fatihah.
  static List<PlaylistQueueEntry> dailyVerses(
    int from, {
    int count = dailyWindow,
  }) {
    final start = from.clamp(1, quranVerseTotal);
    final end = (start + count - 1).clamp(start, quranVerseTotal);
    final title = L10n.current.quranDailyItemTitle;
    return [
      for (var ordinal = start; ordinal <= end; ordinal++)
        PlaylistQueueEntry.verse(
          verseAtOrdinal(ordinal),
          daily: true,
          zikrTitle: title,
        ),
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
        dailyQuran: () =>
            dailyVerses(QuranListeningStore.instance.state.next),
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
        if (kept.isEmpty) {
          return queue.every((entry) => entry.verse != null)
              ? PlaylistStartResult.offlineNeedsConnection
              : PlaylistStartResult.offlineNothingDownloaded;
        }
        if (kept.length < queue.length) {
          result = PlaylistStartResult.startedDownloadedOnly;
        }
        queue = kept;
        startIndex = keptStart;
      }

      await _load(playlist, queue, startIndex);
      unawaited(
        AnalyticsService.feature(
          'zikr_playlist_play',
          label: 'Zikr playlist played',
          parameters: {'track_count': queue.length},
        ),
      );
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

  /// Plays the verse-by-verse Quran from [from] to [to], inclusive - a surah
  /// from the verse the reader tapped, or the rest of a juz - on the same
  /// background queue as a playlist. [title] is what the lock screen files
  /// it under: the surah or the juz.
  Future<PlaylistStartResult> playVerses({
    required VerseKey from,
    required VerseKey to,
    required String title,
  }) async {
    if (_isStarting) return PlaylistStartResult.failed;
    final first = ordinalOfVerse(from);
    final last = ordinalOfVerse(to);
    if (last < first) return PlaylistStartResult.nothingToPlay;
    if (!NetworkUtils().isOnline) {
      return PlaylistStartResult.offlineNeedsConnection;
    }
    _isStarting = true;
    notifyListeners();
    try {
      final queue = [
        for (var ordinal = first; ordinal <= last; ordinal++)
          PlaylistQueueEntry.verse(verseAtOrdinal(ordinal)),
      ];
      await _load(
        ZikrPlaylist(
          id: '$singleZikrIdPrefix${uidForSurah(from.surah) ?? ''}',
          name: title,
          zikrUids: [?uidForSurah(from.surah)],
          updatedAt: DateTime.now().toUtc(),
        ),
        queue,
        0,
      );
      unawaited(
        AnalyticsService.feature(
          'quran_verse_play',
          label: 'Quran verses played',
          parameters: {'verse': from.toString(), 'count': queue.length},
        ),
      );
      return PlaylistStartResult.started;
    } catch (error) {
      debugPrint('Verses failed to start: $error');
      await stop();
      return PlaylistStartResult.failed;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  /// Hands the audio to a new player playing [queue] from [startIndex].
  Future<void> _load(
    ZikrPlaylist playlist,
    List<PlaylistQueueEntry> queue,
    int startIndex,
  ) async {
    await ExclusiveAudio.claim(this, _release);
    await _disposePlayer();

    final player = AudioPlayer();
    _player = player;
    _playlist = playlist;
    _countedZikrUids.clear();
    _queue = List.unmodifiable(queue);
    _lastIndex = null;
    _dailyClock.reset();
    _stopFollowingSpeed = AudioPlaybackSpeed.follow(player);
    _subscriptions
      ..add(
        player.playerStateStream.listen((_) {
          _countPlayingZikr();
          _syncDailyClock();
          notifyListeners();
        }),
      )
      ..add(
        player.currentIndexStream.listen((index) {
          _countPlayingZikr();
          _handleIndexChange(index);
          notifyListeners();
        }),
      )
      ..add(
        player.playbackEventStream.listen(
          (_) {},
          onError: (Object error, StackTrace _) => _skipBrokenTrack(error),
        ),
      );

    await player.setAudioSources([
      for (var i = 0; i < queue.length; i++) _sourceFor(queue[i], '$i'),
    ], initialIndex: startIndex);
    unawaited(player.play());
  }

  /// [entry] as the player plays it. A recitation saved for offline plays
  /// from the device.
  AudioSource _sourceFor(PlaylistQueueEntry entry, String key) {
    final playlist = _playlist;
    final verse = entry.verse;
    return AudioSource.uri(
      AudioDownloadStore.instance.sourceUri(entry.track),
      tag: MediaItem(
        id: verse == null
            ? 'playlist:${playlist?.id}#$key'
            : 'quran:${playlist?.id}#$verse',
        title: entry.title,
        album: playlist?.displayName ?? '',
        artist: entry.track.artist,
      ),
    );
  }

  // --- The day-by-day Quran -------------------------------------------------

  /// Time spent playing [quranDailyUid] verses since the last one was
  /// credited to today's listening.
  final Stopwatch _dailyClock = Stopwatch();
  int? _lastIndex;
  bool _extending = false;
  bool _countedDailyRun = false;

  void _syncDailyClock() {
    final player = _player;
    final playing =
        player != null &&
        player.playing &&
        player.processingState != ProcessingState.completed &&
        (current?.daily ?? false);
    if (playing && !_dailyClock.isRunning) _dailyClock.start();
    if (!playing && _dailyClock.isRunning) {
      _dailyClock.stop();
      _creditDaily();
    }
  }

  /// Adds the listening not yet credited to today, keeping the place on the
  /// verse playing.
  void _creditDaily() {
    final entry = _lastIndex == null ? null : _entryAt(_lastIndex!);
    final verse = entry?.verse;
    if (entry == null || !entry.daily || verse == null) return;
    final listened = _dailyClock.elapsed;
    _dailyClock.reset();
    if (listened <= Duration.zero) return;
    QuranListeningStore.instance.recordPlayback(
      playing: ordinalOfVerse(verse),
      listened: listened,
    );
  }

  PlaylistQueueEntry? _entryAt(int index) =>
      index < 0 || index >= _queue.length ? null : _queue[index];

  void _handleIndexChange(int? index) {
    final previous = _lastIndex == null ? null : _entryAt(_lastIndex!);
    _lastIndex = index;
    final entry = index == null ? null : _entryAt(index);

    final listened = _dailyClock.elapsed;
    _dailyClock.reset();
    final store = QuranListeningStore.instance;
    final previousVerse = previous?.daily == true ? previous!.verse : null;
    final verse = entry?.daily == true ? entry!.verse : null;

    if (verse == null) {
      // Leaving the day's verses for the rest of the playlist.
      if (previousVerse != null && listened > Duration.zero) {
        store.recordPlayback(
          playing: ordinalOfVerse(previousVerse),
          listened: listened,
        );
      }
      return;
    }

    final ordinal = ordinalOfVerse(verse);
    final previousOrdinal = previousVerse == null
        ? null
        : ordinalOfVerse(previousVerse);
    // Played to its end, rather than skipped past.
    final finished =
        previousOrdinal != null &&
            (previousOrdinal + 1 == ordinal ||
                (previousOrdinal == quranVerseTotal && ordinal == 1))
        ? previousOrdinal
        : null;
    store.recordPlayback(
      playing: ordinal,
      listened: listened,
      finished: finished,
    );
    if (finished == quranVerseTotal) {
      showToast(L10n.current.quranDailyKhatmDone);
    }
    if (!_countedDailyRun) {
      _countedDailyRun = true;
      unawaited(
        AnalyticsService.feature(
          'quran_daily_listen',
          label: 'Quran day by day listened',
          parameters: {'verse': verse.toString()},
        ),
      );
    }

    // Only a verse reached by playing on ends the day: one picked by hand is
    // where the reader chose to be.
    if (finished != null && store.state.goalReachedAt(ordinal)) {
      unawaited(_endDailyPortion(index!, verse));
      return;
    }
    unawaited(_extendDailyIfNeeded(index!));
  }

  /// Today's portion is done at [verse]: the playlist moves on past the rest
  /// of the verses or, with nothing after them, pauses on [verse] - which is
  /// where tomorrow starts. Playing on from there is the reader's choice,
  /// and today does not stop again.
  Future<void> _endDailyPortion(int index, VerseKey verse) async {
    final player = _player;
    if (player == null) return;
    QuranListeningStore.instance.markGoalMet();
    var after = -1;
    for (var i = index + 1; i < _queue.length; i++) {
      if (!_queue[i].daily) {
        after = i;
        break;
      }
    }
    final where = localizeDigits(
      '${surahInfoFor(verse.surah)?.displayName ?? ''} $verse',
    ).trim();
    if (after >= 0) {
      await player.seek(Duration.zero, index: after);
      showToast(L10n.current.quranDailyDoneToast(where));
      return;
    }
    await player.pause();
    await player.seek(Duration.zero);
    showToast(
      L10n.current.quranDailyDoneToast(where),
      actionLabel: L10n.current.quranDailyKeepGoing,
      onAction: () {
        if (identical(_player, player)) unawaited(player.play());
      },
    );
  }

  /// Queues the next [dailyWindow] verses once the last few queued come up,
  /// so a day's Quran never runs out mid-listen.
  Future<void> _extendDailyIfNeeded(int index) async {
    final player = _player;
    if (player == null || _extending) return;
    var blockEnd = index;
    while (blockEnd + 1 < _queue.length && _queue[blockEnd + 1].daily) {
      blockEnd++;
    }
    if (blockEnd - index > 8) return;
    final lastVerse = _queue[blockEnd].verse;
    if (lastVerse == null) return;
    final last = ordinalOfVerse(lastVerse);
    final chunk = dailyVerses(last == quranVerseTotal ? 1 : last + 1);
    _extending = true;
    try {
      await player.insertAudioSources(blockEnd + 1, [
        for (final entry in chunk) _sourceFor(entry, ''),
      ]);
      if (!identical(_player, player)) return;
      _queue = List.unmodifiable([
        ..._queue.sublist(0, blockEnd + 1),
        ...chunk,
        ..._queue.sublist(blockEnd + 1),
      ]);
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to queue more of the Quran: $error');
    } finally {
      _extending = false;
    }
  }

  /// Plays zikr [uid]'s recitation on its own, through the same background
  /// queue as a playlist: a play link, Siri or a shortcut asks for one dua,
  /// and it should keep going on the lock screen like any playlist does.
  Future<PlaylistStartResult> playZikr(String uid) {
    return play(
      ZikrPlaylist(
        id: '$singleZikrIdPrefix$uid',
        name: _indexTitle(uid),
        zikrUids: [uid],
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Records which zikr a playlist is actually playing, the first time each
  /// one starts in this run. [play] only says a playlist was started; this is
  /// what says which zikrs people listen to through playlists, including the
  /// ones reached by letting the queue run on or skipping ahead.
  void _countPlayingZikr() {
    final player = _player;
    if (player == null || !player.playing) return;
    final entry = current;
    // Verses are counted by their own events, not as a zikr each.
    if (entry == null || entry.verse != null) return;
    if (!_countedZikrUids.add(entry.zikrUid)) return;
    unawaited(
      AnalyticsService.zikrPlaylistPlay(
        uid: entry.zikrUid,
        title: entry.zikrTitle,
      ),
    );
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

  /// Jumps to [verse] in the queue - a verse tapped in the reader while its
  /// surah plays.
  Future<void> skipToVerse(VerseKey verse) async {
    final index = _queue.indexWhere((entry) => entry.verse == verse);
    if (index >= 0) await skipTo(index);
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
    if (player == null || !canRepeat) return;
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
    _dailyClock.stop();
    _creditDaily();
    _countedDailyRun = false;
    await _disposePlayer();
    _playlist = null;
    _queue = const [];
    notifyListeners();
  }

  Future<void> _disposePlayer() async {
    _stopFollowingSpeed?.call();
    _stopFollowingSpeed = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}
