import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_ali_verses.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('quranAliVerses', () {
    test('every key is a real ayah of its surah', () {
      for (final verse in quranAliVerses.keys) {
        final count = ayahCountOf(verse.surah);
        expect(count, isNotNull, reason: 'surah ${verse.surah} does not exist');
        expect(
          verse.ayah,
          allOf(isNotNull, greaterThanOrEqualTo(1), lessThanOrEqualTo(count!)),
          reason: '$verse is out of range for surah ${verse.surah}',
        );
      }
    });

    test('every note is non-empty', () {
      for (final note in quranAliVerses.values) {
        expect(note.trim(), isNotEmpty);
      }
    });

    test('looks up a curated verse, e.g. Ayat al-Wilayah', () {
      expect(aliRelatedNoteFor(const VerseKey(5, 55)), isNotNull);
    });

    test('an unrelated verse has no note', () {
      expect(aliRelatedNoteFor(const VerseKey(1, 1)), isNull);
    });
  });
}
