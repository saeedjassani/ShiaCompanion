import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../models/airport.dart';

/// Loads and searches the bundled airport database.
///
/// The asset is ~650 KB of tab separated text, parsed once on first use and
/// held in memory afterwards. Lookups are by IATA code; search is a plain
/// substring match over precomputed lowercase text, which is fast enough for
/// per-keystroke filtering of ~8000 rows.
class AirportRepository {
  AirportRepository._();

  static final AirportRepository instance = AirportRepository._();

  static const String assetPath = 'assets/airports.tsv';

  List<Airport>? _airports;
  Map<String, Airport>? _byIata;
  List<String>? _haystacks;
  Future<void>? _loadFuture;

  bool get isLoaded => _airports != null;

  Future<void> load() {
    // A fresh future rather than a cached one, so the callback is scheduled in
    // the caller's zone. Reusing a completed future across zones leaves
    // `.then` callbacks stranded under `flutter_test`'s fake async.
    if (isLoaded) return Future.value();

    final existing = _loadFuture;
    if (existing != null) return existing;

    final future = _loadInternal();
    _loadFuture = future;
    return future;
  }

  Future<void> _loadInternal() async {
    final contents = await rootBundle.loadString(assetPath);
    _adopt(Airport.parseDatabase(contents));
  }

  /// Seeds the repository directly, bypassing the asset bundle. Used by tests.
  @visibleForTesting
  void seedForTesting(List<Airport> airports) => _adopt(airports);

  void _adopt(List<Airport> airports) {
    _airports = List.unmodifiable(airports);
    _byIata = {for (final airport in airports) airport.iata: airport};
    _haystacks = [
      for (final airport in airports) airport.searchHaystack,
    ];
  }

  Airport? byIata(String? iata) {
    if (iata == null || iata.isEmpty) return null;
    return _byIata?[iata.toUpperCase()];
  }

  /// Ranked substring search over code, name, city and country.
  ///
  /// An exact IATA match always sorts first, then prefix matches on the code,
  /// then everything else alphabetically by code — so typing "IST" puts
  /// Istanbul Airport at the top instead of burying it under airports whose
  /// description merely contains those letters.
  List<Airport> search(String query, {int limit = 40}) {
    final airports = _airports;
    final haystacks = _haystacks;
    if (airports == null || haystacks == null) return const [];

    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    final matches = <_ScoredAirport>[];
    for (var index = 0; index < airports.length; index++) {
      if (!haystacks[index].contains(trimmed)) continue;

      final airport = airports[index];
      final code = airport.iata.toLowerCase();
      final int score;
      if (code == trimmed) {
        score = 0;
      } else if (code.startsWith(trimmed)) {
        score = 1;
      } else if (airport.city.toLowerCase().startsWith(trimmed)) {
        score = 2;
      } else if (airport.name.toLowerCase().startsWith(trimmed)) {
        score = 3;
      } else {
        score = 4;
      }
      matches.add(_ScoredAirport(airport, score));
    }

    matches.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      return byScore != 0 ? byScore : a.airport.iata.compareTo(b.airport.iata);
    });

    return [
      for (final match in matches.take(limit)) match.airport,
    ];
  }
}

class _ScoredAirport {
  const _ScoredAirport(this.airport, this.score);

  final Airport airport;
  final int score;
}
