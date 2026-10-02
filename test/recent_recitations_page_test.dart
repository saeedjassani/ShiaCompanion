import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/quran/recent_recitations_page.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

// Its own file rather than part of quran_page_test.dart: QuranPage starts a
// load on the shared RecitationTrackerManager that never settles in a widget
// test, and a later test logging a recitation would wait on it forever.
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

  testWidgets('a recent session can be removed', (tester) async {
    await RecitationTrackerManager.instance.logRecitation(
      id: 'recent_test',
      label: 'Family',
      surah: 1,
      fromAyah: 1,
      toAyah: 7,
      syncRemote: false,
    );
    await tester.pumpWidget(const MaterialApp(home: RecentRecitationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Surah1 1–7 · 7 verses'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Surah1 1–7 · 7 verses'), findsNothing);
    expect(find.textContaining('No sessions yet'), findsOneWidget);
  });
}
