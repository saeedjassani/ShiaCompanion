import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../services/airport_repository.dart';
import '../services/flight_store.dart';
import '../utils/flight_formatting.dart';
import '../utils/timezone_database.dart';
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import 'airport_picker_page.dart';
import '../l10n/l10n.dart';

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
        title: isOrigin ? context.l10n.flightDepartureAirport : context.l10n.flightArrivalAirport,
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
          ? context.l10n.flightChooseDepartureFirst
          : context.l10n.flightChooseArrivalFirst);
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
          ? context.l10n.flightDepartureDateAt(airport.iata)
          : context.l10n.flightArrivalDateAt(airport.iata),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: isDeparture
          ? context.l10n.flightDepartureTimeAt(airport.iata)
          : context.l10n.flightArrivalTimeAt(airport.iata),
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
      setState(() => _errorText = context.l10n.flightChooseBothAirports);
      return;
    }
    if (departure == null || arrival == null) {
      setState(() => _errorText = context.l10n.flightSetTimes);
      return;
    }
    if (origin.iata == destination.iata) {
      setState(() =>
          _errorText = context.l10n.flightAirportsMustDiffer);
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
          context.l10n.flightTimeZoneUnresolved);
      return;
    }
    if (resolved.duration <= Duration.zero) {
      setState(() => _errorText =
          context.l10n.flightArrivalBeforeDeparture);
      return;
    }
    if (resolved.duration >= const Duration(hours: 24)) {
      setState(() => _errorText =
          context.l10n
              .flightDurationTooLong(formatFlightDuration(resolved.duration)));
      return;
    }

    setState(() => _isSaving = true);
    await FlightStore.instance.save(flight);
    if (mounted) Navigator.pop(context, flight);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);

    Widget section(Widget child, {double bottom = 14}) => SliverPadding(
          padding: gutter.copyWith(bottom: bottom),
          sliver: SliverToBoxAdapter(child: child),
        );

    return LargeTitlePage(
      title: _isEditing ? l10n.flightEdit : l10n.flightAdd,
      maxWidth: compactContentWidth,
      slivers: _isLoading
          ? [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ]
          : [
              section(
                CardList(children: [
                  _AirportRow(
                    label: l10n.flightFrom,
                    airport: _origin,
                    first: true,
                    onTap: () => _pickAirport(isOrigin: true),
                  ),
                  _AirportRow(
                    label: l10n.flightTo,
                    airport: _destination,
                    last: true,
                    onTap: () => _pickAirport(isOrigin: false),
                  ),
                ]),
              ),
              section(
                CardList(children: [
                  _DateTimeRow(
                    label: l10n.flightDeparts,
                    hint: l10n.flightDepartsHint,
                    value: _departureLocal,
                    airport: _origin,
                    first: true,
                    onTap: () => _pickDateTime(isDeparture: true),
                  ),
                  _DateTimeRow(
                    label: l10n.flightArrives,
                    hint: l10n.flightArrivesHint,
                    value: _arrivalLocal,
                    airport: _destination,
                    last: true,
                    onTap: () => _pickDateTime(isDeparture: false),
                  ),
                ]),
              ),
              section(
                TextField(
                  controller: _flightNumberController,
                  textCapitalization: TextCapitalization.characters,
                  style: ShiaText.body.copyWith(color: colors.text),
                  decoration: revampFieldDecoration(
                    context,
                    label: l10n.flightNumberLabel,
                    hint: 'e.g. TK 80',
                  ),
                ),
              ),
              if (_errorText != null) section(_ErrorBanner(message: _errorText!)),
              section(
                PageButton(
                  label: _isEditing ? l10n.flightSaveChanges : l10n.flightSave,
                  glyph: OutlineGlyph.check,
                  filled: true,
                  busy: _isSaving,
                  onPressed: _save,
                ),
                bottom: 10,
              ),
              section(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l10n.flightTicketNote,
                    style: ShiaText.caption.copyWith(
                      height: 18 / 13,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
    );
  }
}

/// A 40 px well holding a row's glyph.
class _GlyphWell extends StatelessWidget {
  const _GlyphWell(this.glyph);

  final OutlineGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.well,
        borderRadius: BorderRadius.circular(12),
      ),
      child: OutlineIcon(glyph, size: 20, color: colors.accent),
    );
  }
}

class _RowChevron extends StatelessWidget {
  const _RowChevron();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: Center(
        child: OutlineIcon(OutlineGlyph.chevronRight,
            size: 18, color: ShiaColors.of(context).chevron, strokeWidth: 2),
      ),
    );
  }
}

/// "From" or "To": the airport chosen, or a prompt to choose one.
class _AirportRow extends StatelessWidget {
  const _AirportRow({
    required this.label,
    required this.airport,
    required this.onTap,
    this.first = false,
    this.last = false,
  });

  final String label;
  final Airport? airport;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final airport = this.airport;
    return CardListRow(
      first: first,
      last: last,
      minHeight: 64,
      leading: const _GlyphWell(OutlineGlyph.plane),
      title: Text.rich(TextSpan(children: [
        TextSpan(
          text: '$label  ',
          style: ShiaText.secondary.copyWith(color: colors.textMuted),
        ),
        TextSpan(
          text: airport == null
              ? context.l10n.flightChooseAirport
              : '${airport.iata} · ${airport.locationLabel}',
          style: airport == null
              ? TextStyle(color: colors.accent, fontWeight: FontWeight.w600)
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
      ])),
      subtitle: airport == null ? null : Text(airport.name),
      trailing: const _RowChevron(),
      onTap: onTap,
    );
  }
}

/// "Departs" or "Arrives": the local date and time, or a prompt to set it.
class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.airport,
    required this.onTap,
    this.first = false,
    this.last = false,
  });

  final String label;
  final String hint;
  final DateTime? value;
  final Airport? airport;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final value = this.value;
    final airport = this.airport;
    return CardListRow(
      first: first,
      last: last,
      minHeight: 64,
      leading: const _GlyphWell(OutlineGlyph.clock),
      title: Text.rich(TextSpan(children: [
        TextSpan(
          text: '$label  ',
          style: ShiaText.secondary.copyWith(color: colors.textMuted),
        ),
        TextSpan(
          text: value == null
              ? context.l10n.flightChooseDateTime
              : formatWallClock(value),
          style: value == null
              ? TextStyle(color: colors.accent, fontWeight: FontWeight.w600)
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
      ])),
      subtitle: Text(airport == null
          ? hint
          : '$hint · ${context.l10n.flightAirportTime(airport.iata)}'),
      trailing: const _RowChevron(),
      onTap: onTap,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.danger),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlineIcon(OutlineGlyph.alert, size: 20, color: colors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: ShiaText.secondary.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
