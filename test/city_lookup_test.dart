import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/pages/city_picker.dart';
import 'package:shia_companion/pages/city_prayer_times_page.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/city_clock.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'package:timezone/timezone.dart' as tz;

/// Picking a city as the location, looking one up, and the Home card asking
/// whether a city chosen on a trip is still right. The suite runs in whatever
/// zone the machine is in, so the cities' zones are picked to differ from it,
/// or match it, wherever that is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ensureTimeZoneDatabaseInitialized();

  final service = LocationService.instance;
  final now = DateTime.now();
  final phoneOffset = now.timeZoneOffset;

  // Karbala's clock, unless the machine is already on it.
  final farZone =
      phoneOffset == const Duration(hours: 3) ? 'Asia/Karachi' : 'Asia/Baghdad';
  // A zone that reads the same as the machine today and tomorrow.
  final sameZone = tz.timeZoneDatabase.locations.values
      .firstWhere((zone) => [now, now.add(const Duration(days: 1))].every(
          (moment) =>
              tz.TZDateTime.from(moment, zone).timeZoneOffset ==
              moment.timeZoneOffset))
      .name;

  final karbala = City(
    name: 'Karbala',
    countryCode: 'IQ',
    countryName: 'Iraq',
    latitude: 32.62,
    longitude: 44.03,
    population: 1218732,
    timeZone: farZone,
  );
  final hometown = City(
    name: 'Hometown',
    countryCode: 'XX',
    countryName: 'Homeland',
    latitude: 51.51,
    longitude: -0.13,
    population: 9000000,
    timeZone: sameZone,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    lat = null;
    long = null;
    city = null;
    hijriDate = 0;
    lastLocationFailure = null;
    service.resetForTest();
    CityRepository.instance.seedForTesting([karbala, hometown]);
    PrayerTimesState.debugNow = DateTime.now;
  });

  /// A button that runs [flow], to start it from a real context.
  Future<void> pumpLauncher(
    WidgetTester tester,
    Future<void> Function(BuildContext context) flow,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => flow(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String query, String country) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
    await tester.tap(find.text(country));
    await tester.pumpAndSettle();
  }

  /// Fajr on [city]'s own clock on [day] (that zone's calendar date).
  String fajrOnCityClock(City city, DateTime day) {
    final zone = tz.getLocation(city.timeZone);
    final date = tz.TZDateTime(zone, day.year, day.month, day.day);
    return buildExtendedPrayerTimeEntries(
      prayerTime: getPrayerTimeObject(),
      date: date,
      latitude: city.latitude,
      longitude: city.longitude,
      timeZone: date.timeZoneOffset.inMinutes / 60.0,
    ).first.time;
  }

  group('choosing a city in another time zone', () {
    testWidgets('asks first, and "Just checking times" changes nothing',
        (tester) async {
      await pumpLauncher(tester, chooseCityFlow);
      await pick(tester, 'karb', 'Iraq');

      expect(find.text('Are you in Karbala now?'), findsOneWidget);
      await tester.tap(find.text('Just checking times'));
      await tester.pumpAndSettle();

      // Karbala's times, on Karbala's clock, said once.
      expect(find.byType(CityPrayerTimesPage), findsOneWidget);
      final today = tz.TZDateTime.now(tz.getLocation(farZone));
      expect(find.text(fajrOnCityClock(karbala, today)), findsOneWidget);
      expect(find.textContaining('Karbala time, '), findsOneWidget);
      expect(find.textContaining('notifications stay as they are'),
          findsOneWidget);

      expect(service.isManual, isFalse);
      expect(lat, isNull);
      expect(city, isNull);
    });

    testWidgets('"I\'m in Karbala now" makes it the location, asked once',
        (tester) async {
      await pumpLauncher(tester, chooseCityFlow);
      await pick(tester, 'karb', 'Iraq');
      await tester.tap(find.text("I'm in Karbala now"));
      await tester.pumpAndSettle();

      expect(find.byType(CityPrayerTimesPage), findsNothing);
      expect(service.isManual, isTrue);
      expect(city, 'Karbala');
      // Already answered: the Home card does not ask "Still in Karbala?".
      expect(service.chosenCityClockDifference, isNull);
    });

    testWidgets('closing the question changes nothing', (tester) async {
      await pumpLauncher(tester, chooseCityFlow);
      await pick(tester, 'karb', 'Iraq');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(CityPrayerTimesPage), findsNothing);
      expect(service.isManual, isFalse);
    });
  });

  testWidgets('a city on the phone\'s own clock is chosen without asking',
      (tester) async {
    await pumpLauncher(tester, chooseCityFlow);
    await pick(tester, 'home', 'Homeland');

    expect(find.byType(AlertDialog), findsNothing);
    expect(service.isManual, isTrue);
    expect(city, 'Hometown');
  });

  group('looking up a city', () {
    testWidgets('offers only cities, and opens on the date asked about',
        (tester) async {
      await pumpLauncher(
        tester,
        (context) => lookUpCityFlow(context, date: DateTime(2026, 10, 16)),
      );
      expect(find.text('Another city'), findsOneWidget);
      expect(find.text('Use my current location'), findsNothing);
      expect(find.text('IN YOUR TIME ZONE'), findsNothing);

      await pick(tester, 'karb', 'Iraq');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Friday 16 October'), findsOneWidget);
      expect(find.text(fajrOnCityClock(karbala, DateTime(2026, 10, 16))),
          findsOneWidget);
      expect(find.text('Today in Karbala'), findsOneWidget);
      expect(service.isManual, isFalse);
    });

    testWidgets('steps through the days and back to today', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: CityPrayerTimesPage(city: karbala),
      ));
      await tester.pumpAndSettle();

      final today = tz.TZDateTime.now(tz.getLocation(farZone));
      String header(DateTime day) => formatDate(day, [DD, ' ', d, ' ', MM]);
      expect(find.text(header(today)), findsOneWidget);
      expect(find.text('Today in Karbala'), findsNothing);

      await tester.tap(find.byTooltip('Next day'));
      await tester.pump();
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      expect(find.text(header(tomorrow)), findsOneWidget);

      await tester.tap(find.text('Today in Karbala'));
      await tester.pump();
      expect(find.text(header(today)), findsOneWidget);
    });

    testWidgets('says nothing about the clock when it matches the phone\'s',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: CityPrayerTimesPage(city: hometown),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hometown time'), findsNothing);
      expect(find.textContaining('notifications stay as they are'),
          findsOneWidget);
    });
  });

  group('the Home card', () {
    Future<void> pumpCard(WidgetTester tester) async {
      GeolocatorPlatform.instance = _NoGeolocator();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: HomePrayerTimesCard()),
        ),
      ));
      await tester.pump();
    }

    testWidgets('asks if a city from a trip is still right', (tester) async {
      await service.chooseCity(karbala);
      await pumpCard(tester);

      expect(find.text('Still in Karbala?'), findsOneWidget);
      await tester.tap(find.text('Yes, still here'));
      await tester.pump();

      expect(find.text('Still in Karbala?'), findsNothing);
      expect(SP.prefs.getBool(LocationService.zoneNudgeDismissedKey), isTrue);

      // And it stays answered after a restart.
      service.resetForTest();
      service.restore();
      expect(service.chosenCityClockDifference, isNull);
    });

    testWidgets('"Change city" opens the picker', (tester) async {
      await service.chooseCity(karbala);
      await pumpCard(tester);

      await tester.tap(find.text('Change city'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your city'), findsOneWidget);
    });

    testWidgets('does not ask about a city on the phone\'s clock',
        (tester) async {
      await service.chooseCity(hometown);
      await pumpCard(tester);
      expect(find.textContaining('Still in'), findsNothing);
    });

    testWidgets('does not ask about the phone\'s own location', (tester) async {
      lat = 32.62;
      long = 44.03;
      city = 'Karbala';
      await pumpCard(tester);
      expect(find.textContaining('Still in'), findsNothing);
    });
  });

  test('choosing a city again asks again; the phone\'s location forgets it',
      () async {
    await service.chooseCity(karbala, confirmedInCity: true);
    expect(SP.prefs.getString(LocationService.timeZoneKey), farZone);
    expect(service.chosenCityClockDifference, isNull);

    await service.chooseCity(karbala);
    expect(service.chosenCityClockDifference, cityClockDifference(karbala));

    GeolocatorPlatform.instance = _NoGeolocator();
    await service.useDeviceLocation();
    expect(SP.prefs.containsKey(LocationService.timeZoneKey), isFalse);
    expect(
        SP.prefs.containsKey(LocationService.zoneNudgeDismissedKey), isFalse);
    expect(service.chosenCityClockDifference, isNull);
  });

  test('clock differences read in hours and minutes', () {
    expect(clockDifferenceLabel(const Duration(hours: 2)),
        '2 hr ahead of your phone');
    expect(clockDifferenceLabel(const Duration(hours: -5, minutes: -30)),
        '5 hr 30 min behind your phone');
    expect(clockDifferenceLabel(const Duration(minutes: 45)),
        '45 min ahead of your phone');
    expect(clockDifferenceLabel(Duration.zero), isNull);
    expect(clockDifferenceLabel(null), isNull);
  });
}

/// A phone whose location services are off, so nothing in these tests
/// waits on a fix.
class _NoGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() => Future.value(false);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.denied);
}
