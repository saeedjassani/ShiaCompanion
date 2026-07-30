import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../services/airport_repository.dart';
import '../services/flight_store.dart';
import '../utils/flight_formatting.dart';
import '../utils/timezone_database.dart';
import '../widgets/responsive_content.dart';
import 'airport_picker_page.dart';

/// Add or edit a saved flight. Pops with the saved [Flight], or null.
class FlightEditorPage extends StatefulWidget {
  const FlightEditorPage({super.key, this.existing});

  final Flight? existing;

  @override
  State<FlightEditorPage> createState() => _FlightEditorPageState();
}

class _FlightEditorPageState extends State<FlightEditorPage> {
  final TextEditingController _flightNumberController = TextEditingController();

  Airport? _origin;
  Airport? _destination;
  DateTime? _departureLocal;
  DateTime? _arrivalLocal;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Flight Editor Page'));
    ensureTimeZoneDatabaseInitialized();
    _prefill();
  }

  Future<void> _prefill() async {
    await AirportRepository.instance.load();
    final existing = widget.existing;
    if (existing != null) {
      _origin = existing.origin;
      _destination = existing.destination;
      _departureLocal = existing.departureLocal;
      _arrivalLocal = existing.arrivalLocal;
      _flightNumberController.text = existing.flightNumber ?? '';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickAirport({required bool isOrigin}) async {
    final airport = await pushPageRoute<Airport>(
      context,
      AirportPickerPage(
        title: isOrigin ? 'Departure airport' : 'Arrival airport',
      ),
    );
    if (airport == null || !mounted) return;

    setState(() {
      if (isOrigin) {
        _origin = airport;
      } else {
        _destination = airport;
      }
      _errorText = null;
    });
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final airport = isDeparture ? _origin : _destination;
    if (airport == null) {
      setState(() => _errorText = isDeparture
          ? 'Choose the departure airport first.'
          : 'Choose the arrival airport first.');
      return;
    }

    final now = DateTime.now();
    final initial = (isDeparture ? _departureLocal : _arrivalLocal) ??
        _departureLocal ??
        now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: isDeparture
          ? 'Departure date at ${airport.iata}'
          : 'Arrival date at ${airport.iata}',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: isDeparture
          ? 'Departure time (local at ${airport.iata})'
          : 'Arrival time (local at ${airport.iata})',
    );
    if (time == null || !mounted) return;

    setState(() {
      final value =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isDeparture) {
        _departureLocal = value;
        // Landing before take-off is almost always a stale arrival date, so
        // nudge it forward rather than leaving an invalid pair on screen.
        final arrival = _arrivalLocal;
        if (arrival != null && !arrival.isAfter(value)) {
          _arrivalLocal = null;
        }
      } else {
        _arrivalLocal = value;
      }
      _errorText = null;
    });
  }

  Future<void> _save() async {
    final origin = _origin;
    final destination = _destination;
    final departure = _departureLocal;
    final arrival = _arrivalLocal;

    if (origin == null || destination == null) {
      setState(() => _errorText = 'Choose both airports.');
      return;
    }
    if (departure == null || arrival == null) {
      setState(() => _errorText = 'Set the departure and arrival times.');
      return;
    }
    if (origin.iata == destination.iata) {
      setState(() =>
          _errorText = 'Departure and arrival airports must be different.');
      return;
    }

    final flight = Flight(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      origin: origin,
      destination: destination,
      departureLocal: departure,
      arrivalLocal: arrival,
      flightNumber: _flightNumberController.text.trim().isEmpty
          ? null
          : _flightNumberController.text.trim().toUpperCase(),
    );

    final resolved = ResolvedFlight.resolve(flight);
    if (resolved == null) {
      setState(() => _errorText =
          'Could not resolve the time zone for one of those airports.');
      return;
    }
    if (resolved.duration <= Duration.zero) {
      setState(() => _errorText =
          'Arrival is before departure once time zones are applied. Check the '
          'arrival date — overnight flights land the next day.');
      return;
    }
    if (resolved.duration >= const Duration(hours: 24)) {
      setState(() => _errorText =
          'That works out to ${formatFlightDuration(resolved.duration)} in the '
          'air. Check the arrival date.');
      return;
    }

    setState(() => _isSaving = true);
    await FlightStore.instance.save(flight);
    if (mounted) Navigator.pop(context, flight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit flight' : 'Add flight'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveScrollableContent(
              maxWidth: compactContentWidth,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AirportField(
                    label: 'From',
                    airport: _origin,
                    icon: Icons.flight_takeoff,
                    onTap: () => _pickAirport(isOrigin: true),
                  ),
                  const SizedBox(height: 12),
                  _AirportField(
                    label: 'To',
                    airport: _destination,
                    icon: Icons.flight_land,
                    onTap: () => _pickAirport(isOrigin: false),
                  ),
                  const SizedBox(height: 20),
                  _DateTimeField(
                    label: 'Departs',
                    hint: 'Local time at the departure airport',
                    value: _departureLocal,
                    airport: _origin,
                    onTap: () => _pickDateTime(isDeparture: true),
                  ),
                  const SizedBox(height: 12),
                  _DateTimeField(
                    label: 'Arrives',
                    hint: 'Local time at the arrival airport',
                    value: _arrivalLocal,
                    airport: _destination,
                    onTap: () => _pickDateTime(isDeparture: false),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _flightNumberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Flight number (optional)',
                      hintText: 'e.g. TK 80',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _errorText!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_isEditing ? 'Save changes' : 'Save flight'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the times exactly as they appear on your ticket — '
                    'each one in the local time of its own airport.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AirportField extends StatelessWidget {
  const _AirportField({
    required this.label,
    required this.airport,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Airport? airport;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: airport == null
            ? Text(
                'Choose an airport',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${airport!.iata} · ${airport!.locationLabel}',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    airport!.name,
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

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.hint,
    required this.value,
    required this.airport,
    required this.onTap,
  });

  final String label;
  final String hint;
  final DateTime? value;
  final Airport? airport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suffix = airport == null ? '' : ' at ${airport!.iata}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: '$hint$suffix',
          prefixIcon: const Icon(Icons.schedule),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null ? 'Choose date and time' : formatWallClock(value!),
          style: value == null
              ? theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              size: 20, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
