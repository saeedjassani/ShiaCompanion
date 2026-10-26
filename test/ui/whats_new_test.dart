import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/whats_new_notes.dart';
import 'package:shia_companion/pages/home/color_card.dart';
import 'package:shia_companion/pages/whats_new_page.dart';
import 'package:shia_companion/services/whats_new_service.dart';
import 'package:shia_companion/theme/app_palette.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/theme_palette.dart';

import 'firebase_test_doubles.dart';

void main() {
  final original = List<WhatsNewEntry>.of(whatsNewNotes);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
  });

  tearDownAll(() {
    whatsNewNotes
      ..clear()
      ..addAll(original);
  });

  Future<ThemePaletteProvider> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final palette = ThemePaletteProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: palette,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: child,
        ),
      ),
    );
    await tester.pump();
    return palette;
  }

  group('What\'s new page', () {
    setUp(() async {
      whatsNewNotes
        ..clear()
        ..addAll([
          WhatsNewEntry(
              buildNumber: 100,
              versionName: '1.0.0',
              bullets: [(_) => 'older note']),
          WhatsNewEntry(
              buildNumber: 110,
              versionName: '1.1.0',
              bullets: [(_) => 'newer note'],
              iosBullets: [(_) => 'iOS note']),
        ]);
      SharedPreferences.setMockInitialValues(
          {WhatsNewService.lastSeenBuildKey: 100});
      await SP.init();
      WhatsNewService.debugCurrentBuild = 110;
      WhatsNewService.hasUnread.value = true;
    });

    testWidgets('lists every release, newest first, tagging the unseen one',
        (tester) async {
      await pump(tester, const WhatsNewPage(platform: TargetPlatform.android));

      expect(find.text('newer note'), findsOneWidget);
      expect(find.text('older note'), findsOneWidget);
      expect(find.text('iOS note'), findsNothing);
      expect(
        tester.getTopLeft(find.text('VERSION 1.1.0')).dy,
        lessThan(tester.getTopLeft(find.text('VERSION 1.0.0')).dy),
      );
      // One tag, on 1.1.0.
      expect(find.text('NEW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening it clears the dot', (tester) async {
      await pump(tester, const WhatsNewPage(platform: TargetPlatform.android));

      expect(WhatsNewService.hasUnread.value, isFalse);
      expect(SP.prefs.getInt(WhatsNewService.lastSeenBuildKey), 110);
    });
  });

  group('Home color card', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
    });

    test('shows until a color is chosen or it is dismissed', () async {
      expect(HomeColorCard.shouldShow(isWeb: false), isTrue);
      expect(HomeColorCard.shouldShow(isWeb: true), isFalse);

      SharedPreferences.setMockInitialValues(
          {ThemePaletteProvider.prefsKey: 'teal'});
      await SP.init();
      expect(HomeColorCard.shouldShow(isWeb: false), isFalse);

      SharedPreferences.setMockInitialValues({});
      await SP.init();
      await HomeColorCard.markDismissed();
      expect(HomeColorCard.shouldShow(isWeb: false), isFalse);
    });

    testWidgets('a swatch applies its color, and the card stays',
        (tester) async {
      final palette = await pump(
        tester,
        Scaffold(body: HomeColorCard(onDismiss: () {})),
      );

      await tester.tap(find.bySemanticsLabel('Teal'));
      await tester.pump();

      expect(palette.palette, AppPalette.teal);
      expect(find.text('Choose your color'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('close puts it away for good', (tester) async {
      var dismissed = false;
      await pump(
        tester,
        Scaffold(body: HomeColorCard(onDismiss: () => dismissed = true)),
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      expect(dismissed, isTrue);
      expect(SP.prefs.getBool(HomeColorCard.dismissedKey), isTrue);
    });
  });
}
