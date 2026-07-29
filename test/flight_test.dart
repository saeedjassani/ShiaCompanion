import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/airport.dart';
import 'package:shia_companion/models/flight.dart';
import 'package:shia_companion/services/flight_store.dart';
import 'package:shia_companion/utils/flight_formatting.dart';
import 'package:shia_companion/utils/timezone_database.dart';

const _sfoLine = 'SFO\tKSFO\tSan Francisco International Airport\t'
    'San Francisco\tUnited States\t37.6190\t-122.3750\tAmerica/Los_Angeles';
const _istLine = 'IST\tLTFM\tIstanbul Airport\tArnavutkoy\tTurkey\t'
    '41.2622\t28.7278\tEurope/Istanbul';

Airport? _lookup(String iata) {
  switch (iata) {
    case 'SFO':
      return Airport.tryParseLine(_sfoLine);
    case 'IST':
      return Airport.tryParseLine(_istLine);
    default:
      return null;
  }
}

Flight _sfoToIstanbul() => Flight(
      id: 'test-flight',
      originIata: 'SFO',
      destinationIata: 'IST',
      // TK 80: leaves SFO 19:55 and lands in Istanbul 19:05 the next day.
      departureLocal: DateTime(2026, 7, 30, 19, 55),
      arrivalLocal: DateTime(2026, 7, 31, 19, 5),
      flightNumber: 'TK 80',
    );

