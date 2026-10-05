import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../utils/flight_formatting.dart';
import '../utils/flight_prayer_times.dart';
import '../utils/geo_utils.dart';
import '../widgets/prayer_glyph.dart';
import '../widgets/responsive_content.dart';
import 'flight_editor_page.dart';
import '../l10n/l10n.dart';

/// Prayer times computed along a flight's route, shown in both the departure
/// and arrival time zones.
class FlightPrayerTimesPage extends StatefulWidget {
  const FlightPrayerTimesPage({
    super.key,
    required this.flight,
    this.trackScreenOnInit = true,
  });

  final Flight flight;

  /// Disabled in widget tests, which have no Firebase Analytics instance.
  final bool trackScreenOnInit;

  @override
  State<FlightPrayerTimesPage> createState() => _FlightPrayerTimesPageState();
}

class _FlightPrayerTimesPageState extends State<FlightPrayerTimesPage> {
  late Flight _flight;
  ResolvedFlight? _resolved;
  FlightPrayerPlan? _plan;

  @override
  void initState() {
    super.initState();
    _flight = widget.flight;
    if (widget.trackScreenOnInit) {
      unawaited(trackScreen('Flight Prayer Times Page'));
    }
    _recompute();
  }

  /// Solving the route costs a few hundred prayer-time evaluations, so it is
  /// done once per flight rather than on every rebuild.
  void _recompute() {
    final resolved = ResolvedFlight.resolve(_flight);
    _resolved = resolved;
    _plan = resolved == null
        ? null
        : computeFlightPrayerPlan(
            prayerTime: getPrayerTimeObject(),
            origin:
                GeoPoint(resolved.origin.latitude, resolved.origin.longitude),
            destination: GeoPoint(
              resolved.destination.latitude,
              resolved.destination.longitude,
            ),
            departureUtc: resolved.departureUtc,
            arrivalUtc: resolved.arrivalUtc,
          );
  }

  Future<void> _edit() async {
    final updated = await pushPageRoute<Flight>(
      context,
      FlightEditorPage(existing: _flight),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _flight = updated;
      _recompute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: Text(resolved?.routeLabel ?? context.l10n.flightTitleFallback),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.flightEdit,
            onPressed: _edit,
          ),
        ],
      ),
      body: resolved == null || plan == null
          ? const _UnresolvableFlight()
          : _FlightPrayerTimesBody(resolved: resolved, plan: plan),
    );
  }
}

class _FlightPrayerTimesBody extends StatelessWidget {
  const _FlightPrayerTimesBody({required this.resolved, required this.plan});

  final ResolvedFlight resolved;
  final FlightPrayerPlan plan;

  @override
  Widget build(BuildContext context) {
    final duringFlight = plan.eventsDuringFlight;
    final outsideFlight = plan.eventsOutsideFlight;
    final now = DateTime.now().toUtc();
    final upcoming = duringFlight
        .where((event) => event.instantUtc!.isAfter(now))
        .toList(growable: false);
    // Only worth highlighting a "next" prayer while the flight is under way.
    final nextEvent =
        now.isAfter(plan.departureUtc) && now.isBefore(plan.arrivalUtc)
            ? (upcoming.isEmpty ? null : upcoming.first)
            : null;

    return ResponsiveScrollableContent(
      maxWidth: compactContentWidth,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FlightSummaryCard(resolved: resolved, plan: plan),
          const SizedBox(height: 16),
          if (!plan.isValid)
            _NoticeCard(
              icon: Icons.error_outline,
              title: context.l10n.flightCheckTimes,
              body: context.l10n.flightCheckTimesBody,
              isError: true,
            )
          else ...[
            _SectionHeading(
              title: context.l10n.flightInTheAir,
              subtitle: duringFlight.isEmpty
                  ? null
                  : context.l10n.flightTimesShownAt(
                      resolved.origin.iata, resolved.destination.iata),
            ),
            const SizedBox(height: 8),
            if (duringFlight.isEmpty)
              _NoticeCard(
                icon: Icons.hourglass_empty,
                title: context.l10n.flightNoPrayerDuring,
                body: context.l10n.flightNoPrayerDuringBody,
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ColumnHeader(resolved: resolved),
                    const Divider(height: 1),
                    for (var index = 0; index < duringFlight.length; index++)
                      ...[
                        if (index > 0) const Divider(height: 1),
                        _PrayerEventRow(
                          event: duringFlight[index],
                          resolved: resolved,
                          isNext: identical(duringFlight[index], nextEvent),
                        ),
                      ],
                  ],
                ),
              ),
            if (outsideFlight.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionHeading(title: context.l10n.flightNotDuring),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final event in outsideFlight)
                        _OutsideFlightRow(event: event),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _Disclaimers(plan: plan),
          ],
        ],
      ),
    );
  }
}

