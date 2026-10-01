import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/azan_playback_service.dart';

/// Pinned banner shown while [AzanPlaybackService] has the full Azan
/// playing, with the manual stop control that was the whole point of moving
/// Azan off a plain notification sound.
///
/// Polls rather than listening to a stream: playback is very often started
/// by a background alarm isolate this widget's isolate has no direct
/// reference to, so a SharedPreferences flag - checked by both sides - is
/// the only state they actually share. The system media notification
/// AzanPlaybackService's player also carries its own pause control, so this
/// is a second, always-visible way to stop it rather than the only one.
class AzanPlayingBanner extends StatefulWidget {
  const AzanPlayingBanner({Key? key}) : super(key: key);

  @override
  State<AzanPlayingBanner> createState() => _AzanPlayingBannerState();
}

class _AzanPlayingBannerState extends State<AzanPlayingBanner> {
  Timer? _poll;
  bool _playing = false;
  bool _paused = false;
  String? _prayerName;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      unawaited(_check());
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final playing = await AzanPlaybackService.isPlaying();
    final prayerName =
        playing ? await AzanPlaybackService.currentPrayerName() : null;
    final paused = playing && await AzanPlaybackService.isPaused();
    if (!mounted) return;
    if (playing != _playing || paused != _paused || prayerName != _prayerName) {
      setState(() {
        _playing = playing;
        _paused = paused;
        _prayerName = prayerName;
      });
    }
  }

  Future<void> _resume() async {
    await AzanPlaybackService.resumeIfPaused();
    // The player reports resuming asynchronously, often from another
    // isolate - give it a moment rather than waiting out the next poll.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _check();
  }

  Future<void> _stop() async {
    await AzanPlaybackService.stopIfPlaying();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_playing) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(
                _paused
                    ? Icons.pause_circle_outline_rounded
                    : Icons.volume_up_rounded,
                color: onContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_prayerName ?? 'Prayer'} Azan '
                  '${_paused ? 'is paused' : 'is playing'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onContainer,
                  ),
                ),
              ),
              if (_paused)
                TextButton(
                  onPressed: _resume,
                  style: TextButton.styleFrom(foregroundColor: onContainer),
                  child: const Text('Resume'),
                ),
              TextButton(
                onPressed: _stop,
                style: TextButton.styleFrom(foregroundColor: onContainer),
                child: const Text('Stop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
