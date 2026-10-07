import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data/holy_sites.dart';
import '../models/compass_reading.dart';
import '../services/analytics_service.dart';
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';
import '../utils/geomagnetism.dart';
import '../utils/shared_preferences.dart';
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/page_chrome.dart';
import '../widgets/qibla_compass_dial.dart';
import '../widgets/responsive_content.dart' show ScreenClass;
import '../l10n/l10n.dart';
import 'city_picker.dart';

/// A real compass, pointed at the Kaaba or at any of the shrines in
/// [allHolySites].
///
/// This replaces a web view around a third-party qibla page. The arithmetic was
/// never the hard part — [qiblaBearingDegrees] already existed for the flight
/// screen — so what the web view was really buying was the sensor plumbing,
/// and that is what the three pieces below provide: a heading from
/// [CompassSource], a declination correction from [magneticDeclinationDegrees]
/// so magnetic readings can be compared against true bearings, and a dial to
/// draw the result on.
class QiblaFinder extends StatefulWidget {
  const QiblaFinder({super.key, this.compassSource});

  /// Injected by tests, which have no magnetometer to read.
  final CompassSource? compassSource;

  @override
  State<QiblaFinder> createState() => _QiblaFinderState();
}

/// What the compass is doing, and therefore what the screen has to say about it.
enum _CompassStatus {
  /// Listening, but nothing has arrived yet.
  waiting,

  /// Readings are flowing.
  live,

  /// iOS Safari, waiting for the user to tap and grant sensor access.
  permissionRequired,

  /// Asked and refused.
  permissionDenied,

  /// No compass here — desktop, or a phone with no magnetometer.
  unavailable,
}

class _QiblaFinderState extends State<QiblaFinder> {
  /// Key the chosen destination is persisted under. Ids, not names, so a
  /// reworded entry does not silently reset everybody's choice.
  static const String _targetPreferenceKey = 'qibla_target_site';

  /// How long to wait for a first reading before concluding there is no
  /// compass. Long enough for a cold magnetometer on a slow phone, short
  /// enough that a desktop user is not left staring at a spinner.
  static const Duration _firstReadingGrace = Duration(seconds: 4);

  /// Within this many degrees of the target counts as facing it. Tighter than
  /// this and the readout would flicker on ordinary hand tremor; looser and it
  /// would claim success while visibly off.
  static const double _alignmentToleranceDegrees = 4.0;

  /// Fraction of each new reading folded into the displayed heading. The
  /// sensor is noisy at rest and this is a cheap low-pass — high enough to
  /// still feel immediate when the user turns.
  static const double _smoothing = 0.25;

  late final CompassSource _compass;
  final LocationService _location = LocationService.instance;

  /// Heading in degrees clockwise from *true* north, already smoothed.
  ///
  /// A notifier rather than state because readings arrive around 30 times a
  /// second: this way the dial and the readout repaint and the rest of the
  /// page — cards, picker, notices — does not.
  final ValueNotifier<double> _heading = ValueNotifier<double>(0);

  StreamSubscription<CompassReading>? _subscription;
  Timer? _firstReadingTimer;
  _CompassStatus _status = _CompassStatus.waiting;
  double? _accuracyDegrees;
  bool _hasHeading = false;
  bool _wasAligned = false;

