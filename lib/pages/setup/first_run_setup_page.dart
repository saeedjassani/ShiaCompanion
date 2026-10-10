import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../services/analytics_service.dart';
import '../../services/azaan_opt_in_service.dart';
import '../../services/azan_playback_service.dart';
import '../../services/first_run_setup.dart';
import '../../services/location_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/font_preferences.dart';
import '../../utils/prayer_time_entries.dart';
import '../../utils/shared_preferences.dart';
import '../../utils/sign_in_flow.dart';
import '../../utils/theme_mode.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/prayer_glyph.dart';
import '../../widgets/zikr_reading_preferences.dart';
import '../city_picker.dart';

/// Opens on first-run setup while [showSetup] holds, then on [child] (the
/// app's tab shell) for good. Home is not built until setup is over, so its
/// start-up - deep links, the location refresh, the notification schedule,
/// the synced data - runs once, on what setup chose.
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key, required this.showSetup, required this.child});

  final bool showSetup;
  final Widget child;

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  late bool _showSetup = widget.showSetup;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      child: _showSetup
          ? FirstRunSetupPage(
              onDone: () {
                if (mounted) setState(() => _showSetup = false);
              },
            )
          : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
    );
  }
}

/// First-run setup (docs/DESIGN_SPEC.md, "First-run setup"; mockups
/// Setup-0-welcome … Setup-5-signin): a welcome, then five steps - prayer
/// times, azan, Arabic style, theme, back up.
///
/// Every step can be skipped, and skipping leaves that setting as it was:
/// no location, azan off, the default font and theme. Choices apply as they
/// are made, so the font sample and the whole page follow along. The OS
/// prompts only follow a tap here: "Use my location" asks for location,
/// "Turn on azan" for notifications.
class FirstRunSetupPage extends StatefulWidget {
  const FirstRunSetupPage({
    super.key,
    required this.onDone,
    this.signIn = signInFromButton,
  });

  /// Runs once setup is finished or skipped, and recorded as such.
  final VoidCallback onDone;

  /// Replaced in tests, which have no sign-in to offer.
  final Future<Object?> Function(BuildContext, SignInProvider) signIn;

  /// The steps after the welcome.
  static const int stepCount = 5;

