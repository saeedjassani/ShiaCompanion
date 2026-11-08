import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/models/shrine_plan.dart';
import 'package:shia_companion/models/ziyarat_guide.dart';
import 'package:shia_companion/pages/ziyarat_guide/shrine_plan_view.dart';
import 'package:shia_companion/services/ziyarat_guide_repository.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'firebase_test_doubles.dart';

// The interactive shrine plan (docs/ZIYARAT_GUIDE.md, "Shrine plans") over
// the real Karbala plan: it lays out at every size, a tapped gate shows its
// card, and the list of places selects one.

void main() {
  late ZiyaratGuide guide;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
    final zikr =
        json.decode(File('assets/zikr.json').readAsStringSync()) as Map;
    for (final entry in zikr.entries) {
      items[entry.key] = (entry.value as Map)['title'];
    }
    guide = ZiyaratGuide.fromJson(
      json.decode(File('assets/ziyarat_guide.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    // Loaded (and cached) outside the widget tests' fake clock.
    expect(
        await ZiyaratGuideRepository.loadPlan(
            guide.site('imam_husayn_shrine')!.plan!),
        isNotNull);
  });

  Future<void> settle(WidgetTester tester) async {
    // The plan loads from the asset bundle: real async work.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> pumpPlan(WidgetTester tester, Size size, GuideSite site,
      {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShrinePlanPage(plan: site.plan!, site: site),
    ));
    await settle(tester);
  }

  test('the Karbala drawing parses and projects round trip', () {
    final drawing = ShrinePlan.fromJson(json.decode(
        File('assets/ziyarat_plans/karbala_haramayn.json')
            .readAsStringSync()) as Map<String, dynamic>);
    expect(drawing.shapes, isNotEmpty);
    final tomb =
        guide.site('imam_husayn_shrine')!.plan!.focusFor('imam_husayn_shrine')!;
    final back = drawing.unproject(drawing.project(tomb.location));
    expect(back.latitude, closeTo(tomb.location.latitude, 1e-9));
    expect(back.longitude, closeTo(tomb.location.longitude, 1e-9));
  });

  test('a feature\'s side is measured from its site\'s zarih', () {
    final plan = guide.site('imam_husayn_shrine')!.plan!;
    PlanFeature feature(String id) =>
        plan.features.firstWhere((f) => f.id == id);
    expect(planFeatureSide(feature('husayn_gate_qibla')), 's');
    expect(planFeatureSide(feature('husayn_gate_sidra')), 'n');
    expect(planFeatureSide(feature('husayn_tomb')), isNull);

    // The Umayyad Mosque has no zarih: its gates' middle stands in.
    final mosque = guide.site('umayyad_mosque_ras_al_husayn')!.plan!;
    PlanFeature gate(String id) =>
        mosque.features.firstWhere((f) => f.id == id);
    expect(planFeatureSide(gate('umayyad_gate_amara')), 'n');
    expect(planFeatureSide(gate('umayyad_gate_jayrun')), 'e');
    // In the western part of the south wall.
    expect(planFeatureSide(gate('umayyad_gate_ziyada')), 'sw');
    expect(planFeatureSide(gate('umayyad_gate_barid')), 'w');
  });

  for (final (name, size) in [
    ('a phone', const Size(393, 852)),
    ('a tablet', const Size(834, 1194)),
    ('a desktop window', const Size(1440, 900)),
  ]) {
    testWidgets('lays out on $name, light and dark', (tester) async {
      final site = guide.site('abbas_shrine')!;
      for (final brightness in Brightness.values) {
        await pumpPlan(tester, size, site, brightness: brightness);
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel(RegExp('^Zarih of Hazrat Abbas')),
            findsOneWidget);
      }
    });
  }

  testWidgets('a tapped gate shows its card, with what to recite',
      (tester) async {
    await pumpPlan(
        tester, const Size(393, 852), guide.site('imam_husayn_shrine')!);
    // A northern gate: the test font's wide letters make the hint card at
    // the bottom tall enough to cover the southern ones.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Bab al-Sidra, ')));
    await settle(tester);
    expect(find.text('Bab al-Sidra'), findsWidgets);
    expect(find.text('باب السدرة'), findsOneWidget);
    // Its permission to enter.
    expect(find.text(items['B6'].toString()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list of places selects one', (tester) async {
    await pumpPlan(
        tester, const Size(393, 852), guide.site('imam_husayn_shrine')!);
    await tester.tap(find.byTooltip('Places on the map').first);
    await settle(tester);
    final row = find.text('Tomb of Habib ibn Mazahir (a.s.)');
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester);
    expect(find.text(items['G58'].toString()), findsOneWidget,
        reason: "the card lists Habib's ziyarat");
    expect(tester.takeException(), isNull);
  });
}
