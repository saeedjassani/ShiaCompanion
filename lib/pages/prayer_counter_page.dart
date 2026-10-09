import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../models/prayer_counter_state.dart';
import '../services/analytics_service.dart';
import '../services/proximity_sensor_service.dart';
import '../theme/shia_colors.dart';
import '../utils/shared_preferences.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/app_toast.dart';

/// The Rakaat counter (docs/DESIGN_SPEC.md, "Tools"; mockups `Rakaat-A`
/// and `Rakaat-B`): the prayer's length, the sensor's state, "Rakaat N of
/// M" in large type with a bar per rakaat and a dot per sajdah, and Undo /
/// Start over. The proximity sensor counts each sajdah where the phone has
/// one; the panel is a button for any it misses.
///
/// While the sensor counts, a few seconds without a touch dims the page to
/// the count alone on black ([dimAfter]); a tap brightens it again.
class PrayerCounterPage extends StatefulWidget {
  const PrayerCounterPage({
    super.key,
    this.proximitySensorService = const ProximitySensorService(),
    this.dimAfter = const Duration(seconds: 6),
  });

  final ProximitySensorService proximitySensorService;

  /// How long the page waits without a touch before dimming.
  final Duration dimAfter;

  @override
  State<PrayerCounterPage> createState() => _PrayerCounterPageState();
}

