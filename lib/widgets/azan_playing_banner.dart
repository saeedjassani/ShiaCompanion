import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/l10n.dart';
import '../services/azan_playback_service.dart';
import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'now_playing_capsule.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// Floating glass capsule shown while [AzanPlaybackService] has the Azan
/// playing or paused, with pause/resume and stop. Mounted once above the
/// navigator (see `MaterialApp.builder`), so it stays on screen across pages
/// until the Azan is stopped.
///
/// Polls rather than listening to a stream: playback is very often started
/// outside this isolate - by Android's native player at prayer time - and
/// AzanPlaybackService answers from wherever it is really playing. The
/// playback notification also carries its own pause and stop, so this is a
/// second, always-visible way to steer it rather than the only one.
///
/// It sits just above the page's own floating control ([FloatingBottomSlot])
/// and a playing playlist's capsule; a toast goes above it ([top]).
class AzanPlayingBanner extends StatefulWidget {
  const AzanPlayingBanner({Key? key}) : super(key: key);

  /// How far the banner reaches up from the bottom of the screen, or 0
  /// while it is hidden: where a toast goes to stay clear of it.
  static final ValueNotifier<double> top = ValueNotifier(0);

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
    AzanPlayingBanner.top.value = 0;
    super.dispose();
  }

  // Never straight from build: a toast listening to [AzanPlayingBanner.top]
  // sits elsewhere in the tree, and may not be marked dirty then.
  void _publishTop(double value) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) AzanPlayingBanner.top.value = value;
    });
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
    if (!_playing) {
      _publishTop(0);
      return const SizedBox.shrink();
    }

    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // Just above the page's floating control - the tab bar, a find field,
    // the reader's tools - or, with the keyboard up, above a find field
    // (62 px tall) riding on it. Above a playing playlist's capsule too.
    return ListenableBuilder(
      listenable: NowPlayingCapsule.layout,
      builder: (context, child) {
        final reserved = FloatingBottomSlot.reserved.value;
        final base = keyboard > 0
            ? keyboard + floatingBottomOffset(context) + 62 + 12
            : reserved > 0
                ? reserved + NowPlayingCapsule.gap
                : floatingBottomOffset(context);
        final bottom = math.max(
            base, NowPlayingCapsule.top(context) + NowPlayingCapsule.gap);
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: _ReportHeight(
            onHeight: (height) => _publishTop(bottom + height),
            child: child!,
          ),
        );
      },
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

/// Reports [child]'s laid-out height after each frame it builds in.
class _ReportHeight extends StatelessWidget {
  const _ReportHeight({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) onHeight(box.size.height);
    });
    return child;
  }
}
