import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../constants.dart';
import '../models/flight.dart';
import '../theme/shia_colors.dart';
import '../utils/flight_formatting.dart';
import '../utils/flight_prayer_times.dart';
import '../utils/geo_utils.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/prayer_glyph.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import 'flight_editor_page.dart';
import '../l10n/l10n.dart';

/// When each prayer comes in along [resolved]'s route, with the user's
/// calculation settings. Solving the route costs a few hundred prayer-time
/// evaluations, so callers keep the result rather than redo it per build.
FlightPrayerPlan flightPrayerPlanFor(ResolvedFlight resolved) =>
    computeFlightPrayerPlan(
      prayerTime: getPrayerTimeObject(),
      origin: GeoPoint(resolved.origin.latitude, resolved.origin.longitude),
      destination: GeoPoint(
        resolved.destination.latitude,
        resolved.destination.longitude,
      ),
      departureUtc: resolved.departureUtc,
      arrivalUtc: resolved.arrivalUtc,
    );

/// One flight (mockup `R3-Flight-times`): a departs / arrives card, then
/// **In the air** - each prayer on both airports' clocks, how long after
/// take-off and over where, and the Qibla from a seat - and **On the
/// ground**, what to use for the prayers that do not come in on board.
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

  /// Whether "How these are worked out" is open.
  bool _showMethod = false;

  @override
  void initState() {
    super.initState();
    _flight = widget.flight;
    if (widget.trackScreenOnInit) {
      unawaited(trackScreen('Flight Prayer Times Page'));
    }
    _recompute();
  }

  /// Done once per flight rather than on every rebuild.
  void _recompute() {
    final resolved = ResolvedFlight.resolve(_flight);
    _resolved = resolved;
    _plan = resolved == null ? null : flightPrayerPlanFor(resolved);
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

  /// "London to Jeddah"; the codes where both airports serve one city.
  String _title(AppLocalizations l10n) {
    final from = _flight.origin.place;
    final to = _flight.destination.place;
    return from == to ? _flight.routeLabel : l10n.flightCities(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolved = _resolved;
    final plan = _plan;
    final gutter = pageGutter(context, maxWidth: compactContentWidth);

    return LargeTitlePage(
      title: resolved == null ? l10n.flightTitleFallback : _title(l10n),
      subtitle: _flight.flightNumber,
      maxWidth: compactContentWidth,
      actions: [
        PageTextAction(
          label: l10n.commonEdit,
          semanticsLabel: l10n.flightEdit,
          onPressed: _edit,
        ),
      ],
      slivers: [
        for (final child in resolved == null || plan == null
            ? [
                EmptyStateCard(
                  glyph: OutlineGlyph.info,
                  title: l10n.flightTimeZonesFailed,
                  body: l10n.flightTimeZonesFailedBody,
                  actionLabel: l10n.flightEdit,
                  onAction: _edit,
                ),
              ]
            : _sections(context, resolved, plan))
          SliverPadding(
            padding: gutter.copyWith(bottom: 14),
            sliver: SliverToBoxAdapter(child: child),
          ),
      ],
    );
  }

  List<Widget> _sections(
    BuildContext context,
    ResolvedFlight resolved,
    FlightPrayerPlan plan,
  ) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final duringFlight = plan.eventsDuringFlight;
    // What was in before take-off first, then what waits for landing.
    final outsideFlight = [...plan.eventsOutsideFlight]
      ..sort((a, b) => a.status.index - b.status.index);
    final now = DateTime.now().toUtc();
    // Only worth highlighting a "next" prayer while the flight is under way.
    final nextEvent =
        now.isAfter(plan.departureUtc) && now.isBefore(plan.arrivalUtc)
            ? duringFlight
                .where((event) => event.instantUtc!.isAfter(now))
                .firstOrNull
            : null;

    if (!plan.isValid) {
      return [
        _SummaryCard(resolved: resolved, plan: plan),
        _NoticeCard(
          glyph: OutlineGlyph.alert,
          title: l10n.flightCheckTimes,
          body: l10n.flightCheckTimesBody,
          isError: true,
        ),
      ];
    }

    Widget labelled(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupLabel(label),
            const SizedBox(height: 8),
            child,
          ],
        );

    return [
      _SummaryCard(resolved: resolved, plan: plan),
      labelled(
        l10n.flightInTheAir,
        duringFlight.isEmpty
            ? _NoticeCard(
                glyph: OutlineGlyph.clock,
                title: l10n.flightNoPrayerDuring,
                body: l10n.flightNoPrayerDuringBody,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ColumnHeaders(resolved: resolved),
                  const SizedBox(height: 6),
                  CardList(
                    children: [
                      for (var i = 0; i < duringFlight.length; i++)
                        _InAirRow(
                          event: duringFlight[i],
                          resolved: resolved,
                          isNext: identical(duringFlight[i], nextEvent),
                          last: i == duringFlight.length - 1,
                        ),
                    ],
                  ),
                ],
              ),
      ),
      if (outsideFlight.isNotEmpty)
        labelled(
          l10n.flightOnTheGround,
          CardList(
            children: [
              for (var i = 0; i < outsideFlight.length; i++)
                CardListRow(
                  first: i == 0,
                  last: i == outsideFlight.length - 1,
                  leading: PrayerGlyph(
                    name: outsideFlight[i].name,
                    size: 22,
                    color: colors.textMuted,
                  ),
                  title: Text(_eventName(outsideFlight[i], l10n)),
                  subtitle: Text(
                    _groundExplanation(outsideFlight[i], resolved, l10n),
                    style: const TextStyle(fontSize: 14, height: 18 / 14),
                  ),
                ),
            ],
          ),
        ),
      if (plan.crossesHighLatitude)
        _NoticeCard(
          glyph: OutlineGlyph.alert,
          title: l10n.flightHighLatitude,
          body: l10n.flightHighLatitudeBody,
        ),
      if (plan.hasUncomputablePrayer)
        _NoticeCard(
          glyph: OutlineGlyph.alert,
          title: l10n.flightSomeNotCalculated,
          body: l10n.flightSomeNotCalculatedBody,
          isError: true,
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              expanded: _showMethod,
              child: PageTextAction(
                label: l10n.flightHowWorkedOut,
                onPressed: () => setState(() => _showMethod = !_showMethod),
              ),
            ),
          ),
          if (_showMethod) ...[
            const SizedBox(height: 8),
            _NoticeCard(
              glyph: OutlineGlyph.info,
              body: l10n.flightHowWorkedOutBody,
            ),
            const SizedBox(height: 12),
            _NoticeCard(
              glyph: OutlineGlyph.plane,
              title: plan.usesAircraftHorizon
                  ? l10n.flightHorizonAtAltitude
                  : l10n.flightHorizonAtGround,
              body: plan.usesAircraftHorizon
                  ? l10n.flightAltitudeHorizonBody(
                      _cruiseLabel(plan.cruiseAltitudeFeet),
                      localizeDigits(horizonDipDegrees(plan.cruiseAltitudeFeet)
                          .toStringAsFixed(1)))
                  : l10n.flightGroundHorizonBody,
            ),
          ],
        ],
      ),
    ];
  }

  static String _groundExplanation(
    FlightPrayerEvent event,
    ResolvedFlight resolved,
    AppLocalizations l10n,
  ) {
    final isMidnight = event.prayerIndex == prayerIndexMidnight;
    final from = resolved.origin.place;
    final to = resolved.destination.place;

    return switch (event.status) {
      FlightPrayerStatus.alreadyInAtDeparture => isMidnight
          ? l10n.flightGroundIshaEnded
          : l10n.flightGroundAlreadyIn(from),
      FlightPrayerStatus.afterArrival => isMidnight
          ? l10n.flightGroundIshaOpen(to)
          : l10n.flightGroundAfterLanding(to),
      FlightPrayerStatus.sunAngleNeverReached =>
        l10n.flightSunAngleNeverReached,
      FlightPrayerStatus.duringFlight => '',
    };
  }
}

