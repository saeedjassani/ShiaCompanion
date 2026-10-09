import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/azan_playback_service.dart';
import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// Floating glass capsule shown while [AzanPlaybackService] has the Azan
/// playing or paused, with pause/resume and stop. Mounted once above the
/// navigator (see `MaterialApp.builder`), so it stays on screen across pages
/// until the Azan is stopped.
///
/// Polls rather than listening to a stream: playback is very often started
/// by a background alarm isolate this widget's isolate has no direct
/// reference to, so a SharedPreferences flag - checked by both sides - is
/// the only state they actually share. The system media notification
/// AzanPlaybackService's player also carries its own pause control, so this
/// is a second, always-visible way to steer it rather than the only one.
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
    unawaited(_check());
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
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

  Future<void> _togglePause() async {
    if (_paused) {
      await AzanPlaybackService.resumeIfPaused();
    } else {
      await AzanPlaybackService.pauseIfPlaying();
    }
    // The player reports the change asynchronously, often from another
    // isolate - give it a moment rather than waiting out the next poll.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _check();
  }

  Future<void> _stop() async {
    await AzanPlaybackService.stopIfPlaying();
    await _check();
  }

  String _prayerLabel(BuildContext context) => _prayerName == null
      ? context.l10n.azanPrayerFallback
      : localizedPrayerName(_prayerName!, context.l10n);

  @override
  Widget build(BuildContext context) {
    if (!_playing) return const SizedBox.shrink();

    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    // Clear of the tab bar or a find field (62 px tall) wherever they float,
    // and of a toast above them.
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        floatingBottomOffset(context) +
        62 +
        12 +
        64;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Material(
                type: MaterialType.transparency,
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(26),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: 20, end: 6, top: 4, bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _paused
                                  ? l10n.azanPaused(_prayerLabel(context))
                                  : l10n.azanPlaying(_prayerLabel(context)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ShiaText.secondary.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Semantics(
                              label: _paused
                                  ? l10n.playlistResume
                                  : l10n.commonPause,
                              excludeSemantics: true,
                              button: true,
                              child: IconButton(
                                icon: OutlineIcon(
                                  _paused
                                      ? OutlineGlyph.play
                                      : OutlineGlyph.pause,
                                  size: 22,
                                  color: colors.accent,
                                ),
                                // No tooltip: this sits above the navigator,
                                // where there is no Overlay to show one in.
                                // (Hover/long-press would assert.)
                                onPressed: _togglePause,
                              )),
                          Semantics(
                              label: l10n.commonStop,
                              excludeSemantics: true,
                              button: true,
                              child: IconButton(
                                icon: OutlineIcon(
                                  OutlineGlyph.close,
                                  size: 20,
                                  color: colors.textMuted,
                                  strokeWidth: 2,
                                ),
                                onPressed: _stop,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
