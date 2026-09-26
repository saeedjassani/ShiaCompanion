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

  group('zikrCompletionWait', () {
    // A 10-minute tab and a 1-minute tab.
    const tenMinutes = ZikrTabReadingStats(arabicWords: 1000, latinWords: 0);
    const oneMinute = ZikrTabReadingStats(arabicWords: 100, latinWords: 0);

    test('nothing read far enough yet', () {
      expect(
        zikrCompletionWait(
          seenFractions: {0: 0.5},
          tabs: const [tenMinutes],
          elapsed: const Duration(hours: 1),
        ),
        isNull,
      );
    });

    test('counts once 40% of the tab time has passed', () {
      expect(
        zikrCompletionWait(
          seenFractions: {0: 0.95},
          tabs: const [tenMinutes],
          elapsed: const Duration(minutes: 4),
        ),
        Duration.zero,
      );
      expect(
        zikrCompletionWait(
          seenFractions: {0: 0.95},
          tabs: const [tenMinutes],
          elapsed: const Duration(minutes: 1),
        ),
        const Duration(minutes: 3),
      );
    });

    test('a short dua still needs the ten-second floor', () {
      expect(
        zikrCompletionWait(
          seenFractions: {0: 1},
          tabs: const [ZikrTabReadingStats(arabicWords: 10, latinWords: 0)],
          elapsed: const Duration(seconds: 2),
        ),
        const Duration(seconds: 8),
      );
    });

    test('one finished tab of a multi-tab zikr is enough, timed by that tab',
        () {
      // Reading only the short second tab of a compilation must not wait on
      // the long first tab the reader never opened.
      expect(
        zikrCompletionWait(
          seenFractions: {1: 1},
          tabs: const [tenMinutes, oneMinute, tenMinutes],
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
      zikrCompletionWait(
        seenFractions: {0: seen},
        tabs: stats.tabs,
        elapsed: const Duration(minutes: 5),
      ),
      Duration.zero,
      reason: 'a five-minute recitation of a ~7 minute ziyarah counts',
    );
  });
}
