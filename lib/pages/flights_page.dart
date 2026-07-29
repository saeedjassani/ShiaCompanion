import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/flight.dart';
import '../services/airport_repository.dart';
import '../services/flight_store.dart';
import '../utils/flight_formatting.dart';
import '../utils/timezone_database.dart';
import '../widgets/responsive_content.dart';
import 'flight_editor_page.dart';
import 'flight_prayer_times_page.dart';

/// Saved flights, and the entry point for adding one.
class FlightsPage extends StatefulWidget {
  const FlightsPage({super.key, this.trackScreenOnInit = true});

  /// Disabled in widget tests, which have no Firebase Analytics instance.
  final bool trackScreenOnInit;

  @override
  State<FlightsPage> createState() => _FlightsPageState();
}

class _FlightsPageState extends State<FlightsPage> {
  late bool _isLoading;

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

  Future<void> _confirmDelete(Flight flight) async {
    final label = flight.routeLabel;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove flight?'),
        content: Text('$label will be removed from your saved flights.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) await FlightStore.instance.delete(flight.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times in Flight')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addFlight,
        icon: const Icon(Icons.add),
        label: const Text('Add flight'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: FlightStore.instance,
              builder: (context, _) {
                final flights = FlightStore.instance.flights;
                if (flights.isEmpty) return const _EmptyState();

                return ResponsiveScrollableContent(
                  maxWidth: compactContentWidth,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final flight in flights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FlightCard(
                            flight: flight,
                            onOpen: () => pushPageRoute(
                              context,
                              FlightPrayerTimesPage(flight: flight),
                            ),
                            onDelete: () => _confirmDelete(flight),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  const _FlightCard({
    required this.flight,
    required this.onOpen,
    required this.onDelete,
  });

  final Flight flight;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = ResolvedFlight.resolve(flight);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          flight.routeLabel,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (flight.flightNumber != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            flight.flightNumber!,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatWallClock(flight.departureLocal),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (resolved != null)
                      Text(
                        '${formatFlightDuration(resolved.duration)} · lands '
                        '${formatWallClock(flight.arrivalLocal)} '
                        '${resolved.destination.iata} time',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove flight',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No flights saved',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your flight and this page will work out when each prayer '
              'comes in along the route — shown in both your departure and '
              'arrival city\'s time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
