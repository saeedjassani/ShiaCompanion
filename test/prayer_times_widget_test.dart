import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';
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
    // No time-zone guess unless a test asks for one.
    PrayerTimesState.timeZoneSource = () async => null;
    PrayerTimesState.debugResetTimeZoneGuess();
    // Midnight, so every default-selection prayer is still ahead of "now" and
    // the card's "next 5" is deterministic regardless of when the suite runs.
    PrayerTimesState.debugNow = () => DateTime(2024, 6, 16);
  });

  tearDown(() {
    PrayerTimesState.debugNow = DateTime.now;
    PrayerTimesState.timeZoneSource = () async => null;
    PrayerTimesState.debugResetTimeZoneGuess();
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
    expect(find.byTooltip('Change city'), findsOneWidget);
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
    expect(find.byTooltip('Change city'), findsOneWidget);
  });

  testWidgets('asks which city when the location has never resolved',
      (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);

    await pumpCard(tester);
    expect(find.text('Which city are you in?'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);

    // Must not become an untappable spinner: this card is the only way back
    // once a location fetch has failed.
    await withGeocode(() => service.refresh());
    await tester.pump();

    expect(find.text('Location services are off'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // And the retry is genuinely wired, not just a label.
    expect(
      tester
          .widget<FilledButton>(find.ancestor(
            of: find.text('Try again'),
            matching: find.byType(FilledButton),
          ))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('suggests the city the phone\'s time zone points at',
      (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator();
    PrayerTimesState.timeZoneSource = () async => 'Asia/Baghdad';

    await tester.runAsync(() async {
      await pumpCard(tester);
      // The city list loads off the test's fake clock.
      await CityRepository.instance.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(
        find.text("Your phone's time zone suggests Baghdad."), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.text('Choose city'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text("Yes, I'm in Baghdad"));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(service.isManual, isTrue);
    expect(city, 'Baghdad');
    // A city is all the card needs to show the times.
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.byTooltip('Change city'), findsOneWidget);
    expect(find.text('Baghdad'), findsOneWidget);
  });

  testWidgets('says "next day" under the first time that falls tomorrow',
      (tester) async {
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    GeolocatorPlatform.instance = _FakeGeolocator();
    final now = DateTime(2024, 6, 16, 23, 30);
    PrayerTimesState.debugNow = () => now;
    // A small phone, where five columns leave the note the least room.
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpCard(tester);

    // Which time is the first one tomorrow, worked out as the card does.
    final readings = nextWidgetPrayerTimeReadings(
      prayerTime: getPrayerTimeObject(),
      latitude: lat!,
      longitude: long!,
      count: selectedWidgetPrayerTimes().length,
      now: now,
      times: selectedWidgetPrayerTimes(),
    );
    final tagged = readings.indexWhere((r) =>
        r.dateTime.year != now.year ||
        r.dateTime.month != now.month ||
        r.dateTime.day != now.day);
    expect(tagged, greaterThanOrEqualTo(0),
        reason: 'this time of day must roll into tomorrow');

    // Once only, like a date divider, and under that time's own name.
    final note = find.text('next day');
    expect(note, findsOneWidget);
    final name = find.text(readings[tagged].time.name);
    expect(
      (tester.getRect(note).center.dx - tester.getRect(name).center.dx).abs(),
      lessThan(1.0),
    );
    expect(tester.getRect(note).top, greaterThan(tester.getRect(name).bottom));
    expect(tester.takeException(), isNull);
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

  testWidgets('invokes onTap when card is tapped', (tester) async {
    lat = 32.02;
    long = 44.34;
    city = 'Najaf';
    GeolocatorPlatform.instance = _FakeGeolocator();

    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomePrayerTimesCard(
          onTap: () {
            tapped = true;
          },
        ),
      ),
    ));

    expect(find.text('Fajr'), findsOneWidget);
    await tester.tap(find.text('Fajr'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
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