class _PrayerCounterPageState extends State<PrayerCounterPage>
    with WidgetsBindingObserver {
  static const _totalRakaatKey = 'prayer_counter_total_rakaat';
  static const _completedSajdahsKey = 'prayer_counter_completed_sajdahs';
  static const _sensorDebounce = Duration(milliseconds: 700);

  late PrayerCounterState _counter;
  StreamSubscription<bool>? _proximitySubscription;
  bool? _sensorAvailable;
  bool _sensorEnabled = false;
  bool _sensorNear = false;
  bool _sensorArmed = false;
  bool _resumeSensorWhenActive = false;
  DateTime? _lastSensorCountAt;

  bool _dimmed = false;
  Timer? _dimTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _counter = _loadCounter();
    unawaited(trackScreen('Rakaat Counter Page'));
    unawaited(WakelockPlus.enable());
    unawaited(_checkSensorAvailability());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _resumeSensorWhenActive) {
      _resumeSensorWhenActive = false;
      if (_sensorAvailable == true && !_counter.isComplete) {
        unawaited(_setSensorEnabled(true));
      }
    } else if (state != AppLifecycleState.resumed && _sensorEnabled) {
      _resumeSensorWhenActive = true;
      unawaited(_setSensorEnabled(false));
    }
  }

  PrayerCounterState _loadCounter() {
    if (!SP.isInitialized) {
      return const PrayerCounterState(totalRakaat: 4);
    }

    final savedTotal = SP.prefs.getInt(_totalRakaatKey) ?? 4;
    final totalRakaat = const {2, 3, 4}.contains(savedTotal) ? savedTotal : 4;
    final savedSajdahs = SP.prefs.getInt(_completedSajdahsKey) ?? 0;
    final completedSajdahs = savedSajdahs.clamp(0, totalRakaat * 2);
    final savedCounter = PrayerCounterState(
      totalRakaat: totalRakaat,
      completedSajdahs: completedSajdahs,
    );
    if (savedCounter.isComplete) {
      unawaited(SP.prefs.setInt(_completedSajdahsKey, 0));
      return savedCounter.reset();
    }
    return savedCounter;
  }

  // ---------------------------------------------------------------------------
  // Dim mode
  // ---------------------------------------------------------------------------

  /// Dims only while the sensor counts: counting by hand means touching the
  /// panel after every sajdah, and a tap on the dimmed page only brightens
  /// it. Never under a screen reader, which has no use for a black page.
  bool get _canDim =>
      _sensorEnabled &&
      !_counter.isComplete &&
      !(MediaQuery.maybeAccessibleNavigationOf(context) ?? false);

  /// Starts the wait for dim mode over: on every touch, and whenever what
  /// decides whether the page may dim changes.
  void _restartDimTimer() {
    _dimTimer?.cancel();
    _dimTimer = null;
    if (!mounted || _dimmed || !_canDim) return;
    _dimTimer = Timer(widget.dimAfter, () {
      if (!mounted || !_canDim) return;
      setState(() => _dimmed = true);
    });
  }

  void _brighten() {
    if (_dimmed) setState(() => _dimmed = false);
    _restartDimTimer();
  }

  // ---------------------------------------------------------------------------
  // The sensor
  // ---------------------------------------------------------------------------

  Future<void> _checkSensorAvailability() async {
    final available = await widget.proximitySensorService.isAvailable();
    if (!mounted) return;
    setState(() => _sensorAvailable = available);
    if (available && !_counter.isComplete) {
      await _setSensorEnabled(true);
    }
  }

  Future<void> _setSensorEnabled(bool enabled) async {
    if (enabled && _sensorEnabled) return;

    if (!enabled) {
      final subscription = _proximitySubscription;
      _proximitySubscription = null;
      if (mounted) {
        setState(() {
          _sensorEnabled = false;
          _sensorNear = false;
          _sensorArmed = false;
          _dimmed = false;
        });
        _restartDimTimer();
      }
      await subscription?.cancel();
      return;
    }

    if (_sensorAvailable != true || _counter.isComplete) return;

    setState(() {
      _sensorEnabled = true;
      _sensorNear = false;
      _sensorArmed = false;
    });
    _restartDimTimer();
    _proximitySubscription =
        widget.proximitySensorService.proximityStates.listen(
      _handleProximityState,
      onError: (_) {
        if (!mounted) return;
        unawaited(_setSensorEnabled(false));
        showToast(context.l10n.counterSensorStopped);
      },
    );
  }

  void _handleProximityState(bool isNear) {
    if (!mounted || !_sensorEnabled) return;

    setState(() => _sensorNear = isNear);
    if (!isNear) {
      _sensorArmed = true;
      return;
    }

    final now = DateTime.now();
    final wasRecentlyCounted = _lastSensorCountAt != null &&
        now.difference(_lastSensorCountAt!) < _sensorDebounce;
    if (!_sensorArmed || wasRecentlyCounted || _counter.isComplete) return;

    _sensorArmed = false;
    _lastSensorCountAt = now;
    _recordSajdah();
  }

  // ---------------------------------------------------------------------------
  // Counting
  // ---------------------------------------------------------------------------

  void _recordSajdah() {
    if (_counter.isComplete) return;

    setState(() => _counter = _counter.recordSajdah());
    _saveCounter();
    if (_counter.isComplete) {
      unawaited(AnalyticsService.feature(
        'rakaat_prayer_completed',
        label: 'Rakaat counter completed',
        parameters: {'total_rakaat': _counter.totalRakaat},
      ));
      HapticFeedback.heavyImpact();
      // Bright again for the end of the prayer, so "Prayer complete" and
      // the salawat below can be read.
      setState(() => _dimmed = false);
      unawaited(_setSensorEnabled(false));
      showToastContent(
        const Text(
          'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَآلِ مُحَمَّدٍ وَعَجِّلْ فَرَجَهُمْ وَالْعَنْ أَعْدَاءَهُمْ أَجْمَعِينَ',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _undoSajdah() {
    if (!_counter.hasStarted) return;
    setState(() => _counter = _counter.undoSajdah());
    _saveCounter();
    HapticFeedback.selectionClick();
    if (_sensorAvailable == true && !_sensorEnabled) {
      unawaited(_setSensorEnabled(true));
    }
  }

  void _reset() {
    setState(() => _counter = _counter.reset());
    _saveCounter();
    HapticFeedback.selectionClick();
    if (_sensorAvailable == true && !_sensorEnabled) {
      unawaited(_setSensorEnabled(true));
    }
  }

  Future<void> _changeTotalRakaat(int totalRakaat) async {
    if (totalRakaat == _counter.totalRakaat) return;

    if (_counter.hasStarted) {
      final shouldReset = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.counterStartOverTitle),
              content: Text(context.l10n.counterStartOverBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.counterStartOver),
                ),
              ],
            ),
          ) ??
          false;
      if (!shouldReset || !mounted) return;
    }

    setState(() => _counter = _counter.reset(totalRakaat: totalRakaat));
    _saveCounter();
    if (_sensorAvailable == true && !_sensorEnabled) {
      unawaited(_setSensorEnabled(true));
    }
  }

  void _saveCounter() {
    if (!SP.isInitialized) return;
    unawaited(SP.prefs.setInt(_totalRakaatKey, _counter.totalRakaat));
    unawaited(
      SP.prefs.setInt(_completedSajdahsKey, _counter.completedSajdahs),
    );
  }

  void _showPlacementGuide() {
    final l10n = context.l10n;
    showRevampSheet<void>(
      context,
      title: l10n.counterPhonePlacement,
      builder: (context) {
        final colors = ShiaColors.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(SliverCardList.radius),
                border: Border.all(color: colors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.counterPlacementBody,
                    style: ShiaText.body.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.counterPlacementTest,
                    style: ShiaText.secondary.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (_sensorAvailable == true) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? l10n.counterIphoneNote
                      : l10n.counterAndroidNote,
                  style: ShiaText.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dimTimer?.cancel();
    _proximitySubscription?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final page = Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FillOrScroll(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ToolHeader(title: l10n.counterTitle),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.counterRakaatInPrayer,
                            style: ShiaText.body.copyWith(
                              fontSize: 16,
                              height: 20 / 16,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 168,
                          child: SegmentedSwitcher<int>(
                            segments: const [
                              Segment(2, '2'),
                              Segment(3, '3'),
                              Segment(4, '4'),
                            ],
                            selected: _counter.totalRakaat,
                            onChanged: (total) =>
                                unawaited(_changeTotalRakaat(total)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // The link drops under the pill where the two don't fit
                    // side by side (a large text size, a longer language).
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _sensorPill(context),
                        _PlacementLink(onTap: _showPlacementGuide),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(child: _counterPanel(context)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PageButton(
                            label: l10n.commonUndo,
                            glyph: OutlineGlyph.undo,
                            onPressed: _counter.hasStarted ? _undoSajdah : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PageButton(
                            label: l10n.counterStartOver,
                            glyph: OutlineGlyph.reset,
                            onPressed: _counter.hasStarted ? _reset : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Listener(
      // Every touch on the page puts dim mode off for another few seconds.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restartDimTimer(),
      child: Stack(
        children: [
          ExcludeSemantics(excluding: _dimmed, child: page),
          if (_dimmed)
            Positioned.fill(
              // Fades in; brightening is instant, as it should be for
              // someone who has just touched the screen to see it.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: _DimView(counter: _counter, onBrighten: _brighten),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sensorPill(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final (label, dot) = _counter.isComplete
        ? (l10n.counterComplete, colors.success)
        : _sensorAvailable == null
            ? (l10n.counterCheckingSensor, colors.chevron)
            : _sensorAvailable == false
                ? (l10n.counterNoSensorPill, colors.chevron)
                : _sensorEnabled && _sensorNear
                    ? (l10n.counterSajdahDetected, colors.accent)
                    : _sensorEnabled
                        ? (l10n.counterSensorOnPill, colors.success)
                        : (l10n.counterSensorOffPill, colors.chevron);
    final toggleable = _sensorAvailable == true && !_counter.isComplete;
    final onTap =
        toggleable ? () => unawaited(_setSensorEnabled(!_sensorEnabled)) : null;

    return Semantics(
      button: toggleable,
      toggled: toggleable ? _sensorEnabled : null,
      label: toggleable ? l10n.counterAutomaticSensing : null,
      value: label,
      hint: toggleable ? l10n.counterSensorToggleHint : null,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // 44 to tap, though it draws as the mockup's 34 px pill.
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: ShiaText.caption.copyWith(
                        fontSize: 14,
                        height: 18 / 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _counterPanel(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final complete = _counter.isComplete;
    final hint = complete
        ? l10n.counterCompleteHint
        : _sensorEnabled
            ? l10n.counterMissedHint
            : l10n.counterManualTapHint;

    return Semantics(
      button: !complete,
      label: complete ? l10n.counterPrayerComplete : l10n.counterAddSajdah,
      value: l10n.counterSemanticsValue(_counter.currentRakaat,
          _counter.totalRakaat, _counter.sajdahsInCurrentRakaat),
      hint: complete ? l10n.counterCompleteHint : null,
      excludeSemantics: true,
      onTap: complete ? null : _recordSajdah,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: complete ? null : _recordSajdah,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    // Shrinks rather than overflows on a short screen or
                    // at a large text size.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _CountDisplay(
                        counter: _counter,
                        palette: _CountPalette.of(colors),
                        numberSize: 160,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Phone placement", a link to how to place the phone.
class _PlacementLink extends StatelessWidget {
  const _PlacementLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              child: Text(
                context.l10n.counterPhonePlacement,
                style: ShiaText.caption.copyWith(
                  fontSize: 14,
                  height: 18 / 14,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The colours of a [_CountDisplay]: the theme's on the page, the fixed
/// low-light browns of dim mode on black.
class _CountPalette {
  const _CountPalette({
    required this.number,
    required this.muted,
    required this.done,
    required this.now,
    required this.ahead,
    required this.dotOn,
    required this.dotOff,
    required this.label,
  });

  factory _CountPalette.of(ShiaColors colors) => _CountPalette(
        number: colors.text,
        muted: colors.textMuted,
        done: colors.accent,
        now: Color.lerp(colors.accent, colors.readerDivider, 0.5)!,
        ahead: colors.readerDivider,
        dotOn: colors.accent,
        dotOff: Color.lerp(colors.line, colors.chevron, 0.5)!,
        label: colors.text,
      );

  /// Mockup `Rakaat-B`: nothing brighter than a dim sand on black.
  static const dim = _CountPalette(
    number: Color(0xFFB8A48E),
    muted: Color(0xFF8C7B6B),
    done: Color(0xFF8C7B6B),
    now: Color(0xFF5A4D41),
    ahead: Color(0xFF241E19),
    dotOn: Color(0xFFB8A48E),
    dotOff: Color(0xFF5A4D41),
    label: Color(0xFFB8A48E),
  );

  final Color number;
  final Color muted;
  final Color done;
  final Color now;
  final Color ahead;
  final Color dotOn;
  final Color dotOff;
  final Color label;
}

/// "Rakaat / 3 of 4", a bar per rakaat and the sajdah dots.
class _CountDisplay extends StatelessWidget {
  const _CountDisplay({
    required this.counter,
    required this.palette,
    required this.numberSize,
  });

  final PrayerCounterState counter;
  final _CountPalette palette;
  final double numberSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final complete = counter.isComplete;
    final scale = numberSize / 160;
    final sajdahs = counter.sajdahsInCurrentRakaat;

    Widget dot(bool on) => Container(
          width: 18 * scale,
          height: 18 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? palette.dotOn : null,
            border: on ? null : Border.all(color: palette.dotOff, width: 2),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          complete ? l10n.counterPrayerComplete : l10n.counterRakaatCaption,
          style: TextStyle(
            fontSize: 20 * scale,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        SizedBox(height: 10 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${counter.currentRakaat}',
              style: TextStyle(
                fontSize: numberSize,
                height: 0.94,
                fontWeight: FontWeight.w700,
                letterSpacing: -numberSize / 26,
                color: palette.number,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: 10 * scale),
            Text(
              l10n.counterOfTotal(counter.totalRakaat),
              style: TextStyle(
                fontSize: 28 * scale,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= counter.totalRakaat; i++) ...[
              if (i > 1) SizedBox(width: 8 * scale),
              Container(
                width: 40 * scale,
                height: 8 * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4 * scale),
                  color: complete || i < counter.currentRakaat
                      ? palette.done
                      : i == counter.currentRakaat
                          ? palette.now
                          : palette.ahead,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 28 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot(sajdahs >= 1),
            SizedBox(width: 12 * scale),
            dot(sajdahs >= 2),
            SizedBox(width: 12 * scale),
            Text(
              complete
                  ? l10n.counterAllSajdahsDone
                  : l10n.counterSajdahsOfTwo(sajdahs),
              style: TextStyle(
                fontSize: 22 * scale,
                height: 1.27,
                fontWeight: FontWeight.w600,
                color: palette.label,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dim mode (mockup `Rakaat-B`): the count alone, in dim browns on black.
/// A tap anywhere, or the ×, brightens the page; nothing here counts.
class _DimView extends StatelessWidget {
  const _DimView({required this.counter, required this.onBrighten});

  final PrayerCounterState counter;
  final VoidCallback onBrighten;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const palette = _CountPalette.dim;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Semantics(
        button: true,
        label: l10n.counterDimmedHint,
        value: l10n.counterSemanticsValue(counter.currentRakaat,
            counter.totalRakaat, counter.sajdahsInCurrentRakaat),
        excludeSemantics: true,
        onTap: onBrighten,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBrighten,
          child: Material(
            color: Colors.black,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 16, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Tooltip(
                        message: l10n.counterLeaveDim,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(
                              side: BorderSide(color: Color(0xFF2A241E))),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onBrighten,
                            child: const SizedBox.square(
                              dimension: 44,
                              child: Center(
                                child: OutlineIcon(OutlineGlyph.close,
                                    size: 20,
                                    color: Color(0xFF8C7B6B),
                                    strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _CountDisplay(
                            counter: counter,
                            palette: palette,
                            numberSize: 200,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      l10n.counterDimmedHint,
                      textAlign: TextAlign.center,
                      style: ShiaText.secondary.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
