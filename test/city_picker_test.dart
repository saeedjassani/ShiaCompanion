import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/pages/city_picker.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

City _city(
  String name,
  String country,
  String countryName, {
  int population = 100000,
  String zone = 'Asia/Baghdad',
  String admin1 = '',
  List<String> aliases = const [],
}) =>
    City(
      name: name,
      countryCode: country,
      countryName: countryName,
      admin1Name: admin1,
      latitude: 1,
      longitude: 2,
      population: population,
      timeZone: zone,
      aliases: aliases,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    CityRepository.instance.seedForTesting([
      _city('Karachi', 'PK', 'Pakistan',
          population: 11624219, zone: 'Asia/Karachi'),
      _city('Karbala', 'IQ', 'Iraq', population: 1218732, aliases: ['Kerbala']),
      _city('Baghdad', 'IQ', 'Iraq', population: 7216000),
      _city('Springfield', 'US', 'United States',
          admin1: 'Illinois', zone: 'America/Chicago'),
      _city('Springfield', 'US', 'United States',
          admin1: 'Missouri', zone: 'America/Chicago'),
    ]);
  });

  /// Opens the picker from a button and reports what it returned.
  Future<List<CityChoice?>> openPicker(WidgetTester tester) async {
    final results = <CityChoice?>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(await showCityPicker(context)),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('finds a city as it is typed and returns it', (tester) async {
    final results = await openPicker(tester);
    expect(find.text('Choose your city'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kar');
    await tester.pump();
    expect(find.text('CITIES'), findsOneWidget);
    expect(find.textContaining('chi', findRichText: true), findsOneWidget);
    expect(find.text('Pakistan'), findsOneWidget);

    await tester.tap(find.text('Iraq'));
    await tester.pumpAndSettle();

    expect(results.single, isA<ChosenCity>());
    expect((results.single! as ChosenCity).city.name, 'Karbala');
  });

  testWidgets('says which other spelling found a city', (tester) async {
    await openPicker(tester);
    await tester.enterText(find.byType(TextField), 'kerbala');
    await tester.pump();
    expect(find.text('Iraq · also Kerbala'), findsOneWidget);
  });

  testWidgets('tells two cities of one name apart by province', (tester) async {
    await openPicker(tester);
    await tester.enterText(find.byType(TextField), 'springfield');
    await tester.pump();
    expect(find.text('Illinois, United States'), findsOneWidget);
    expect(find.text('Missouri, United States'), findsOneWidget);
  });

  testWidgets('offers a way forward when nothing matches', (tester) async {
    await openPicker(tester);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('No city called “zzzz”'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
  });

  testWidgets('can go back to the phone\'s own location', (tester) async {
    final results = await openPicker(tester);
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();
    expect(results.single, isA<UseDeviceLocation>());
  });

  testWidgets('suggests cities in the phone\'s time zone before typing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const Scaffold(body: CityPicker(timeZone: 'Asia/Baghdad')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('IN YOUR TIME ZONE'), findsOneWidget);
    expect(find.textContaining('Baghdad', findRichText: true), findsOneWidget);
    expect(find.textContaining('Karachi', findRichText: true), findsNothing);
    expect(find.textContaining('GeoNames'), findsOneWidget);
  });

  testWidgets('is a centred dialog from tablet width up', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openPicker(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