  @override
  State<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends State<FirstRunSetupPage> {
  /// 0 is the welcome; 1 to [FirstRunSetupPage.stepCount] the steps.
  int _step = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('First-run Setup'));
    unawaited(_restoreEarlierChoices());
  }

  /// Setup is offered until it is finished, so an earlier launch may have
  /// got partway; pick up what it chose. Home reads the same preferences
  /// again once it starts.
  Future<void> _restoreEarlierChoices() async {
    if (!SP.isInitialized) return;
    lat ??= SP.prefs.getDouble('lat');
    long ??= SP.prefs.getDouble('long');
    city ??= SP.prefs.getString('city');
    LocationService.instance.restore();
    arabicFontSize = SP.prefs.getDouble('ara_font_size') ?? arabicFontSize;
    arabicFont = await FontPreferences.getSelectedFont() ?? arabicFont;
    if (mounted) setState(() {});
  }

  void _goTo(int step) {
    if (!mounted || _finishing) return;
    setState(() => _step = step);
  }

  void _next() {
    if (_step >= FirstRunSetupPage.stepCount) {
      unawaited(_finish(skipped: false));
    } else {
      _goTo(_step + 1);
    }
  }

  Future<void> _finish({required bool skipped}) async {
    if (_finishing) return;
    _finishing = true;
    // Azan stays off unless the Azan step turned it on; recording that as
    // the answer is what keeps the question from coming back.
    if (!AzaanOptInService.hasBeenAsked) {
      await AzaanOptInService.answer(const []);
    }
    await FirstRunSetup.markDone();
    unawaited(AnalyticsService.feature(
      'first_run_setup',
      label: 'First-run setup',
      parameters: {
        'outcome': skipped ? 'skipped' : 'finished',
        'step': _step,
      },
    ));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget page = switch (_step) {
      0 => _WelcomeStep(
          onStart: () => _goTo(1),
          onSkipAll: () => _finish(skipped: true),
        ),
      1 => _LocationStep(onNext: _next),
      2 => _AzanStep(onNext: _next),
      3 => _FontStep(onNext: _next),
      4 => _ThemeStep(onNext: _next),
      _ => _BackupStep(signIn: widget.signIn, onNext: _next),
    };

    return PopScope(
      // Back goes to the step before; on the welcome it leaves the app, as
      // back on Home does.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        backgroundColor: colors.ground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_step), child: page),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Frame and controls shared by the steps
// ---------------------------------------------------------------------------

/// Unselected dots, the empty tick ring and the outlined buttons' border:
/// a step darker than [ShiaColors.line], for a control rather than a card.
Color _outline(ShiaColors colors) =>
    Color.lerp(colors.line, colors.chevron, 0.35)!;

final TextStyle _titleStyle = ShiaText.largeTitle
    .copyWith(fontSize: 30, height: 36 / 30, letterSpacing: -0.3);

/// One step: "Step 2 of 5" with its dots and Skip at the top, the step's
/// content (scrolling when the text is large), and its buttons at the
/// bottom.
class _StepFrame extends StatelessWidget {
  const _StepFrame({
    this.step,
    this.onSkip,
    required this.children,
    required this.actions,
    this.centred = false,
    this.horizontalPadding = 20,
  });

  /// Null for the welcome, which has no step line.
  final int? step;
  final VoidCallback? onSkip;
  final List<Widget> children;
  final List<Widget> actions;

  /// Centres [children] in the space above the buttons (the welcome,
  /// location and back-up steps); otherwise they start at the top.
  final bool centred;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final step = this.step;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step != null) _StepHeader(step: step, onSkip: onSkip),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 28)
                          .clamp(0, double.infinity)),
                  child: Column(
                    mainAxisAlignment: centred
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            action,
          ],
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, this.onSkip});

  final int step;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final onSkip = this.onSkip;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.setupStepOf(step, FirstRunSetupPage.stepCount),
              style: ShiaText.secondary.copyWith(
                  fontWeight: FontWeight.w600, color: colors.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 1; i <= FirstRunSetupPage.stepCount; i++) ...[
                  if (i > 1) const SizedBox(width: 5),
                  Container(
                    width: i == step ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step ? colors.accent : _outline(colors),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: colors.accent,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: buttonTextStyle(context, ShiaText.body)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(context.l10n.setupSkip),
            ),
        ],
      ),
    );
  }
}

/// The step's heading and the line under it.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final body = this.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: _titleStyle.copyWith(color: colors.text)),
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body,
            style: ShiaText.body
                .copyWith(height: 24 / 17, color: colors.translation),
          ),
        ],
      ],
    );
  }
}

/// The 96 px tinted circle over the location and back-up steps.
class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.glyph, this.size = 48});

  final OutlineGlyph glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: colors.tintedNotice,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: OutlineIcon(glyph,
            size: size, color: colors.accent, strokeWidth: 1.6),
      ),
    );
  }
}

enum _ButtonKind { primary, secondary, quiet }