  HolySite _target = kaaba;

  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Qibla Finder'));
    _compass = widget.compassSource ?? const PlatformCompassSource();
    _target = holySiteById(
      SP.isInitialized ? SP.prefs.getString(_targetPreferenceKey) : null,
    );
    _location.addListener(_onLocationChanged);
    // Quietly, with no dialogs: the screen has plenty to show while this runs,
    // and an unprompted permission sheet on open is hostile.
    unawaited(_location.refreshIfStale());
    _start();
  }

  @override
  void dispose() {
    _firstReadingTimer?.cancel();
    unawaited(_subscription?.cancel());
    _location.removeListener(_onLocationChanged);
    _heading.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    // Coordinates move the target bearing and the declination, both of which
    // are read during build.
    if (mounted) setState(() {});
  }

  void _start() {
    if (_compass.requiresPermission) {
      setState(() => _status = _CompassStatus.permissionRequired);
      return;
    }
    _listen();
  }

  void _listen() {
    final stream = _compass.open();
    if (stream == null) {
      setState(() => _status = _CompassStatus.unavailable);
      return;
    }

    setState(() => _status = _CompassStatus.waiting);
    _subscription = stream.listen(_onReading, onError: (Object _) {});
    _firstReadingTimer?.cancel();
    _firstReadingTimer = Timer(_firstReadingGrace, () {
      if (!mounted || _hasHeading) return;
      setState(() => _status = _CompassStatus.unavailable);
    });
  }

  Future<void> _grantPermission() async {
    final granted = await _compass.requestPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() => _status = _CompassStatus.permissionDenied);
      return;
    }
    _listen();
  }

  void _onReading(CompassReading reading) {
    final trueHeading = reading.reference == NorthReference.geographic
        ? reading.headingDegrees
        : normalizeBearing(reading.headingDegrees + _declination);

    if (!_hasHeading) {
      _heading.value = trueHeading;
    } else {
      // Interpolate along the shortest arc, so a reading that crosses north
      // does not send the dial the long way round through south.
      final step = relativeBearingDegrees(_heading.value, trueHeading);
      _heading.value = normalizeBearing(_heading.value + step * _smoothing);
    }

    final accuracyChanged = _accuracyDegrees != reading.accuracyDegrees;
    if (!_hasHeading || _status != _CompassStatus.live || accuracyChanged) {
      setState(() {
        _hasHeading = true;
        _status = _CompassStatus.live;
        _accuracyDegrees = reading.accuracyDegrees;
      });
    }

    _reportAlignment();
  }

  /// One short buzz the moment the needle lines up, so the phone can be held
  /// at prayer height rather than stared at.
  void _reportAlignment() {
    final bearing = _targetBearing;
    if (bearing == null) return;

    final aligned = relativeBearingDegrees(_heading.value, bearing).abs() <=
        _alignmentToleranceDegrees;
    if (aligned == _wasAligned) return;
    _wasAligned = aligned;
    if (aligned && !kIsWeb) unawaited(HapticFeedback.mediumImpact());
  }

  GeoPoint? get _here {
    final latitude = lat;
    final longitude = long;
    if (latitude == null || longitude == null) return null;
    return GeoPoint(latitude, longitude);
  }

  /// Local magnetic declination, or zero when we have nowhere to evaluate it.
  /// Zero is also the honest answer in that case: with no coordinates there is
  /// no target bearing either, so nothing is being compared against anything.
  double get _declination {
    final here = _here;
    return here == null ? 0 : magneticDeclinationDegrees(here);
  }

  double? get _targetBearing {
    final here = _here;
    return here == null ? null : initialBearingDegrees(here, _target.location);
  }

  double? get _qiblaBearing {
    final here = _here;
    if (here == null || _target.id == kaaba.id) return null;
    return qiblaBearingDegrees(here);
  }

  double? get _distanceKm {
    final here = _here;
    return here == null ? null : greatCircleDistanceKm(here, _target.location);
  }

  bool get _isLive => _status == _CompassStatus.live;

  Future<void> _pickTarget() async {
    final chosen = await showRevampSheet<HolySite>(
      context,
      title: context.l10n.qiblaPointTowards,
      builder: (context) => _HolySitePicker(selected: _target, from: _here),
    );
    if (chosen == null || !mounted) return;

    setState(() {
      _target = chosen;
      // The old target's alignment says nothing about the new one, and leaving
      // it set would swallow the buzz when the needle lines up again.
      _wasAligned = false;
    });
    if (SP.isInitialized) {
      unawaited(SP.prefs.setString(_targetPreferenceKey, chosen.id));
    }
    unawaited(AnalyticsService.feature(
      'qibla_target_changed',
      label: 'Qibla target changed',
      parameters: {'target': chosen.id},
    ));
  }

  Future<void> _refreshLocation() async {
    // A chosen city is never refreshed by GPS, so for one the button changes
    // the city instead of doing nothing.
    if (_location.isManual) {
      await chooseCityFlow(context);
    } else {
      await _location.refresh(context: context);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: widePageWidth);

    final target = _TargetCard(target: _target, onTap: _pickTarget);
    // Permission and calibration come first: until they are sorted, the
    // dial below cannot be trusted.
    final notices = _notices();
    final dial = ValueListenableBuilder<double>(
      valueListenable: _heading,
      builder: (context, heading, _) => QiblaCompassDial(
        headingDegrees: _isLive ? heading : 0,
        targetBearingDegrees: _targetBearing,
        qiblaBearingDegrees: _qiblaBearing,
        targetLabel: _target.city,
        isAligned: _isLive && _isAlignedAt(heading),
        isLive: _isLive,
      ),
    );
    final instruction = ValueListenableBuilder<double>(
      valueListenable: _heading,
      builder: (context, heading, _) => _TurnInstruction(
        target: _target,
        targetBearing: _targetBearing,
        headingDegrees: heading,
        isLive: _isLive,
        isAligned: _isAlignedAt(heading),
      ),
    );
    final stats = ValueListenableBuilder<double>(
      valueListenable: _heading,
      builder: (context, heading, _) => _StatsRow(
        distanceKm: _distanceKm,
        targetBearing: _targetBearing,
        headingDegrees: _isLive ? heading : null,
      ),
    );
    final locationStrip = _LocationStrip(
      location: _location,
      here: _here,
      onRefresh: _refreshLocation,
    );

    Widget column(List<Widget> children, {double spacing = 14}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        );

    return LargeTitlePage(
      title: context.l10n.qiblaPageTitle,
      maxWidth: widePageWidth,
      actions: [
        RoundIconButton(
          label: context.l10n.qiblaAboutCompass,
          icon: OutlineIcon(OutlineGlyph.info, size: 22, color: colors.accent),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => _AboutCompassDialog(
              declination: _here == null ? null : _declination,
            ),
          ),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, constraints) {
              // A desktop or a tablet on its side: the dial and what it
              // says on the left, the rest beside it.
              if (WideColumns.splits(constraints.maxWidth)) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: column([
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: dial,
                          ),
                        ),
                        instruction,
                      ]),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: column([target, ...notices, stats, locationStrip]),
                    ),
                  ],
                );
              }
              return column([
                target,
                ...notices,
                Center(
                  child: ConstrainedBox(
                    // Bigger on a tablet, which has the room.
                    constraints: BoxConstraints(
                        maxWidth: ScreenClass.of(context).isPhone ? 300 : 380),
                    child: dial,
                  ),
                ),
                instruction,
                stats,
                locationStrip,
              ]);
            }),
          ),
        ),
      ],
    );
  }

  bool _isAlignedAt(double heading) {
    final bearing = _targetBearing;
    if (bearing == null) return false;
    return relativeBearingDegrees(heading, bearing).abs() <=
        _alignmentToleranceDegrees;
  }

  List<Widget> _notices() {
    final notices = <Widget>[];

    if (_here == null) {
      notices.add(
        _NoticeCard(
          icon: Icons.location_off_outlined,
          title: context.l10n.qiblaLocationNeeded,
          body: context.l10n.qiblaLocationNeededBody,
          action:
              _location.isRefreshing ? null : context.l10n.qiblaUseMyLocation,
          onAction: _refreshLocation,
        ),
      );
    }

    switch (_status) {
      case _CompassStatus.permissionRequired:
        notices.add(
          _NoticeCard(
            icon: Icons.explore_outlined,
            title: context.l10n.qiblaTurnOnCompass,
            body: context.l10n.qiblaTurnOnCompassBody,
            action: context.l10n.qiblaAllowCompass,
            onAction: _grantPermission,
          ),
        );
      case _CompassStatus.permissionDenied:
        notices.add(
          _NoticeCard(
            icon: Icons.explore_off_outlined,
            title: context.l10n.qiblaCompassBlocked,
            body: context.l10n.qiblaCompassBlockedBody,
          ),
        );
      case _CompassStatus.unavailable:
        notices.add(
          _NoticeCard(
            icon: Icons.explore_off_outlined,
            title: context.l10n.qiblaNoCompass,
            body: context.l10n.qiblaNoCompassBody,
          ),
        );
      case _CompassStatus.waiting:
      case _CompassStatus.live:
        break;
    }

    final accuracy = _accuracyDegrees;
    if (_isLive && accuracy != null && accuracy > 15) {
      notices.add(
        _NoticeCard(
          icon: Icons.refresh,
          title: context.l10n.qiblaNeedsCalibrating,
          body: context.l10n.qiblaNeedsCalibratingBody(accuracy.round()),
        ),
      );
    }

    return notices;
  }
}

