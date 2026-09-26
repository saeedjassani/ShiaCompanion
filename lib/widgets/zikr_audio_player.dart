import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../constants.dart';
import '../models/zikr_audio_track.dart';
import '../services/analytics_service.dart';
import '../services/audio_download_store.dart';
import '../services/exclusive_audio.dart';
import '../utils/network_utils.dart';
import '../pages/playlists_page.dart';
import 'audio_download_button.dart';

/// Recitation player hosted inside [ZikrActionBar], in place of its action
/// row. It is only built once a reader taps Listen, so the ~95% of readings
/// that never touch audio pay nothing for it.
///
/// Many recordings come from duas.org, whose permission is conditional on
/// credit; that acknowledgement lives on the About page rather than here, so
/// this bar stays focused on playback.
///
/// Playback is streamed from the app's R2 bucket unless the reader has saved
/// the recitation for offline listening (the download button here, or a
/// playlist's Download all - see [AudioDownloadStore]): the corpus is about a
/// gigabyte and individual tracks run to 39 MB, so nothing is saved
/// unasked. Streaming works on web, where nothing can be saved, because just_audio drives a plain `<audio>` element, which is exempt
/// from CORS, so the bucket needs no `Access-Control-Allow-Origin` - anything
/// that read the bytes directly (`fetch`, or an element with `crossOrigin`
/// set) would need one.
///
/// Each track carries a [MediaItem] tag so just_audio_background can show a
/// lock-screen/notification control and keep playing once the app is
/// backgrounded - the point of a player at all for something like Dua Kumayl,
/// which runs half an hour.
class ZikrAudioPlayer extends StatefulWidget {
  final List<ZikrAudioTrack> tracks;
  final String zikrUid;
  final String zikrTitle;

  /// Dismisses the player and hands the bar back to the action row. Disposing
  /// this widget stops playback, so closing is also how a reader stops.
  final VoidCallback onClose;

