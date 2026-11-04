import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/l10n.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/services/location_service.dart';
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
    L10n.current = lookupAppLocalizations(const Locale('en'));
  });

  Position _pos(double latitude, double longitude) => Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
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

    test(
        'resolves the locality (not subdivision) using the real adminLevel schema',
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

  group('place name in the app language', () {
    Future<List<Uri>> geocodeRequests(
      Map<String, String> bodiesByLanguage,
      Future<void> Function() body,
    ) async {
      final requests = <Uri>[];
      await http.runWithClient(
        body,
        () => MockClient((request) async {
          requests.add(request.url);
          final language = request.url.queryParameters['localityLanguage'];
          return http.Response.bytes(
              utf8.encode(bodiesByLanguage[language] ?? ''), 200);
        }),
      );
      return requests;
    }

    const karbala = {
      'en': '{"locality":"Karbala","city":"Karbala","countryCode":"IQ"}',
      'ur': '{"locality":"کربلا","city":"کربلا","countryCode":"IQ"}',
    };

    test('asks for the name in the app language and remembers which', () async {
      L10n.current = lookupAppLocalizations(const Locale('ur'));
      GeolocatorPlatform.instance =
          _FakeGeolocator(currentPosition: _pos(32.6, 44.0));

      final requests = await geocodeRequests(karbala, () async {
        expect(await initializeLocation(force: true), isTrue);
      });

      expect(requests.single.queryParameters['localityLanguage'], 'ur');
      expect(city, 'کربلا');
      expect(cityLabelLanguage, 'ur');
    });

    test('prefers the city in the reader\'s script over an English locality',
        () async {
      L10n.current = lookupAppLocalizations(const Locale('gu'));
      GeolocatorPlatform.instance =
          _FakeGeolocator(currentPosition: _pos(24.86, 67.01));

      await geocodeRequests({
        'gu': '{"locality":"Lyari Town","city":"કરાચી","countryCode":"PK"}',
      }, () => initializeLocation(force: true));

      expect(city, 'કરાચી');
    });

    test('drops a trailing disambiguator from the name', () async {
      L10n.current = lookupAppLocalizations(const Locale('ur'));
      GeolocatorPlatform.instance =
          _FakeGeolocator(currentPosition: _pos(21.17, 72.83));

      await geocodeRequests({
        'ur':
            '{"locality":"سورت (شہر)","city":"سورت (شہر)","countryCode":"IN"}',
      }, () => initializeLocation(force: true));

      expect(city, 'سورت');
    });

    test('renames the stored GPS location when the language changes', () async {
      lat = 32.6;
      long = 44.0;
      city = 'Karbala';
      LocationService.instance.restore();
      L10n.current = lookupAppLocalizations(const Locale('ur'));

      final requests = await geocodeRequests(karbala, () async {
        await LocationService.instance.relabelForAppLanguage();
        // Already in Urdu: nothing more to fetch.
        await LocationService.instance.relabelForAppLanguage();
      });

      expect(requests, hasLength(1));
      expect(city, 'کربلا');
      expect(cityLabelLanguage, 'ur');
    });

    test('offline, takes the name from the city list in the new language',
        () async {
      lat = 32.6;
      long = 44.0;
      city = 'Karbala';
      LocationService.instance.restore();
      L10n.current = lookupAppLocalizations(const Locale('ur'));

      await runWithGeocode(null,
          geocodeError: Exception('no network'),
          body: () => LocationService.instance.relabelForAppLanguage());

      expect(city, 'کربلا');
      expect(cityLabelLanguage, 'ur');
    });

    test(
        'keeps the old name, and tries again later, offline where the list '
        'has no city near', () async {
      // Out in the Arabian Sea.
      lat = 15.0;
      long = 62.0;
      city = 'Karbala';
      LocationService.instance.restore();
      L10n.current = lookupAppLocalizations(const Locale('ur'));

      await runWithGeocode(null,
          geocodeError: Exception('no network'),
          body: () => LocationService.instance.relabelForAppLanguage());

      expect(city, 'Karbala');
      expect(cityLabelLanguage, 'en');
    });

    Future<void> chooseKarbala({required double latitude}) async {
      lat = latitude;
      long = 44.02;
      city = 'Karbala';
      SharedPreferences.setMockInitialValues({LocationService.manualKey: true});
      await SP.init();
      LocationService.instance.restore();
      L10n.current = lookupAppLocalizations(const Locale('ur'));
    }

    test('names a chosen city from the list, offline', () async {
      await chooseKarbala(latitude: 32.62);

      final requests = await geocodeRequests(
          karbala, () => LocationService.instance.relabelForAppLanguage());

      expect(requests, isEmpty);
      expect(city, 'کربلا');
      expect(cityLabelLanguage, 'ur');
    });

    test('keeps a chosen place the list does not have as it is', () async {
      await chooseKarbala(latitude: 10.5);

      final requests = await geocodeRequests(
          karbala, () => LocationService.instance.relabelForAppLanguage());

      expect(requests, isEmpty);
      expect(city, 'Karbala');
    });
  });

  group('offline, named from the bundled city list', () {
    City listed(String name, double latitude, double longitude) => City(
          name: name,
          countryCode: 'PK',
          countryName: 'Pakistan',
          latitude: latitude,
          longitude: longitude,
          population: 1000000,
          timeZone: 'Asia/Karachi',
        );

    setUp(() {
      CityRepository.instance.seedForTesting([
        listed('Karachi', 24.86, 67.01),
        listed('Hyderabad', 25.39, 68.37),
      ]);
    });
    tearDown(() => CityRepository.instance.seedForTesting(const []));

    Future<void> fixAt(double latitude, double longitude,
        {bool online = false, String status = 'unreachable'}) async {
      GeolocatorPlatform.instance =
          _FakeGeolocator(currentPosition: _pos(latitude, longitude));
      await http.runWithClient(
        () async => expect(await initializeLocation(force: true), isTrue),
        () => MockClient((request) async {
          if (online) {
            return http.Response(
                '{"locality":"Lyari Town","city":"Karachi","countryCode":"PK"}',
                200);
          }
          if (status == 'error') return http.Response('', 503);
          throw Exception('no network');
        }),
      );
    }

    test('a first fix taken offline is named after the nearest city', () async {
      await fixAt(24.80, 67.05);

      expect(city, 'Karachi');
      expect(SP.prefs.getString('city'), 'Karachi');
      expect(cityLabelLanguage, 'en');
    });

    test('so is one when the geocoder answers with an error', () async {
      await fixAt(24.80, 67.05, status: 'error');

      expect(city, 'Karachi');
    });

    test('a geocoded name for the same spot is kept', () async {
      await fixAt(24.86, 67.01, online: true);
      expect(city, 'Lyari Town');

      await fixAt(24.87, 67.02);

      expect(city, 'Lyari Town');
    });

    test('the last place\'s name is replaced after moving offline', () async {
      await fixAt(24.86, 67.01, online: true);
      expect(city, 'Lyari Town');

      await fixAt(25.40, 68.36);

      expect(city, 'Hyderabad');
      expect(needToSchedule, isTrue);
    });

    test('a name stored before its place was recorded gives way', () async {
      city = 'Somewhere Else';
      await SP.prefs.setString('city', 'Somewhere Else');

      await fixAt(25.40, 68.36);

      expect(city, 'Hyderabad');
    });

    test('a name in another language gives way to one in the app\'s', () async {
      await fixAt(24.86, 67.01, online: true);
      L10n.current = lookupAppLocalizations(const Locale('ur'));
      CityRepository.instance.seedForTesting([listed('کراچی', 24.86, 67.01)]);

      await fixAt(24.86, 67.01);

      expect(city, 'کراچی');
      expect(cityLabelLanguage, 'ur');
    });

    test('nothing within reach keeps what there was', () async {
      await fixAt(24.86, 67.01, online: true);

      await fixAt(30.0, 75.0);

      expect(city, 'Lyari Town');
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
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future.value(lastKnownPosition);
}
