import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../utils/flight_formatting.dart';
import '../utils/flight_prayer_times.dart';
import '../utils/geo_utils.dart';
import '../utils/prayer_time_icons.dart';
import '../widgets/responsive_content.dart';
import 'flight_editor_page.dart';

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
        title: Text(resolved?.routeLabel ?? 'Flight'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit flight',
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
            const _NoticeCard(
              icon: Icons.error_outline,
              title: 'Check the flight times',
              body: 'The arrival is not after the departure once each '
                  'airport\'s time zone is applied. Tap edit to fix the dates.',
              isError: true,
            )
          else ...[
            _SectionHeading(
              title: 'In the air',
              subtitle: duringFlight.isEmpty
                  ? null
                  : 'Times shown at ${resolved.origin.iata} and '
                      '${resolved.destination.iata} local clocks',
            ),
            const SizedBox(height: 8),
            if (duringFlight.isEmpty)
              const _NoticeCard(
                icon: Icons.hourglass_empty,
                title: 'No prayer comes in during this flight',
                body: 'Every prayer time falls either before take-off or '
                    'after landing.',
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
              const _SectionHeading(title: 'Not during this flight'),
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
              '${formatFlightDuration(resolved.duration)} in the air · '
              '${formatDistanceKm(plan.distanceKm)} great-circle',
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
            child: Text('${resolved.origin.iata} time',
                textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text('${resolved.destination.iata} time',
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
                    Icon(
                      prayerIconFor(event.name),
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
        position == null ? '' : ' · over ${formatCoordinates(position)}';
    final prefix = event.prayerIndex == prayerIndexMidnight
        ? 'End of the Isha window · '
        : '';
    return '$prefix${formatFlightDuration(elapsed)} after take-off$where';
  }

  String _qiblaLine() {
    final bearing = event.qiblaBearingDegrees!;
    final relative = event.qiblaRelativeToCourseDegrees!;
    final magnitude = relative.abs().round();

    final String relativeText;
    if (magnitude <= 10) {
      relativeText = 'straight ahead';
    } else if (magnitude >= 170) {
      relativeText = 'directly behind you';
    } else {
      final side = relative > 0 ? 'right' : 'left';
      relativeText = '$magnitude° to your $side';
    }

    return 'Qibla ${bearing.round()}° (${compassLabel(bearing)}) — '
        '$relativeText relative to the direction of flight';
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
      leading: Icon(
        prayerIconFor(event.name),
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
            ? 'The Isha window had already closed before take-off.'
            : 'Already in before take-off — use the prayer times for your '
                'departure city.';
      case FlightPrayerStatus.afterArrival:
        return isMidnight
            ? 'The Isha window does not close until after landing.'
            : 'Comes in after landing — use the prayer times for your '
                'destination.';
      case FlightPrayerStatus.sunAngleNeverReached:
        return 'The sun never reaches the required angle anywhere along this '
            'route, so no time can be calculated.';
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
        const _NoticeCard(
          icon: Icons.info_outline,
          title: 'How these are worked out',
          body: 'The aircraft is assumed to follow the great-circle route at a '
              'steady speed, and each prayer time is solved for the position '
              'the aircraft is at when that time arrives. Delays, holding, and '
              'routing around weather will shift these times. Altitude is not '
              'accounted for; being high up brings sunset slightly later and '
              'dawn slightly earlier than shown.',
        ),
        if (plan.crossesHighLatitude) ...[
          const SizedBox(height: 12),
          const _NoticeCard(
            icon: Icons.ac_unit,
            title: 'This route crosses high latitudes',
            body: 'Above roughly 48°, the sun may not dip far enough below the '
                'horizon for dawn and nightfall to happen normally. Times for '
                'Fajr, Maghrib and Isha there fall back to a proportional '
                'estimate of the night. Rulings for prayer at high latitude '
                'differ — please follow your marja.',
          ),
        ],
        if (plan.hasUncomputablePrayer) ...[
          const SizedBox(height: 12),
          const _NoticeCard(
            icon: Icons.wb_twilight,
            title: 'Some prayer times could not be calculated',
            body: 'The sun stays above the required angle for the whole route, '
                'so those prayers have no calculated time. Please follow your '
                'marja\'s ruling for these conditions.',
            isError: true,
          ),
        ],
      ],
    );
  }
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
            Text('Time zones could not be loaded',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'One of these airports has a time zone this build does not '
              'recognise. Tap edit to pick the airports again.',
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
