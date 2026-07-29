import 'package:timezone/timezone.dart' as tz;

import '../utils/timezone_database.dart';
import 'airport.dart';

/// A flight the user has saved, used to work out prayer times en route.
///
/// Departure and arrival are stored as *wall clock* times — exactly what is
/// printed on a boarding pass — together with the airports they belong to.
/// The UTC instants are derived from the airports' time zones, which is what
/// makes "10:35 pm SFO" and "8:15 pm IST" line up on one timeline.
///
/// The airports are stored in full rather than by code. A saved flight is then
/// self-contained: it keeps working if the bundled airport database changes,
/// if an airport is looked up from somewhere else in future, and — the case
/// that matters most here — when the phone is offline at 38,000 feet.
class Flight {
  const Flight({
    required this.id,
    required this.origin,
    required this.destination,
    required this.departureLocal,
    required this.arrivalLocal,
    this.flightNumber,
  });

  final String id;
  final Airport origin;
  final Airport destination;

  /// Scheduled departure as shown at the origin airport (local wall clock).
  final DateTime departureLocal;

  /// Scheduled arrival as shown at the destination airport (local wall clock).
  final DateTime arrivalLocal;

  /// Optional label such as `TK 80`.
  final String? flightNumber;

  String get routeLabel => '${origin.iata} → ${destination.iata}';

  Flight copyWith({
    Airport? origin,
    Airport? destination,
    DateTime? departureLocal,
    DateTime? arrivalLocal,
    String? flightNumber,
  }) {
    return Flight(
      id: id,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureLocal: departureLocal ?? this.departureLocal,
      arrivalLocal: arrivalLocal ?? this.arrivalLocal,
      flightNumber: flightNumber ?? this.flightNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'departure': _encodeWallClock(departureLocal),
        'arrival': _encodeWallClock(arrivalLocal),
        if (flightNumber != null && flightNumber!.isNotEmpty)
          'flightNumber': flightNumber,
      };

  /// [resolveIata] upgrades flights written before airports were stored in
  /// full, when only the IATA code was persisted.
  static Flight? fromJson(
    Map<String, dynamic> json, {
    Airport? Function(String iata)? resolveIata,
  }) {
    final id = json['id'];
    final origin = _decodeAirport(json['origin'], resolveIata);
    final destination = _decodeAirport(json['destination'], resolveIata);
    final departure = _decodeWallClock(json['departure']);
    final arrival = _decodeWallClock(json['arrival']);

    if (id is! String ||
        origin == null ||
        destination == null ||
        departure == null ||
        arrival == null) {
      return null;
    }

    final flightNumber = json['flightNumber'];
    return Flight(
      id: id,
      origin: origin,
      destination: destination,
      departureLocal: departure,
      arrivalLocal: arrival,
      flightNumber: flightNumber is String && flightNumber.isNotEmpty
          ? flightNumber
          : null,
    );
  }

  static Airport? _decodeAirport(
    Object? value,
    Airport? Function(String iata)? resolveIata,
  ) {
    if (value is Map) return Airport.fromJson(Map<String, dynamic>.from(value));
    if (value is String) return resolveIata?.call(value);
    return null;
  }

  /// Wall-clock times are serialized without a zone suffix on purpose: they are
  /// only meaningful alongside their airport.
  static String _encodeWallClock(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
        '${two(value.day)}T${two(value.hour)}:${two(value.minute)}';
  }

  static DateTime? _decodeWallClock(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    // Strip any zone information a previous version may have written.
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
    );
  }
}

/// A [Flight] placed onto the UTC timeline.
///
/// Constructed through [ResolvedFlight.resolve], which returns null only when
/// an airport's time zone is missing from the bundled time zone database.
class ResolvedFlight {
  const ResolvedFlight._({
    required this.flight,
    required this.originLocation,
    required this.destinationLocation,
    required this.departureUtc,
    required this.arrivalUtc,
  });

  final Flight flight;
  final tz.Location originLocation;
  final tz.Location destinationLocation;
  final DateTime departureUtc;
  final DateTime arrivalUtc;

  Airport get origin => flight.origin;
  Airport get destination => flight.destination;

  static ResolvedFlight? resolve(Flight flight) {
    final originLocation = tryGetLocation(flight.origin.timeZoneId);
    final destinationLocation = tryGetLocation(flight.destination.timeZoneId);
    if (originLocation == null || destinationLocation == null) return null;

    return ResolvedFlight._(
      flight: flight,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
      departureUtc: _toUtc(originLocation, flight.departureLocal),
      arrivalUtc: _toUtc(destinationLocation, flight.arrivalLocal),
    );
  }

  Duration get duration => arrivalUtc.difference(departureUtc);

  /// A flight must go forwards in time and, in practice, take less than a day.
  /// Anything else means the arrival date was entered wrong — the classic
  /// mistake being an overnight flight recorded as landing the same day.
  bool get hasPlausibleDuration =>
      duration > Duration.zero && duration < const Duration(hours: 24);

  String get routeLabel => flight.routeLabel;

  static DateTime _toUtc(tz.Location location, DateTime wallClock) {
    return tz.TZDateTime(
      location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    ).toUtc();
  }
}
