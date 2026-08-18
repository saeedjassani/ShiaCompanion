import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LocationService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    lat = null;
    long = null;
    city = null;
    lastLocationFailure = null;
    service.resetForTest();
    // Midnight, so every default-selection prayer is still ahead of "now" and
    // the card's "next 5" is deterministic regardless of when the suite runs.
    PrayerTimesState.debugNow = () => DateTime(2024, 6, 16);
  });

  tearDown(() {
    PrayerTimesState.debugNow = DateTime.now;
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

  Future<void> pumpCard(WidgetTester tester) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomePrayerTimesCard()),
    ));
  }

  Future<T> withGeocode<T>(Future<T> Function() body) {
    return http.runWithClient(
      body,
      () => MockClient((request) async => http.Response(
            '{"locality":"Najaf","city":"Najaf","countryCode":"IQ"}',
            200,
          )),
    );
  }

  testWidgets('keeps showing prayer times while a refresh is in flight',
      (tester) async {
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    final gate = Completer<Position>();
    GeolocatorPlatform.instance = _FakeGeolocator(pending: gate.future);

    await pumpCard(tester);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.textContaining('Najaf'), findsOneWidget);

    await withGeocode(() async {
      unawaited(service.refresh());
      await tester.pump();

      // The whole point: a spinner appears, and nothing else moves.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Zuhr'), findsOneWidget);
      expect(find.text('Maghrib'), findsOneWidget);
      expect(find.textContaining('Najaf'), findsOneWidget);

      gate.complete(_pos(32.02, 44.34));
      await tester.pumpAndSettle();
    });

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('keeps the times and offers a retry when a refresh fails',
      (tester) async {
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);

    await pumpCard(tester);
    await withGeocode(() => service.refresh());
    await tester.pump();

    expect(find.text('Fajr'), findsOneWidget);
    expect(find.textContaining('Location services are off'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('offers a refresh even when the location has never resolved',
      (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);

    await pumpCard(tester);
    expect(find.text('Location not available'), findsOneWidget);
    expect(find.text('Tap here to enable location'), findsOneWidget);

    // Must not become an untappable spinner: the empty state is the only way
    // back once a location fetch has failed.
    await withGeocode(() => service.refresh());
    await tester.pump();

    expect(find.text('Location services are off'), findsOneWidget);
    expect(find.text('Tap to try again'), findsOneWidget);

    // And the retry is genuinely wired, not just a label.
    expect(
      tester.widget<InkWell>(find.ancestor(
        of: find.text('Tap to try again'),
        matching: find.byType(InkWell),
      )).onTap,
      isNotNull,
    );
  });

  testWidgets('fits the "(next day)" note inside its column on a phone',
      (tester) async {
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    GeolocatorPlatform.instance = _FakeGeolocator();
    // Late enough that the tail of the row has rolled over into tomorrow, so
    // one column actually carries the note.
    PrayerTimesState.debugNow = () => DateTime(2024, 6, 16, 23, 30);
    // A small phone, where five columns leave the note barely any room.
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpCard(tester);

    final note = find.text('(next day)');
    expect(note, findsOneWidget);

    // The note must be scaled to fit rather than clipped mid-word: what gets
    // painted has to be no wider than the column it sits in.
    final column = find.ancestor(of: note, matching: find.byType(Expanded));
    final painted = tester.getSize(find.ancestor(
      of: note,
      matching: find.byType(FittedBox),
    ));
    expect(painted.width, lessThanOrEqualTo(tester.getSize(column).width));
  });

  testWidgets('discloses the age of a stale reading', (tester) async {
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    service.setUpdatedAtForTest(
      DateTime.now().subtract(const Duration(hours: 30)),
    );
    GeolocatorPlatform.instance = _FakeGeolocator();

    await pumpCard(tester);

    expect(find.textContaining('updated 1d ago'), findsOneWidget);
  });
}

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.pending,
    this.serviceEnabled = true,
  });

  final Future<Position>? pending;
  final bool serviceEnabled;

  @override
  Future<bool> isLocationServiceEnabled() => Future.value(serviceEnabled);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    final gated = pending;
    if (gated != null) return gated;
    return Future.error(StateError('no position configured'));
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future.value(null);
}
