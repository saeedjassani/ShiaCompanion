import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/airport.dart';
import 'package:shia_companion/services/airport_repository.dart';
import 'package:shia_companion/utils/timezone_database.dart';

void main() {
  late List<Airport> airports;

  setUpAll(() {
    // Read the shipped asset straight off disk: the point of these tests is
    // that the real database is well formed and searchable.
    airports = Airport.parseDatabase(
      File(AirportRepository.assetPath).readAsStringSync(),
    );
    AirportRepository.instance.seedForTesting(airports);
    ensureTimeZoneDatabaseInitialized();
  });

  group('bundled airport database', () {
    test('parses a substantial number of airports', () {
      expect(airports.length, greaterThan(5000));
    });

    test('IATA codes are unique, so lookups are unambiguous', () {
      final codes = <String>{};
      final duplicates = <String>[];
      for (final airport in airports) {
        if (!codes.add(airport.iata)) duplicates.add(airport.iata);
      }
      expect(duplicates, isEmpty);
    });

    test('every entry has usable coordinates and a resolvable time zone', () {
      for (final airport in airports) {
        expect(airport.latitude, inInclusiveRange(-90, 90),
            reason: airport.iata);
        expect(airport.longitude, inInclusiveRange(-180, 180),
            reason: airport.iata);
        expect(tryGetLocation(airport.timeZoneId), isNotNull,
            reason: '${airport.iata} has unknown zone ${airport.timeZoneId}');
      }
    });

    test('includes the airports this feature exists for', () {
      const expected = {
        'SFO': 'America/Los_Angeles',
        'IST': 'Europe/Istanbul',
        'JFK': 'America/New_York',
        'LHR': 'Europe/London',
        'DXB': 'Asia/Dubai',
        'NJF': 'Asia/Baghdad', // Najaf
        'BGW': 'Asia/Baghdad', // Baghdad
        'MHD': 'Asia/Tehran', // Mashhad
        'JED': 'Asia/Riyadh', // Jeddah
        'KHI': 'Asia/Karachi',
        'BOM': 'Asia/Kolkata',
        // Stored canonically: Africa/Dar_es_Salaam is a tzdb link to Nairobi.
        'DAR': 'Africa/Nairobi',
      };

      for (final entry in expected.entries) {
        final airport = AirportRepository.instance.byIata(entry.key);
        expect(airport, isNotNull, reason: 'missing ${entry.key}');
        expect(airport!.timeZoneId, entry.value, reason: entry.key);
      }
    });
  });

  group('search', () {
    test('an exact code match ranks first', () {
      expect(AirportRepository.instance.search('IST').first.iata, 'IST');
      expect(AirportRepository.instance.search('SFO').first.iata, 'SFO');
      expect(AirportRepository.instance.search('jfk').first.iata, 'JFK');
    });

    test('finds airports by city and by country', () {
      final istanbul = AirportRepository.instance.search('Istanbul');
      expect(istanbul.map((a) => a.iata), contains('SAW'));

      final iraq = AirportRepository.instance.search('Iraq');
      expect(iraq.map((a) => a.iata), contains('NJF'));
    });

    test('matches airport names', () {
      final results = AirportRepository.instance.search('Imam Khomeini');
      expect(results.first.iata, 'IKA');
    });

    test('is case insensitive and ignores surrounding whitespace', () {
      expect(AirportRepository.instance.search('  ist  ').first.iata, 'IST');
    });

    test('returns nothing for an empty or unmatched query', () {
      expect(AirportRepository.instance.search(''), isEmpty);
      expect(AirportRepository.instance.search('   '), isEmpty);
      expect(AirportRepository.instance.search('zzzzznotanairport'), isEmpty);
    });

    test('respects the result limit', () {
      expect(
        AirportRepository.instance.search('a', limit: 5).length,
        lessThanOrEqualTo(5),
      );
    });

    test('byIata is case insensitive and null-safe', () {
      expect(AirportRepository.instance.byIata('sfo')?.iata, 'SFO');
      expect(AirportRepository.instance.byIata(null), isNull);
      expect(AirportRepository.instance.byIata(''), isNull);
      expect(AirportRepository.instance.byIata('ZZZ'), isNull);
    });
  });
}