class _FlightSummaryCard extends StatelessWidget {
  const _FlightSummaryCard({required this.resolved, required this.plan});

  final ResolvedFlight resolved;
  final FlightPrayerPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flightNumber = resolved.flight.flightNumber;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (flightNumber != null) ...[
              Text(
                flightNumber,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _EndpointColumn(
                    airport: resolved.origin,
                    wallClock: resolved.flight.departureLocal,
                    label: 'Departs',
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.flight, color: theme.colorScheme.primary),
                ),
                Expanded(
                  child: _EndpointColumn(
                    airport: resolved.destination,
                    wallClock: resolved.flight.arrivalLocal,
                    label: 'Arrives',
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              context.l10n.flightDurationAndDistance(
                  formatFlightDuration(resolved.duration),
                  formatDistanceKm(plan.distanceKm)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointColumn extends StatelessWidget {
  const _EndpointColumn({
    required this.airport,
    required this.wallClock,
    required this.label,
    required this.alignment,
  });

  final Airport airport;
  final DateTime wallClock;
  final String label;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textAlign =
        alignment == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          airport.iata,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          formatClock12(wallClock),
          textAlign: textAlign,
          style: theme.textTheme.titleMedium,
        ),
        Text(
          formatShortDate(wallClock),
          textAlign: textAlign,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.resolved});

  final ResolvedFlight resolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Expanded(flex: 4, child: SizedBox()),
          Expanded(
            flex: 3,
            child: Text(context.l10n.flightAirportTime(resolved.origin.iata),
                textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text(context.l10n.flightAirportTime(resolved.destination.iata),
                textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

class _PrayerEventRow extends StatelessWidget {
  const _PrayerEventRow({
    required this.event,
    required this.resolved,
    required this.isNext,
  });

  final FlightPrayerEvent event;
  final ResolvedFlight resolved;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instant = event.instantUtc!;
    final originTime = toZone(instant, resolved.originLocation);
    final destinationTime = toZone(instant, resolved.destinationLocation);
    final elapsed = instant.difference(resolved.departureUtc);

    return Container(
      color: isNext
          ? theme.colorScheme.primary.withValues(alpha: 0.07)
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    PrayerGlyph(
                      name: event.name,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        event.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: _TimeCell(
                  time: originTime,
                  dayOffset: formatDayOffset(
                    resolved.flight.departureLocal,
                    originTime,
                  ),
                  emphasized: true,
                ),
              ),
              Expanded(
                flex: 3,
                child: _TimeCell(
                  time: destinationTime,
                  dayOffset: formatDayOffset(
                    resolved.flight.arrivalLocal,
                    destinationTime,
                  ),
                  emphasized: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _detailLine(elapsed),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_horizonLine() case final horizonLine?)
            Text(
              horizonLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (event.qiblaRelativeToCourseDegrees != null)
            Text(
              _qiblaLine(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _detailLine(Duration elapsed) {
    final position = event.position;
    final where =
        position == null
            ? ''
            : L10n.current.flightOverPosition(formatCoordinates(position));
    final prefix = event.prayerIndex == prayerIndexMidnight
        ? L10n.current.flightEndOfIshaWindow
        : '';
    return prefix +
        L10n.current.flightAfterTakeoff(formatFlightDuration(elapsed)) +
        where;
  }

  /// Explains the altitude correction per prayer, in the direction it actually
  /// moves: later for Maghrib and Isha, earlier for Fajr and sunrise.
  String? _horizonLine() {
    final shift = event.shiftFromGroundHorizon;
    if (shift == null) return null;

    final minutes = shift.inMinutes;
    if (minutes.abs() < 1) return null;

    return minutes > 0
        ? L10n.current.flightHorizonLater(minutes.abs())
        : L10n.current.flightHorizonEarlier(minutes.abs());
  }

  String _qiblaLine() {
    final bearing = event.qiblaBearingDegrees!;
    final relative = event.qiblaRelativeToCourseDegrees!;
    final magnitude = relative.abs().round();

    final String relativeText;
    if (magnitude <= 10) {
      relativeText = L10n.current.flightStraightAhead;
    } else if (magnitude >= 170) {
      relativeText = L10n.current.flightDirectlyBehind;
    } else {
      relativeText = relative > 0
          ? L10n.current.flightQiblaToRight(magnitude)
          : L10n.current.flightQiblaToLeft(magnitude);
    }

    return L10n.current.flightQiblaLine(
        bearing.round(), compassLabel(bearing), relativeText);
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.time,
    required this.dayOffset,
    required this.emphasized,
  });

  final DateTime time;
  final String? dayOffset;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatClock12(time),
          textAlign: TextAlign.end,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            color: emphasized
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (dayOffset != null)
          Text(
            dayOffset!,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _OutsideFlightRow extends StatelessWidget {
  const _OutsideFlightRow({required this.event});

  final FlightPrayerEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      leading: PrayerGlyph(
        name: event.name,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(event.name),
      subtitle: Text(_explanation(event)),
      subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  static String _explanation(FlightPrayerEvent event) {
    final isMidnight = event.prayerIndex == prayerIndexMidnight;

    switch (event.status) {
      case FlightPrayerStatus.alreadyInAtDeparture:
        return isMidnight
            ? L10n.current.flightIshaClosedBeforeTakeoff
            : L10n.current.flightAlreadyInBeforeTakeoff;
      case FlightPrayerStatus.afterArrival:
        return isMidnight
            ? L10n.current.flightIshaOpenUntilLanding
            : L10n.current.flightAfterLanding;
      case FlightPrayerStatus.sunAngleNeverReached:
        return L10n.current.flightSunAngleNeverReached;
      case FlightPrayerStatus.duringFlight:
        return '';
    }
  }
}

class _Disclaimers extends StatelessWidget {
  const _Disclaimers({required this.plan});

  final FlightPrayerPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NoticeCard(
          icon: Icons.info_outline,
          title: context.l10n.flightHowWorkedOut,
          body: context.l10n.flightHowWorkedOutBody,
        ),
        const SizedBox(height: 12),
        _NoticeCard(
          icon: Icons.flight_class,
          title: plan.usesAircraftHorizon
              ? context.l10n.flightHorizonAtAltitude
              : context.l10n.flightHorizonAtGround,
          body: plan.usesAircraftHorizon
              ? context.l10n.flightAltitudeHorizonBody(
                  _cruiseLabel(plan.cruiseAltitudeFeet),
                  horizonDipDegrees(plan.cruiseAltitudeFeet)
                      .toStringAsFixed(1))
              : context.l10n.flightGroundHorizonBody,
        ),
        if (plan.crossesHighLatitude) ...[
          const SizedBox(height: 12),
          _NoticeCard(
            icon: Icons.ac_unit,
            title: context.l10n.flightHighLatitude,
            body: context.l10n.flightHighLatitudeBody,
          ),
        ],
        if (plan.hasUncomputablePrayer) ...[
          const SizedBox(height: 12),
          _NoticeCard(
            icon: Icons.wb_twilight,
            title: context.l10n.flightSomeNotCalculated,
            body: context.l10n.flightSomeNotCalculatedBody,
            isError: true,
          ),
        ],
      ],
    );
  }
}

/// `38,000 ft`
String _cruiseLabel(double feet) {
  final rounded = feet.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    if (index > 0 && (rounded.length - index) % 3 == 0) buffer.write(',');
    buffer.write(rounded[index]);
  }
  return L10n.current.flightAltitudeFeet(buffer.toString());
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _UnresolvableFlight extends StatelessWidget {
  const _UnresolvableFlight();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(context.l10n.flightTimeZonesFailed,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              context.l10n.flightTimeZonesFailedBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
