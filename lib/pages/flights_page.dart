import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/flight.dart';
import '../services/airport_repository.dart';
import '../services/flight_store.dart';
import '../theme/shia_colors.dart';
import '../utils/flight_formatting.dart';
import '../utils/flight_prayer_times.dart';
import '../utils/prayer_time_entries.dart';
import '../utils/timezone_database.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import 'flight_editor_page.dart';
import 'flight_prayer_times_page.dart';
import '../l10n/l10n.dart';

/// Prayer times in flight (docs/DESIGN_SPEC.md, "Prayer times in flight";
/// mockup `R3-Flights`): **Add a flight**, then a card per saved flight -
/// the route in large type, the cities, when it leaves and lands, and which
/// prayers come in on board.
class FlightsPage extends StatefulWidget {
  const FlightsPage({super.key, this.trackScreenOnInit = true});

  /// Disabled in widget tests, which have no Firebase Analytics instance.
  final bool trackScreenOnInit;

  @override
  State<FlightsPage> createState() => _FlightsPageState();
}

class _FlightsPageState extends State<FlightsPage> {
  late bool _isLoading;

  /// Each card's plan, worked out once per saved flight: an edit saves a new
  /// [Flight], which gets its own.
  final Expando<FlightPrayerPlan> _plans = Expando();

  @override
  void initState() {
    super.initState();
    if (widget.trackScreenOnInit) {
      unawaited(trackScreen('Flights Page'));
    }
    ensureTimeZoneDatabaseInitialized();
    FlightStore.instance.load();
    // The airport database is parsed once per process, so revisiting this page
    // should not flash a spinner.
    _isLoading = !AirportRepository.instance.isLoaded;
    if (_isLoading) {
      AirportRepository.instance.load().then((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  Future<void> _addFlight() async {
    final flight = await pushPageRoute<Flight>(
      context,
      const FlightEditorPage(),
    );
    if (flight == null || !mounted) return;
    await pushPageRoute(context, FlightPrayerTimesPage(flight: flight));
  }

  Future<void> _editFlight(Flight flight) async {
    await pushPageRoute<Flight>(context, FlightEditorPage(existing: flight));
  }

  Future<void> _confirmDelete(Flight flight) async {
    final label = flight.routeLabel;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.flightRemoveTitle),
        content: Text(context.l10n.flightRemoveBody(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.commonRemove),
          ),
        ],
      ),
    );

    if (shouldDelete == true) await FlightStore.instance.delete(flight.id);
  }

  Future<void> _showOptions(BuildContext anchor, Flight flight) async {
    final l10n = anchor.l10n;
    final value = await showMenuAt<String>(anchor, [
      PopupMenuItem(value: 'edit', child: Text(l10n.flightEdit)),
      PopupMenuItem(value: 'remove', child: Text(l10n.flightRemove)),
    ]);
    if (!mounted) return;
    switch (value) {
      case 'edit':
        unawaited(_editFlight(flight));
      case 'remove':
        unawaited(_confirmDelete(flight));
    }
  }