  const ZikrAudioPlayer({
    Key? key,
    required this.tracks,
    required this.zikrUid,
    required this.zikrTitle,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ZikrAudioPlayer> createState() => _ZikrAudioPlayerState();
}

class _ZikrAudioPlayerState extends State<ZikrAudioPlayer> {
  AudioPlayer? _player;
  int _trackIndex = 0;
  bool _failed = false;
  bool _hasCountedPlay = false;
  double? _dragValue;
  StreamSubscription<PlayerState>? _stateSub;

  // setAudioSource is what attaches the MediaItem tag (the zikr/track title)
  // that the notification and lock screen read. _togglePlay awaits this so a
  // tap on a page that just opened can never start playback - and so the
  // foreground-service notification - before that title is attached; without
  // it, Android has nothing to show but the notification channel's generic
  // name until the load catches up.
  Future<void> _loadFuture = Future.value();

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player?.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadFuture = _load();
    // Tapping the headphones icon in the action bar is what mounts this
    // widget at all, so that tap should start the recitation, not just open
    // a paused player that needs a second tap.
    unawaited(_togglePlay());
  }

  @override
  void didUpdateWidget(covariant ZikrAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An admin edit can swap the track list under a live player.
    if (oldWidget.tracks != widget.tracks) {
      _trackIndex = 0;
      _failed = false;
      _loadFuture = _load();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    ExclusiveAudio.relinquish(this);
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  /// Called when a playlist starts while this page's player is alive: only
  /// one player may exist at a time, so this one goes and the bar closes.
  Future<void> _releaseToOtherPlayer() async {
    await _stateSub?.cancel();
    _stateSub = null;
    final player = _player;
    _player = null;
    await player?.dispose();
    if (mounted) widget.onClose();
  }

  ZikrAudioTrack? get _currentTrack =>
      _trackIndex >= 0 && _trackIndex < widget.tracks.length
          ? widget.tracks[_trackIndex]
          : null;

  Future<void> _load() async {
    final track = _currentTrack;
    if (_player == null || track == null) return;

    // A playlist playing in the background owns the one player the app is
    // allowed; it has to be gone before this one loads.
    await ExclusiveAudio.claim(this, _releaseToOtherPlayer);
    await AudioDownloadStore.instance.load();
    final player = _player;
    if (player == null) return;

    try {
      await player.setAudioSource(AudioSource.uri(
        AudioDownloadStore.instance.sourceUri(track),
        tag: MediaItem(
          // Unique per zikr+track, not just the URL, so the notification
          // updates correctly if two zikrs ever happened to share a file.
          id: '${widget.zikrUid}#$_trackIndex',
          title: track.label ?? widget.zikrTitle,
          album: widget.zikrTitle,
          artist: track.artist,
        ),
      ));
      if (!mounted) return;
      setState(() => _failed = false);
    } catch (error) {
      // A recording that has moved or been removed must not leave a play
      // button that does nothing, so the player removes itself instead.
      debugPrint('Zikr audio failed to load: $error');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;

    if (player.playing) {
      await player.pause();
      return;
    }

    await _loadFuture;
    if (!mounted || _failed) return;

    // Restart rather than no-op when the track has run to the end.
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    if (!_hasCountedPlay) {
      _hasCountedPlay = true;
      unawaited(AnalyticsService.feature(
        'zikr_audio_play',
        label: 'Zikr audio played',
        parameters: {'zikr_uid': widget.zikrUid},
      ));
    }
    await player.play();
  }

  Future<void> _retry() async {
    setState(() => _failed = false);
    await (_loadFuture = _load());
    if (mounted && !_failed) unawaited(_togglePlay());
  }

  Future<void> _selectTrack(int index) async {
    if (index == _trackIndex) return;
    final wasPlaying = _player?.playing ?? false;
    setState(() {
      _trackIndex = index;
      _dragValue = null;
    });
    await _player?.stop();
    await (_loadFuture = _load());
    // Switching tracks mid-recitation should carry the "playing" state
    // across, the same as choosing a track was never a pause action.
    if (wasPlaying) unawaited(_togglePlay());
  }

  Future<void> _showTrackPicker() async {
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Audio list', style: theme.textTheme.titleMedium),
              ),
            ),
            // A ListTile with a trailing check rather than RadioListTile:
            // the radio's groupValue/onChanged pair is deprecated in favour
            // of a RadioGroup ancestor, and picking a track is a one-shot
            // choice that closes the sheet, not a form control to be read
            // back later.
            for (var i = 0; i < widget.tracks.length; i++)
              ListTile(
                title: Text(widget.tracks[i].label ?? 'Track ${i + 1}'),
                subtitle:
                    AudioDownloadStore.instance.isDownloaded(widget.tracks[i])
                        ? const Text('Downloaded')
                        : null,
                trailing: i == _trackIndex
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                selected: i == _trackIndex,
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await _selectTrack(selected);
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null || widget.tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // A track that will not load leaves the bar in place but says so, rather
    // than vanishing: the reader asked for audio and deserves an answer.
    // Closing returns them to the action row.
    if (_failed) {
      // Offline with nothing saved is the common case, and one the reader can
      // fix - so it says so, rather than implying the recording is gone.
      final track = _currentTrack;
      final offline = !NetworkUtils().isOnline &&
          track != null &&
          !AudioDownloadStore.instance.isDownloaded(track);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        child: Row(
          children: [
            Icon(offline ? Icons.cloud_off_rounded : Icons.error_outline,
                size: 20, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offline
                    ? "You're offline and this recitation isn't downloaded"
                    : "This recitation couldn't be loaded",
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Try again',
              onPressed: _retry,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close player',
              onPressed: widget.onClose,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPlayButton(player, colorScheme),
          const SizedBox(width: 4),
          Expanded(child: _buildBody(player, theme)),
          // Playlists are dark-launched to admins with their home tile.
          if (isUserAdmin)
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Add to playlist',
              onPressed: () => showAddToPlaylistSheet(
                context,
                zikrUid: widget.zikrUid,
                zikrTitle: widget.zikrTitle,
              ),
            ),
          if (AudioDownloadStore.isSupported)
            AudioDownloadButton(
              tracks: widget.tracks,
              label: widget.zikrTitle,
            ),
          if (widget.tracks.length > 1)
            IconButton(
              icon: const Icon(Icons.playlist_play),
              tooltip: 'Choose recording',
              onPressed: _showTrackPicker,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close player',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(AudioPlayer player, ColorScheme colorScheme) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final waiting = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        if (waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }
        final playing = state?.playing ?? false;
        return IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            padding: const EdgeInsets.all(10),
          ),
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28),
          tooltip: playing ? 'Pause recitation' : 'Play recitation',
          onPressed: _togglePlay,
        );
      },
    );
  }

  Widget _buildBody(AudioPlayer player, ThemeData theme) {
    final track = _currentTrack;
    final label = widget.tracks.length > 1
        ? (track?.label ?? 'Recitation')
        : 'Recitation audio';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _buildProgress(player, theme),
      ],
    );
  }

  Widget _buildProgress(AudioPlayer player, ThemeData theme) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final totalMs = duration.inMilliseconds.toDouble();
        final positionMs = position.inMilliseconds
            .clamp(0, duration.inMilliseconds)
            .toDouble();

        return Row(
          children: [
            Text(
              _formatDuration(
                  Duration(milliseconds: (_dragValue ?? positionMs).round())),
              style: theme.textTheme.bodySmall,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  min: 0,
                  // A zero max would make the Slider assert before duration
                  // arrives, which is a frame or two after the first build.
                  max: totalMs <= 0 ? 1 : totalMs,
                  value: totalMs <= 0 ? 0 : (_dragValue ?? positionMs),
                  onChanged: totalMs <= 0
                      ? null
                      : (value) => setState(() => _dragValue = value),
                  onChangeEnd: totalMs <= 0
                      ? null
                      : (value) {
                          _player?.seek(Duration(milliseconds: value.round()));
                          setState(() => _dragValue = null);
                        },
                ),
              ),
            ),
            Text(_formatDuration(duration), style: theme.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}
