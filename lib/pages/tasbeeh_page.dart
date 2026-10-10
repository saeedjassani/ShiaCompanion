import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../models/tasbeeh_state.dart';
import '../services/analytics_service.dart';
import '../theme/shia_colors.dart';
import '../utils/shared_preferences.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';

/// Tasbeeh (docs/DESIGN_SPEC.md, "Tools"; mockup `Tasbeeh-A`): a guided
/// Tasbih al-Zahra or a free count. The whole panel is the button; −1, the
/// total and Reset (with an inline confirmation) sit under it, and beep,
/// vibration and the free count's targets are behind the settings button.
class TasbeehPage extends StatefulWidget {
  const TasbeehPage({super.key});

  /// The free count. Was the only count, so it keeps its old key.
  static const String freeCountKey = 'count';
  static const String zahraCountKey = 'tasbeeh_zahra_count';
  static const String modeKey = 'tasbeeh_mode';
  static const String beepKey = 'tasbeeh_beep';
  static const String vibrateKey = 'tasbeeh_vibrate';
  static const String targetsKey = 'tasbeeh_targets';

  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> {
  late TasbeehMode _mode;
  int _zahraCount = 0;
  int _freeCount = 0;
  bool _beep = true;
  bool _vibrate = true;
  List<int> _targets = List.of(defaultFreeTargets);
  bool _confirmingReset = false;
  int _countedThisSession = 0;

  @override
  void initState() {
    super.initState();
    final prefs = SP.prefs;
    _freeCount = prefs.getInt(TasbeehPage.freeCountKey) ?? 0;
    _zahraCount =
        (prefs.getInt(TasbeehPage.zahraCountKey) ?? 0).clamp(0, zahraTotal);
    _mode = switch (prefs.getString(TasbeehPage.modeKey)) {
      'zahra' => TasbeehMode.zahra,
      'free' => TasbeehMode.free,
      // Someone part-way through a count from before Tasbih al-Zahra was
      // offered carries on where they were; everyone else starts guided.
      _ => _freeCount > 0 ? TasbeehMode.free : TasbeehMode.zahra,
    };
    _beep = prefs.getBool(TasbeehPage.beepKey) ?? true;
    _vibrate = prefs.getBool(TasbeehPage.vibrateKey) ?? true;
    final savedTargets = prefs
        .getStringList(TasbeehPage.targetsKey)
        ?.map(int.tryParse)
        .whereType<int>()
        .toList();
    if (savedTargets != null) _targets = savedTargets;
    trackScreen('Tasbeeh Page');
  }

  @override
  void dispose() {
    if (_countedThisSession > 0) {
      AnalyticsService.feature(
        'tasbeeh_session',
        label: 'Tasbeeh counted',
        parameters: {'count': _countedThisSession, 'mode': _mode.name},
      );
    }
    super.dispose();
  }

  int get _count => _mode == TasbeehMode.zahra ? _zahraCount : _freeCount;

  void _setCount(int value) {
    setState(() {
      if (_mode == TasbeehMode.zahra) {
        _zahraCount = value;
      } else {
        _freeCount = value;
      }
    });
    // Every change rather than once on leaving, so a count survives the app
    // being closed from the app switcher.
    unawaited(SP.prefs.setInt(
      _mode == TasbeehMode.zahra
          ? TasbeehPage.zahraCountKey
          : TasbeehPage.freeCountKey,
      value,
    ));
  }

  void _countOne() {
    if (_confirmingReset) setState(() => _confirmingReset = false);
    if (_mode == TasbeehMode.zahra && _zahraCount >= zahraTotal) {
      // "Tap to start again".
      _setCount(0);
      return;
    }
    final next = _count + 1;
    // One event per tap would drown every other feature in the ranking, so
    // the session is summarised once when the page goes away.
    _countedThisSession++;
    final atTarget = _mode == TasbeehMode.zahra
        ? ZahraProgress.isTarget(next)
        : _targets.contains(next);
    if (atTarget) {
      if (_beep) SystemSound.play(SystemSoundType.alert);
      if (_vibrate) HapticFeedback.mediumImpact();
    }
    _setCount(next);
  }

  void _minusOne() {
    if (_count == 0) return;
    _setCount(_count - 1);
  }

  void _reset() {
    setState(() => _confirmingReset = false);
    _setCount(0);
  }

  void _setMode(TasbeehMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _confirmingReset = false;
    });
    unawaited(SP.prefs.setString(TasbeehPage.modeKey, mode.name));
  }

  Future<void> _openSettings() async {
    await showRevampSheet<void>(
      context,
      title: context.l10n.tasbeehSettings,
      builder: (context) => _TasbeehSettings(
        beep: _beep,
        vibrate: _vibrate,
        targets: _targets,
        onBeep: (value) {
          setState(() => _beep = value);
          unawaited(SP.prefs.setBool(TasbeehPage.beepKey, value));
        },
        onVibrate: (value) {
          setState(() => _vibrate = value);
          unawaited(SP.prefs.setBool(TasbeehPage.vibrateKey, value));
        },
        onTargets: (targets) {
          setState(() => _targets = targets);
          unawaited(SP.prefs.setStringList(
              TasbeehPage.targetsKey, [for (final t in targets) '$t']));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final zahra = _mode == TasbeehMode.zahra;

    return Scaffold(
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
                    ToolHeader(
                      title: l10n.tasbeehTitle,
                      action: RoundIconButton(
                        label: l10n.tasbeehSettings,
                        icon: OutlineIcon(OutlineGlyph.sliders,
                            size: 22, color: colors.accent),
                        onPressed: _openSettings,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SegmentedSwitcher<TasbeehMode>(
                      segments: [
                        Segment(TasbeehMode.zahra, l10n.tasbeehModeZahra),
                        Segment(TasbeehMode.free, l10n.tasbeehModeFree),
                      ],
                      selected: _mode,
                      onChanged: _setMode,
                    ),
                    if (zahra) ...[
                      const SizedBox(height: 14),
                      _PhaseBars(progress: ZahraProgress(_zahraCount)),
                    ],
                    const SizedBox(height: 14),
                    Expanded(
                      child: _CountPanel(
                        mode: _mode,
                        count: _count,
                        nextTarget: _beep || _vibrate
                            ? nextFreeTarget(_freeCount, _targets)
                            : null,
                        onTap: _countOne,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _confirmingReset
                        ? _ResetConfirmation(
                            onCancel: () =>
                                setState(() => _confirmingReset = false),
                            onReset: _reset,
                          )
                        : _CounterControls(
                            // A free count's mode is already named in the
                            // switcher above; only Tasbih al-Zahra has a
                            // total to show here.
                            total: zahra
                                ? l10n.tasbeehTotal(_zahraCount, zahraTotal)
                                : null,
                            onMinusOne: _count > 0 ? _minusOne : null,
                            onReset: _count > 0
                                ? () => setState(() => _confirmingReset = true)
                                : null,
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

/// Tasbih al-Zahra's three phrases as bars, the current one's label bold.
class _PhaseBars extends StatelessWidget {
  const _PhaseBars({required this.progress});

  final ZahraProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final phrases = _zahraPhrases(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < zahraPhases.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress.fillOf(i),
                      backgroundColor: colors.readerDivider,
                      color: colors.accent,
                      semanticsLabel: phrases[i],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n
                      .tasbeehPhaseLabel(phrases[i], zahraPhases[i].size),
                  style: ShiaText.caption.copyWith(
                    fontWeight: !progress.isComplete && i == progress.phaseIndex
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: !progress.isComplete && i == progress.phaseIndex
                        ? colors.text
                        : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

List<String> _zahraPhrases(BuildContext context) => [
      context.l10n.tasbeehAllahuAkbar,
      context.l10n.tasbeehAlhamdulillah,
      context.l10n.tasbeehSubhanAllah,
    ];

/// The big panel that counts one on every tap.
class _CountPanel extends StatelessWidget {
  const _CountPanel({
    required this.mode,
    required this.count,
    required this.nextTarget,
    required this.onTap,
  });

  final TasbeehMode mode;
  final int count;

  /// The free count's next target, when it marks them.
  final int? nextTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final zahra = mode == TasbeehMode.zahra;
    final progress = ZahraProgress(zahra ? count : 0);
    final done = zahra && progress.isComplete;
    final phrase = _zahraPhrases(context)[progress.phaseIndex];
    final shown = zahra ? progress.countInPhase : count;
    final ofText = zahra
        ? l10n.tasbeehOf(progress.phase.size)
        : nextTarget == null
            ? l10n.tasbeehNoLimit
            : l10n.tasbeehNextTarget(nextTarget!);

    final Widget content;
    if (done) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            child: OutlineIcon(OutlineGlyph.check,
                size: 34, color: colors.onAccent, strokeWidth: 2.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.tasbeehComplete,
            textAlign: TextAlign.center,
            style: ShiaText.sectionTitle
                .copyWith(fontSize: 24, height: 30 / 24, color: colors.text),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.tasbeehCompleteHint,
            textAlign: TextAlign.center,
            style: ShiaText.body.copyWith(color: colors.textMuted),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (zahra) ...[
            Text(
              progress.phase.arabic,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: arabicFont,
                fontSize: 44,
                height: 72 / 44,
                color: colors.text,
              ),
            ),
            Text(
              phrase,
              style: ShiaText.body.copyWith(
                  fontSize: 18, height: 24 / 18, color: colors.textMuted),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            localizeDigits('$shown', context.l10n),
            style: TextStyle(
              fontSize: 112,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -3,
              color: colors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ofText,
            style: ShiaText.sectionTitle.copyWith(
                height: 26 / 20,
                fontWeight: FontWeight.w600,
                color: colors.textMuted),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: l10n.tasbeehCountOne,
      value: done
          ? l10n.tasbeehComplete
          : zahra
              ? '$phrase, ${localizeDigits('$shown', l10n)} '
                  '${l10n.tasbeehOf(progress.phase.size)}'
              : localizeDigits('$shown', l10n),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    // Shrinks rather than overflows on a short screen or at
                    // a large text size.
                    child: FittedBox(fit: BoxFit.scaleDown, child: content),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tasbeehTapHint,
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

/// −1, the total, and Reset.
class _CounterControls extends StatelessWidget {
  const _CounterControls({
    required this.total,
    required this.onMinusOne,
    required this.onReset,
  });

  final String? total;
  final VoidCallback? onMinusOne;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Semantics(
            label: l10n.tasbeehMinusOne,
            excludeSemantics: true,
            button: true,
            enabled: onMinusOne != null,
            onTap: onMinusOne,
            child: PillButton(label: '−1', onPressed: onMinusOne),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            total ?? '',
            textAlign: TextAlign.center,
            style: ShiaText.secondary.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(width: 10),
        PillButton(
          label: l10n.tasbeehReset,
          glyph: OutlineGlyph.reset,
          onPressed: onReset,
        ),
      ],
    );
  }
}

/// "Start again from 0?" with Cancel and Reset, in place of the controls.
class _ResetConfirmation extends StatelessWidget {
  const _ResetConfirmation({required this.onCancel, required this.onReset});

  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.tasbeehStartAgainQuestion,
              style: ShiaText.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text),
            ),
          ),
          const SizedBox(width: 8),
          PillButton(label: l10n.commonCancel, onPressed: onCancel),
          const SizedBox(width: 8),
          PillButton(
              label: l10n.tasbeehReset, onPressed: onReset, filled: true),
        ],
      ),
    );
  }
}

/// What is behind the settings button: beep and vibration at each target,
/// and the free count's targets.
class _TasbeehSettings extends StatefulWidget {
  const _TasbeehSettings({
    required this.beep,
    required this.vibrate,
    required this.targets,
    required this.onBeep,
    required this.onVibrate,
    required this.onTargets,
  });

  final bool beep;
  final bool vibrate;
  final List<int> targets;
  final ValueChanged<bool> onBeep;
  final ValueChanged<bool> onVibrate;
  final ValueChanged<List<int>> onTargets;

  @override
  State<_TasbeehSettings> createState() => _TasbeehSettingsState();
}

class _TasbeehSettingsState extends State<_TasbeehSettings> {
  static const int _fields = 3;

  late bool _beep = widget.beep;
  late bool _vibrate = widget.vibrate;
  late final List<TextEditingController> _controllers = [
    for (var i = 0; i < _fields; i++)
      TextEditingController(
          text: i < widget.targets.length ? '${widget.targets[i]}' : ''),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _targetsChanged() {
    widget.onTargets([
      for (final controller in _controllers)
        if ((int.tryParse(controller.text.trim()) ?? 0) > 0)
          int.parse(controller.text.trim()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardList(children: [
          CardSwitchRow(
            label: l10n.tasbeehBeepAtTargets,
            value: _beep,
            onChanged: (value) {
              setState(() => _beep = value);
              widget.onBeep(value);
            },
          ),
          CardSwitchRow(
            label: l10n.tasbeehVibrateAtTargets,
            value: _vibrate,
            onChanged: (value) {
              setState(() => _vibrate = value);
              widget.onVibrate(value);
            },
            last: true,
          ),
        ]),
        const SizedBox(height: 18),
        GroupLabel(l10n.tasbeehTargetsLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _fields; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controllers[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  textAlign: TextAlign.center,
                  style: ShiaText.body.copyWith(color: colors.text),
                  onChanged: (_) => _targetsChanged(),
                  decoration: InputDecoration(
                    labelText: l10n.tasbeehTargetNumber(i + 1),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.line),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.tasbeehZahraTargetsNote,
            style: ShiaText.caption.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}
