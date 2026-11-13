// Renders a shrine plan to PNGs for a person (or an agent) to look at:
//
//   flutter test scripts/ziyarat_maps/plan_shots_test.dart \
//     --dart-define=SITE=imam_husayn_shrine --dart-define=OUT=/some/dir
//
// Writes <site>_light.png, <site>_dark.png and <site>_list.png (the places
// list) at a phone's size, with real fonts (Roboto from Flutter's cache,
// Scheherazade for Arabic), plus one PNG per feature named in FEATURES
// (comma-separated ids) with its card open. Not part of `flutter test`'s
// default run (it lives outside test/).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/models/ziyarat_guide.dart';
import 'package:shia_companion/pages/ziyarat_guide/shrine_plan_view.dart';
import 'package:shia_companion/services/ziyarat_guide_repository.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import '../../test/ui/firebase_test_doubles.dart';
import '../../test/helpers/finders.dart';

const _site = String.fromEnvironment('SITE');
const _out = String.fromEnvironment('OUT');
const _features = String.fromEnvironment('FEATURES');

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  late ZiyaratGuide guide;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // A test in all but location (scripts/, so the default run skips it).
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
    final fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
        '/bin/cache/artifacts/material_fonts';
    await _font('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf',
    ]);
    await _font('Scheherazade', ['assets/fonts/scheherazade.ttf']);
    final zikr =
        json.decode(File('assets/zikr.json').readAsStringSync()) as Map;
    for (final entry in zikr.entries) {
      items[entry.key] = (entry.value as Map)['title'];
    }
    guide = ZiyaratGuide.fromJson(
        json.decode(File('assets/ziyarat_guide.json').readAsStringSync())
            as Map<String, dynamic>);
    final site = guide.site(_site);
    if (site?.plan == null) throw StateError('no plan for site "$_site"');
    await ZiyaratGuideRepository.loadPlan(site!.plan!);
  });

  Future<void> shot(WidgetTester tester, Widget page, String name,
      {Brightness brightness = Brightness.light,
      Future<void> Function()? then}) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    final theme = buildAppTheme(brightness);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
            textTheme: theme.textTheme.apply(
                fontFamily: 'Roboto', fontFamilyFallback: ['Scheherazade'])),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTextStyle(
          style: const TextStyle(
              fontFamily: 'Roboto', fontFamilyFallback: ['Scheherazade']),
          child: page,
        ),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    await settle();
    if (then != null) {
      await then();
      await settle();
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('plan shots', (tester) async {
    final site = guide.site(_site)!;
    final plan = site.plan!;
    Directory(_out).createSync(recursive: true);
    await shot(
        tester, ShrinePlanPage(plan: plan, site: site), '${_site}_light');
    await shot(tester, ShrinePlanPage(plan: plan, site: site), '${_site}_dark',
        brightness: Brightness.dark);
    await shot(
      tester,
      ShrinePlanPage(plan: plan, site: site),
      '${_site}_list',
      then: () => tester.tap(findTooltip('Places on the map').first),
    );
    for (final id in _features.split(',').where((id) => id.isNotEmpty)) {
      final feature = plan.features.firstWhere((f) => f.id == id);
      await shot(
          tester,
          ShrinePlanPage(plan: plan, site: site, initialFeature: feature),
          '${_site}_$id');
    }
  });
}
