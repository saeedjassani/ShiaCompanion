import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/airport.dart';
import 'package:shia_companion/models/flight.dart';
import 'package:shia_companion/pages/flight_prayer_times_page.dart';
import 'package:shia_companion/services/airport_repository.dart';
import 'package:shia_companion/utils/timezone_database.dart';

/// Looks an airport up from the real database. Saved flights embed the whole
/// airport, so this stands in for what the picker would have handed over.
Airport _airport(String iata) => AirportRepository.instance.byIata(iata)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Seeded here rather than in setUpAll: the flight literals below are built
  // while main() runs, which is before any setUpAll callback fires.
  AirportRepository.instance.seedForTesting(
    Airport.parseDatabase(
      File(AirportRepository.assetPath).readAsStringSync(),
    ),
  );
  ensureTimeZoneDatabaseInitialized();

  // TK 80: SFO 19:55 on 30 July → IST 19:05 on 31 July.
  final sfoToIstanbul = Flight(
    id: 'tk80',
    origin: _airport('SFO'),
    destination: _airport('IST'),
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

    // Maghrib arrives soon after take-off, over the western United States.
    expect(find.textContaining('1h 11m after take-off'), findsOneWidget);
    // The qibla is given relative to the cabin, not just as a bearing.
    expect(
      find.textContaining('relative to the direction of flight'),
      findsWidgets,
    );

    // The altitude correction is disclosed per prayer, and in both directions:
    // Maghrib and Isha later, Fajr and sunrise earlier.
    expect(
      find.textContaining('later than the horizon of the ground below'),
      findsWidgets,
    );
    expect(
      find.textContaining('earlier than the horizon of the ground below'),
      findsWidgets,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('explains which horizon the times are measured from',
      (tester) async {
    await _pump(tester, sfoToIstanbul);

    await tester.scrollUntilVisible(
      find.text('Measured from the horizon at altitude'),
      300,
    );
    expect(find.textContaining('38,000 ft'), findsOneWidget);
    // The jurisprudential question is named, not answered.
    expect(find.textContaining('question for your marja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains prayers that fall outside the flight', (tester) async {
    // A daytime transcontinental hop: Fajr is long past at push-back and
    // Maghrib does not arrive until after landing.
    await _pump(
      tester,
      Flight(
        id: 'daytime',
        origin: _airport('SFO'),
        destination: _airport('JFK'),
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

  testWidgets('degrades gracefully when a time zone cannot be resolved',
      (tester) async {
    // A saved flight now carries its own airports, so the only way resolving
    // can fail is a time zone this build's database does not know.
    await _pump(
      tester,
      sfoToIstanbul.copyWith(
        destination: Airport.tryParseLine(
          'ZZZ\tZZZZ\tNowhere\tNowhere\tNowhere\t0\t0\tMars/Olympus_Mons',
        ),
      ),
    );

    expect(find.text('Time zones could not be loaded'), findsOneWidget);
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
