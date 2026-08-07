import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LocationService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    lat = null;
    long = null;
    city = null;
    needToSchedule = false;
    lastLocationFailure = null;
    service.resetForTest();
  });

  Position _posAt(double latitude, double longitude, DateTime timestamp) =>
      Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );

  Position _pos(double latitude, double longitude) =>
      _posAt(latitude, longitude, DateTime.now());

  Future<T> withGeocode<T>(Future<T> Function() body) {
    return http.runWithClient(
      body,
      () => MockClient((request) async => http.Response(
            '{"locality":"Karbala","city":"Karbala",'
            '"principalSubdivision":"Karbala","countryName":"Iraq",'
            '"countryCode":"IQ"}',
            200,
          )),
    );
  }

  group('freshness window', () {
    test('reuses a recent fix instead of fetching again', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() async {
        await service.refresh();
        expect(geolocator.currentPositionCalls, 1);

        // Second open, moments later: nothing should hit the location stack.
        final reused = await service.refreshIfStale();

        expect(reused, isTrue);
        expect(geolocator.currentPositionCalls, 1);
      });
    });

    test('refetches once the fix has aged out', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() async {
        await service.refresh();
        expect(geolocator.currentPositionCalls, 1);

        service.setUpdatedAtForTest(
          DateTime.now().subtract(LocationService.freshnessWindow * 2),
        );

        await service.refreshIfStale();

        expect(geolocator.currentPositionCalls, 2);
      });
    });

    test('always fetches when nothing is stored yet', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;

      expect(service.isStale, isTrue);

      await withGeocode(() async {
        await service.refreshIfStale();
        expect(geolocator.currentPositionCalls, 1);
      });
    });

    test('an explicit refresh ignores the freshness window', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() async {
        await service.refresh();
        expect(service.isStale, isFalse);

        await service.refresh();

        expect(geolocator.currentPositionCalls, 2);
      });
    });
  });

  group('stale fixes and retry cooldown', () {
    test('ages a last-known fallback from when it was measured', () async {
      final old = DateTime.now().subtract(const Duration(hours: 20));
      GeolocatorPlatform.instance = _CountingGeolocator(
        currentPositionError: TimeoutException('no fix'),
        lastKnownPosition: _posAt(32.6, 44.0, old),
      );

      await withGeocode(() => service.refresh());

      // Stamping this "now" would hide a 20-hour-old fix behind a fresh label
      // and block a retry for the whole freshness window.
      expect(service.updatedAt, old);
      expect(service.isStale, isTrue);
      expect(service.shouldDiscloseAge, isTrue);
    });

    test('does not retry every resume when only a stale fallback is available',
        () async {
      final geolocator = _CountingGeolocator(
        currentPositionError: TimeoutException('no fix'),
        lastKnownPosition:
            _posAt(32.6, 44.0, DateTime.now().subtract(const Duration(days: 1))),
      );
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() => service.refreshIfStale());
      expect(geolocator.currentPositionCalls, 1);

      // The fetch "succeeded", but only by recovering a day-old fix, so we are
      // still stale and would otherwise attempt again on every single resume.
      expect(service.isStale, isTrue);
      await withGeocode(() => service.refreshIfStale());
      await withGeocode(() => service.refreshIfStale());

      expect(geolocator.currentPositionCalls, 1);
    });

    test('does not retry an unfixable device on every resume', () async {
      final geolocator = _CountingGeolocator(serviceEnabled: false);
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() => service.refreshIfStale());
      expect(geolocator.currentPositionCalls, 0);

      // Location is permanently stale here, so without a cooldown each of
      // these would run a full attempt.
      await withGeocode(() => service.refreshIfStale());
      await withGeocode(() => service.refreshIfStale());

      expect(geolocator.isLocationServiceEnabledCalls, 1);
    });

    test('an explicit refresh ignores the cooldown', () async {
      final geolocator = _CountingGeolocator(serviceEnabled: false);
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() => service.refreshIfStale());
      await withGeocode(() => service.refresh());

      expect(geolocator.isLocationServiceEnabledCalls, 2);
    });

    test('drops a failure once the stored fix is deemed good enough', () async {
      GeolocatorPlatform.instance =
          _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      await withGeocode(() => service.refresh());

      GeolocatorPlatform.instance = _CountingGeolocator(serviceEnabled: false);
      await withGeocode(() => service.refresh());
      expect(service.status, LocationRefreshStatus.failed);

      // Next open: the fix is still fresh, so we are not retrying and have no
      // business showing a red error about an attempt we no longer need.
      await withGeocode(() => service.refreshIfStale());

      expect(service.status, LocationRefreshStatus.idle);
    });
  });

  group('in-flight dedupe', () {
    test('overlapping callers share a single fetch', () async {
      final gate = Completer<Position>();
      final geolocator = _CountingGeolocator(pending: gate.future);
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() async {
        // App open, resume and a button tap landing together.
        final first = service.refresh();
        final second = service.refresh();
        final third = service.refreshIfStale();

        expect(service.isRefreshing, isTrue);
        gate.complete(_pos(32.6, 44.0));

        expect(await Future.wait([first, second, third]),
            [isTrue, isTrue, isTrue]);
        expect(geolocator.currentPositionCalls, 1);
      });
    });

    test('a new fetch is allowed once the previous one settles', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;

      await withGeocode(() async {
        await service.refresh();
        await service.refresh();

        expect(geolocator.currentPositionCalls, 2);
      });
    });
  });

  group('status', () {
    test('reports refreshing then idle across a successful fetch', () async {
      final gate = Completer<Position>();
      GeolocatorPlatform.instance = _CountingGeolocator(pending: gate.future);

      final seen = <LocationRefreshStatus>[];
      void listener() => seen.add(service.status);
      service.addListener(listener);
      addTearDown(() => service.removeListener(listener));

      await withGeocode(() async {
        final fetch = service.refresh();
        expect(service.status, LocationRefreshStatus.refreshing);

        gate.complete(_pos(32.6, 44.0));
        await fetch;
      });

      expect(service.status, LocationRefreshStatus.idle);
      expect(seen,
          [LocationRefreshStatus.refreshing, LocationRefreshStatus.idle]);
    });

    test('surfaces why a fetch failed instead of just failing', () async {
      GeolocatorPlatform.instance = _CountingGeolocator(serviceEnabled: false);

      final success = await withGeocode(() => service.refresh());

      expect(success, isFalse);
      expect(service.status, LocationRefreshStatus.failed);
      expect(service.failure, LocationFailure.serviceDisabled);
      expect(service.failureMessage, 'Location services are off');
    });

    test('distinguishes a permanent permission denial', () async {
      GeolocatorPlatform.instance = _CountingGeolocator(
        permission: LocationPermission.deniedForever,
      );

      await withGeocode(() => service.refresh());

      expect(service.failure, LocationFailure.permissionDeniedForever);
    });

    test('a failed fetch leaves the previous location intact', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;
      await withGeocode(() => service.refresh());

      GeolocatorPlatform.instance = _CountingGeolocator(serviceEnabled: false);
      await withGeocode(() => service.refresh());

      // The card keeps rendering prayer times from these.
      expect(lat, 32.6);
      expect(long, 44.0);
      expect(city, 'Karbala');
    });

    test('clears a stale failure after a later success', () async {
      GeolocatorPlatform.instance = _CountingGeolocator(serviceEnabled: false);
      await withGeocode(() => service.refresh());
      expect(service.failure, isNotNull);

      GeolocatorPlatform.instance =
          _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      await withGeocode(() => service.refresh());

      expect(service.status, LocationRefreshStatus.idle);
      expect(service.failure, isNull);
    });
  });

  group('restore', () {
    test('treats a location stored without a stamp as stale', () async {
      lat = 32.6;
      long = 44.0;

      service.restore();

      expect(service.updatedAt, isNull);
      expect(service.isStale, isTrue);
    });

    test('reads back a persisted stamp so a restart stays throttled', () async {
      final geolocator = _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      GeolocatorPlatform.instance = geolocator;
      await withGeocode(() => service.refresh());

      // Simulate a cold start with the same prefs.
      service.resetForTest();
      service.restore();

      expect(service.updatedAt, isNotNull);
      expect(service.isStale, isFalse);
      await service.refreshIfStale();
      expect(geolocator.currentPositionCalls, 1);
    });

    test('drops the retired live-location switch', () async {
      await SP.prefs.setBool('use_live_location', true);

      service.restore();
      await Future<void>.delayed(Duration.zero);

      expect(SP.prefs.containsKey('use_live_location'), isFalse);
    });
  });

  group('age disclosure', () {
    test('stays quiet about a fresh reading', () async {
      GeolocatorPlatform.instance =
          _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      await withGeocode(() => service.refresh());

      expect(service.shouldDiscloseAge, isFalse);
    });

    test('admits the age once the reading is old', () async {
      GeolocatorPlatform.instance =
          _CountingGeolocator(currentPosition: _pos(32.6, 44.0));
      await withGeocode(() => service.refresh());

      service.setUpdatedAtForTest(
        DateTime.now().subtract(LocationService.staleDisclosureAge * 2),
      );

      expect(service.shouldDiscloseAge, isTrue);
    });
  });
}

class _CountingGeolocator extends GeolocatorPlatform {
  _CountingGeolocator({
    this.currentPosition,
    this.currentPositionError,
    this.lastKnownPosition,
    this.pending,
    this.serviceEnabled = true,
    this.permission = LocationPermission.always,
  });

  final Position? currentPosition;
  final Object? currentPositionError;
  final Position? lastKnownPosition;
  final Future<Position>? pending;
  final bool serviceEnabled;
  final LocationPermission permission;

  int currentPositionCalls = 0;
  int isLocationServiceEnabledCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() {
    isLocationServiceEnabledCalls++;
    return Future.value(serviceEnabled);
  }

  @override
  Future<LocationPermission> checkPermission() => Future.value(permission);

  @override
  Future<LocationPermission> requestPermission() => Future.value(permission);

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    currentPositionCalls++;
    if (currentPositionError != null) {
      return Future.error(currentPositionError!);
    }
    final gated = pending;
    if (gated != null) return gated;
    return Future.value(currentPosition!);
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future.value(lastKnownPosition);
}
