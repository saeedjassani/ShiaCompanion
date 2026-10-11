import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/location_status_line.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LocationService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    lastLocationFailure = null;
    service.resetForTest();
  });

  Future<T> withGeocode<T>(Future<T> Function() body) {
    return http.runWithClient(
      body,
      () => MockClient((request) async => http.Response(
            '{"locality":"Najaf","city":"Najaf","countryCode":"IQ"}',
            200,
          )),
    );
  }

  void ageBy(Duration age) =>
      service.setUpdatedAtForTest(DateTime.now().subtract(age));

  /// Leaves the service in the state an automatic refresh that failed with
  /// [geolocator] would.
  Future<void> failWith(_FakeGeolocator geolocator) async {
    GeolocatorPlatform.instance = geolocator;
    await withGeocode(() => service.refresh());
    expect(service.status, LocationRefreshStatus.failed);
  }

  Future<void> pumpLine(WidgetTester tester) {
    return tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: LocationStatusLine()),
    ));
  }

  group('LocationStatus.of', () {
    test('says nothing about a reading under a day old', () {
      ageBy(const Duration(hours: 20));
      expect(LocationStatus.of(service), isNull);
    });

    test('says nothing when a refresh of a younger reading fails', () async {
      ageBy(const Duration(hours: 2));
      await failWith(_FakeGeolocator(serviceEnabled: false));
      expect(LocationStatus.of(service), isNull);
    });

    test('offers an update for a day-old reading', () {
      ageBy(const Duration(hours: 50));
      final status = LocationStatus.of(service)!;
      expect(status.message, 'Location from 2 days ago');
      expect(status.action, LocationStatusAction.update);
    });

    test('asks for the permission when it was denied', () async {
      ageBy(const Duration(hours: 30));
      await failWith(_FakeGeolocator(permission: LocationPermission.denied));
      final status = LocationStatus.of(service)!;
      expect(status.message, 'Location permission needed · 1 day ago');
      expect(status.action, LocationStatusAction.allow);
    });

    test('opens settings when the permission was denied for good', () async {
      ageBy(const Duration(hours: 30));
      await failWith(
          _FakeGeolocator(permission: LocationPermission.deniedForever));
      final status = LocationStatus.of(service)!;
      expect(status.message, 'Location permission needed · 1 day ago');
      expect(status.action, LocationStatusAction.openSettings);
    });

    test('turns location on when services are off', () async {
      ageBy(const Duration(hours: 30));
      await failWith(_FakeGeolocator(serviceEnabled: false));
      final status = LocationStatus.of(service)!;
      expect(status.message, 'Location services are off · 1 day ago');
      expect(status.action, LocationStatusAction.turnOn);
    });

    test('tries again when no fix came', () async {
      ageBy(const Duration(hours: 30));
      await failWith(
          _FakeGeolocator(positionError: TimeoutException('no fix')));
      final status = LocationStatus.of(service)!;
      expect(status.message, "Couldn't get a location fix · 1 day ago");
      expect(status.action, LocationStatusAction.tryAgain);
    });

    test('says nothing about a city the reader chose', () async {
      await service.chooseCity(const City(
        name: 'Karbala',
        countryCode: 'IQ',
        countryName: 'Iraq',
        latitude: 32.616,
        longitude: 44.025,
        population: 1218732,
        timeZone: 'Asia/Baghdad',
      ));
      ageBy(const Duration(days: 30));
      expect(LocationStatus.of(service), isNull);
    });

    test('says nothing while a refresh is running', () async {
      ageBy(const Duration(hours: 30));
      final gate = Completer<Position>();
      GeolocatorPlatform.instance = _FakeGeolocator(pending: gate.future);
      await withGeocode(() async {
        final fetch = service.refresh();
        expect(LocationStatus.of(service), isNull);
        gate.complete(_pos(32.02, 44.34));
        await fetch;
      });
    });
  });

  group('LocationStatusLine', () {
    testWidgets('draws nothing while there is nothing to say', (tester) async {
      ageBy(const Duration(hours: 1));
      await pumpLine(tester);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('Update fetches the location and the line goes away',
        (tester) async {
      ageBy(const Duration(hours: 30));
      GeolocatorPlatform.instance =
          _FakeGeolocator(position: _pos(32.02, 44.34));
      await pumpLine(tester);
      expect(find.text('Location from 1 day ago'), findsOneWidget);

      await withGeocode(() async {
        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();
      });

      expect(find.text('Location from 1 day ago'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('Allow asks for the permission again', (tester) async {
      ageBy(const Duration(hours: 30));
      final geolocator = _FakeGeolocator(
        permission: LocationPermission.denied,
        position: _pos(32.02, 44.34),
      );
      await failWith(geolocator);
      await pumpLine(tester);
      expect(
          find.text('Location permission needed · 1 day ago'), findsOneWidget);

      geolocator.grantOnRequest = true;
      await withGeocode(() async {
        await tester.tap(find.text('Allow'));
        await tester.pumpAndSettle();
      });

      expect(geolocator.requestPermissionCalls, 2);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('Turn on opens location settings and retries on return',
        (tester) async {
      ageBy(const Duration(hours: 30));
      final geolocator = _FakeGeolocator(
        serviceEnabled: false,
        position: _pos(32.02, 44.34),
      );
      await failWith(geolocator);
      await pumpLine(tester);

      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(geolocator.openLocationSettingsCalls, 1);

      // Back from settings with location on: no wait for the cooldown.
      geolocator.serviceEnabled = true;
      await withGeocode(() async {
        for (final state in const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
      });

      expect(service.status, LocationRefreshStatus.idle);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('Open settings opens the app settings', (tester) async {
      ageBy(const Duration(hours: 30));
      final geolocator =
          _FakeGeolocator(permission: LocationPermission.deniedForever);
      await failWith(geolocator);
      await pumpLine(tester);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(geolocator.openAppSettingsCalls, 1);
    });
  });
}

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

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.always,
    this.position,
    this.positionError,
    this.pending,
  });

  bool serviceEnabled;
  LocationPermission permission;
  final Position? position;
  final Object? positionError;
  final Future<Position>? pending;
  bool grantOnRequest = false;
  int requestPermissionCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() => Future.value(serviceEnabled);

  @override
  Future<LocationPermission> checkPermission() => Future.value(permission);

  @override
  Future<LocationPermission> requestPermission() {
    requestPermissionCalls++;
    return Future.value(
        grantOnRequest ? LocationPermission.whileInUse : permission);
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    final gated = pending;
    if (gated != null) return gated;
    final fix = position;
    if (fix != null) return Future.value(fix);
    return Future.error(positionError ?? StateError('no position'));
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future.value(null);

  @override
  Future<bool> openAppSettings() {
    openAppSettingsCalls++;
    return Future.value(true);
  }

  @override
  Future<bool> openLocationSettings() {
    openLocationSettingsCalls++;
    return Future.value(true);
  }
}