/// The setup's 56 px buttons: [_ButtonKind.primary] filled in the accent,
/// [_ButtonKind.secondary] outlined on the surface, [_ButtonKind.quiet] text
/// in the accent ("Skip setup").
class _SetupButton extends StatelessWidget {
  const _SetupButton({
    required this.label,
    required this.onPressed,
    this.kind = _ButtonKind.primary,
    this.leading,
    this.busy = false,
    this.height = 56,
    this.background,
    this.foreground,
    this.outlined = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final _ButtonKind kind;
  final Widget? leading;
  final bool busy;
  final double height;

  /// Overrides, for Sign in with Apple's black (white in dark) button.
  final Color? background;
  final Color? foreground;

  /// Whether a [_ButtonKind.secondary] button has its outline.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final primary = kind == _ButtonKind.primary;
    final fg = foreground ??
        switch (kind) {
          _ButtonKind.primary => colors.onAccent,
          _ButtonKind.secondary => colors.text,
          _ButtonKind.quiet => colors.accent,
        };
    final bg = background ??
        switch (kind) {
          _ButtonKind.primary => colors.accent,
          _ButtonKind.secondary => colors.surface,
          _ButtonKind.quiet => Colors.transparent,
        };
    final leading = this.leading;

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: primary ? bg.withValues(alpha: 0.55) : bg,
        disabledForegroundColor: fg.withValues(alpha: primary ? 0.9 : 0.5),
        elevation: 0,
        shape: StadiumBorder(
          side: kind == _ButtonKind.secondary && outlined
              ? BorderSide(color: _outline(colors))
              : BorderSide.none,
        ),
        textStyle: buttonTextStyle(
          context,
          ShiaText.body.copyWith(
            fontSize: 18,
            height: 22 / 18,
            fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else if (leading != null)
            leading,
          if (busy || leading != null) const SizedBox(width: 10),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// A card that is one of several choices: the chosen one outlined in the
/// accent, the rest in the card line.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide(color: colors.accent, width: 2)
              : BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The round tick at a choice card's corner: filled when chosen, an empty
/// ring when not.
class _Tick extends StatelessWidget {
  const _Tick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.accent : null,
        border: selected ? null : Border.all(color: _outline(colors), width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? OutlineIcon(OutlineGlyph.check,
              size: 16, color: colors.onAccent, strokeWidth: 3)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// The steps
// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart, required this.onSkipAll});

  final VoidCallback onStart;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    return _StepFrame(
      centred: true,
      horizontalPadding: 24,
      actions: [
        _SetupButton(label: l10n.setupGetStarted, onPressed: onStart),
        _SetupButton(
          label: l10n.setupSkipAll,
          onPressed: onSkipAll,
          kind: _ButtonKind.quiet,
          height: 48,
        ),
      ],
      children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x402A1E16),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            // The icon file has a transparent margin round its own rounded
            // square; scaled up past it so the shadow has no gap to show in.
            child: OverflowBox(
              maxWidth: 134,
              maxHeight: 134,
              child: Image.asset('assets/logo.png',
                  width: 134, height: 134, excludeFromSemantics: true),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Semantics(
          header: true,
          child: Text(
            l10n.setupWelcomeTitle,
            textAlign: TextAlign.center,
            style: ShiaText.largeTitle.copyWith(color: colors.text),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.setupWelcomeBody,
          textAlign: TextAlign.center,
          style: ShiaText.body
              .copyWith(fontSize: 19, height: 27 / 19, color: colors.text),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.setupWelcomeHint,
          textAlign: TextAlign.center,
          style:
              ShiaText.body.copyWith(height: 24 / 17, color: colors.textMuted),
        ),
      ],
    );
  }
}

class _LocationStep extends StatefulWidget {
  const _LocationStep({required this.onNext});

  final VoidCallback onNext;

  @override
  State<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<_LocationStep> {
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    unawaited(AnalyticsService.feature(
      'device_location_chosen',
      label: 'Device location chosen',
      parameters: {'source': 'setup'},
    ));
    // With context: anything that goes wrong (location off, permission
    // refused) explains itself in a dialog, and the step stays put so the
    // city is still a tap away.
    final found =
        await LocationService.instance.useDeviceLocation(context: context);
    if (!mounted) return;
    setState(() => _locating = false);
    if (found) widget.onNext();
  }

  Future<void> _chooseCity() async {
    final before = LocationService.instance.updatedAt;
    await chooseCityFlow(context);
    if (!mounted) return;
    final location = LocationService.instance;
    if (location.hasLocation && location.updatedAt != before) {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    return _StepFrame(
      step: 1,
      onSkip: _locating ? null : widget.onNext,
      centred: true,
      horizontalPadding: 24,
      actions: [
        _SetupButton(
          label: l10n.setupUseMyLocation,
          onPressed: _useMyLocation,
          busy: _locating,
          leading: OutlineIcon(OutlineGlyph.pin,
              size: 20, color: colors.onAccent, strokeWidth: 2),
        ),
        _SetupButton(
          label: l10n.setupChooseCity,
          onPressed: _locating ? null : _chooseCity,
          kind: _ButtonKind.secondary,
        ),
      ],
      children: [
        const _StepBadge(glyph: OutlineGlyph.pin),
        const SizedBox(height: 24),
        _Heading(title: l10n.setupLocationTitle),
        const SizedBox(height: 16),
        Text(
          l10n.setupLocationBody,
          style: ShiaText.body
              .copyWith(fontSize: 18, height: 26 / 18, color: colors.text),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.setupLocationAlternative,
          style: ShiaText.body
              .copyWith(fontSize: 16, height: 22 / 16, color: colors.textMuted),
        ),
      ],
    );
  }
}

class _AzanStep extends StatefulWidget {
  const _AzanStep({required this.onNext});

  final VoidCallback onNext;

  /// The five prayers the step offers, as the prayer-time code names them.
  static const List<String> prayers = [
    'Fajr',
    'Zuhr',
    'Asr',
    'Maghrib',
    'Isha'
  ];

  @override
  State<_AzanStep> createState() => _AzanStepState();
}

class _AzanStepState extends State<_AzanStep> {
  /// On to start with: the three the app has always suggested.
  final Set<String> _on = {
    for (final prayer in _AzanStep.prayers)
      if (AzaanOptInService.defaultEnabledPrayerKeys
          .contains(notificationPreferenceKeyForPrayer(prayer)))
        prayer,
  };
  bool _samplePlaying = false;
  bool _saving = false;
  Map<String, String> _times = const {};

  @override
  void initState() {
    super.initState();
    _times = _todaysTimes();
  }

  @override
  void dispose() {
    if (_samplePlaying) unawaited(AzanPlaybackService.stopIfPlaying());
    super.dispose();
  }

  /// Today's times at the location from step 1, when it set one.
  static Map<String, String> _todaysTimes() {
    final latitude = lat;
    final longitude = long;
    if (latitude == null || longitude == null) return const {};
    final now = DateTime.now();
    try {
      return {
        for (final entry in buildExtendedPrayerTimeEntries(
          prayerTime: getPrayerTimeObject(),
          date: now,
          latitude: latitude,
          longitude: longitude,
          timeZone: prayerTimeZoneFor(now),
        ))
          entry.name: localizeClockTime(entry.time),
      };
    } catch (e) {
      debugPrint('Setup could not work out prayer times: $e');
      return const {};
    }
  }

  Future<void> _toggleSample() async {
    if (_samplePlaying) {
      await AzanPlaybackService.stopIfPlaying();
      if (mounted) setState(() => _samplePlaying = false);
      return;
    }
    setState(() => _samplePlaying = true);
    try {
      // Plays in the app, so it needs no notification permission yet. Its
      // future ends when the azan does, or when Stop stops it.
      await AzanPlaybackService.playNow(prayerName: _AzanStep.prayers.first);
    } catch (e) {
      debugPrint('Azan sample failed: $e');
    }
    if (mounted) setState(() => _samplePlaying = false);
  }

  Future<void> _answer(bool turnOn) async {
    if (_saving) return;
    setState(() => _saving = true);
    if (_samplePlaying) await AzanPlaybackService.stopIfPlaying();
    if (turnOn) {
      // So the notification permission can be asked straight away, on this
      // tap; Home would otherwise get to it only after setup.
      try {
        await ensureNotificationsPlugin();
      } catch (e) {
        debugPrint('Notifications could not start: $e');
      }
    }
    await AzaanOptInService.answer([
      if (turnOn)
        for (final prayer in _on) notificationPreferenceKeyForPrayer(prayer),
    ]);
    unawaited(AnalyticsService.feature(
      'azaan_opt_in',
      label: 'Azan opt-in',
      parameters: {
        'choice': turnOn ? 'enabled' : 'declined',
        'source': 'setup',
      },
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return _StepFrame(
      step: 2,
      onSkip: _saving ? null : () => _answer(false),
      actions: [
        _SetupButton(
          label: l10n.setupTurnOnAzan,
          onPressed: _on.isEmpty ? null : () => _answer(true),
          busy: _saving,
        ),
        _SetupButton(
          label: l10n.setupNotNow,
          onPressed: _saving ? null : () => _answer(false),
          kind: _ButtonKind.secondary,
        ),
      ],
      children: [
        _Heading(title: l10n.setupAzanTitle, body: l10n.setupAzanBody),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, prayer) in _AzanStep.prayers.indexed)
                _PrayerSwitchRow(
                  prayer: prayer,
                  time: _times[prayer],
                  value: _on.contains(prayer),
                  last: i == _AzanStep.prayers.length - 1,
                  onChanged: (value) => setState(() {
                    value ? _on.add(prayer) : _on.remove(prayer);
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _toggleSample,
              icon: OutlineIcon(
                _samplePlaying ? OutlineGlyph.pause : OutlineGlyph.speaker,
                size: 18,
                color: colors.text,
                strokeWidth: 1.9,
                filled: _samplePlaying,
              ),
              label: Text(
                  _samplePlaying ? l10n.setupStopSample : l10n.setupPlaySample),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: colors.text,
                backgroundColor: colors.surface,
                side: BorderSide(color: _outline(colors)),
                shape: const StadiumBorder(),
                textStyle: buttonTextStyle(context, ShiaText.secondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (isIOS)
              Text(
                l10n.setupAzanIosNote,
                style: ShiaText.caption.copyWith(color: colors.textMuted),
              ),
          ],
        ),
      ],
    );
  }
}

class _PrayerSwitchRow extends StatelessWidget {
  const _PrayerSwitchRow({
    required this.prayer,
    required this.time,
    required this.value,
    required this.onChanged,
    required this.last,
  });

  final String prayer;
  final String? time;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final name = localizedPrayerName(prayer, context.l10n);
    final time = this.time;
    return Semantics(
      label: context.l10n.setupAzanFor(name),
      toggled: value,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 10, 4),
          decoration: BoxDecoration(
            border:
                last ? null : Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              PrayerGlyph(name: prayer, size: 22, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: ShiaText.cardTitle.copyWith(color: colors.text)),
              ),
              if (time != null) ...[
                Text(
                  time.toLowerCase(),
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
                const SizedBox(width: 12),
              ],
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontStep extends StatefulWidget {
  const _FontStep({required this.onNext});

  final VoidCallback onNext;

  /// The mockup's sample: the opening of Dua Kumayl.
  static const String sample =
      'اَللّٰهُمَّ اِنِّىْ اَسْاَلُكَ بِرَحْمَتِكَ الَّتِىْ وَسِعَتْ كُلَّ شَيْءٍ';

  @override
  State<_FontStep> createState() => _FontStepState();
}

class _FontStepState extends State<_FontStep> {
  /// What the step opened on, for Skip to put back.
  late final String _initialFont;
  late final double _initialSize;

  @override
  void initState() {
    super.initState();
    _initialFont = arabicFont;
    _initialSize = arabicFontSize;
  }

  Future<void> _choose(String font) async {
    if (font == arabicFont) return;
    await saveArabicFontChoice(font);
    if (mounted) setState(() {});
  }

  void _step(int direction) {
    final next = (arabicFontSize + 2 * direction)
        .clamp(minArabicFontSize, maxArabicFontSize)
        .toDouble();
    if (next == arabicFontSize) return;
    setArabicFontSizePref(next);
    setState(() {});
  }

  void _continue() {
    if (arabicFontSize != _initialSize) commitArabicFontSize();
    widget.onNext();
  }

  Future<void> _skip() async {
    if (arabicFont != _initialFont) await saveArabicFontChoice(_initialFont);
    if (arabicFontSize != _initialSize) setArabicFontSizePref(_initialSize);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    String hintFor(String font) => font == 'Scheherazade'
        ? l10n.setupFontScheherazadeHint
        : l10n.setupFontQalamHint;

    return _StepFrame(
      step: 3,
      onSkip: _skip,
      actions: [
        _SetupButton(label: l10n.commonContinue, onPressed: _continue),
      ],
      children: [
        _Heading(title: l10n.setupFontTitle, body: l10n.setupFontBody),
        for (final font in FontPreferences.validFonts) ...[
          const SizedBox(height: 14),
          _ChoiceCard(
            selected: font == arabicFont,
            onTap: () => _choose(font),
            semanticLabel:
                '${l10n.readerArabicFontLabel(font)}. ${hintFor(font)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            font,
                            style: ShiaText.cardTitle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.text),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            hintFor(font),
                            style: ShiaText.caption.copyWith(
                                fontSize: 14,
                                height: 18 / 14,
                                color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Tick(selected: font == arabicFont),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _FontStep.sample,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: arabicFontSize,
                    height: 1.9,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(l10n.setupTextSize,
                  style: ShiaText.cardTitle.copyWith(color: colors.text)),
            ),
            _SizeButton(
              text: '${l10n.textSizeLetter}−',
              fontSize: 15,
              label: l10n.readerArabicSmaller,
              onPressed:
                  arabicFontSize > minArabicFontSize ? () => _step(-1) : null,
            ),
            SizedBox(
              width: 48,
              child: Text(
                localizeDigits('${arabicFontSize.toInt()}', context.l10n),
                textAlign: TextAlign.center,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
            _SizeButton(
              text: '${l10n.textSizeLetter}+',
              fontSize: 19,
              label: l10n.readerArabicBigger,
              onPressed:
                  arabicFontSize < maxArabicFontSize ? () => _step(1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.text,
    required this.fontSize,
    required this.label,
    required this.onPressed,
  });

  final String text;
  final double fontSize;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: _outline(colors))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 44,
            child: Center(
              child: Text(
                text,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? colors.text
                      : colors.text.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeStep extends StatefulWidget {
  const _ThemeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  State<_ThemeStep> createState() => _ThemeStepState();
}

class _ThemeStepState extends State<_ThemeStep> {
  /// What the step opened on, for Skip to put back.
  late final ThemeMode _initial;

  @override
  void initState() {
    super.initState();
    _initial = context.read<ThemeModeProvider>().themeMode;
  }

  Future<void> _choose(ThemeMode mode) async {
    final provider = context.read<ThemeModeProvider>();
    if (provider.themeMode == mode) return;
    await provider.setThemeMode(mode);
  }

  void _continue() {
    final mode = context.read<ThemeModeProvider>().themeMode;
    if (mode != _initial) {
      unawaited(AnalyticsService.feature(
        'theme_mode_changed',
        label: 'Theme changed',
        parameters: {'theme_mode': mode.name},
      ));
    }
    widget.onNext();
  }

  Future<void> _skip() async {
    await context.read<ThemeModeProvider>().setThemeMode(_initial);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final mode = context.watch<ThemeModeProvider>().themeMode;

    return _StepFrame(
      step: 4,
      onSkip: _skip,
      actions: [
        _SetupButton(label: l10n.commonContinue, onPressed: _continue),
      ],
      children: [
        _Heading(title: l10n.setupThemeTitle, body: l10n.setupThemeBody),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, choice)
                in [ThemeMode.light, ThemeMode.dark].indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  selected: mode == choice,
                  onTap: () => _choose(choice),
                  semanticLabel: ThemeModeProvider.label(choice, l10n),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _ThemePreview(
                        colors: choice == ThemeMode.dark
                            ? ShiaColors.dark
                            : ShiaColors.light,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            choice == ThemeMode.dark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 18,
                            color: colors.text,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              ThemeModeProvider.label(choice, l10n),
                              style: ShiaText.cardTitle
                                  .copyWith(color: colors.text),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _ChoiceCard(
          selected: mode == ThemeMode.system,
          onTap: () => _choose(ThemeMode.system),
          semanticLabel:
              '${l10n.setupThemeSameAsPhone}. ${l10n.setupThemeSameAsPhoneHint}',
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _outline(colors)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Container(color: ShiaColors.light.ground)),
                    Expanded(child: Container(color: ShiaColors.dark.ground)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.setupThemeSameAsPhone,
                      style: ShiaText.cardTitle.copyWith(
                          fontWeight: FontWeight.w700, color: colors.text),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.setupThemeSameAsPhoneHint,
                      style: ShiaText.caption.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Tick(selected: mode == ThemeMode.system),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small drawing of Home in [colors]: the title, the prayer card, three
/// shortcuts and two lines of text.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.colors});

  final ShiaColors colors;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, Color color) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );
    final faint = Color.lerp(colors.line, colors.chevron, 0.2)!;

    return ExcludeSemantics(
      child: Container(
        width: 112,
        height: 170,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: colors.ground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(60, 8, colors.text),
            const SizedBox(height: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: colors.prayerCard,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: colors.well,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            bar(80, 6, faint),
            const SizedBox(height: 8),
            bar(64, 6, faint),
          ],
        ),
      ),
    );
  }
}

class _BackupStep extends StatefulWidget {
  const _BackupStep({required this.signIn, required this.onNext});

  final Future<Object?> Function(BuildContext, SignInProvider) signIn;
  final VoidCallback onNext;

  @override
  State<_BackupStep> createState() => _BackupStepState();
}

class _BackupStepState extends State<_BackupStep> {
  SignInProvider? _signingIn;

  Future<void> _signIn(SignInProvider provider) async {
    if (_signingIn != null) return;
    setState(() => _signingIn = provider);
    final user = await widget.signIn(context, provider);
    if (!mounted) return;
    setState(() => _signingIn = null);
    if (user != null) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = _signingIn != null;
    // Apple's own guidance: a black button on light grounds, white on dark.
    final appleBackground = dark ? Colors.white : Colors.black;
    final appleForeground = dark ? Colors.black : Colors.white;

    return _StepFrame(
      step: 5,
      centred: true,
      actions: [
        _SetupButton(
          label: l10n.setupContinueWithGoogle,
          onPressed: busy ? null : () => _signIn(SignInProvider.google),
          busy: _signingIn == SignInProvider.google,
          kind: _ButtonKind.secondary,
          height: 54,
          leading: Image.asset('assets/images/google_logo.png',
              width: 20, height: 20, excludeFromSemantics: true),
        ),
        if (appleSignInOffered)
          _SetupButton(
            label: l10n.setupContinueWithApple,
            onPressed: busy ? null : () => _signIn(SignInProvider.apple),
            busy: _signingIn == SignInProvider.apple,
            kind: _ButtonKind.secondary,
            height: 54,
            background: appleBackground,
            foreground: appleForeground,
            outlined: false,
            leading: Image.asset('assets/images/apple_logo.png',
                width: 20,
                height: 20,
                color: appleForeground,
                excludeFromSemantics: true),
          ),
        _SetupButton(
          label: l10n.setupMaybeLater,
          onPressed: busy ? null : widget.onNext,
          kind: _ButtonKind.secondary,
          height: 54,
          background: Colors.transparent,
        ),
      ],
      children: [
        const _StepBadge(glyph: OutlineGlyph.cloudCheck, size: 52),
        const SizedBox(height: 20),
        _Heading(title: l10n.setupBackupTitle),
        const SizedBox(height: 14),
        Text(
          l10n.setupBackupBody,
          style: ShiaText.body
              .copyWith(fontSize: 18, height: 26 / 18, color: colors.text),
        ),
        const SizedBox(height: 14),
        for (final (i, item) in [
          l10n.setupBackupFavorites,
          l10n.setupBackupQuran,
          l10n.setupBackupQaza,
        ].indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              OutlineIcon(OutlineGlyph.check,
                  size: 22, color: colors.success, strokeWidth: 2.2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item,
                    style: ShiaText.body.copyWith(color: colors.text)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
