import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('surah <-> uid', () {
    test('maps every surah to its document and back', () {
      for (var surah = 1; surah <= surahCount; surah++) {
        final uid = uidForSurah(surah);
        expect(uid, isNotNull, reason: 'surah $surah has no uid');
        expect(surahForUid(uid!), surah);
      }
    });

    test('anchors the mapping the corpus was built with', () {
      expect(uidForSurah(1), 'A5');
      expect(uidForSurah(114), 'A118');
    });

    test('rejects surah numbers outside 1..114', () {
      expect(uidForSurah(0), isNull);
      expect(uidForSurah(115), isNull);
      expect(uidForSurah(-1), isNull);
    });

    test('Ayat al Kursi and other categories are not surahs', () {
      expect(surahForUid('A4'), isNull);
      expect(surahForUid('A119'), isNull);
      expect(surahForUid('E18'), isNull);
      expect(surahForUid('G4'), isNull);
      expect(surahForUid('AA2'), isNull);
    });

    test('resolves an alias uid through its primary', () {
      expect(surahForUid('X1|A9'), 5);
    });
  });

  group('surahAyahCounts', () {
    test('covers all 114 surahs', () {
      expect(surahAyahCounts, hasLength(surahCount));
      expect(surahAyahCounts.every((count) => count > 0), isTrue);
    });

    test('totals the 6236 ayahs of the Quran', () {
      expect(surahAyahCounts.reduce((a, b) => a + b), 6236);
    });

    test('ayahCountOf guards the range', () {
      expect(ayahCountOf(1), 7);
      expect(ayahCountOf(2), 286);
      expect(ayahCountOf(114), 6);
      expect(ayahCountOf(115), isNull);
    });
  });

  group('VerseKey.tryParse', () {
    test('accepts every separator form', () {
      for (final input in ['23:56', '23/56', '23-56', '23.56', '23 56']) {
        expect(VerseKey.tryParse(input), const VerseKey(23, 56),
            reason: 'failed on "$input"');
      }
    });

    test('tolerates spaces around the separator', () {
      expect(VerseKey.tryParse(' 23 : 56 '), const VerseKey(23, 56));
    });

    test('a bare number is the whole surah', () {
      expect(VerseKey.tryParse('23'), const VerseKey(23));
      expect(VerseKey.tryParse('23')?.ayah, isNull);
    });

    test('clamps an ayah past the end of the surah', () {
      expect(VerseKey.tryParse('2:300'), const VerseKey(2, 286));
      expect(VerseKey.tryParse('114:99'), const VerseKey(114, 6));
    });

    test('rejects a surah outside the Quran', () {
      expect(VerseKey.tryParse('115:1'), isNull);
      expect(VerseKey.tryParse('0:0'), isNull);
      expect(VerseKey.tryParse('999'), isNull);
    });

    test('rejects junk rather than guessing', () {
      for (final input in ['', '   ', 'al-baqarah', '2:', ':56', '2:3:4', '2a']) {
        expect(VerseKey.tryParse(input), isNull, reason: 'accepted "$input"');
      }
    });

    test('formats canonically', () {
      expect(const VerseKey(23, 56).toString(), '23:56');
      expect(const VerseKey(23).toString(), '23');
    });
  });

  group('juz table', () {
    final juzList = allJuz();

    test('has all thirty, numbered in order', () {
      expect(juzList, hasLength(30));
      for (var i = 0; i < juzList.length; i++) {
        expect(juzList[i].number, i + 1);
      }
    });

    test('spans the whole Quran end to end', () {
      expect(juzList.first.start, const VerseKey(1, 1));
      expect(juzList.last.end, const VerseKey(114, 6));
    });

    test('every boundary is a verse that exists', () {
      for (final juz in juzList) {
        for (final key in [juz.start, juz.end]) {
          expect(isSurahNumber(key.surah), isTrue,
              reason: 'juz ${juz.number} points at surah ${key.surah}');
          expect(key.ayah, isNotNull);
          expect(key.ayah!, inInclusiveRange(1, ayahCountOf(key.surah)!),
              reason: 'juz ${juz.number} boundary $key is out of range');
        }
      }
    });

    test('each juz continues exactly where the previous one stopped', () {
      for (var i = 1; i < juzList.length; i++) {
        final previousEnd = juzList[i - 1].end;
        final start = juzList[i].start;

        if (previousEnd.surah == start.surah) {
          expect(start.ayah, previousEnd.ayah! + 1,
              reason: 'gap or overlap before juz ${juzList[i].number}');
        } else {
          expect(start.surah, previousEnd.surah + 1,
              reason: 'juz ${juzList[i].number} skips a surah');
          expect(start.ayah, 1);
          expect(previousEnd.ayah, ayahCountOf(previousEnd.surah));
        }
      }
    });

    test('knows the boundaries readers actually quote', () {
      expect(juzList[4].start, const VerseKey(4, 24));
      expect(juzList[16].start, const VerseKey(21, 1));
      expect(juzList[29].start, const VerseKey(78, 1));
    });
  });

  group('surahInfoFor', () {
    setUp(() {
      // The corpus is inconsistent about the spacing around the colon, so the
      // three shapes it actually ships are all represented here.
      items = {
        'A5': '1: al-Faatehah الفاتحة',
        'A6': '2 : Al-Baqarah البقرة',
        'A94': "90 : Al-Balad البلد",
        'A10': "6: al-An'aam الأنعام",
      };
    });

    tearDown(() => items = {});

    test('splits the number, English name and Arabic name', () {
      final info = surahInfoFor(2)!;
      expect(info.number, 2);
      expect(info.englishName, 'Al-Baqarah');
      expect(info.arabicName, 'البقرة');
      expect(info.uid, 'A6');
      expect(info.ayahCount, 286);
    });

    test('handles both spacings and keeps punctuation in the name', () {
      expect(surahInfoFor(1)!.englishName, 'al-Faatehah');
      expect(surahInfoFor(90)!.englishName, 'Al-Balad');
      expect(surahInfoFor(6)!.englishName, "al-An'aam");
    });

    test('falls back rather than dropping a surah with no title', () {
      final info = surahInfoFor(3)!;
      expect(info.englishName, 'Surah 3');
      expect(info.arabicName, isEmpty);
      expect(info.ayahCount, 200);
    });

    test('allSurahs always lists all 114 in order', () {
      final surahs = allSurahs();
      expect(surahs, hasLength(surahCount));
      expect(surahs.first.number, 1);
      expect(surahs.last.number, 114);
      expect(surahs[1].englishName, 'Al-Baqarah');
    });

    test('is null outside the Quran', () {
      expect(surahInfoFor(0), isNull);
      expect(surahInfoFor(115), isNull);
    });
  });

  group('AyahIndex', () {
    AyahIndex indexOf(String data, {String code = '012', int surah = 1}) {
      return AyahIndex.fromParsedContent(
        ZikrContentParser.parseContent(data, hideHeaderLine: false, code: code),
        surah: surah,
      );
    }

    test('reads ayah numbers from the trailing markers', () {
      final index = indexOf(
        'بِسْمِ اللهِ\n'
        'BISMILLAH\n'
        'In the name of Allah\n'
        'اَلْحَمْدُ لِلّٰهِ (1)\n'
        'ALHAMDU LILLAH\n'
        'All praise is due to Allah\n'
        'اَلرَّحْمٰنِ (2)\n'
        'AR RAHMAAN\n'
        'The Beneficent',
      );

      expect(index.verses, [const VerseKey(1, 1), const VerseKey(1, 2)]);
      expect(index.spans.first.ayah, isNull, reason: 'Bismillah is not an ayah');
      expect(index.spanIndexForVerse(const VerseKey(1, 1)), 1);
      expect(index.spanIndexForVerse(const VerseKey(1, 2)), 2);
    });

    test('a span covers its ayah and the lines belonging to it', () {
      final index = indexOf(
        'اَلْحَمْدُ لِلّٰهِ (1)\n'
        'ALHAMDU LILLAH\n'
        'All praise is due to Allah\n'
        'اَلرَّحْمٰنِ (2)\n'
        'AR RAHMAAN\n'
        'The Beneficent',
      );

      final first = index.spans.first;
      expect(first.start, 0);
      expect(first.end, 3);
      expect(first.contains(1), isTrue);
      expect(first.contains(2), isTrue);
      expect(first.contains(3), isFalse);
    });

    test('indexes by marker, not by position', () {
      // at-Tawbah has no Bismillah, so the first Arabic line is already ayah 1.
      final index = indexOf(
        'بَرَآءَةٌ (1)\n'
        'BARAA-ATUN\n'
        'A declaration of immunity',
      );

      expect(index.spanIndexForVerse(const VerseKey(1, 1)), 0);
    });

    test('falls back to the nearest earlier ayah when one is absent', () {
      final index = indexOf(
        'اَلْحَمْدُ (1)\n'
        'ALHAMDU\n'
        'Praise\n'
        'اَلرَّحْمٰنِ (3)\n'
        'AR RAHMAAN\n'
        'The Beneficent',
      );

      expect(index.spanIndexForVerse(const VerseKey(1, 2)), isNull);
      expect(
        index.nearestSpanIndexForVerse(const VerseKey(1, 2)),
        index.spanIndexForVerse(const VerseKey(1, 1)),
      );
      expect(
        index.nearestSpanIndexForVerse(const VerseKey(1, 3)),
        index.spanIndexForVerse(const VerseKey(1, 3)),
      );
      expect(
        index.nearestSpanIndexForVerse(const VerseKey(1, 99)),
        index.spanIndexForVerse(const VerseKey(1, 3)),
      );
    });

    test('is empty for content with no Arabic at all', () {
      final index = indexOf('Just an English note\nAnd another');
      expect(index.isEmpty, isTrue);
      expect(index.nearestSpanIndexForVerse(const VerseKey(1, 1)), isNull);
    });
  });

  group('surah documents', () {
    // Reads the shipped assets directly rather than through the asset bundle,
    // so this stays a plain unit test.
    Map<String, dynamic> readSurahDocument(int surah) {
      final file = File('assets/zikr/${uidForSurah(surah)}');
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }

    AyahIndex indexOfSurah(int surah) {
      final document = readSurahDocument(surah);
      return AyahIndex.fromParsedContent(
        ZikrContentParser.parseContent(
          document['data']?.toString() ?? '',
          hideHeaderLine: false,
          code: document['code']?.toString(),
        ),
        surah: surah,
      );
    }

    test('every surah has a document that parses to ayahs', () {
      for (var surah = 1; surah <= surahCount; surah++) {
        expect(File('assets/zikr/${uidForSurah(surah)}').existsSync(), isTrue,
            reason: 'surah $surah has no document');
        expect(indexOfSurah(surah).isEmpty, isFalse,
            reason: 'surah $surah parsed to no ayahs');
      }
    });

    test('ayah numbers never go backwards or repeat', () {
      for (var surah = 1; surah <= surahCount; surah++) {
        final numbers = indexOfSurah(surah)
            .spans
            .map((span) => span.ayah)
            .whereType<int>()
            .toList();

        for (var i = 1; i < numbers.length; i++) {
          expect(numbers[i], greaterThan(numbers[i - 1]),
              reason: 'surah $surah is out of order at index $i');
        }
      }
    });

    test('every surah document holds exactly its canonical ayahs', () {
      final incomplete = <String>[];
      for (var surah = 1; surah <= surahCount; surah++) {
        final found = indexOfSurah(surah)
            .verses
            .map((verse) => verse.ayah!)
            .toList();
        final expected = List.generate(ayahCountOf(surah)!, (i) => i + 1);
        if (found.length != expected.length || !_sameNumbers(found, expected)) {
          incomplete.add('surah $surah: ${found.length}/${expected.length}');
        }
      }

      expect(incomplete, isEmpty);
    });
  });
}

bool _sameNumbers(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
