import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../theme/shia_colors.dart';
import '../utils/shared_preferences.dart';
import 'audio_download_button.dart' show PlayerIconButton;
import 'outline_icon.dart';

/// Where the reader's chosen auto-scroll speed is kept, so the next zikr
/// starts at the pace they settled on.
const String zikrAutoScrollSpeedKey = 'auto_scroll_speed';

const int minAutoScrollSpeed = 1;
const int maxAutoScrollSpeed = 10;
const int defaultAutoScrollSpeed = 4;

/// The Arabic size the speed table is tuned at. The pace scales with the
/// reader's own size, so making the text bigger keeps the same words per
/// minute rather than slowing the reading down.
const double _autoScrollReferenceFontSize = 32;

/// How fast a [speed] step moves the text, in logical pixels a second, with
/// the Arabic drawn at [arabicFontSize].
///
/// Each step is a quarter faster than the one before, so the slow end - a
/// careful recitation - has fine steps and the fast end - skimming - still
/// gets somewhere in ten.
double autoScrollPixelsPerSecond(int speed, {double arabicFontSize = 32}) {
  final step = speed.clamp(minAutoScrollSpeed, maxAutoScrollSpeed) - 1;
  return 8 *
      math.pow(1.25, step).toDouble() *
      (arabicFontSize / _autoScrollReferenceFontSize);
}

/// The reader's auto-scroll: whether it is on, whether it is paused, and
/// how fast. The page owns it and swaps the action capsule's tools for
/// [ZikrAutoScrollControls] while it is [active]; the content viewer listens
/// and moves the open tab's list while it is [running].
///
/// Off unless the reader starts it from the Text & reading sheet, so nobody
/// who does not want it ever sees a control for it.
class ZikrAutoScrollController extends ChangeNotifier {
  bool _active = false;
  bool _paused = false;
  int? _speed;

  /// Shown in the capsule - running or paused.
  bool get active => _active;
  bool get paused => _paused;

  /// Whether the text should be moving now.
  bool get running => _active && !_paused;

  int get speed {
    final stored =
        SP.isInitialized ? SP.prefs.getInt(zikrAutoScrollSpeedKey) : null;
    return _speed ??= (stored ?? defaultAutoScrollSpeed)
        .clamp(minAutoScrollSpeed, maxAutoScrollSpeed);
  }

  double get pixelsPerSecond =>
      autoScrollPixelsPerSecond(speed, arabicFontSize: arabicFontSize);

  void start() {
    if (running) return;
    _active = true;
    _paused = false;
    unawaited(AnalyticsService.feature(
      'zikr_auto_scroll_started',
      label: 'Auto-scroll started',
      parameters: {'speed': '$speed'},
    ));
    notifyListeners();
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _paused = false;
    notifyListeners();
  }

  void togglePause() {
    if (!_active) return;
    _paused = !_paused;
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _paused = true;
    notifyListeners();
  }

  /// The text has run out: stays in the capsule, paused, so the reader can
  /// swipe to the next part and carry on, or close it.
  void pauseAtEnd() => pause();

  bool get canGoFaster => speed < maxAutoScrollSpeed;
  bool get canGoSlower => speed > minAutoScrollSpeed;

  void faster() => _setSpeed(speed + 1);
  void slower() => _setSpeed(speed - 1);

  void _setSpeed(int value) {
    final next = value.clamp(minAutoScrollSpeed, maxAutoScrollSpeed);
    if (next == speed) return;
    _speed = next;
    if (SP.isInitialized) {
      unawaited(SP.prefs.setInt(zikrAutoScrollSpeedKey, next));
    }
    notifyListeners();
  }
}

/// What the action capsule holds while auto-scroll is on, in place of its
/// tools: play/pause, the speed with a step down and up either side, and
/// close. Same height as the tools, so swapping never moves the text.
class ZikrAutoScrollControls extends StatelessWidget {
  const ZikrAutoScrollControls({super.key, required this.controller});

  final ZikrAutoScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final colors = ShiaColors.of(context);
        final l10n = context.l10n;
        final playLabel =
            controller.paused ? l10n.autoScrollResume : l10n.autoScrollPause;
        Color tint(bool enabled) =>
            enabled ? colors.accent : colors.accent.withValues(alpha: 0.38);
        return Row(
          children: [
            Tooltip(
              message: playLabel,
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                label: playLabel,
                excludeSemantics: true,
                onTap: controller.togglePause,
                child: Material(
                  color: colors.accent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: controller.togglePause,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: OutlineIcon(
                          controller.paused
                              ? OutlineGlyph.play
                              : OutlineGlyph.pause,
                          size: 22,
                          color: colors.onAccent,
                          strokeWidth: 2,
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.readerAutoScroll,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.3),
                    style: ShiaText.caption.copyWith(
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    controller.paused && controller.active
                        ? l10n.autoScrollPaused
                        : l10n.autoScrollSpeed(controller.speed),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.3),
                    style: ShiaText.caption.copyWith(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            PlayerIconButton(
              label: l10n.autoScrollSlower,
              icon: OutlineIcon(OutlineGlyph.minus,
                  size: 20,
                  color: tint(controller.canGoSlower),
                  strokeWidth: 2),
              onPressed: controller.canGoSlower ? controller.slower : null,
            ),
            PlayerIconButton(
              label: l10n.autoScrollFaster,
              icon: OutlineIcon(OutlineGlyph.plus,
                  size: 20,
                  color: tint(controller.canGoFaster),
                  strokeWidth: 2),
              onPressed: controller.canGoFaster ? controller.faster : null,
            ),
            PlayerIconButton(
              label: l10n.autoScrollStop,
              icon: OutlineIcon(OutlineGlyph.close,
                  size: 20, color: colors.textMuted, strokeWidth: 2),
              onPressed: controller.stop,
            ),
          ],
        );
      },
    );
  }
}