  FlightPrayerPlan? _planFor(Flight flight, ResolvedFlight? resolved) {
    if (resolved == null) return null;
    return _plans[flight] ??= flightPrayerPlanFor(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);

    return LargeTitlePage(
      title: l10n.flightsPageTitle,
      subtitle: l10n.flightsSubtitle,
      maxWidth: compactContentWidth,
      slivers: [
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: PageButton(
              label: l10n.flightAddAFlight,
              glyph: OutlineGlyph.plus,
              filled: true,
              onPressed: _isLoading ? null : _addFlight,
            ),
          ),
        ),
        if (_isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          ListenableBuilder(
            listenable: FlightStore.instance,
            builder: (context, _) {
              final flights = FlightStore.instance.flights;
              return SliverPadding(
                padding: gutter,
                sliver: SliverList.list(
                  children: [
                    if (flights.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: EmptyStateCard(
                          glyph: OutlineGlyph.plane,
                          title: l10n.flightNoneSaved,
                          body: l10n.flightNoneSavedBody,
                        ),
                      ),
                    for (final flight in flights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Builder(builder: (context) {
                          final resolved = ResolvedFlight.resolve(flight);
                          return _FlightCard(
                            flight: flight,
                            resolved: resolved,
                            plan: _planFor(flight, resolved),
                            onOpen: () => pushPageRoute(
                              context,
                              FlightPrayerTimesPage(flight: flight),
                            ),
                            onOptions: (anchor) => _showOptions(anchor, flight),
                          );
                        }),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l10n.flightsFootnote,
                        style: ShiaText.caption.copyWith(
                          height: 18 / 13,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One saved flight: "LHR ✈ JED", "London to Jeddah", the ⋯ for edit and
/// remove; then the date and departure, the time in the air and landing,
/// and a pill naming what comes in on board. Tapping it opens the flight.
class _FlightCard extends StatelessWidget {
  const _FlightCard({
    required this.flight,
    required this.resolved,
    required this.plan,
    required this.onOpen,
    required this.onOptions,
  });

  final Flight flight;
  final ResolvedFlight? resolved;
  final FlightPrayerPlan? plan;
  final VoidCallback onOpen;
  final void Function(BuildContext anchor) onOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final resolved = this.resolved;
    final cities =
        l10n.flightCities(flight.origin.place, flight.destination.place);
    final flightNumber = flight.flightNumber;
    final codeStyle = ShiaText.sectionTitle.copyWith(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w700,
      color: colors.text,
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: cities,
                          excludeSemantics: true,
                          child: Row(
                            children: [
                              Text(flight.origin.iata, style: codeStyle),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                // The glyph points up; turned to fly from the
                                // first code to the second.
                                child: Transform.rotate(
                                  angle: (rtl ? -1 : 1) * math.pi / 2,
                                  child: OutlineIcon(OutlineGlyph.plane,
                                      size: 18,
                                      color: colors.accent,
                                      strokeWidth: 1.2,
                                      filled: true),
                                ),
                              ),
                              Text(flight.destination.iata, style: codeStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flightNumber == null
                              ? cities
                              : '$cities · $flightNumber',
                          style: ShiaText.secondary
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (anchor) => MoreButton(
                      label: l10n.flightOptionsFor(cities),
                      onPressed: () => onOptions(anchor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.flightDepartsOn(
                            formatShortDate(flight.departureLocal),
                            formatClock12(flight.departureLocal),
                          ),
                          style:
                              ShiaText.cardTitle.copyWith(color: colors.text),
                        ),
                        if (resolved != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.flightLandsAt(
                              formatFlightDuration(resolved.duration, l10n),
                              formatClock12(flight.arrivalLocal),
                              flight.destination.place,
                            ),
                            style: ShiaText.secondary.copyWith(
                              fontSize: 14,
                              height: 18 / 14,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                        if (_pill(context) case final pill?) ...[
                          const SizedBox(height: 6),
                          pill,
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
                    child: OutlineIcon(OutlineGlyph.chevronRight,
                        size: 16, color: colors.chevron, strokeWidth: 2.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What comes in on board: the prayers by name, "No prayer in the air",
  /// or a warning that the times entered cannot be right.
  Widget? _pill(BuildContext context) {
    final plan = this.plan;
    if (plan == null) return null;
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);

    if (!plan.isValid) {
      return _Pill(text: l10n.flightCheckTimes, color: colors.danger);
    }
    final names = <String>[];
    for (final event in plan.eventsDuringFlight) {
      if (!_prayers.contains(event.prayerIndex)) continue;
      final name = localizedPrayerName(event.name, l10n);
      if (!names.contains(name)) names.add(name);
    }
    if (names.isEmpty) {
      return _Pill(text: l10n.flightNoPrayerInAir, color: colors.textMuted);
    }
    return _Pill(
      text: l10n.flightPrayersInAir(names.join(l10n.listSeparator)),
      color: colors.accent,
    );
  }

  /// The five prayers; sunrise and the end of Isha are not something to
  /// pray, so they stay off the pill.
  static const _prayers = {
    prayerIndexFajr,
    prayerIndexZuhr,
    prayerIndexAsr,
    prayerIndexMaghrib,
    prayerIndexIsha,
  };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        text,
        style: ShiaText.caption.copyWith(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
