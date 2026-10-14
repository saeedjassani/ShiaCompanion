import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/pages/zikr/zikr_reading_stats.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  testWidgets('al-Baqarah is fully seen only at its last ayah', (t) async {
    final uid = uidForSurah(2)!;
    final data = jsonDecode(File('assets/zikr/$uid').readAsStringSync())['data']
        as String;
    final reports = <ZikrContentScrollPosition>[];
    final verses = <QuranReadingPosition>[];

    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: [data],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          surahNumber: 2,
          onScrollPositionChanged: reports.add,
          onAyahPositionChanged: verses.add,
          footer: const SizedBox(height: 120),
          listPadding: const EdgeInsets.only(top: 80, bottom: 140),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(reports, isNotEmpty);
    expect(reports.last.seenFraction, isNotNull);
    expect(reports.last.seenFraction!, lessThan(0.1));

    final position =
        t.widget<ListView>(find.byType(ListView)).controller!.position;

    // Walk down to the first place the old 90% rule would have called the
    // surah recited.
    for (var i = 0; i < 4000; i++) {
      position.jumpTo(position.pixels + 200);
      await t.pump();
      if ((reports.last.seenFraction ?? 0) >= zikrCompletionSeenThreshold) {
        break;
      }
    }
    await t.pump();
    // Ayah 265 at the top in this layout: 21 ayahs, al-Baqarah's longest
    // among them, still to come - the "Completed" readers reported.
    expect(verses.last.verse.ayah!, lessThan(270));
    final nearEnd = reports.last.seenFraction!;
    expect(nearEnd, greaterThanOrEqualTo(zikrCompletionSeenThreshold),
        reason: 'what a dua would count as recited');
    expect(nearEnd, lessThan(zikrFullyReadThreshold),
        reason: 'ayahs are still below the screen');

    for (var i = 0; i < 20; i++) {
      position.jumpTo(position.maxScrollExtent);
      await t.pump();
    }
    expect(reports.last.seenFraction!,
        greaterThanOrEqualTo(zikrFullyReadThreshold));
  });

  testWidgets('Ziyarat Ashura is fully seen only at its last line', (t) async {
    final data =
        jsonDecode(File('assets/zikr/G4').readAsStringSync())['data'] as String;
    final reports = <ZikrContentScrollPosition>[];

    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: [data],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          onScrollPositionChanged: reports.add,
          listPadding: const EdgeInsets.only(top: 80, bottom: 140),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(reports.where((r) => r.seenFraction == null), isEmpty,
        reason: 'a laid out tab is always measured');

    final position =
        t.widget<ListView>(find.byType(ListView)).controller!.position;
    for (var i = 0; i < 2000; i++) {
      position.jumpTo(position.pixels + 50);
      await t.pump();
      if (reports.last.seenFraction! >= zikrCompletionSeenThreshold) break;
    }
    await t.pump();
    expect(position.pixels, lessThan(position.maxScrollExtent),
        reason: 'the ziyarah does not end at 90%');
    expect(reports.last.seenFraction!, lessThan(zikrFullyReadThreshold));

    for (var i = 0; i < 20; i++) {
      position.jumpTo(position.maxScrollExtent);
      await t.pump();
    }
    expect(reports.last.seenFraction!,
        greaterThanOrEqualTo(zikrFullyReadThreshold));
  });
}
