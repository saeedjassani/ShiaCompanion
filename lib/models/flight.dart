import 'package:timezone/timezone.dart' as tz;

import '../utils/timezone_database.dart';
import 'airport.dart';

/// A flight the user has saved, used to work out prayer times en route.
///
/// Departure and arrival are stored as *wall clock* times — exactly what is
/// printed on a boarding pass — together with the airports they belong to.
/// The UTC instants are derived from the airports' time zones, which is what
/// makes "10:35 pm SFO" and "8:15 pm IST" line up on one timeline.
class Flight {
  const Flight({
    required this.id,
    required this.originIata,
    required this.destinationIata,
    required this.departureLocal,
    required this.arrivalLocal,
    this.flightNumber,
  });

  final String id;
  final String originIata;
  final String destinationIata;

  /// Scheduled departure as shown at the origin airport (local wall clock).
  final DateTime departureLocal;

  /// Scheduled arrival as shown at the destination airport (local wall clock).
  final DateTime arrivalLocal;

  /// Optional label such as `TK 80`.
  final String? flightNumber;

  Flight copyWith({
    String? originIata,
    String? destinationIata,
    DateTime? departureLocal,
    DateTime? arrivalLocal,
    String? flightNumber,
  }) {
    return Flight(
      id: id,
      originIata: originIata ?? this.originIata,
      destinationIata: destinationIata ?? this.destinationIata,
      departureLocal: departureLocal ?? this.departureLocal,
      arrivalLocal: arrivalLocal ?? this.arrivalLocal,
      flightNumber: flightNumber ?? this.flightNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': originIata,
        'destination': destinationIata,
        'departure': _encodeWallClock(departureLocal),
        'arrival': _encodeWallClock(arrivalLocal),
        if (flightNumber != null && flightNumber!.isNotEmpty)
          'flightNumber': flightNumber,
      };

  static Flight? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final origin = json['origin'];
    final destination = json['destination'];
    final departure = _decodeWallClock(json['departure']);
    final arrival = _decodeWallClock(json['arrival']);

    if (id is! String ||
        origin is! String ||
        destination is! String ||
        departure == null ||
        arrival == null) {
      return null;
    }

    final flightNumber = json['flightNumber'];
    return Flight(
      id: id,
      originIata: origin,
      destinationIata: destination,
      departureLocal: departure,
      arrivalLocal: arrival,
      flightNumber: flightNumber is String && flightNumber.isNotEmpty
          ? flightNumber
          : null,
    );
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

/// A [Flight] joined to its airports and resolved onto the UTC timeline.
///
/// Constructed through [ResolvedFlight.resolve], which returns null when either
/// airport or time zone is missing from the bundled database.
class ResolvedFlight {
  const ResolvedFlight._({
    required this.flight,
    required this.origin,
    required this.destination,
    required this.originLocation,
    required this.destinationLocation,
    required this.departureUtc,
    required this.arrivalUtc,
  });

  final Flight flight;
  final Airport origin;
  final Airport destination;
  final tz.Location originLocation;
  final tz.Location destinationLocation;
  final DateTime departureUtc;
  final DateTime arrivalUtc;

  static ResolvedFlight? resolve(
    Flight flight, {
    required Airport? Function(String iata) lookup,
  }) {
    final origin = lookup(flight.originIata);
    final destination = lookup(flight.destinationIata);
    if (origin == null || destination == null) return null;

    final originLocation = tryGetLocation(origin.timeZoneId);
    final destinationLocation = tryGetLocation(destination.timeZoneId);
    if (originLocation == null || destinationLocation == null) return null;

    return ResolvedFlight._(
      flight: flight,
      origin: origin,
      destination: destination,
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

  String get routeLabel => '${origin.iata} → ${destination.iata}';

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