void main() {
  setUpAll(ensureTimeZoneDatabaseInitialized);

  group('Airport', () {
    test('parses a well formed line', () {
      final airport = Airport.tryParseLine(_sfoLine)!;

      expect(airport.iata, 'SFO');
      expect(airport.icao, 'KSFO');
      expect(airport.city, 'San Francisco');
      expect(airport.latitude, closeTo(37.619, 1e-6));
      expect(airport.longitude, closeTo(-122.375, 1e-6));
      expect(airport.timeZoneId, 'America/Los_Angeles');
      expect(airport.locationLabel, 'San Francisco, United States');
    });

    test('rejects malformed lines instead of throwing', () {
      expect(Airport.tryParseLine(''), isNull);
      expect(Airport.tryParseLine('SFO\tKSFO\tName'), isNull);
      expect(
        Airport.tryParseLine('SFO\tKSFO\tName\tCity\tUS\tnope\t-122\tUTC'),
        isNull,
      );
    });

    test('parses a database and skips blank lines', () {
      final airports = Airport.parseDatabase('$_sfoLine\n\n$_istLine\n');
      expect(airports.map((a) => a.iata), ['SFO', 'IST']);
    });

    test('falls back to the airport name when there is no city', () {
      final airport = Airport.tryParseLine(
        'AAA\tNTGA\tAnaa Airport\t\tFrench Polynesia\t-17.35\t-145.51\t'
        'Pacific/Tahiti',
      )!;
      expect(airport.locationLabel, 'Anaa Airport, French Polynesia');
    });
  });

  group('Flight serialization', () {
    test('round-trips through JSON', () {
      final flight = _sfoToIstanbul();
      final restored = Flight.fromJson(flight.toJson())!;

      expect(restored.id, flight.id);
      expect(restored.originIata, 'SFO');
      expect(restored.destinationIata, 'IST');
      expect(restored.departureLocal, flight.departureLocal);
      expect(restored.arrivalLocal, flight.arrivalLocal);
      expect(restored.flightNumber, 'TK 80');
    });

    test('keeps departure a wall clock, with no zone attached', () {
      final json = _sfoToIstanbul().toJson();
      expect(json['departure'], '2026-07-30T19:55');
      expect(json['arrival'], '2026-07-31T19:05');
    });

    test('drops a zone suffix written by an older build', () {
      final restored = Flight.fromJson({
        'id': 'x',
        'origin': 'SFO',
        'destination': 'IST',
        'departure': '2026-07-30T19:55:00Z',
        'arrival': '2026-07-31T19:05:00Z',
      })!;

      expect(restored.departureLocal, DateTime(2026, 7, 30, 19, 55));
      expect(restored.departureLocal.isUtc, isFalse);
    });

    test('returns null for incomplete records', () {
      expect(Flight.fromJson({'id': 'x'}), isNull);
      expect(
        Flight.fromJson({'id': 'x', 'origin': 'SFO', 'destination': 'IST'}),
        isNull,
      );
    });
  });

  group('ResolvedFlight', () {
    test('places each wall clock on the UTC timeline via its own zone', () {
      final resolved = ResolvedFlight.resolve(_sfoToIstanbul(),
          lookup: _lookup)!;

      // 19:55 PDT (UTC-7) on 30 July.
      expect(resolved.departureUtc, DateTime.utc(2026, 7, 31, 2, 55));
      // 19:05 TRT (UTC+3) on 31 July.
      expect(resolved.arrivalUtc, DateTime.utc(2026, 7, 31, 16, 5));
      expect(resolved.duration, const Duration(hours: 13, minutes: 10));
      expect(resolved.hasPlausibleDuration, isTrue);
      expect(resolved.routeLabel, 'SFO → IST');
    });

    test('returns null when an airport is unknown', () {
      final flight = _sfoToIstanbul().copyWith(destinationIata: 'ZZZ');
      expect(ResolvedFlight.resolve(flight, lookup: _lookup), isNull);
    });

    test('flags an overnight flight recorded as landing the same day', () {
      // The classic data-entry mistake: arrival date left on the departure day.
      final flight = _sfoToIstanbul()
          .copyWith(arrivalLocal: DateTime(2026, 7, 30, 19, 5));
      final resolved = ResolvedFlight.resolve(flight, lookup: _lookup)!;

      expect(resolved.duration.isNegative, isTrue);
      expect(resolved.hasPlausibleDuration, isFalse);
    });
  });

  group('FlightStore encoding', () {
    test('round-trips a list of flights', () {
      final flights = [_sfoToIstanbul()];
      expect(
        FlightStore.decode(FlightStore.encode(flights)).single.id,
        'test-flight',
      );
    });

    test('sorts by departure', () {
      final later = _sfoToIstanbul();
      final earlier = Flight(
        id: 'earlier',
        originIata: 'IST',
        destinationIata: 'SFO',
        departureLocal: DateTime(2026, 7, 1, 8),
        arrivalLocal: DateTime(2026, 7, 1, 14),
      );

      final sorted = FlightStore.decode(FlightStore.encode([later, earlier]));
      expect(sorted.map((flight) => flight.id), ['earlier', 'test-flight']);
    });

    test('survives corrupt storage instead of breaking the page', () {
      expect(FlightStore.decode(null), isEmpty);
      expect(FlightStore.decode(''), isEmpty);
      expect(FlightStore.decode('not json'), isEmpty);
      expect(FlightStore.decode('{"not":"a list"}'), isEmpty);
      // A bad entry drops out; the good one survives.
      expect(
        FlightStore.decode('[{"id":"broken"},'
            '{"id":"ok","origin":"SFO","destination":"IST",'
            '"departure":"2026-07-30T19:55","arrival":"2026-07-31T19:05"}]'),
        hasLength(1),
      );
    });
  });

  group('formatting', () {
    test('formats clocks in 12 hour time', () {
      expect(formatClock12(DateTime(2026, 7, 30, 0, 5)), '12:05 am');
      expect(formatClock12(DateTime(2026, 7, 30, 12, 0)), '12:00 pm');
      expect(formatClock12(DateTime(2026, 7, 30, 19, 55)), '7:55 pm');
    });

    test('formats dates and durations', () {
      expect(formatShortDate(DateTime(2026, 7, 30)), 'Thu 30 Jul');
      expect(formatWallClock(DateTime(2026, 7, 30, 19, 55)),
          'Thu 30 Jul, 7:55 pm');
      expect(formatFlightDuration(const Duration(hours: 13, minutes: 10)),
          '13h 10m');
      expect(formatFlightDuration(const Duration(minutes: 45)), '45m');
      expect(formatFlightDuration(const Duration(hours: 2)), '2h');
    });

    test('formats distances with thousands separators', () {
      expect(formatDistanceKm(10766.4), '10,766 km');
      expect(formatDistanceKm(842.2), '842 km');
      expect(formatDistanceKm(0), '0 km');
    });

    test('reports day offsets so a next-day prayer is unmistakable', () {
      final departure = DateTime(2026, 7, 30, 19, 55);
      expect(formatDayOffset(departure, DateTime(2026, 7, 30, 23, 0)), isNull);
      expect(formatDayOffset(departure, DateTime(2026, 7, 31, 1, 0)), '+1 day');
      expect(formatDayOffset(departure, DateTime(2026, 8, 1, 1, 0)), '+2 days');
      expect(formatDayOffset(departure, DateTime(2026, 7, 29, 1, 0)), '-1 day');
    });
  });
}
