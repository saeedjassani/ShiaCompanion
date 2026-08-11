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
        '${_arabicLine(45)}\n${_latinLine(200)}',
      ]);

      expect(stats.hasContent, isTrue);
      expect(stats.tabs.single.arabicWords, 45);
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

    test('weights tabs by their share of the reciting time', () {
      final stats = analyzeZikrReadingStats([
        _arabicLine(30),
        _arabicLine(10),
      ]);

      expect(stats.tabWeights, [closeTo(0.75, 0.0001), closeTo(0.25, 0.0001)]);
    });

    test('weights empty tabs equally instead of dividing by zero', () {
      final stats = analyzeZikrReadingStats(['', '']);

      expect(stats.tabWeights, [0.5, 0.5]);
    });

    test('has no weights without tabs', () {
      expect(ZikrReadingStats.empty.tabWeights, isEmpty);
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

  group('zikrReadingProgress', () {
    test('counts earlier tabs as complete', () {
      expect(
        zikrReadingProgress(
          tabWeights: const [0.75, 0.25],
          tabIndex: 1,
          tabFraction: 0.5,
        ),
        closeTo(0.875, 0.0001),
      );
    });

    test('scales the current tab by its own weight', () {
      expect(
        zikrReadingProgress(
          tabWeights: const [0.75, 0.25],
          tabIndex: 0,
          tabFraction: 0.5,
        ),
        closeTo(0.375, 0.0001),
      );
    });

    test('clamps an out of range tab index', () {
      expect(
        zikrReadingProgress(
          tabWeights: const [1],
          tabIndex: 4,
          tabFraction: 1,
        ),
        1,
      );
    });

    test('is zero without tabs', () {
      expect(
        zikrReadingProgress(tabWeights: const [], tabIndex: 0, tabFraction: 1),
        0,
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

    test('rounds progress down until the zikr is finished', () {
      expect(zikrProgressLabel(0), '0%');
      expect(zikrProgressLabel(0.339), '33%');
      expect(zikrProgressLabel(0.98), '98%');
      expect(zikrProgressLabel(1), 'Completed');
    });
  });
}
