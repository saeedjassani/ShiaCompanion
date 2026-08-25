import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/holy_sites.dart';
import 'package:shia_companion/models/compass_reading.dart';
import 'package:shia_companion/pages/qibla_finder.dart';
import 'package:shia_companion/services/compass_service.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/geo_utils.dart';
import 'package:shia_companion/utils/geomagnetism.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/qibla_compass_dial.dart';

/// A compass whose readings the test writes by hand.
class _FakeCompass implements CompassSource {
  _FakeCompass({this.available = true, this.requiresPermission = false});

  final bool available;
  final StreamController<CompassReading> _controller =
      StreamController<CompassReading>.broadcast();

  @override
  final bool requiresPermission;

  bool permissionGranted = true;
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Stream<CompassReading>? open() => available ? _controller.stream : null;

  void emit(double heading, {NorthReference? reference, double? accuracy}) {
    _controller.add(
      CompassReading(
        headingDegrees: heading,
        reference: reference ?? NorthReference.magnetic,
        accuracyDegrees: accuracy,
      ),
    );
  }

  Future<void> close() => _controller.close();
}

/// Berkeley, California — far enough west that the declination correction is
/// worth about 13°, and far enough from Makkah that the great-circle bearing
/// is north-east rather than the south-east a flat map suggests.
const GeoPoint _berkeley = GeoPoint(37.87, -122.27);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    LocationService.instance.resetForTest();
    lat = _berkeley.latitude;
    long = _berkeley.longitude;
    city = 'Berkeley';
    // Fresh enough that the page does not try to fetch a real position.
    LocationService.instance.setUpdatedAtForTest(DateTime.now());
  });

  tearDown(() {
    lat = null;
    long = null;
    city = null;
  });

  Future<_FakeCompass> pumpPage(
    WidgetTester tester, {
    bool available = true,
    bool requiresPermission = false,
  }) async {
    final compass = _FakeCompass(
      available: available,
      requiresPermission: requiresPermission,
    );
    addTearDown(compass.close);
    await tester.pumpWidget(
      MaterialApp(home: QiblaFinder(compassSource: compass)),
    );
    await tester.pump();
    return compass;
  }

  /// Feeds one heading in repeatedly so the display's low-pass filter settles
  /// on it, the way holding the phone still would.
  Future<void> settleOn(
    WidgetTester tester,
    _FakeCompass compass,
    double heading, {
    NorthReference? reference,
  }) async {
    for (var i = 0; i < 60; i++) {
      compass.emit(heading, reference: reference);
      await tester.pump();
    }
  }

  testWidgets('starts on the Kaaba and reports the great-circle direction',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Kaaba'), findsOneWidget);
    expect(find.text('Makkah, Saudi Arabia'), findsOneWidget);

    // Roughly 19° east of north from the Bay Area. The exact value is
    // whatever the shared bearing maths says; what is asserted here is that
    // the screen shows that value rather than inventing its own.
    final expected = qiblaBearingDegrees(_berkeley);
    expect(expected, closeTo(19, 2));
    expect(find.text(formatBearing(expected)), findsOneWidget);
  });

  testWidgets('corrects a magnetic reading for local declination',
      (tester) async {
    final compass = await pumpPage(tester);

    // The device says it is pointing at magnetic north. True north is about
    // 13° to the west of that here, so the screen should say the user is
    // facing roughly 13°, not 0°.
    await settleOn(tester, compass, 0);

    final declination = magneticDeclinationDegrees(_berkeley);
    expect(declination, closeTo(13, 2));

    // The first reading is adopted verbatim — the low-pass filter only damps
    // what comes after — so the displayed heading is exactly the corrected one.
    expect(find.text(formatBearing(declination)), findsOneWidget);
    expect(find.text(formatBearing(0)), findsNothing);
  });

  testWidgets('a true-north reading is used as-is', (tester) async {
    final compass = await pumpPage(tester);

    // iOS hands back a heading Core Location has already corrected. Adding the
    // declination again would double-count it, so pointing at true north must
    // read as north.
    await settleOn(tester, compass, 0, reference: NorthReference.geographic);

    expect(find.textContaining('N · 0°'), findsOneWidget);
  });

  testWidgets('says which way to turn, and confirms when you are facing it',
      (tester) async {
    final compass = await pumpPage(tester);
    final qibla = qiblaBearingDegrees(_berkeley);
    final declination = magneticDeclinationDegrees(_berkeley);

    // Pointing due south: the Kaaba is a long way round to the left.
    await settleOn(tester, compass, 180 - declination);
    expect(find.textContaining('Turn left'), findsOneWidget);

    // Now pointing at it.
    await settleOn(tester, compass, qibla - declination);
    expect(find.text('Facing Kaaba'), findsOneWidget);
  });

  testWidgets('switches to another shrine and remembers the choice',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Kaaba'));
    await tester.pumpAndSettle();

    final karbala = otherHolySites
        .firstWhere((site) => site.id == 'imam_husayn_karbala');
    await tester.tap(find.text(karbala.name));
    await tester.pumpAndSettle();

    expect(find.text(karbala.name), findsOneWidget);
    expect(find.text('Karbala, Iraq'), findsOneWidget);
    expect(
      find.text(formatBearing(initialBearingDegrees(_berkeley, karbala.location))),
      findsOneWidget,
    );
    expect(SP.prefs.getString('qibla_target_site'), karbala.id);
  });

  testWidgets('falls back to a north-up dial when there is no compass',
      (tester) async {
    await pumpPage(tester, available: false);
    await tester.pump();

    expect(find.text('No compass on this device'), findsOneWidget);
    // Still useful: the bearing from true north is on screen even with no
    // sensor to orient it against.
    expect(find.textContaining('of true north'), findsOneWidget);
  });

  testWidgets('reports no compass when readings never arrive', (tester) async {
    await pumpPage(tester);

    expect(find.text('No compass on this device'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('No compass on this device'), findsOneWidget);
  });

  testWidgets('asks for browser permission before listening', (tester) async {
    final compass = await pumpPage(tester, requiresPermission: true);

    expect(find.text('Turn on the compass'), findsOneWidget);
    await tester.ensureVisible(find.text('Allow compass'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow compass'));
    await tester.pumpAndSettle();

    expect(compass.permissionRequests, 1);
    expect(find.text('Turn on the compass'), findsNothing);
  });

  testWidgets('prompts for calibration when the reading is coarse',
      (tester) async {
    final compass = await pumpPage(tester);

    compass.emit(30, accuracy: 5);
    await tester.pump();
    expect(find.text('Compass needs calibrating'), findsNothing);

    compass.emit(30, accuracy: 35);
    await tester.pump();
    expect(find.text('Compass needs calibrating'), findsOneWidget);
    expect(find.textContaining('35°'), findsOneWidget);
  });

  testWidgets('asks for a location when there is none', (tester) async {
    lat = null;
    long = null;
    city = null;

    await pumpPage(tester);

    expect(find.text('Location needed'), findsOneWidget);
    expect(find.text('Waiting for your location'), findsOneWidget);
  });
}
