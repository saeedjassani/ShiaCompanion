import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/airport.dart';
import 'package:shia_companion/models/flight.dart';
import 'package:shia_companion/pages/flight_prayer_times_page.dart';
import 'package:shia_companion/services/airport_repository.dart';
import 'package:shia_companion/utils/timezone_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AirportRepository.instance.seedForTesting(
      Airport.parseDatabase(
        File(AirportRepository.assetPath).readAsStringSync(),
      ),
    );
    ensureTimeZoneDatabaseInitialized();
  });

  // TK 80: SFO 19:55 on 30 July → IST 19:05 on 31 July.
  final sfoToIstanbul = Flight(
    id: 'tk80',
    originIata: 'SFO',
    destinationIata: 'IST',
    departureLocal: DateTime(2026, 7, 30, 19, 55),
    arrivalLocal: DateTime(2026, 7, 31, 19, 5),
    flightNumber: 'TK 80',
  );

  testWidgets('renders the route, both time columns, and prayer rows',
      (tester) async {
    await _pump(tester, sfoToIstanbul);

    expect(find.text('SFO → IST'), findsOneWidget);
    expect(find.text('TK 80'), findsOneWidget);
    // The two time columns the feature exists to provide.
    expect(find.text('SFO time'), findsOneWidget);
    expect(find.text('IST time'), findsOneWidget);
    expect(find.textContaining('13h 10m in the air'), findsOneWidget);

    // Every prayer comes in en route on this flight, so nothing is left over.
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Zuhr'), findsOneWidget);
    expect(find.text('Asr'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    expect(find.text('Not during this flight'), findsNothing);

    // Maghrib arrives shortly after take-off, over the western United States.
    expect(find.textContaining('45m after take-off'), findsOneWidget);
    // The qibla is given relative to the cabin, not just as a bearing.
    expect(
      find.textContaining('relative to the direction of flight'),
      findsWidgets,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('explains prayers that fall outside the flight', (tester) async {
    // A daytime transcontinental hop: Fajr is long past at push-back and
    // Maghrib does not arrive until after landing.
    await _pump(
      tester,
      Flight(
        id: 'daytime',
        originIata: 'SFO',
        destinationIata: 'JFK',
        departureLocal: DateTime(2026, 7, 30, 9),
        arrivalLocal: DateTime(2026, 7, 30, 17, 25),
      ),
    );

    expect(find.text('Not during this flight'), findsOneWidget);
    expect(find.textContaining('Already in before take-off'), findsWidgets);
    expect(find.textContaining('Comes in after landing'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warns about the high-latitude portion of the route',
      (tester) async {
    await _pump(tester, sfoToIstanbul);

    await tester.scrollUntilVisible(
      find.textContaining('crosses high latitudes'),
      300,
    );
    expect(find.textContaining('crosses high latitudes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flags a flight whose arrival precedes its departure',
      (tester) async {
    // Arrival date left on the departure day — the common data-entry slip.
    await _pump(
      tester,
      sfoToIstanbul.copyWith(arrivalLocal: DateTime(2026, 7, 30, 19, 5)),
    );

    expect(find.text('Check the flight times'), findsOneWidget);
    expect(find.text('SFO time'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('degrades gracefully when an airport is unknown', (tester) async {
    await _pump(tester, sfoToIstanbul.copyWith(destinationIata: 'ZZZ'));

    expect(find.text('Airports could not be loaded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow in dark theme on a phone',
      (tester) async {
    await _pump(tester, sfoToIstanbul, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Flight flight, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: FlightPrayerTimesPage(
        flight: flight,
        trackScreenOnInit: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
