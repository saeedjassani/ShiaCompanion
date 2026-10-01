import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_reading_stats.dart';

void main() {
  group('zikrTabSeenFraction', () {
    test('measures to the bottom of the view, not the top', () {
      // 10,000px of text in a 1,000px view: scrolled to 8,000 means the
      // reader can see down to 9,000 of 10,000.
      expect(
        zikrTabSeenFraction(
          scrollOffset: 8000,
          maxScrollExtent: 9000,
          viewportDimension: 1000,
        ),
        closeTo(0.9, 1e-9),
      );
    });

    test('a tab that fits on screen is fully seen', () {
      expect(
        zikrTabSeenFraction(
          scrollOffset: 0,
          maxScrollExtent: 0,
          viewportDimension: 800,
        ),
        1,
      );
    });

    test('the first screenful counts as seen', () {
      expect(
        zikrTabSeenFraction(
          scrollOffset: 0,
          maxScrollExtent: 3000,
          viewportDimension: 1000,
        ),
        closeTo(0.25, 1e-9),
      );
    });
  });

  group('zikrTabCompletionWait', () {
    // A 10-minute tab and a 1-minute tab.
    const tenMinutes = ZikrTabReadingStats(arabicWords: 1000, latinWords: 0);
    const oneMinute = ZikrTabReadingStats(arabicWords: 100, latinWords: 0);

    test('nothing read far enough yet', () {
      expect(
        zikrTabCompletionWait(
          seenFraction: 0.5,
          tab: tenMinutes,
          elapsed: const Duration(hours: 1),
        ),
        isNull,
      );
    });

    test('counts once 40% of the tab time has passed', () {
      expect(
        zikrTabCompletionWait(
          seenFraction: 0.95,
          tab: tenMinutes,
          elapsed: const Duration(minutes: 4),
        ),
        Duration.zero,
      );
      expect(
        zikrTabCompletionWait(
          seenFraction: 0.95,
          tab: tenMinutes,
          elapsed: const Duration(minutes: 1),
        ),
        const Duration(minutes: 3),
      );
    });

    test('a short dua still needs the ten-second floor', () {
      expect(
        zikrTabCompletionWait(
          seenFraction: 1,
          tab: const ZikrTabReadingStats(arabicWords: 10, latinWords: 0),
          elapsed: const Duration(seconds: 2),
        ),
        const Duration(seconds: 8),
      );
    });

    test('a tab is timed by its own length, not the compilation\'s', () {
      expect(
        zikrTabCompletionWait(
          seenFraction: 1,
          tab: oneMinute,
          elapsed: const Duration(seconds: 30),
        ),
        Duration.zero,
      );
    });
  });

  test('Ziyarat Ashura counts with the sajdah passage on screen', () {
    // The last ~5% of Ziyarat Ashura is recited in sajdah, so the reader
    // stops scrolling with it still on screen rather than scrolling it away.
    final data =
        jsonDecode(File('assets/zikr/G4').readAsStringSync())['data'] as String;
    final lines =
        data.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final sajdah = lines.indexWhere((line) => line.contains('Sajdah'));
    expect(sajdah, greaterThan(0));

    // Lines as uniform height: the sajdah instruction sits at the very bottom
    // of the view - the least of it the reader could have seen.
    const lineHeight = 40.0;
    const viewport = 800.0;
    final total = lines.length * lineHeight;
    final seen = zikrTabSeenFraction(
      scrollOffset: (sajdah + 1) * lineHeight - viewport,
      maxScrollExtent: total - viewport,
      viewportDimension: viewport,
    );
    expect(seen, greaterThanOrEqualTo(zikrCompletionSeenThreshold));

    final stats = analyzeZikrReadingStats([data]);
    expect(
      zikrTabCompletionWait(
        seenFraction: seen,
        tab: stats.tabs.single,
        elapsed: const Duration(minutes: 5),
      ),
      Duration.zero,
      reason: 'a five-minute recitation of a ~7 minute ziyarah counts',
    );
  });
}
