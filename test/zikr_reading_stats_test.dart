import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_reading_stats.dart';

/// `words` Arabic words on a single line.
String _arabicLine(int words) => List.filled(words, 'اللهم').join(' ');

/// `words` Latin words on a single line.
String _latinLine(int words) => List.filled(words, 'word').join(' ');

void main() {
  group('analyzeZikrReadingStats', () {
    test('times Arabic tabs by their Arabic words alone', () {
      final stats = analyzeZikrReadingStats([
        '${_arabicLine(100)}\n${_latinLine(200)}',
      ]);

      expect(stats.hasContent, isTrue);
      expect(stats.tabs.single.arabicWords, 100);
      expect(stats.tabs.single.latinWords, 200);
      expect(stats.duration, const Duration(minutes: 1));
    });

    test('falls back to reading speed when a tab has no Arabic', () {
      final stats = analyzeZikrReadingStats([_latinLine(190)]);

      expect(stats.tabs.single.arabicWords, 0);
      expect(stats.duration, const Duration(minutes: 1));
    });

    test('drops the header line when it is shown as a tab chip', () {
      final stats = analyzeZikrReadingStats(
        ['Part one\n${_arabicLine(45)}'],
        hideHeaderLine: true,
      );

      expect(stats.tabs.single.latinWords, 0);
      expect(stats.tabs.single.arabicWords, 45);
    });

    test('counts markdown link labels but not their targets', () {
      final stats = analyzeZikrReadingStats(
        ['Read [the full source](https://example.com/a/very/long/path)'],
      );

      expect(stats.tabs.single.latinWords, 4);
    });

    test('reports no content for blank tabs', () {
      final stats = analyzeZikrReadingStats(['', '   \n\n']);

      expect(stats.hasContent, isFalse);
      expect(stats.duration, Duration.zero);
    });

    test('has no content without tabs', () {
      expect(ZikrReadingStats.empty.hasContent, isFalse);
    });
  });

  group('zikrTabScrollFraction', () {
    test('treats content that fits on screen as fully read', () {
      expect(
        zikrTabScrollFraction(scrollOffset: 0, maxScrollExtent: 0),
        1,
      );
    });

    test('reports the scrolled share and clamps overscroll', () {
      expect(
        zikrTabScrollFraction(scrollOffset: 50, maxScrollExtent: 200),
        0.25,
      );
      expect(
        zikrTabScrollFraction(scrollOffset: -30, maxScrollExtent: 200),
        0,
      );
      expect(
        zikrTabScrollFraction(scrollOffset: 260, maxScrollExtent: 200),
        1,
      );
    });
  });

  group('zikrSmoothedTabFraction', () {
    test('passes through the first measurement of a tab', () {
      expect(
        zikrSmoothedTabFraction(
          rawFraction: 0.4,
          scrollOffset: 100,
          previousScrollOffset: null,
          previousDisplayedFraction: null,
        ),
        0.4,
      );
    });

    test('holds the best-so-far value against a dip while moving forward', () {
      // ListView.builder revised its maxScrollExtent estimate upward, so the
      // fraction dropped even though the offset kept increasing.
      expect(
        zikrSmoothedTabFraction(
          rawFraction: 0.3,
          scrollOffset: 150,
          previousScrollOffset: 100,
          previousDisplayedFraction: 0.4,
        ),
        0.4,
      );
    });

    test('adopts a higher fraction once it overtakes the held value', () {
      expect(
        zikrSmoothedTabFraction(
          rawFraction: 0.5,
          scrollOffset: 150,
          previousScrollOffset: 100,
          previousDisplayedFraction: 0.4,
        ),
        0.5,
      );
    });

    test('lets a real backward scroll bring the fraction back down', () {
      expect(
        zikrSmoothedTabFraction(
          rawFraction: 0.2,
          scrollOffset: 50,
          previousScrollOffset: 100,
          previousDisplayedFraction: 0.4,
        ),
        0.2,
      );
    });
  });

  group('zikrLineWeights', () {
    test('weights a tab with Arabic by its Arabic words alone', () {
      expect(
        zikrLineWeights([
          'Heading line',
          'بِسْمِ اللّهِ الرَّحْمٰنِ',
          'Bismillah ar-Rahman',
          'In the name of Allah',
          '',
        ]),
        [0, 3, 0, 0, 0],
      );
    });

    test('weights a tab without Arabic by all of its words', () {
      expect(zikrLineWeights(['one two', 'three', '']), [2, 1, 0]);
    });
  });

  group('zikrContentFractionAbove', () {
    test('measures by words, not by the heights of unbuilt items', () {
      // A heading, a 90-word paragraph and a closing note, as paragraph view
      // lays them out: the estimate for the unbuilt paragraph is irrelevant,
      // since only the built items around the line are measured.
      const weights = [0.0, 90.0, 10.0];
      const laidOut = [
        ZikrLaidOutItem(index: 0, top: 0, extent: 40),
        ZikrLaidOutItem(index: 1, top: 40, extent: 3000),
      ];
      expect(
        zikrContentFractionAbove(
          itemWeights: weights,
          laidOut: laidOut,
          line: 40 + 1500,
        ),
        closeTo(0.45, 1e-9),
      );
    });

    test('counts items ahead of the built range as passed', () {
      expect(
        zikrContentFractionAbove(
          itemWeights: const [10, 10, 10, 10],
          laidOut: const [
            ZikrLaidOutItem(index: 2, top: 500, extent: 100),
            ZikrLaidOutItem(index: 3, top: 600, extent: 100),
          ],
          line: 550,
        ),
        closeTo(0.625, 1e-9),
      );
    });

    test('ignores weightless items and the padding around the list', () {
      const weights = [0.0, 10.0, 0.0];
      const laidOut = [
        ZikrLaidOutItem(index: 0, top: 100, extent: 20),
        ZikrLaidOutItem(index: 1, top: 120, extent: 100),
        ZikrLaidOutItem(index: 2, top: 220, extent: 30),
      ];
      expect(
        zikrContentFractionAbove(
            itemWeights: weights, laidOut: laidOut, line: 50),
        0,
      );
      expect(
        zikrContentFractionAbove(
            itemWeights: weights, laidOut: laidOut, line: 400),
        1,
      );
    });

    test('cannot measure a tab without words or without layout', () {
      expect(
        zikrContentFractionAbove(
          itemWeights: const [0, 0],
          laidOut: const [ZikrLaidOutItem(index: 0, top: 0, extent: 10)],
          line: 5,
        ),
        isNull,
      );
      expect(
        zikrContentFractionAbove(
            itemWeights: const [1], laidOut: const [], line: 5),
        isNull,
      );
    });
  });

  group('zikrReadingLine', () {
    test('starts at the top of the view and ends at the bottom', () {
      expect(
        zikrReadingLine(
            scrollOffset: 0, maxScrollExtent: 2000, viewportDimension: 800),
        0,
      );
      expect(
        zikrReadingLine(
            scrollOffset: 1000, maxScrollExtent: 2000, viewportDimension: 800),
        1400,
      );
      expect(
        zikrReadingLine(
            scrollOffset: 2000, maxScrollExtent: 2000, viewportDimension: 800),
        2800,
      );
    });

    test('is the bottom of the view for a tab that fits on screen', () {
      expect(
        zikrReadingLine(
            scrollOffset: 0, maxScrollExtent: 0, viewportDimension: 800),
        800,
      );
    });
  });

  group('labels', () {
    test('formats durations for the reader', () {
      expect(formatZikrDuration(const Duration(seconds: 20)), 'under 1 min');
      expect(formatZikrDuration(const Duration(minutes: 8)), '8 min');
      expect(formatZikrDuration(const Duration(minutes: 60)), '1 hr');
      expect(formatZikrDuration(const Duration(minutes: 65)), '1 hr 5 min');
      expect(formatZikrDuration(const Duration(minutes: 125)), '2 hrs 5 min');
    });

    test('labels the reading time estimate', () {
      expect(
        zikrReadingTimeLabel(const Duration(minutes: 3)),
        '3 min read',
      );
    });

    test('rounds progress down', () {
      expect(zikrProgressLabel(0), '0%');
      expect(zikrProgressLabel(0.339), '33%');
      expect(zikrProgressLabel(0.98), '98%');
      expect(zikrProgressLabel(1), '100%');
    });

    test('says Completed only once the tab counts as recited', () {
      expect(zikrProgressLabel(1, completed: true), 'Completed');
      // Returning to the top of a recited tab to read it again.
      expect(zikrProgressLabel(0.1, completed: true), 'Completed');
    });
  });
}
