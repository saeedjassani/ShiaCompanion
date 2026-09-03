import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

void main() {
  group('snapToArabicLineIndex', () {
    test('lands exactly on the verse when the fraction matches it exactly', () {
      expect(
        snapToArabicLineIndex(
          scrollFraction: 3 / 9,
          lineCount: 10,
          arabicLineIndexes: {0, 3, 6},
        ),
        3,
      );
    });

    test('snaps backward to the verse already on screen, not the one ahead',
        () {
      // Estimated line 5 (from fraction 0.6) sits between verses at 3 and 6,
      // closer to 6 by distance - but the verse at 3 is what is actually
      // showing at the top of the view, so that is what gets marked, not
      // the one still ahead that has not been reached yet.
      expect(
        snapToArabicLineIndex(
          scrollFraction: 0.6,
          lineCount: 10,
          arabicLineIndexes: {0, 3, 6},
        ),
        3,
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

    test('falls back to the first verse before reaching any Arabic line', () {
      expect(
        snapToArabicLineIndex(
          scrollFraction: 0.0,
          lineCount: 10,
          arabicLineIndexes: {3, 6},
        ),
        3,
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

    test(
        'is stable across repeated calls at the same position - regression '
        'for the reported drift', () {
      // Bookmarking twice in a row without deliberately scrolling must
      // return the same verse both times, not creep forward. This is a
      // direct regression test for the original bug: forward-snapping only
      // held for the single instant an estimate sat exactly on a verse's
      // start index, so any small scroll jitter pushed it just past that
      // point and the marker jumped to the next verse - repeatable, and
      // one-directional. Backward-snapping is stable across a verse's
      // entire span instead of a single point.
      const arabicLines = {0, 5, 11, 20};
      final first = snapToArabicLineIndex(
        scrollFraction: 0.3,
        lineCount: 40,
        arabicLineIndexes: arabicLines,
      );
      final second = snapToArabicLineIndex(
        scrollFraction: 0.3,
        lineCount: 40,
        arabicLineIndexes: arabicLines,
      );
      expect(first, second);

      // A small jitter that stays within the same verse's span must not
      // move the result either.
      final jittered = snapToArabicLineIndex(
        scrollFraction: 0.32,
        lineCount: 40,
        arabicLineIndexes: arabicLines,
      );
      expect(jittered, first);
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
