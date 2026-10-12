import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/services/first_run_setup.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';
import 'package:shia_companion/widgets/azan_offer_dialog.dart';
import 'package:timezone/timezone.dart' as tz;

/// Setup leaves out its Azan step without a location; the question is put
/// once one is set instead.
void main() {
  Future<void> prefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    await SP.init();
  }

  setUp(() async {
    await prefs({FirstRunSetup.stateKey: FirstRunSetup.done});
    ensureTimeZoneDatabaseInitialized();
    tz.setLocalLocation(tz.UTC);
    LocationService.instance.resetForTest();
    lat = 51.5;
    long = -0.12;
  });

  tearDown(() {
    lat = null;
    long = null;
  });

  Future<void> pumpOffer(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => offerAzanOnceLocated(context),
          child: const Text('Set location'),
        ),
      ),
    ));
    await tester.tap(find.text('Set location'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks once a location is set, and Not now counts as the answer',
      (tester) async {
    await pumpOffer(tester);
    expect(find.text('Hear the azan at prayer time?'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(AzaanOptInService.hasBeenAsked, isTrue);
    expect(AzaanOptInService.isEnabled, isFalse);

    await tester.tap(find.text('Set location'));
    await tester.pumpAndSettle();
    expect(find.text('Hear the azan at prayer time?'), findsNothing);
  });

  testWidgets('Turn on azan enables the three it names', (tester) async {
    await pumpOffer(tester);
    await tester.tap(find.text('Turn on azan'));
    await tester.pumpAndSettle();

    expect(
      AzaanOptInService.allPrayerKeys
          .where((k) => SP.prefs.getBool(k) == true)
          .toSet(),
      AzaanOptInService.defaultEnabledPrayerKeys.toSet(),
    );
  });

  testWidgets('not without a location', (tester) async {
    lat = null;
    long = null;
    await pumpOffer(tester);
    expect(find.text('Hear the azan at prayer time?'), findsNothing);
  });

  testWidgets('not during setup, which asks for itself', (tester) async {
    await prefs({FirstRunSetup.stateKey: FirstRunSetup.pending});
    await pumpOffer(tester);
    expect(find.text('Hear the azan at prayer time?'), findsNothing);
  });

  testWidgets('not once answered', (tester) async {
    await prefs({
      FirstRunSetup.stateKey: FirstRunSetup.done,
      AzaanOptInService.askedKey: true,
    });
    await pumpOffer(tester);
    expect(find.text('Hear the azan at prayer time?'), findsNothing);
  });
}
