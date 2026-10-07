import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/pages/prayer_counter_page.dart';
import 'package:shia_companion/services/proximity_sensor_service.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart' as wakelock;
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

/// A proximity sensor driven by the test: [near] and [far] stand for a
/// forehead coming down onto the turbah and lifting off it.
class _FakeSensor extends ProximitySensorService {
  _FakeSensor({this.available = true});

  final bool available;
  final StreamController<bool> _states = StreamController<bool>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<bool> get proximityStates => _states.stream;

  void near() => _states.add(true);
  void far() => _states.add(false);

  /// Lifts off and comes down again: one sajdah. The events arrive after
  /// the frame they were sent in, so the page shows them a frame later.
  Future<void> sajdah(WidgetTester tester) async {
    far();
    await tester.pump();
    near();
    await tester.pump();
    await tester.pump();
  }
}

const _dimAfter = Duration(seconds: 6);
const _dimHint = 'Dimmed for prayer · tap to brighten';

void main() {
  late WakelockPlusPlatformInterface originalWakelock;

  setUp(() async {
    originalWakelock = wakelock.wakelockPlusPlatformInstance;
    wakelock.wakelockPlusPlatformInstance = _FakeWakelockPlatform();
    SharedPreferences.setMockInitialValues({});
    await SP.init();
  });

  tearDown(() {
    wakelock.wakelockPlusPlatformInstance = originalWakelock;
  });

  testWidgets('counts rakaat in words: "Rakaat 2 of 4", "1 of 2 sajdahs"',
      (tester) async {
    await _pump(tester, _FakeSensor(available: false));

    expect(find.text('Rakaat in this prayer'), findsOneWidget);
    expect(find.text('No sensor · tap to count'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('of 4'), findsOneWidget);
    expect(find.text('0 of 2 sajdahs'), findsOneWidget);
    expect(find.text('Tap anywhere here after each sajdah.'), findsOneWidget);

    await _addSajdah(tester);
    expect(find.text('1 of 2 sajdahs'), findsOneWidget);

    await _addSajdah(tester);
    expect(find.text('2'), findsWidgets);
    expect(find.text('0 of 2 sajdahs'), findsOneWidget);
    expect(SP.prefs.getInt('prayer_counter_completed_sajdahs'), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo and start over', (tester) async {
    await _pump(tester, _FakeSensor(available: false));

    await _addSajdah(tester);
    await _addSajdah(tester);
    await _addSajdah(tester);
    expect(find.text('1 of 2 sajdahs'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.text('0 of 2 sajdahs'), findsOneWidget);

    await tester.tap(find.text('Start over'));
    await tester.pump();
    expect(SP.prefs.getInt('prayer_counter_completed_sajdahs'), 0);
  });

  testWidgets('a two-rakaat prayer completes after four sajdahs',
      (tester) async {
    await _pump(tester, _FakeSensor(available: false));

    await tester.tap(find.text('2').first);
    await tester.pump();
    expect(find.text('of 2'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await _addSajdah(tester);
    }
    expect(find.text('Prayer complete'), findsOneWidget);
    expect(find.text('All sajdahs done'), findsOneWidget);
    expect(find.text('Tap Start over for your next prayer.'), findsOneWidget);
    // Let the salawat snackbar go.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the sensor counts a sajdah each time it is covered',
      (tester) async {
    final sensor = _FakeSensor();
    await _pump(tester, sensor);

    expect(find.text('Sensor on · auto-counting'), findsOneWidget);
    expect(find.text('Missed one? Tap anywhere here to add a sajdah.'),
        findsOneWidget);

    await sensor.sajdah(tester);
    expect(find.text('1 of 2 sajdahs'), findsOneWidget);
    expect(find.text('Sajdah detected'), findsOneWidget);

    // Staying covered counts once.
    sensor.near();
    await tester.pump();
    await tester.pump();
    expect(find.text('1 of 2 sajdahs'), findsOneWidget);

    // Tapping the pill turns automatic counting off.
    await tester.tap(find.text('Sajdah detected'));
    await tester.pump();
    expect(find.text('Sensor off · tap to count'), findsOneWidget);
  });

  testWidgets(
      'dims after a few seconds without a touch while the sensor counts',
      (tester) async {
    final sensor = _FakeSensor();
    await _pump(tester, sensor);

    await tester.pump(_dimAfter - const Duration(seconds: 1));
    expect(find.text(_dimHint), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(_dimHint), findsOneWidget);
    expect(find.text('Rakaat in this prayer').hitTestable(), findsNothing,
        reason: 'the page beneath is covered while dimmed');

    // The sensor keeps counting, and the dim count follows.
    await sensor.sajdah(tester);
    expect(find.text('1 of 2 sajdahs').hitTestable(), findsOneWidget);
    expect(find.text(_dimHint), findsOneWidget);

    // A tap brightens, and does not count.
    await tester.tap(find.text(_dimHint));
    await tester.pump();
    expect(find.text(_dimHint), findsNothing);
    expect(find.text('1 of 2 sajdahs'), findsOneWidget);

    // And dims again after another quiet spell.
    await tester.pump(_dimAfter);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(_dimHint), findsOneWidget);

    // The × brightens too.
    await tester.tap(find.byTooltip('Leave dim mode'));
    await tester.pump();
    expect(find.text(_dimHint), findsNothing);
  });

  testWidgets('touches keep it bright', (tester) async {
    await _pump(tester, _FakeSensor());

    for (var i = 0; i < 3; i++) {
      await tester.pump(_dimAfter - const Duration(seconds: 2));
      await tester.tap(find.text('Rakaat in this prayer'));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_dimHint), findsNothing);
  });

  testWidgets('never dims while counting by hand', (tester) async {
    await _pump(tester, _FakeSensor(available: false));

    await tester.pump(_dimAfter * 3);
    expect(find.text(_dimHint), findsNothing);
  });

  testWidgets('brightens for the end of the prayer', (tester) async {
    SharedPreferences.setMockInitialValues({
      'prayer_counter_total_rakaat': 2,
      'prayer_counter_completed_sajdahs': 3,
    });
    await SP.init();
    final sensor = _FakeSensor();
    await _pump(tester, sensor);

    await tester.pump(_dimAfter + const Duration(seconds: 1));
    expect(find.text(_dimHint), findsOneWidget);

    await sensor.sajdah(tester);
    expect(find.text(_dimHint), findsNothing);
    expect(find.text('Prayer complete'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the placement help opens from its link', (tester) async {
    await _pump(tester, _FakeSensor(available: false));

    await tester.tap(find.text('Phone placement'));
    await tester.pumpAndSettle();
    expect(find.textContaining('flat below the turbah'), findsOneWidget);
  });

  testWidgets('fits a small phone at 1.5x text, bright and dimmed',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, _FakeSensor());
    expect(tester.takeException(), isNull);
    await tester.pump(_dimAfter + const Duration(seconds: 1));
    expect(find.text(_dimHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, ProximitySensorService sensor) async {
  if (tester.view.physicalSize == const Size(2400, 1800)) {
    // A phone rather than the test default's 800 x 600 window.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home:
        PrayerCounterPage(proximitySensorService: sensor, dimAfter: _dimAfter),
  ));
  await tester.pump();
}

Future<void> _addSajdah(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Add a sajdah'));
  await tester.pump();
}
