import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

void main() {
  group('snapToArabicLineIndex', () {
    test('lands on the verse at the exact fraction', () {
      // 10 lines, Arabic starts at 0, 3, 6 - scrolling to 60% (line ~5.4,
      // rounds to 5) should snap forward to the verse starting at 6.
      expect(
        snapToArabicLineIndex(
          scrollFraction: 0.6,
          lineCount: 10,
          arabicLineIndexes: {0, 3, 6},
        ),
        6,
      );
    });

    test('snaps forward, not to the nearest verse in either direction', () {
      // Estimated line 4 sits between verses at 3 and 6, closer to 3, but
      // reading continues past whatever was on screen - the verse ahead
      // (6) is the more natural "resume from here" than the one behind.
      expect(
        snapToArabicLineIndex(
          scrollFraction: 0.4,
          lineCount: 10,
          arabicLineIndexes: {0, 3, 6},
        ),
        6,
      );
    });

    test('never lands mid-verse - always exactly on an Arabic index', () {
      const arabicLines = {0, 5, 11, 20, 34};
      for (var i = 0; i <= 10; i++) {
        final fraction = i / 10;
        final snapped = snapToArabicLineIndex(
          scrollFraction: fraction,
          lineCount: 40,
          arabicLineIndexes: arabicLines,
        );
        expect(arabicLines, contains(snapped),
            reason: 'fraction $fraction snapped to $snapped');
      }
    });

    test('falls back to the last verse once past every Arabic line', () {
      expect(
        snapToArabicLineIndex(
          scrollFraction: 1.0,
          lineCount: 10,
          arabicLineIndexes: {0, 3, 6},
        ),
        6,
      );
    });

    test('is null without any Arabic line to anchor to', () {
      expect(
        snapToArabicLineIndex(
          scrollFraction: 0.5,
          lineCount: 10,
          arabicLineIndexes: {},
        ),
        isNull,
      );
    });

    test('is null for content with no lines at all', () {
      expect(
        snapToArabicLineIndex(
          scrollFraction: 0.5,
          lineCount: 0,
          arabicLineIndexes: {0},
        ),
        isNull,
      );
    });

    test('clamps an out-of-range fraction instead of throwing', () {
      expect(
        snapToArabicLineIndex(
          scrollFraction: -0.5,
          lineCount: 10,
          arabicLineIndexes: {0, 5},
        ),
        0,
      );
      expect(
        snapToArabicLineIndex(
          scrollFraction: 1.5,
          lineCount: 10,
          arabicLineIndexes: {0, 5},
        ),
        5,
      );
    });
  });

  group('BookmarkedVerseRange', () {
    test('ends where the next Arabic line begins', () {
      final range = BookmarkedVerseRange.fromStart(
        3,
        arabicLineIndexes: {0, 3, 6},
        lineCount: 10,
      );
      expect(range!.start, 3);
      expect(range.end, 6);
      expect(range.contains(3), isTrue);
      expect(range.contains(4), isTrue);
      expect(range.contains(5), isTrue);
      expect(range.contains(6), isFalse,
          reason: 'that line starts the next verse');
      expect(range.contains(2), isFalse);
    });

    test('runs to the end of the content for the last verse', () {
      final range = BookmarkedVerseRange.fromStart(
        6,
        arabicLineIndexes: {0, 3, 6},
        lineCount: 10,
      );
      expect(range!.start, 6);
      expect(range.end, 10);
    });

    test('is null without a start index', () {
      expect(
        BookmarkedVerseRange.fromStart(
          null,
          arabicLineIndexes: {0, 3},
          lineCount: 10,
        ),
        isNull,
      );
    });
  });
}
