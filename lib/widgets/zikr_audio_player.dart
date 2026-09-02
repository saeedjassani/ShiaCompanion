import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/zikr_audio_track.dart';
import '../services/analytics_service.dart';

/// Recitation player hosted inside [ZikrActionBar], in place of its action
/// row. It is only built once a reader taps Listen, so the ~95% of readings
/// that never touch audio pay nothing for it.
///
/// duas.org's permission to use their recordings is conditional on credit;
/// that acknowledgement lives on the About page rather than here, so this bar
/// stays focused on playback.
///
/// Playback is streamed, never downloaded: the corpus is about a gigabyte and
/// individual tracks run to 39 MB. On web this works because just_audio drives
/// a plain `<audio>` element, which is exempt from CORS; mp3.duas.org sends no
/// `Access-Control-Allow-Origin`, so anything that read the bytes directly
/// (`fetch`, or an element with `crossOrigin` set) would be blocked.
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
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  ZikrAudioTrack? get _currentTrack =>
      _trackIndex >= 0 && _trackIndex < widget.tracks.length
          ? widget.tracks[_trackIndex]
          : null;

  Future<void> _load() async {
    final player = _player;
    final track = _currentTrack;
    if (player == null || track == null) return;

    try {
      await player.setAudioSource(AudioSource.uri(
        Uri.parse(track.url),
        tag: MediaItem(
          // Unique per zikr+track, not just the URL, so the notification
          // updates correctly if two zikrs ever happened to share a file.
          id: '${widget.zikrUid}#$_trackIndex',
          title: track.label ?? widget.zikrTitle,
          album: widget.zikrTitle,
          artist: 'duas.org',
        ),
      ));
      if (!mounted) return;
      setState(() => _failed = false);
    } catch (error) {
      // A duas.org file that has moved or been removed must not leave a play
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

  Future<void> _selectTrack(int index) async {
    if (index == _trackIndex) return;
    setState(() {
      _trackIndex = index;
      _dragValue = null;
    });
    await _player?.stop();
    await (_loadFuture = _load());
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
                child: Text('Recordings', style: theme.textTheme.titleMedium),
              ),
            ),
            for (var i = 0; i < widget.tracks.length; i++)
              RadioListTile<int>(
                value: i,
                groupValue: _trackIndex,
                title: Text(widget.tracks[i].label ?? 'Track ${i + 1}'),
                onChanged: (value) => Navigator.of(sheetContext).pop(value),
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This recitation is unavailable',
                style: theme.textTheme.bodySmall,
              ),
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
