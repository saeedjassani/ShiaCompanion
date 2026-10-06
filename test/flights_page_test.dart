import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/airport.dart';
import 'package:shia_companion/models/flight.dart';
import 'package:shia_companion/pages/flights_page.dart';
import 'package:shia_companion/services/airport_repository.dart';
import 'package:shia_companion/services/flight_store.dart';
import 'package:shia_companion/utils/timezone_database.dart';

Airport _airport(String iata) => AirportRepository.instance.byIata(iata)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureTimeZoneDatabaseInitialized();
  });

  AirportRepository.instance.seedForTesting(
    Airport.parseDatabase(
      File(AirportRepository.assetPath).readAsStringSync(),
    ),
  );

  tearDown(() => FlightStore.instance.resetForTesting());

  testWidgets('invites the user to add a flight when none are saved',
      (tester) async {
    FlightStore.instance.resetForTesting();
    await _pump(tester);

    expect(find.text('Prayer times in flight'), findsWidgets);
    expect(find.text('No flights saved'), findsOneWidget);
    expect(find.text('Add a flight'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists a saved flight with its route and schedule',
      (tester) async {
    FlightStore.instance.resetForTesting(flights: [
      Flight(
        id: 'tk80',
        origin: _airport('SFO'),
        destination: _airport('IST'),
        departureLocal: DateTime(2026, 7, 30, 19, 55),
        arrivalLocal: DateTime(2026, 7, 31, 19, 5),
        flightNumber: 'TK 80',
      ),
    ]);
    await _pump(tester);

    expect(find.text('SFO'), findsOneWidget);
    expect(find.text('IST'), findsOneWidget);
    // Each airport by its city, as the airport list has it.
    final istanbul = _airport('IST').place;
    expect(find.text('San Francisco to $istanbul · TK 80'), findsOneWidget);
    expect(find.text('Thu 30 Jul · departs 7:55 pm'), findsOneWidget);
    expect(find.text('13 h 10 min · lands 7:05 pm $istanbul time'),
        findsOneWidget);
    // All five prayers come in on board this one, in the order they do.
    expect(
        find.text('Maghrib, Isha, Fajr, Zuhr, Asr in the air'), findsOneWidget);
    expect(find.text('No flights saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sorts saved flights by departure', (tester) async {
    FlightStore.instance.resetForTesting(flights: [
      Flight(
        id: 'later',
        origin: _airport('SFO'),
        destination: _airport('IST'),
        departureLocal: DateTime(2026, 9, 1, 19, 55),
        arrivalLocal: DateTime(2026, 9, 2, 19, 5),
      ),
      Flight(
        id: 'earlier',
        origin: _airport('IST'),
        destination: _airport('NJF'),
        departureLocal: DateTime(2026, 7, 30, 8),
        arrivalLocal: DateTime(2026, 7, 30, 11, 30),
      ),
    ]);
    await _pump(tester);

    final routes = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => data?.contains(' to ') == true)
        .toList();

    final istanbul = _airport('IST').place;
    expect(routes, ['$istanbul to Najaf', 'San Francisco to $istanbul']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says when no prayer comes in on board', (tester) async {
    FlightStore.instance.resetForTesting(flights: [
      Flight(
        id: 'hop',
        origin: _airport('IST'),
        destination: _airport('NJF'),
        departureLocal: DateTime(2026, 7, 30, 8),
        arrivalLocal: DateTime(2026, 7, 30, 11, 30),
      ),
    ]);
    await _pump(tester);

    expect(find.text('No prayer in the air'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits or removes a flight from its options', (tester) async {
    FlightStore.instance.resetForTesting(flights: [
      Flight(
        id: 'hop',
        origin: _airport('IST'),
        destination: _airport('NJF'),
        departureLocal: DateTime(2026, 7, 30, 8),
        arrivalLocal: DateTime(2026, 7, 30, 11, 30),
      ),
    ]);
    await _pump(tester);

    await tester.tap(
        find.bySemanticsLabel('Options for ${_airport('IST').place} to Najaf'));
    await tester.pumpAndSettle();
    expect(find.text('Edit flight'), findsOneWidget);

    await tester.tap(find.text('Remove flight'));
    await tester.pumpAndSettle();
    expect(find.text('Remove flight?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(FlightStore.instance.flights, isEmpty);
    expect(find.text('No flights saved'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: FlightsPage(trackScreenOnInit: false)),
  );
  await tester.pumpAndSettle();
}
