import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/tasbeeh_state.dart';
import 'package:shia_companion/pages/tasbeeh_page.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  group('Tasbih al-Zahra progress', () {
    test('walks the three phrases at 34, 33 and 33', () {
      expect(const ZahraProgress(0).phaseIndex, 0);
      expect(const ZahraProgress(33).phaseIndex, 0);
      expect(const ZahraProgress(33).countInPhase, 33);
      expect(const ZahraProgress(34).phaseIndex, 1);
      expect(const ZahraProgress(34).countInPhase, 0);
      expect(const ZahraProgress(66).phaseIndex, 1);
      expect(const ZahraProgress(67).phaseIndex, 2);
      expect(const ZahraProgress(99).countInPhase, 32);
      expect(const ZahraProgress(99).isComplete, isFalse);
      expect(const ZahraProgress(100).isComplete, isTrue);
      expect(const ZahraProgress(100).phaseIndex, 2);
    });

    test('fills each phrase bar in turn', () {
      const progress = ZahraProgress(50);
      expect(progress.fillOf(0), 1);
      expect(progress.fillOf(1), closeTo(16 / 33, 1e-9));
      expect(progress.fillOf(2), 0);
    });

    test('marks the end of each phrase', () {
      expect(
        [for (var i = 1; i <= 100; i++) if (ZahraProgress.isTarget(i)) i],
        [34, 67, 100],
      );
    });

    test('a free count looks ahead to its next target', () {
      expect(nextFreeTarget(0, [100, 34, 67]), 34);
      expect(nextFreeTarget(34, defaultFreeTargets), 100);
      expect(nextFreeTarget(100, defaultFreeTargets), 200);
      expect(nextFreeTarget(300, defaultFreeTargets), isNull);
      expect(nextFreeTarget(5, const []), isNull);
    });
  });

  group('Tasbeeh page', () {
    testWidgets('starts guided on Tasbih al-Zahra for a new user',
        (tester) async {
      await _pump(tester, {});

      expect(find.text('Tasbeeh'), findsOneWidget);
      expect(find.text('Allahu Akbar · 34'), findsOneWidget);
      expect(find.text('اَللّٰهُ اَكْبَرُ'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('of 34'), findsOneWidget);
      expect(find.text('Total 0 of 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moves on to Alhamdulillah after 34', (tester) async {
      await _pump(tester, {});

      await _tapPanel(tester, 34);

      expect(find.text('اَلْحَمْدُ لِلّٰهِ'), findsOneWidget);
      expect(find.text('Alhamdulillah'), findsOneWidget);
      expect(find.text('of 33'), findsOneWidget);
      expect(find.text('Total 34 of 100'), findsOneWidget);
      expect(SP.prefs.getInt(TasbeehPage.zahraCountKey), 34,
          reason: 'saved on every count, not only on leaving');
    });

    testWidgets('completes at 100, and a tap starts it again',
        (tester) async {
      await _pump(tester, {TasbeehPage.zahraCountKey: 99});

      await _tapPanel(tester, 1);
      expect(find.text('Tasbih al-Zahra complete'), findsOneWidget);
      expect(find.text('100 of 100 · tap to start again'), findsOneWidget);

      await _tapPanel(tester, 1);
      expect(find.text('Tasbih al-Zahra complete'), findsNothing);
      expect(find.text('Total 0 of 100'), findsOneWidget);
    });

    testWidgets('−1 takes one back, and Reset asks first', (tester) async {
      await _pump(tester, {TasbeehPage.zahraCountKey: 10});

      await tester.tap(find.text('−1'));
      await tester.pump();
      expect(find.text('Total 9 of 100'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('Start again from 0?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Total 9 of 100'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('Start again from 0?'), findsNothing);
      expect(find.text('Total 0 of 100'), findsOneWidget);
      expect(SP.prefs.getInt(TasbeehPage.zahraCountKey), 0);
    });

    testWidgets('someone mid-way through an old count carries on in Free count',
        (tester) async {
      await _pump(tester, {TasbeehPage.freeCountKey: 250});

      expect(find.text('250'), findsOneWidget);
      expect(find.text('Next target 300'), findsOneWidget);
      expect(find.text('Allahu Akbar · 34'), findsNothing);
    });

    testWidgets('each way of counting keeps its own count', (tester) async {
      await _pump(tester, {});

      await _tapPanel(tester, 3);
      await tester.tap(find.text('Free count'));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Next target 100'), findsOneWidget);

      await _tapPanel(tester, 5);
      expect(find.text('5'), findsOneWidget);
      expect(SP.prefs.getInt(TasbeehPage.freeCountKey), 5);
      expect(SP.prefs.getString(TasbeehPage.modeKey), 'free');

      await tester.tap(find.text('Tasbih al-Zahra'));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('beep, vibration and targets are kept from the settings sheet',
        (tester) async {
      await _pump(tester, {TasbeehPage.modeKey: 'free'});

      await tester.tap(find.bySemanticsLabel('Counter settings'));
      await tester.pumpAndSettle();
      expect(find.text('Beep at each target'), findsOneWidget);

      await tester.tap(find.text('Beep at each target'));
      await tester.pump();
      expect(SP.prefs.getBool(TasbeehPage.beepKey), isFalse);

      await tester.enterText(find.byType(TextField).first, '33');
      await tester.pump();
      expect(SP.prefs.getStringList(TasbeehPage.targetsKey),
          ['33', '200', '300']);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Next target 33'), findsOneWidget);
    });

    testWidgets('fits a small phone at 1.5x text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, {TasbeehPage.zahraCountKey: 40});
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pump(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  await SP.init();
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: const TasbeehPage(),
  ));
  await tester.pump();
}

Future<void> _tapPanel(WidgetTester tester, int times) async {
  final panel = find.text('Tap anywhere');
  for (var i = 0; i < times; i++) {
    await tester.tap(panel);
    await tester.pump();
  }
}
