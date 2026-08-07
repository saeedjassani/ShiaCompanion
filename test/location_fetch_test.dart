import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    lat = null;
    long = null;
    city = null;
    needToSchedule = false;
  });

  Position _pos(double latitude, double longitude) => Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime(2020, 1, 1),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );

  Future<void> runWithGeocode(
    String? geocodeBody, {
    Object? geocodeError,
    required Future<void> Function() body,
  }) async {
    await http.runWithClient(
      body,
      () => MockClient((request) async {
        if (request.url.toString().contains('bigdatacloud')) {
          if (geocodeError != null) throw geocodeError;
          return http.Response(geocodeBody ?? '', 200);
        }
        return http.Response('', 404);
      }),
    );
  }

  group('#2 last-known position fallback', () {
    test('uses last known position when a fresh fix times out', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPositionError: TimeoutException('timed out'),
        lastKnownPosition: _pos(12.34, 56.78),
      );

      await runWithGeocode(
        '{"locality":"Fallback City","city":"Fallback City",'
        '"principalSubdivision":"Fallback Region","countryName":"Fallback Country",'
        '"countryCode":"US","localityInfo":{"administrative":'
        '[{"adminLevel":4,"name":"Fallback Region"},'
        '{"adminLevel":2,"name":"Fallback Country"}]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(lat, 12.34);
          expect(long, 56.78);
          expect(city, 'Fallback City');
        },
      );
    });

    test('fails when fresh fix errors and no last known position exists',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPositionError: TimeoutException('timed out'),
        lastKnownPosition: null,
      );

      await runWithGeocode(
        null,
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isFalse);
          expect(lat, isNull);
          expect(long, isNull);
        },
      );
    });

    test('falls back to last known position on a non-timeout failure',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPositionError: Exception('gps unavailable'),
        lastKnownPosition: _pos(9.87, 6.54),
      );

      await runWithGeocode(
        '{"locality":"Recovered City","city":"Recovered City",'
        '"principalSubdivision":"Recovered Region","countryName":"Recovered Country",'
        '"countryCode":"US","localityInfo":{"administrative":'
        '[{"adminLevel":4,"name":"Recovered Region"},'
        '{"adminLevel":2,"name":"Recovered Country"}]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(lat, 9.87);
          expect(long, 6.54);
        },
      );
    });
  });

  group('#3 geocode fallback label', () {
    test('updates city to resolved name when geocode is valid', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(40.71, -74.0),
      );

      await runWithGeocode(
        '{"locality":"New York","city":"New York",'
        '"principalSubdivision":"New York","countryName":"United States",'
        '"countryCode":"US","localityInfo":{"administrative":'
        '[{"adminLevel":4,"name":"New York"},'
        '{"adminLevel":2,"name":"United States"}]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(city, 'New York');
          expect(city, isNot('Old City'));
        },
      );
    });

    test('resolves the locality (not subdivision) using the real adminLevel schema',
        () async {
      // Mirrors the actual BigDataCloud client response shape, where admin
      // levels are integers (2=country, 4=state, 8=city) under `adminLevel`.
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(37.3861, -122.0839),
      );

      await runWithGeocode(
        '{"locality":"Mountain View","city":"San Jose",'
        '"principalSubdivision":"California","countryName":"United States",'
        '"countryCode":"US","localityInfo":{"administrative":'
        '[{"adminLevel":2,"name":"United States"},'
        '{"adminLevel":4,"name":"California"},'
        '{"adminLevel":8,"name":"Mountain View"}]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(city, 'Mountain View');
          expect(city, isNot('California'));
        },
      );
    });

    test('keeps a sparse administrative tree from rejecting a real city',
        () async {
      city = 'Old City';
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(26.22, 50.58),
      );

      // City-states and small territories report a shallow admin hierarchy with
      // no country/subdivision entry. The locality is still the right label.
      await runWithGeocode(
        '{"locality":"Manama","city":"Manama",'
        '"principalSubdivision":"Capital","countryName":"Bahrain",'
        '"countryCode":"BH","localityInfo":{"administrative":'
        '[{"adminLevel":8,"name":"Manama"}]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(city, 'Manama');
        },
      );
    });

    test('widens to the next available label when there is no locality',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(1.0, 2.0),
      );

      await runWithGeocode(
        '{"locality":"","city":"",'
        '"principalSubdivision":"Region X","countryName":"Country Y",'
        '"countryCode":"US","localityInfo":{"administrative":[]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(city, 'Region X');
        },
      );
    });

    test('rejects an ocean fix with no country code', () async {
      city = 'Old City';
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(0.0, 0.0),
      );

      // What an emulator parked at Null Island returns: a plausible-looking
      // ocean name, but no country. The previous label must survive.
      await runWithGeocode(
        '{"locality":"Atlantic Ocean","city":"",'
        '"principalSubdivision":"","countryName":"",'
        '"countryCode":"","localityInfo":{"administrative":[]}}',
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(city, 'Old City');
        },
      );
    });

    test('never degrades the saved city to coordinates when geocode fails',
        () async {
      city = 'Stable City';
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(3.0, 4.0),
      );

      // This label is published to the home screen widget and the watch
      // complication, so a transient network failure must not rewrite it.
      await runWithGeocode(
        null,
        geocodeError: Exception('no network'),
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(city, 'Stable City');
        },
      );
    });

    test('leaves the city unset when the first ever geocode fails', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        currentPosition: _pos(3.0, 4.0),
      );

      await runWithGeocode(
        null,
        geocodeError: Exception('no network'),
        body: () async {
          final success = await initializeLocation(force: true);

          expect(success, isTrue);
          expect(lat, 3.0);
          expect(city, isNull);
        },
      );
    });
  });
}

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.lastKnownPosition,
    this.currentPosition,
    this.currentPositionError,
  });

  final Position? lastKnownPosition;
  final Position? currentPosition;
  final Object? currentPositionError;

  @override
  Future<bool> isLocationServiceEnabled() => Future.value(true);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    if (currentPositionError != null) throw currentPositionError!;
    if (currentPosition == null) {
      throw StateError('currentPosition not configured');
    }
    return currentPosition!;
  }

  @override
  Future<Position?> getLastKnownPosition(
          {bool forceLocationManager = false}) =>
      Future.value(lastKnownPosition);
}
