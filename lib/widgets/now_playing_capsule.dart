import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import '../constants.dart' show appNavigatorKey, items;
import '../data/uid_title_data.dart';
import '../l10n/l10n.dart';
import '../pages/playlists_page.dart';
import '../pages/zikr/zikr_page.dart';
import '../services/analytics_service.dart';
import '../services/playlist_audio_service.dart';
import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// "3:12", "1:02:45".
String formatPlaybackTime(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return localizeDigits(hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds');
}

/// Marks a control that floats at the bottom of a page - the tab bar, a
/// find field, the reader's tools, a docked bar - so the [NowPlayingCapsule]
/// can sit just above it rather than on top of it.
///
/// Only the current route's controls count: the tab bar stays mounted under
/// a pushed page, but is not on screen.
class FloatingBottomSlot extends StatefulWidget {
  const FloatingBottomSlot({
    super.key,
    required this.child,
    this.extent,
    this.enabled = true,
  });

  final Widget child;

  /// How far the control reaches up from the bottom of the screen. Null
  /// measures [child], for a bar docked at the very bottom.
  final double? extent;

  /// False while the control is out of frame (the reader's tools hidden).
  final bool enabled;

  /// The highest extent of every control on the current page, 0 for none.
  static final ValueNotifier<double> reserved = ValueNotifier(0);

  static final Map<State<FloatingBottomSlot>, double> _extents = {};
  static bool _publishScheduled = false;

  // Never straight from build or dispose: the capsule listening to
  // [reserved] sits elsewhere in the tree, and may not be marked dirty then.
  static void _publish() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _publishScheduled = false;
      reserved.value = _extents.values.fold(0.0, math.max);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  State<FloatingBottomSlot> createState() => _FloatingBottomSlotState();
}

class _FloatingBottomSlotState extends State<FloatingBottomSlot> {
  void _report() {
    if (!mounted) return;
    final current = ModalRoute.isCurrentOf(context) ?? true;
    double? extent;
    if (current && widget.enabled) {
      extent = widget.extent;
      if (extent == null) {
        final box = context.findRenderObject() as RenderBox?;
        extent = box != null && box.hasSize ? box.size.height : null;
      }
    }
    final before = FloatingBottomSlot._extents[this];
    if (extent == null) {
      FloatingBottomSlot._extents.remove(this);
    } else {
      FloatingBottomSlot._extents[this] = extent;
    }
    if (before != extent) FloatingBottomSlot._publish();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds this slot when its route stops or starts being on top.
    ModalRoute.isCurrentOf(context);
    SchedulerBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }

  @override
  void dispose() {
    if (FloatingBottomSlot._extents.remove(this) != null) {
      FloatingBottomSlot._publish();
    }
    super.dispose();
  }
}

/// Tells the [NowPlayingCapsule] when a sheet, dialog or menu is open over
/// the page, so it gets out of the way rather than covering its buttons.
/// Registered in the app's `navigatorObservers`.
final NowPlayingRouteObserver nowPlayingRouteObserver =
    NowPlayingRouteObserver();

class NowPlayingRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];

  /// Whether the route on top is a sheet, dialog or menu.
  final ValueNotifier<bool> popupOnTop = ValueNotifier(false);

  void _changed() {
    final popup = _routes.isNotEmpty && _routes.last is PopupRoute;
    // A route can be pushed while the tree is building; the capsule above
    // the navigator can't be rebuilt then.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => popupOnTop.value = popup);
    } else {
      popupOnTop.value = popup;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (at >= 0) _routes.removeAt(at);
    if (newRoute != null) {
      _routes.insert(at >= 0 ? at : _routes.length, newRoute);
    }
    _changed();
  }
}

/// The playing playlist, floating as a glass capsule over every page until
/// it is stopped - the way the Azan's controls do (`AzanPlayingBanner`).
/// Mounted once above the navigator, in `MaterialApp.builder`.
///
/// It sits just above the page's own floating control ([FloatingBottomSlot])
/// and steps aside while the keyboard, a sheet or a dialog is up. A tap on
/// the title opens the rest of the controls: the seek bar, previous, repeat
/// and the way back to the playlist.
class NowPlayingCapsule extends StatefulWidget {
  const NowPlayingCapsule({super.key});

  /// The collapsed capsule's height.
  static const double height = 64;

  /// The gap between the capsule and the control below it.
  static const double gap = 10;

  /// What a page adds below its last row while the capsule is up, so the
  /// row can scroll clear of it.
  static const double contentClearance = height + gap;