/// A prayer by name, or "Isha time ends" for the midnight that closes it.
String _eventName(FlightPrayerEvent event, AppLocalizations l10n) =>
    event.prayerIndex == prayerIndexMidnight
        ? l10n.flightIshaEnds
        : localizedPrayerName(event.name, l10n);

/// Departs / arrives, each on its own airport's clock, then the time in the
/// air and the distance.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.resolved, required this.plan});

  final ResolvedFlight resolved;
  final FlightPrayerPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final flight = resolved.flight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Endpoint(
                  label: l10n.flightDepartsFrom(resolved.origin.place),
                  wallClock: flight.departureLocal,
                  airport: resolved.origin.iata,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Endpoint(
                  label: l10n.flightArrivesIn(resolved.destination.place),
                  wallClock: flight.arrivalLocal,
                  airport: resolved.destination.iata,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.flightInAirDistance(
              formatFlightDuration(resolved.duration, l10n),
              formatDistanceKm(plan.distanceKm),
            ),
            style: ShiaText.secondary.copyWith(
              fontSize: 14,
              height: 19 / 14,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.wallClock,
    required this.airport,
  });

  final String label;
  final DateTime wallClock;
  final String airport;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final muted = ShiaText.secondary.copyWith(
      fontSize: 14,
      height: 18 / 14,
      color: colors.textMuted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ShiaText.caption.copyWith(color: colors.textMuted)),
        const SizedBox(height: 1),
        Text(
          formatClock12(wallClock),
          style: ShiaText.sectionTitle.copyWith(
            height: 25 / 20,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          context.l10n.flightDateAtAirport(formatShortDate(wallClock), airport),
          style: muted,
        ),
      ],
    );
  }
}

/// The width of each clock's column in the In the air card.
const double _timeColumnWidth = 80;

