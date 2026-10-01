import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_mahdi_verses.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('quranMahdiVerses', () {
    test('every key is a real ayah of its surah', () {
      for (final verse in quranMahdiVerses.keys) {
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
      for (final note in quranMahdiVerses.values) {
        expect(note.trim(), isNotEmpty);
      }
    });

    test('looks up a curated verse, e.g. Baqiyyatullah', () {
      expect(mahdiRelatedNoteFor(const VerseKey(11, 86)), isNotNull);
    });

    test('an unrelated verse has no note', () {
      expect(mahdiRelatedNoteFor(const VerseKey(1, 1)), isNull);
    });
  });
}