  /// What [top] depends on, for widgets that keep clear of the capsule.
  static Listenable get layout => Listenable.merge([
        PlaylistAudioService.instance.visible,
        FloatingBottomSlot.reserved,
        nowPlayingRouteObserver.popupOnTop,
      ]);

  static bool _shown(BuildContext context) =>
      PlaylistAudioService.instance.visible.value &&
      !nowPlayingRouteObserver.popupOnTop.value &&
      MediaQuery.viewInsetsOf(context).bottom == 0;

  static double _bottom(BuildContext context) {
    final reserved = FloatingBottomSlot.reserved.value;
    return reserved > 0 ? reserved + gap : floatingBottomOffset(context);
  }

  /// How far the collapsed capsule reaches up from the bottom of the
  /// screen, or 0 while it is hidden: where a toast or the Azan's controls
  /// go to stay clear of it. Listen to [layout] to follow it.
  static double top(BuildContext context) =>
      _shown(context) ? _bottom(context) + height : 0;

  @override
  State<NowPlayingCapsule> createState() => _NowPlayingCapsuleState();
}

class _NowPlayingCapsuleState extends State<NowPlayingCapsule> {
  // An Overlay of its own: this sits above the navigator, so without one
  // there would be nowhere to show a tooltip or the seek bar's thumb.
  late final OverlayEntry _entry = OverlayEntry(builder: _buildEntry);
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    PlaylistAudioService.instance.visible.addListener(_collapseWhenGone);
  }

  @override
  void dispose() {
    PlaylistAudioService.instance.visible.removeListener(_collapseWhenGone);
    super.dispose();
  }

  void _collapseWhenGone() {
    if (!PlaylistAudioService.instance.visible.value && _expanded) {
      _expanded = false;
      _entry.markNeedsBuild();
    }
  }

  void _toggleExpanded() {
    _expanded = !_expanded;
    _entry.markNeedsBuild();
  }

  Future<void> _openPlaylist() async {
    final audio = PlaylistAudioService.instance;
    final id = audio.playlist?.id;
    final navigator = appNavigatorKey.currentState;
    if (id == null || navigator == null) return;
    _expanded = false;
    _entry.markNeedsBuild();
    // A dua started on its own (a play link, Siri) has no playlist page.
    final zikrUid = audio.singleZikrUid;
    await navigator.push(MaterialPageRoute(
      builder: (_) => zikrUid == null
          ? PlaylistDetailPage(playlistId: id)
          : ZikrPage(
              UidTitleData(zikrUid, items[zikrUid]?.toString() ?? zikrUid),
              source: ZikrOpenSource.playlist,
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Overlay(initialEntries: [_entry]),
    );
  }

  Widget _buildEntry(BuildContext context) {
    final audio = PlaylistAudioService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([audio, NowPlayingCapsule.layout]),
      builder: (context, _) {
        final player = audio.player;
        final current = audio.current;
        final shown = NowPlayingCapsule._shown(context) &&
            player != null &&
            current != null;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final duration =
            reduceMotion ? Duration.zero : const Duration(milliseconds: 240);

        return Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: NowPlayingCapsule._bottom(context),
              child: Padding(
                padding: pageGutter(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: floatingControlWidth),
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: shown
                          ? _CapsuleBody(
                              key: const ValueKey('now-playing'),
                              audio: audio,
                              player: player,
                              current: current,
                              expanded: _expanded,
                              onToggleExpanded: _toggleExpanded,
                              onOpenPlaylist: _openPlaylist,
                            )
                          : const SizedBox(
                              key: ValueKey('hidden'),
                              width: double.infinity,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CapsuleBody extends StatelessWidget {
  const _CapsuleBody({
    super.key,
    required this.audio,
    required this.player,
    required this.current,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenPlaylist,
  });

  final PlaylistAudioService audio;
  final AudioPlayer player;
  final PlaylistQueueEntry current;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenPlaylist;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final caption = ShiaText.caption.copyWith(color: colors.textMuted);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final summary = Semantics(
      button: true,
      expanded: expanded,
      onTapHint:
          expanded ? l10n.playlistHideControls : l10n.playlistShowControls,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleExpanded,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200 && !expanded) onToggleExpanded();
          if (velocity > 200 && expanded) onToggleExpanded();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.secondary.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.playlistNowPlayingPosition(
                  audio.playlist?.displayName ?? '',
                  audio.zikrPosition ?? 1,
                  audio.zikrCount,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: caption,
              ),
            ],
          ),
        ),
      ),
    );

    final row = SizedBox(
      height: NowPlayingCapsule.height,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _RingPlayButton(audio: audio, player: player),
          const SizedBox(width: 10),
          Expanded(child: summary),
          IconButton(
            icon: Icon(Icons.skip_next_rounded, color: colors.accent),
            tooltip: l10n.commonNext,
            onPressed: player.hasNext ? audio.next : null,
          ),
          IconButton(
            icon: OutlineIcon(OutlineGlyph.close,
                size: 20, color: colors.textMuted, strokeWidth: 2),
            tooltip: l10n.commonStop,
            onPressed: audio.stop,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    final more = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeekBar(audio: audio, player: player),
          Row(
            children: [
              IconButton(
                icon: OutlineIcon(OutlineGlyph.repeat,
                    size: 22,
                    color: audio.isRepeating ? colors.accent : colors.chevron),
                tooltip: audio.isRepeating
                    ? l10n.playlistRepeatOn
                    : l10n.playlistRepeat,
                isSelected: audio.isRepeating,
                onPressed: audio.toggleRepeat,
              ),
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: colors.accent),
                tooltip: l10n.commonPrevious,
                onPressed: audio.previous,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenPlaylist,
                icon: OutlineIcon(OutlineGlyph.playlist,
                    size: 18, color: colors.accent),
                label: Text(
                  audio.singleZikrUid == null
                      ? l10n.playlistOpenPlaylist
                      : l10n.playlistOpenText,
                  style: ShiaText.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        type: MaterialType.transparency,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(NowPlayingCapsule.height / 2),
          // A fixed-height row can only take so much: past 1.5x, the title
          // and its caption would no longer fit.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row,
                  if (expanded) more,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Play / pause, ringed by how far the recording has got.
class _RingPlayButton extends StatelessWidget {
  const _RingPlayButton({required this.audio, required this.player});

  final PlaylistAudioService audio;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      initialData: player.playerState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final loading = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        final playing = state?.playing ?? false;
        return Tooltip(
          message: playing ? l10n.commonPause : l10n.commonPlay,
          excludeFromSemantics: true,
          child: Semantics(
            button: true,
            label: playing ? l10n.commonPause : l10n.commonPlay,
            excludeSemantics: true,
            onTap: audio.togglePlay,
            child: SizedBox.square(
              dimension: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snapshot) {
                        final total = player.duration?.inMilliseconds ?? 0;
                        final position = snapshot.data?.inMilliseconds ?? 0;
                        return CircularProgressIndicator(
                          value: loading
                              ? null
                              : total <= 0
                                  ? 0
                                  : (position / total).clamp(0.0, 1.0),
                          strokeWidth: 2.5,
                          color: colors.accent,
                          backgroundColor:
                              colors.accent.withValues(alpha: 0.16),
                        );
                      },
                    ),
                  ),
                  Material(
                    color: colors.accent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: audio.togglePlay,
                      child: SizedBox.square(
                        dimension: 38,
                        child: Center(
                          child: OutlineIcon(
                            playing ? OutlineGlyph.pause : OutlineGlyph.play,
                            size: 18,
                            color: colors.onAccent,
                            strokeWidth: 2.2,
                            filled: !playing,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The expanded capsule's seek bar, between the elapsed and total time.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.audio, required this.player});

  final PlaylistAudioService audio;
  final AudioPlayer player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Where the thumb is being dragged, so it doesn't jump back to the
  /// playing position until the seek lands.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final caption = ShiaText.caption.copyWith(color: colors.textMuted);
    final player = widget.player;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final total = duration.inMilliseconds.toDouble();
        final value = _dragValue ??
            (total <= 0
                ? 0.0
                : position.inMilliseconds.clamp(0, total.toInt()).toDouble());
        return Row(
          children: [
            Text(
              formatPlaybackTime(Duration(milliseconds: value.round())),
              style: caption,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: colors.accent,
                  inactiveTrackColor: colors.accent.withValues(alpha: 0.16),
                  thumbColor: colors.accent,
                ),
                child: Slider(
                  max: total <= 0 ? 1 : total,
                  value: total <= 0 ? 0 : value.clamp(0, total),
                  onChanged: total <= 0
                      ? null
                      : (value) => setState(() => _dragValue = value),
                  onChangeEnd: total <= 0
                      ? null
                      : (value) async {
                          await widget.audio
                              .seek(Duration(milliseconds: value.round()));
                          if (mounted) setState(() => _dragValue = null);
                        },
                ),
              ),
            ),
            Text(formatPlaybackTime(duration), style: caption),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}
