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

    expect(find.text('No flights saved'), findsOneWidget);
    expect(find.text('Add flight'), findsOneWidget);
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

    expect(find.text('SFO → IST'), findsOneWidget);
    expect(find.text('TK 80'), findsOneWidget);
    expect(find.text('Thu 30 Jul, 7:55 pm'), findsOneWidget);
    expect(find.textContaining('13h 10m'), findsOneWidget);
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
        .where((data) => data == 'SFO → IST' || data == 'IST → NJF')
        .toList();

    expect(routes, ['IST → NJF', 'SFO → IST']);
    expect(tester.takeException(), isNull);
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
