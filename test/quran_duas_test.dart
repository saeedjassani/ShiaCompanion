import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_duas.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('quranDuas', () {
    test('every dua starts and ends on a real ayah of its surah', () {
      for (final dua in quranDuas) {
        final count = ayahCountOf(dua.verse.surah);
        expect(count, isNotNull,
            reason: 'surah ${dua.verse.surah} does not exist');
        expect(
          dua.verse.ayah,
          allOf(isNotNull, greaterThanOrEqualTo(1), lessThanOrEqualTo(count!)),
          reason: '${dua.opening} is out of range',
        );
        if (dua.endAyah != null) {
          expect(
            dua.endAyah,
            allOf(greaterThan(dua.verse.ayah!), lessThanOrEqualTo(count)),
            reason: '${dua.opening} has a bad end ayah',
          );
        }
      }
    });

    test('is in mushaf order with no duplicates', () {
      for (var i = 1; i < quranDuas.length; i++) {
        final a = quranDuas[i - 1].verse;
        final b = quranDuas[i].verse;
        expect(
          a.surah < b.surah || (a.surah == b.surah && a.ayah! < b.ayah!),
          isTrue,
          reason: '$a should come before $b',
        );
      }
    });

    test('every dua has an opening and a note', () {
      for (final dua in quranDuas) {
        expect(dua.opening.trim(), isNotEmpty);
        expect(dua.note.trim(), isNotEmpty);
      }
    });
  });
}
