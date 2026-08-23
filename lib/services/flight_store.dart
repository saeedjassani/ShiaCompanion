import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/airport.dart';
import '../models/flight.dart';
import '../utils/shared_preferences.dart';
import 'airport_repository.dart';
import '../services/analytics_service.dart';

/// Local persistence for saved flights.
///
/// Flights are short lived and device specific, so they live in shared
/// preferences rather than syncing through Firestore like favorites do.
class FlightStore extends ChangeNotifier {
  FlightStore._();

  static final FlightStore instance = FlightStore._();

  static const String storageKey = 'saved_flights_v1';

  List<Flight> _flights = const [];
  bool _hasLoaded = false;

  bool get hasLoaded => _hasLoaded;

  /// Saved flights, soonest departure first.
  List<Flight> get flights => List.unmodifiable(_flights);

  void load() {
    if (_hasLoaded) return;
    _hasLoaded = true;
    if (!SP.isInitialized) return;

    _flights = decode(SP.prefs.getString(storageKey));
    notifyListeners();
  }

  Future<void> save(Flight flight) async {
    final next = [..._flights];
    final index = next.indexWhere((existing) => existing.id == flight.id);
    if (index >= 0) {
      next[index] = flight;
    } else {
      next.add(flight);
    }
    unawaited(AnalyticsService.feature(
      index >= 0 ? 'flight_edited' : 'flight_added',
      label: index >= 0 ? 'Flight edited' : 'Flight added',
    ));
    await _persist(next);
  }

  Future<void> delete(String id) async {
    await _persist(
      _flights.where((flight) => flight.id != id).toList(growable: false),
    );
  }

  Future<void> _persist(List<Flight> flights) async {
    final sorted = sortByDeparture(flights);
    _flights = sorted;
    _hasLoaded = true;
    notifyListeners();

    if (!SP.isInitialized) return;
    await SP.prefs.setString(storageKey, encode(sorted));
  }

  static List<Flight> sortByDeparture(List<Flight> flights) {
    final sorted = [...flights]
      ..sort((a, b) => a.departureLocal.compareTo(b.departureLocal));
    return List.unmodifiable(sorted);
  }

  static String encode(List<Flight> flights) {
    return jsonEncode([for (final flight in flights) flight.toJson()]);
  }

  /// Tolerant of anything that is not a well-formed flight list: a corrupt or
  /// partially written entry drops out instead of breaking the whole page.
  ///
  /// [resolveIata] upgrades flights saved before airports were stored in full;
  /// it defaults to the bundled database.
  static List<Flight> decode(
    String? raw, {
    Airport? Function(String iata)? resolveIata,
  }) {
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final lookup = resolveIata ?? AirportRepository.instance.byIata;
      final flights = <Flight>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final flight = Flight.fromJson(
          Map<String, dynamic>.from(entry),
          resolveIata: lookup,
        );
        if (flight != null) flights.add(flight);
      }
      return sortByDeparture(flights);
    } catch (e) {
      debugPrint('Unable to decode saved flights: $e');
      return const [];
    }
  }

  /// Replaces in-memory state without touching storage. Used by tests.
  @visibleForTesting
  void resetForTesting({List<Flight> flights = const []}) {
    _flights = FlightStore.sortByDeparture(flights);
    _hasLoaded = true;
  }
}
