import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

/// A tab laid out as transliteration / Arabic / translation triplets, which
/// is what code 102 means, with a plain instruction line between the two
/// verses and a heading on top.
ParsedZikrContent _tripletContent() {
  return ZikrContentParser.parseContent(
    [
      'Recite this three times',
      'BISMILLAAHIR RAHMAANIR RAHEEM',
      'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ',
      'In the name of Allah, the Beneficent, the Merciful',
      'Then say',
      'ALHAMDU LILLAAHI RABBIL AALAMEEN',
      'اَلْحَمْدُ لِلّٰهِ رَبِّ الْعٰلَمِيْنَ',
      'All praise is due to Allah, Lord of the worlds',
    ].join('\n'),
    hideHeaderLine: false,
    code: '102',
  );
}

void main() {
  setUp(() {
    showTransliteration = true;
    showTranslation = true;
  });

  tearDown(() {
    showTransliteration = true;
    showTranslation = true;
  });

  group('parsed triplets', () {
    test('groups each Arabic line with its transliteration and translation',
        () {
      final content = _tripletContent();

      expect(content.arabicCodes, {2, 6});
      expect(content.transliCodes, {1, 5});
      expect(content.translaCodes, {3, 7});

      final group = content.groupContaining(2);
      expect(group, isNotNull);
      expect(group!.start, 1, reason: 'code 102 puts transliteration first');
      expect(group.end, 4);

      // Every member of the triplet resolves to the same span.
      expect(content.groupContaining(1), same(group));
      expect(content.groupContaining(3), same(group));
    });

    test('leaves standalone lines out of any triplet', () {
      final content = _tripletContent();
      expect(content.groupContaining(0), isNull, reason: 'heading');
      expect(content.groupContaining(4), isNull, reason: 'instruction line');
    });

    test('groups an Arabic-then-English layout the other way round', () {
      final content = ZikrContentParser.parseContent(
        [
          'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ',
          'ALLAAHUMMA SALLI ALAA MUHAMMAD',
          'O Allah, send blessings upon Muhammad',
        ].join('\n'),
        hideHeaderLine: false,
        code: '012',
      );

      final group = content.groupContaining(0);
      expect(group!.start, 0);
      expect(group.end, 3);
      expect(content.groupContaining(2), same(group));
    });
  });

  group('bookmarkedLineRange', () {
    test('covers the whole triplet when the reader stopped on the Arabic', () {
      final content = _tripletContent();
      final range = bookmarkedLineRange(
        bookmarkLineIndex: 2,
        content: content,
      );

      expect(range!.start, 1,
          reason: 'the tint starts at the triplet, not '
              'part way into it');
      expect(range.end, 4);
    });

    test('covers the same triplet from its transliteration or translation', () {
      final content = _tripletContent();
      for (final lineIndex in [1, 2, 3]) {
        final range = bookmarkedLineRange(
          bookmarkLineIndex: lineIndex,
          content: content,
        );
        expect(range!.start, 1, reason: 'bookmarked on line $lineIndex');
        expect(range.end, 4, reason: 'bookmarked on line $lineIndex');
      }
    });

    test('marks just the one line when it stands on its own', () {
      final content = _tripletContent();
      final range = bookmarkedLineRange(
        bookmarkLineIndex: 4,
        content: content,
      );

      expect(range!.start, 4);
      expect(range.end, 5);
      expect(range.contains(5), isFalse);
    });

    test('is null without a saved line, or for a line past the content', () {
      final content = _tripletContent();
      expect(
        bookmarkedLineRange(bookmarkLineIndex: null, content: content),
        isNull,
      );
      expect(
        bookmarkedLineRange(bookmarkLineIndex: 99, content: content),
        isNull,
      );
      expect(
        bookmarkedLineRange(bookmarkLineIndex: -1, content: content),
        isNull,
      );
    });

    test('does not move when the reading settings change', () {
      // The whole point of anchoring to a line: switching transliteration off
      // changes what is drawn, never which triplet is marked.
      final content = _tripletContent();
      final before =
          bookmarkedLineRange(bookmarkLineIndex: 2, content: content);

      showTransliteration = false;
      final after = bookmarkedLineRange(bookmarkLineIndex: 2, content: content);

      expect(after!.start, before!.start);
      expect(after.end, before.end);
    });
  });

  group('visible lines within the marker', () {
    test('skips a switched-off transliteration and moves the label down', () {
      final content = _tripletContent();
      final range =
          bookmarkedLineRange(bookmarkLineIndex: 2, content: content)!;

      expect(firstVisibleLineInRange(range, content), 1);
      expect(isZikrLineVisible(content, 1), isTrue);

      showTransliteration = false;
      expect(isZikrLineVisible(content, 1), isFalse,
          reason: 'a hidden line draws nothing, so it must not be tinted');
      expect(firstVisibleLineInRange(range, content), 2,
          reason: 'the label moves to the Arabic, the first line still shown');
    });

    test('keeps the label on the Arabic when the translation is off too', () {
      final content = _tripletContent();
      final range =
          bookmarkedLineRange(bookmarkLineIndex: 2, content: content)!;

      showTransliteration = false;
      showTranslation = false;

      expect(firstVisibleLineInRange(range, content), 2);
      expect(isZikrLineVisible(content, 3), isFalse);
    });

    test('reports no line to mark when the whole triplet is switched off', () {
      // An Arabic-less layout cannot happen, but a range of purely English
      // lines can be asked about, and must not be tinted into a stray band.
      final content = ZikrContentParser.parseContent(
        ['بِسْمِ اللّٰهِ', 'In the name of Allah'].join('\n'),
        hideHeaderLine: false,
        code: '02',
      );
      showTranslation = false;

      const translationOnly = ZikrLineGroup(start: 1, end: 2);
      expect(firstVisibleLineInRange(translationOnly, content), isNull);
    });
  });
}