/// Where the reading is being taken from, and a way to update it.
class _LocationStrip extends StatelessWidget {
  const _LocationStrip({
    required this.location,
    required this.here,
    required this.onRefresh,
  });

  final LocationService location;
  final GeoPoint? here;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final label = here == null
        ? context.l10n.qiblaLocationUnknown
        : [city, formatCoordinates(here!)]
            .whereType<String>()
            .where((part) => part.isNotEmpty)
            .join(' · ');

    return Row(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child:
              OutlineIcon(OutlineGlyph.pin, size: 18, color: colors.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: ShiaText.caption.copyWith(color: colors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (location.isRefreshing)
          const SizedBox.square(
            dimension: 44,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          PageTextAction(
            label: location.isManual
                ? context.l10n.cityChangeCity
                : context.l10n.qiblaUpdateLocation,
            onPressed: onRefresh,
          ),
      ],
    );
  }
}

/// The destination the needle points at, and the way to change it.
class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target, required this.onTap});

  final HolySite target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);

    return Semantics(
      button: true,
      label: '${l10n.qiblaPointingTowards} '
          '${l10n.qiblaTargetIn(target.name, target.city)}',
      hint: l10n.qiblaChangeTarget,
      excludeSemantics: true,
      onTap: onTap,
      child: CardList(
        children: [
          CardListRow(
            first: true,
            last: true,
            minHeight: 56,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qiblaPointingTowards,
                  style: ShiaText.caption.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n.qiblaTargetIn(target.name, target.city),
                  style: ShiaText.cardTitle.copyWith(color: colors.text),
                ),
              ],
            ),
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
              child: Text(
                l10n.qiblaChange,
                style: ShiaText.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

/// The one line the user is actually reading: which way to turn.
class _TurnInstruction extends StatelessWidget {
  const _TurnInstruction({
    required this.target,
    required this.targetBearing,
    required this.headingDegrees,
    required this.isLive,
    required this.isAligned,
  });

  final HolySite target;
  final double? targetBearing;
  final double headingDegrees;
  final bool isLive;
  final bool isAligned;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final bearing = targetBearing;

    late final String message;
    late final Color color;
    String? hint;

    if (bearing == null) {
      message = l10n.qiblaWaitingForLocation;
      color = colors.textMuted;
    } else if (!isLive) {
      message = l10n.qiblaBearingFromNorth(target.name, formatBearing(bearing));
      color = colors.text;
    } else if (isAligned) {
      message = l10n.qiblaFacing(target.name);
      color = colors.success;
    } else {
      final offset = relativeBearingDegrees(headingDegrees, bearing);
      message = offset > 0
          ? l10n.qiblaTurnRight(offset.abs().round())
          : l10n.qiblaTurnLeft(offset.abs().round());
      color = colors.text;
      hint = l10n.qiblaHoldFlat;
    }

    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: ShiaText.largeTitle.copyWith(
              fontSize: 28,
              height: 34 / 28,
              color: color,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: ShiaText.secondary.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.distanceKm,
    required this.targetBearing,
    required this.headingDegrees,
  });

  final double? distanceKm;
  final double? targetBearing;
  final double? headingDegrees;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: l10n.qiblaDistance,
            value: distanceKm == null ? '—' : formatDistanceKm(distanceKm!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: l10n.qiblaDirection,
            value: targetBearing == null ? '—' : formatBearing(targetBearing!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: l10n.qiblaYouFace,
            value:
                headingDegrees == null ? '—' : formatBearing(headingDegrees!),
          ),
        ),
      ],
    );
  }
}

