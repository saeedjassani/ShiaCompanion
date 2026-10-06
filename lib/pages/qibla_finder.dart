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
import '../widgets/qibla_compass_dial.dart';
import '../widgets/responsive_content.dart';
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

    final aligned =
        relativeBearingDegrees(_heading.value, bearing).abs() <=
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
    return here == null
        ? null
        : initialBearingDegrees(here, _target.location);
  }

  double? get _qiblaBearing {
    final here = _here;
    if (here == null || _target.id == kaaba.id) return null;
    return qiblaBearingDegrees(here);
  }

  double? get _distanceKm {
    final here = _here;
    return here == null
        ? null
        : greatCircleDistanceKm(here, _target.location);
  }

  bool get _isLive => _status == _CompassStatus.live;

  Future<void> _pickTarget() async {
    final chosen = await showModalBottomSheet<HolySite>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.qiblaTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: context.l10n.qiblaAboutCompass,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => _AboutCompassDialog(
                declination: _here == null ? null : _declination,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveScrollableContent(
          maxWidth: compactContentWidth,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocationStrip(
                location: _location,
                here: _here,
                onRefresh: _refreshLocation,
              ),
              const SizedBox(height: 14),
              _TargetCard(target: _target, onTap: _pickTarget),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _heading,
                    builder: (context, heading, _) => QiblaCompassDial(
                      headingDegrees: _isLive ? heading : 0,
                      targetBearingDegrees: _targetBearing,
                      qiblaBearingDegrees: _qiblaBearing,
                      targetLabel: _target.city,
                      isAligned: _isLive && _isAlignedAt(heading),
                      isLive: _isLive,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: _heading,
                builder: (context, heading, _) => _TurnInstruction(
                  target: _target,
                  targetBearing: _targetBearing,
                  headingDegrees: heading,
                  isLive: _isLive,
                  isAligned: _isAlignedAt(heading),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: _heading,
                builder: (context, heading, _) => _StatsRow(
                  distanceKm: _distanceKm,
                  targetBearing: _targetBearing,
                  headingDegrees: _isLive ? heading : null,
                ),
              ),
              ..._notices(),
            ],
          ),
        ),
      ),
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
          action: _location.isRefreshing ? null : context.l10n.qiblaUseMyLocation,
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

    if (notices.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      for (final notice in notices) ...[notice, const SizedBox(height: 12)],
    ];
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
    final theme = Theme.of(context);
    final label = here == null
        ? context.l10n.qiblaLocationUnknown
        : [city, formatCoordinates(here!)]
            .whereType<String>()
            .where((part) => part.isNotEmpty)
            .join(' · ');

    return Row(
      children: [
        Icon(
          here == null ? Icons.location_off_outlined : Icons.place_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (location.isRefreshing)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(location.isManual
                ? Icons.edit_location_alt_outlined
                : Icons.my_location),
            tooltip: location.isManual
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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.mosque,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.qiblaPointingTowards,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            target.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (target.arabicName != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            target.arabicName!,
                            style: TextStyle(
                              fontFamily: arabicFont,
                              fontSize: 17,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      target.place,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more, size: 20),
              const SizedBox(width: 4),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final bearing = targetBearing;

    late final IconData icon;
    late final String message;
    late final Color color;

    if (bearing == null) {
      icon = Icons.location_searching;
      message = context.l10n.qiblaWaitingForLocation;
      color = theme.colorScheme.onSurfaceVariant;
    } else if (!isLive) {
      icon = Icons.north;
      message = context.l10n
          .qiblaBearingFromNorth(target.name, formatBearing(bearing));
      color = theme.colorScheme.onSurfaceVariant;
    } else if (isAligned) {
      icon = Icons.check_circle;
      message = context.l10n.qiblaFacing(target.name);
      color = alignedAccentColor(theme.brightness == Brightness.dark);
    } else {
      final offset = relativeBearingDegrees(headingDegrees, bearing);
      icon = offset > 0 ? Icons.turn_right : Icons.turn_left;
      message = offset > 0
          ? context.l10n.qiblaTurnRight(offset.abs().round())
          : context.l10n.qiblaTurnLeft(offset.abs().round());
      color = theme.colorScheme.primary;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: context.l10n.qiblaDistance,
              value: distanceKm == null ? '—' : formatDistanceKm(distanceKm!),
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _Stat(
              label: context.l10n.qiblaDirection,
              value:
                  targetBearing == null ? '—' : formatBearing(targetBearing!),
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _Stat(
              label: context.l10n.qiblaYouFace,
              value:
                  headingDegrees == null ? '—' : formatBearing(headingDegrees!),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: onAction == null ? null : () => onAction!(),
                    child: Text(action!),
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
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                context.l10n.qiblaPointTowards,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _SiteTile(site: kaaba, selected: selected, from: from),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'ZIYARAT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  for (final site in otherHolySites)
                    _SiteTile(site: site, selected: selected, from: from),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.selected,
    required this.from,
  });

  final HolySite site;
  final HolySite selected;
  final GeoPoint? from;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = site.id == selected.id;
    final origin = from;

    return ListTile(
      onTap: () => Navigator.of(context).pop(site),
      selected: isSelected,
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          isSelected ? Icons.check : Icons.mosque_outlined,
          size: 20,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
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
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDistanceKm(greatCircleDistanceKm(origin, site.location)),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  compassLabel(initialBearingDegrees(origin, site.location)),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
