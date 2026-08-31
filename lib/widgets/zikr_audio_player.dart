import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/zikr_audio_track.dart';
import '../services/analytics_service.dart';
import '../utils/external_launch.dart';

/// Compact recitation player shown under the app bar on a zikr.
///
/// The audio is hot-linked from duas.org, who allow it on condition of
/// credit, so [_CreditLine] is part of the player itself rather than buried in
/// the about page — it stays on screen whenever the audio is in use.
///
/// Playback is streamed, never downloaded: the corpus is about a gigabyte and
/// individual tracks run to 39 MB. On web this works because just_audio drives
/// a plain `<audio>` element, which is exempt from CORS; mp3.duas.org sends no
/// `Access-Control-Allow-Origin`, so anything that read the bytes directly
/// (`fetch`, or an element with `crossOrigin` set) would be blocked.
class ZikrAudioPlayer extends StatefulWidget {
  final List<ZikrAudioTrack> tracks;
  final String zikrUid;

  const ZikrAudioPlayer({
    Key? key,
    required this.tracks,
    required this.zikrUid,
  }) : super(key: key);

  @override
  State<ZikrAudioPlayer> createState() => _ZikrAudioPlayerState();
}

class _ZikrAudioPlayerState extends State<ZikrAudioPlayer> {
  static const String _creditUrl = 'https://www.duas.org';

  AudioPlayer? _player;
  int _trackIndex = 0;
  bool _failed = false;
  bool _hasCountedPlay = false;
  double? _dragValue;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player?.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ZikrAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An admin edit can swap the track list under a live player.
    if (oldWidget.tracks != widget.tracks) {
      _trackIndex = 0;
      _failed = false;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  Future<void> _load() async {
    final player = _player;
    if (player == null) return;
    if (_trackIndex < 0 || _trackIndex >= widget.tracks.length) return;

    try {
      await player.setUrl(widget.tracks[_trackIndex].url);
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
    await _load();
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
    if (player == null || widget.tracks.isEmpty || _failed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildPlayButton(player),
                Expanded(child: _buildProgress(player, theme)),
              ],
            ),
            if (widget.tracks.length > 1) _buildTrackSelector(theme),
            _CreditLine(onTap: () => launchExternalUri(Uri.parse(_creditUrl))),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(AudioPlayer player) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final waiting = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        if (waiting) {
          return const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final playing = state?.playing ?? false;
        return IconButton(
          iconSize: 32,
          icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          tooltip: playing ? 'Pause recitation' : 'Play recitation',
          onPressed: _togglePlay,
        );
      },
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position),
                      style: theme.textTheme.bodySmall),
                  Text(_formatDuration(duration),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackSelector(ThemeData theme) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final track = widget.tracks[index];
          return ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: Text(track.label ?? 'Track ${index + 1}'),
            selected: index == _trackIndex,
            onSelected: (_) => _selectTrack(index),
          );
        },
      ),
    );
  }
}

/// duas.org grant use of their recordings on condition they are credited.
class _CreditLine extends StatelessWidget {
  final VoidCallback onTap;

  const _CreditLine({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Text(
            'Audio courtesy of duas.org',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