/// One of the three tiles under the instruction.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: ShiaText.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: ShiaText.cardTitle.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SliverCardList.radius),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.well,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ShiaText.cardTitle.copyWith(color: colors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  PageButton(
                    label: action!,
                    onPressed: onAction == null ? null : () => onAction!(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full list of destinations, with how far each one is from here.
class _HolySitePicker extends StatelessWidget {
  const _HolySitePicker({required this.selected, required this.from});

  final HolySite selected;
  final GeoPoint? from;

  @override
  Widget build(BuildContext context) {
    final others = otherHolySites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardList(children: [
          _SiteTile(
              site: kaaba, selected: selected, from: from, first: true,
              last: true),
        ]),
        const SizedBox(height: 18),
        GroupLabel(context.l10n.menuZiyarats),
        const SizedBox(height: 8),
        CardList(children: [
          for (final (i, site) in others.indexed)
            _SiteTile(
              site: site,
              selected: selected,
              from: from,
              first: i == 0,
              last: i == others.length - 1,
            ),
        ]),
      ],
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.selected,
    required this.from,
    this.first = false,
    this.last = false,
  });

  final HolySite site;
  final HolySite selected;
  final GeoPoint? from;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final isSelected = site.id == selected.id;
    final origin = from;

    return MergeSemantics(
      child: Semantics(
        selected: isSelected,
        child: CardListRow(
          first: first,
          last: last,
          onTap: () => Navigator.of(context).pop(site),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? colors.accent : colors.well,
              shape: BoxShape.circle,
            ),
            child: isSelected
                ? OutlineIcon(OutlineGlyph.check,
                    size: 20, color: colors.onAccent, strokeWidth: 2.4)
                : OutlineIcon(OutlineGlyph.pin, size: 20, color: colors.accent),
          ),
          title: Text(
            site.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(site.place),
          trailing: origin == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDistanceKm(
                            greatCircleDistanceKm(origin, site.location)),
                        style: ShiaText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      Text(
                        compassLabel(
                            initialBearingDegrees(origin, site.location)),
                        style:
                            ShiaText.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _AboutCompassDialog extends StatelessWidget {
  const _AboutCompassDialog({required this.declination});

  /// Local magnetic declination, or null when there is no location to compute
  /// it for.
  final double? declination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final declination = this.declination;

    return AlertDialog(
      title: Text(context.l10n.qiblaAboutCompass),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.qiblaGreatCircleBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              declination == null
                  ? context.l10n.qiblaDeclinationUnknownBody
                  : declination >= 0
                      ? context.l10n.qiblaDeclinationEast(
                          declination.abs().toStringAsFixed(1))
                      : context.l10n.qiblaDeclinationWest(
                          declination.abs().toStringAsFixed(1)),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.qiblaSteadyReadingBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
      ],
    );
  }
}

/// `1,204 km` — whole kilometres, grouped, since nothing here is precise to
/// better than the width of a city and a decimal would imply otherwise.
String formatDistanceKm(double kilometres) {
  if (kilometres < 1) return L10n.current.qiblaDistanceHere;
  return '${NumberFormat.decimalPattern().format(kilometres.round())} km';
}
