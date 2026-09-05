import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';
import 'package:shia_companion/utils/quran_index.dart';

/// Two short surahs stitched together, the way a juz portion arrives.
AyahIndex _portionIndex() {
  final spans = <AyahSpan>[];
  var line = 0;
  for (final surah in [4, 5]) {
    for (var ayah = 1; ayah <= 6; ayah++) {
      spans.add(AyahSpan(surah: surah, ayah: ayah, start: line, end: line + 3));
      line += 3;
    }
  }
  return AyahIndex.fromSpans(spans);
}

void main() {
  group('resolveInitialVerse', () {
    // The reported bug: bookmark 5:81, reopen al-Maidah from the surah list,
    // and it opened at the top instead. The list passes VerseKey(5) with no
    // ayah, which used to shadow the bookmark entirely.
    test('a surah with no ayah asked for resumes at the bookmark', () {
      expect(
        resolveInitialVerse(
          requested: const VerseKey(5),
          bookmarked: const VerseKey(5, 81),
        ),
        const VerseKey(5, 81),
      );
    });

    test('a verse that was asked for wins over the bookmark', () {
      expect(
        resolveInitialVerse(
          requested: const VerseKey(5, 12),
          bookmarked: const VerseKey(5, 81),
        ),
        const VerseKey(5, 12),
      );
    });

    test('with nothing asked for it is the bookmark', () {
      expect(
        resolveInitialVerse(requested: null, bookmarked: const VerseKey(5, 81)),
        const VerseKey(5, 81),
      );
    });

    test('with no bookmark and no ayah there is nowhere to go', () {
      expect(
        resolveInitialVerse(requested: const VerseKey(5), bookmarked: null),
        isNull,
      );
      expect(resolveInitialVerse(requested: null, bookmarked: null), isNull);
    });
  });

  group('bookmarkedVerseInPortion', () {
    test('finds a bookmark stored against a surah the juz passes through', () {
      // Bookmarking 5:2 while reading the juz writes against al-Maidah, so
      // this is what has to find it again when the juz is reopened.
      expect(
        bookmarkedVerseInPortion(
          _portionIndex(),
          (surah) => surah == 5 ? 2 : null,
        ),
        const VerseKey(5, 2),
      );
    });

    test('ignores a bookmark whose verse this juz does not reach', () {
      // Al-Maidah is in the portion, but only its first six verses are.
      expect(
        bookmarkedVerseInPortion(
          _portionIndex(),
          (surah) => surah == 5 ? 99 : null,
        ),
        isNull,
      );
    });

    test('ignores surahs the portion does not cover at all', () {
      expect(
        bookmarkedVerseInPortion(
          _portionIndex(),
          (surah) => surah == 2 ? 1 : null,
        ),
        isNull,
      );
    });

    test('is null when nothing in the portion is bookmarked', () {
      expect(bookmarkedVerseInPortion(_portionIndex(), (_) => null), isNull);
    });

    test('only asks about the surahs the portion actually covers', () {
      final asked = <int>[];
      bookmarkedVerseInPortion(_portionIndex(), (surah) {
        asked.add(surah);
        return null;
      });

      expect(asked.toSet(), {4, 5});
    });
  });

  group('a bookmark and the verse it means', () {
    test('an ayah is enough to place a bookmark in another document', () {
      // The whole reason the bookmark carries an ayah: the same verse has to
      // be findable in the juz that was being read and in the surah's own
      // page, which number their lines completely differently.
      final portion = _portionIndex();
      final surahOnly = AyahIndex.fromSpans([
        for (var ayah = 1; ayah <= 10; ayah++)
          AyahSpan(surah: 5, ayah: ayah, start: ayah * 3, end: ayah * 3 + 3),
      ]);

      const verse = VerseKey(5, 2);
      final inPortion = portion.spanIndexForVerse(verse);
      final inSurah = surahOnly.spanIndexForVerse(verse);

      expect(inPortion, isNotNull);
      expect(inSurah, isNotNull);
      expect(
        portion.spans[inPortion!].start,
        isNot(surahOnly.spans[inSurah!].start),
        reason: 'the lines differ, which is why the ayah is what is stored',
      );
    });
  });
}
