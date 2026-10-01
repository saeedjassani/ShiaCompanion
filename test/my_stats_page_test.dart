import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/my_stats_page.dart';
import 'package:shia_companion/services/activity_stats_store.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
    items = {
      for (var surah = 1; surah <= surahCount; surah++)
        uidForSurah(surah)!: '$surah: Surah$surah اسم',
    };
  });

  tearDownAll(() => items = {});

  testWidgets('My Stats shows streak, history, Quran progress and milestones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tracker = RecitationTrackerManager.instance;
    await tracker.addLabel('Family');
    // Al-Fatihah and the first juz of al-Baqarah over three days.
    await tracker.logRecitation(
      label: 'Family',
      surah: 1,
      fromAyah: 1,
      toAyah: 7,
      recitedAt: DateTime(now.year, now.month, now.day - 2, 9),
      syncRemote: false,
    );
    await tracker.logRecitation(
      label: 'Family',
      surah: 2,
      fromAyah: 1,
      toAyah: 141,
      recitedAt: DateTime(now.year, now.month, now.day - 1, 9),
      syncRemote: false,
    );
    await tracker.logRecitation(
      label: 'Family',
      surah: 2,
      fromAyah: 142,
      toAyah: 160,
      recitedAt: DateTime(now.year, now.month, now.day, 9),
      syncRemote: false,
    );
    await ActivityStatsStore.instance.recordZikrCompleted('X1');

    await tester.pumpWidget(const MaterialApp(home: MyStatsPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('Quran progress'), findsOneWidget);
    expect(find.text('Family'), findsWidgets);
    expect(find.text('Recited till'), findsOneWidget);
    expect(find.text('Surah2: 160'), findsOneWidget);
    expect(find.text('Juz 2'), findsOneWidget);
    expect(find.text('Milestones'), findsOneWidget);
    expect(find.text('3-day streak'), findsOneWidget);
    expect(find.text('100 verses'), findsOneWidget);

    // Switching the history metric re-plots without error.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Zikrs'));
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
