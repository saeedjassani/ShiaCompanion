import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/qaza_tracker_state.dart';
import 'package:shia_companion/pages/qaza_tracker_page.dart';
import 'package:shia_companion/services/qaza_tracker_manager.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  setUpAll(setUpFirebaseForRenderTests);

  /// Signed out, with [counts] as the device's own qaza list.
  Future<void> seed(
    WidgetTester tester,
    Map<QazaEntryType, ({int remaining, int completed})> counts,
  ) async {
    SharedPreferences.setMockInitialValues({
      if (counts.isNotEmpty)
        'qaza_tracker_guest': jsonEncode({
          for (final entry in counts.entries)
            entry.key.key: {
              'remaining': entry.value.remaining,
              'completed': entry.value.completed,
            },
        }),
    });
    await tester.runAsync(() async {
      await SP.init();
      await QazaTrackerManager.instance.loadQaza(force: true);
    });
  }

  /// A bounded settle: a spinner would keep pumpAndSettle going forever.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: QazaTrackerPage()));
    await settle(tester);
  }

  testWidgets('with nothing owed, offers to work out how many',
      (tester) async {
    await seed(tester, {});
    await pump(tester);

    expect(find.text('Missed prayers for a while?'), findsOneWidget);
    expect(find.text('Work out how many I owe'), findsOneWidget);
    // The five daily prayers, Zuhr spelt as everywhere else; Namaz-e-Ayat
    // and Other wait behind the header link.
    expect(find.text('Zuhr'), findsOneWidget);
    expect(find.text('Namaz-e-Ayat'), findsNothing);

    await tester.tap(find.text('Add Namaz-e-Ayat or other'));
    await settle(tester);
    expect(find.text('Namaz-e-Ayat'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('sums up what is owed, a row per prayer', (tester) async {
    await seed(tester, {
      for (final type in qazaDailyPrayers) type: (remaining: 250, completed: 12),
      QazaEntryType.fast: (remaining: 30, completed: 0),
    });
    await pump(tester);

    expect(find.text('1,280'), findsOneWidget);
    expect(find.text('left to make up'), findsOneWidget);
    expect(find.text('60 done'), findsOneWidget);
    expect(find.text('250 left · 12 done', findRichText: true),
        findsNWidgets(5));
    expect(find.text('30 left · 0 done', findRichText: true), findsOneWidget);
    expect(find.text('Prayed'), findsNWidgets(5));
    expect(find.text('Fasted'), findsOneWidget);
  });

  testWidgets('the ⋯ menu holds the rarer actions', (tester) async {
    await seed(tester, {QazaEntryType.fajr: (remaining: 1, completed: 0)});
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('More for Fajr'));
    await settle(tester);
    expect(find.text('Add a missed one'), findsOneWidget);
    expect(find.text('Edit count'), findsOneWidget);
    // Nothing done yet, so nothing to undo.
    expect(find.text('Undo'), findsNothing);
  });
}