/// "JED time · LHR time" over the In the air card: the destination's clock
/// first, as the one the flight is heading into.
class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.resolved});

  final ResolvedFlight resolved;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = ShiaText.caption.copyWith(
      fontWeight: FontWeight.w600,
      color: ShiaColors.of(context).textMuted,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          const Spacer(),
          for (final airport in [resolved.destination, resolved.origin])
            SizedBox(
              width: _timeColumnWidth,
              child: Text(
                l10n.flightAirportTime(airport.iata),
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

/// A prayer that comes in on board: its name and both clocks, how long
/// after take-off and where, how far the altitude moves it, and the Qibla.
class _InAirRow extends StatelessWidget {
  const _InAirRow({
    required this.event,
    required this.resolved,
    required this.isNext,
    required this.last,
  });

  final FlightPrayerEvent event;
  final ResolvedFlight resolved;
  final bool isNext;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final instant = event.instantUtc!;
    final originTime = toZone(instant, resolved.originLocation);
    final destinationTime = toZone(instant, resolved.destinationLocation);
    final elapsed =
        formatFlightDuration(instant.difference(resolved.departureUtc), l10n);
    final position = event.position;
    final detail = TextStyle(
      fontSize: 14,
      height: 19 / 14,
      color: colors.textMuted,
    );
    final horizon = _horizonLine(l10n);
    final qibla = _qiblaLine(l10n);

    return Container(
      decoration: BoxDecoration(
        color: isNext ? colors.selectedTint : null,
        border: last ? null : Border(bottom: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PrayerGlyph(name: event.name, size: 22, color: colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _eventName(event, l10n),
                  style: ShiaText.cardTitle.copyWith(color: colors.text),
                ),
              ),
              _TimeCell(
                time: destinationTime,
                dayOffset: formatDayOffset(
                    resolved.flight.arrivalLocal, destinationTime),
                emphasized: true,
              ),
              _TimeCell(
                time: originTime,
                dayOffset:
                    formatDayOffset(resolved.flight.departureLocal, originTime),
                emphasized: false,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 32, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position == null
                      ? l10n.flightAfterTakeoff(elapsed)
                      : l10n.flightAfterTakeoffOver(
                          elapsed, formatCoordinates(position)),
                  style: detail,
                ),
                if (horizon != null) Text(horizon, style: detail),
                if (qibla != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      OutlineIcon(OutlineGlyph.compass,
                          size: 15, color: colors.accent, strokeWidth: 2),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          qibla,
                          style: detail.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Explains the altitude correction per prayer, in the direction it actually
  /// moves: later for Maghrib and Isha, earlier for Fajr and sunrise.
  String? _horizonLine(AppLocalizations l10n) {
    final shift = event.shiftFromGroundHorizon;
    if (shift == null) return null;

    final minutes = shift.inMinutes;
    if (minutes.abs() < 1) return null;

    return minutes > 0
        ? l10n.flightHorizonLater(minutes.abs())
        : l10n.flightHorizonEarlier(minutes.abs());
  }

  /// "Qibla 100° · about 50° to your left": from a seat facing the front.
  String? _qiblaLine(AppLocalizations l10n) {
    final bearing = event.qiblaBearingDegrees;
    final relative = event.qiblaRelativeToCourseDegrees;
    if (bearing == null || relative == null) return null;
    final magnitude = relative.abs().round();

    final String relativeText;
    if (magnitude <= 10) {
      relativeText = l10n.flightStraightAhead;
    } else if (magnitude >= 170) {
      relativeText = l10n.flightDirectlyBehind;
    } else {
      relativeText = relative > 0
          ? l10n.flightAboutToRight(magnitude)
          : l10n.flightAboutToLeft(magnitude);
    }

    return l10n.flightQiblaShort(bearing.round() % 360, relativeText);
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
    final colors = ShiaColors.of(context);

    return SizedBox(
      width: _timeColumnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              formatClock12(time),
              maxLines: 1,
              style: ShiaText.body.copyWith(
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
                color: emphasized ? colors.text : colors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (dayOffset != null)
            Text(
              dayOffset!,
              style: ShiaText.caption.copyWith(
                fontSize: 12,
                height: 16 / 12,
                color: colors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// `38,000 ft`
String _cruiseLabel(double feet) => L10n.current
    .flightAltitudeFeet(NumberFormat.decimalPattern().format(feet.round()));

/// A note on how to read the times, or a warning about them: a glyph in a
/// well, a title and a paragraph.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.glyph,
    this.title,
    required this.body,
    this.isError = false,
  });

  final OutlineGlyph glyph;
  final String? title;
  final String body;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final tone = isError ? colors.danger : colors.accent;

    return Container(
      padding: const EdgeInsets.all(14),
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
              color: isError ? tone.withValues(alpha: 0.10) : colors.well,
              borderRadius: BorderRadius.circular(10),
            ),
            child: OutlineIcon(glyph, size: 20, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: ShiaText.cardTitle.copyWith(
                      color: isError ? colors.danger : colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  body,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
