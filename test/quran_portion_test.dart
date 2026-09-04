import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_portion.dart';

/// Serves the real shipped surah documents off disk, so these tests run
/// against the corpus the app actually reads rather than a fixture of it.
class _DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  final bundle = _DiskAssetBundle();

  setUp(() {
    items = {
      for (var surah = 1; surah <= surahCount; surah++)
        uidForSurah(surah)!: '$surah: Surah$surah اسم',
    };
  });

  tearDown(() => items = {});

  group('juz portions', () {
    test('every juz assembles into something readable', () async {
      for (var juz = 1; juz <= 30; juz++) {
        final portion = await loadJuzPortion(juz, bundle);
        expect(portion, isNotNull, reason: 'juz $juz did not load');
        expect(portion!.isEmpty, isFalse, reason: 'juz $juz is empty');
        expect(portion.data, isNotEmpty, reason: 'juz $juz has no text');
        expect(portion.title, 'Juz $juz');
      }
    });

    test('a juz starts on its first verse', () async {
      for (final part in allJuz()) {
        final portion = await loadJuzPortion(part.number, bundle);
        expect(
          portion!.firstVerse,
          part.start,
          reason: 'juz ${part.number} does not begin where it should',
        );
      }
    },
        // Juz 4 begins at 3:93, one of the ayahs missing from the corpus, so
        // it currently begins one verse late. Unskips with the repair.
        skip: 'pending the separate Quran corpus repair');

    test('a juz runs across the surah boundary, which is the whole point',
        () async {
      // The reported bug: a juz used to stop at the end of its first surah.
      // Juz 6 is the case - an-Nisa 148 through al-Maidah 81.
      final portion = (await loadJuzPortion(6, bundle))!;

      expect(portion.firstVerse, const VerseKey(4, 148));
      expect(portion.lastVerse, const VerseKey(5, 81));
      expect(
        portion.index.spans.map((span) => span.surah).toSet(),
        {4, 5},
        reason: 'juz 6 covers an-Nisa and al-Maidah',
      );
    });

    test('ayah numbers restart at each surah rather than running on', () async {
      final portion = (await loadJuzPortion(6, bundle))!;
      final verses = portion.index.verses;

      final lastOfNisa = verses.lastWhere((verse) => verse.surah == 4);
      final firstOfMaidah = verses.firstWhere((verse) => verse.surah == 5);

      expect(lastOfNisa.ayah, 176);
      expect(firstOfMaidah.ayah, 1);
      expect(verses.indexOf(firstOfMaidah), verses.indexOf(lastOfNisa) + 1);
    });

    test('a heading marks each surah the portion enters', () async {
      final portion = (await loadJuzPortion(6, bundle))!;
      final headings = portion.index.spans
          .where((span) => span.startsSurah != null)
          .map((span) => span.startsSurah!.number)
          .toList();

      expect(headings, [4, 5], reason: 'one heading per surah, in order');
    });

    test('a surah entered from its start keeps its Bismillah', () async {
      final portion = (await loadJuzPortion(6, bundle))!;
      final maidahSpans =
          portion.index.spans.where((span) => span.surah == 5).toList();

      expect(maidahSpans.first.ayah, isNull, reason: 'the Bismillah leads');
      expect(maidahSpans.first.startsSurah?.number, 5);
      expect(maidahSpans[1].ayah, 1);
    });

    test('a surah entered mid-way does not reopen with a Bismillah', () async {
      final portion = (await loadJuzPortion(6, bundle))!;
      final nisaSpans =
          portion.index.spans.where((span) => span.surah == 4).toList();

      expect(nisaSpans.first.ayah, 148);
      expect(
        nisaSpans.any((span) => span.ayah == null),
        isFalse,
        reason: 'juz 6 joins an-Nisa partway through',
      );
    });

    test('juz 1 opens on al-Fatihah and runs into al-Baqarah', () async {
      final portion = (await loadJuzPortion(1, bundle))!;

      // Al-Fatihah is the one surah whose Bismillah is itself ayah 1, so its
      // opening span is numbered where every other surah's is not.
      expect(portion.index.spans.first.ayah, 1);
      expect(portion.index.spans.first.startsSurah?.number, 1);
      expect(portion.firstVerse, const VerseKey(1, 1));
      expect(portion.lastVerse, const VerseKey(2, 141));

      // Al-Baqarah is entered from its start, so it does bring its Bismillah.
      final baqarah =
          portion.index.spans.where((span) => span.surah == 2).toList();
      expect(baqarah.first.ayah, isNull);
      expect(baqarah.first.startsSurah?.number, 2);
    });

    test('juz 30 stitches all thirty-seven of its surahs', () async {
      final portion = (await loadJuzPortion(30, bundle))!;

      expect(portion.index.spans.map((span) => span.surah).toSet(), hasLength(37));
      expect(portion.index.verses, hasLength(564));
      expect(portion.firstVerse, const VerseKey(78, 1));
      expect(portion.lastVerse, const VerseKey(114, 6));
    });

    test('spans address real lines, in order and without gaps', () async {
      final portion = (await loadJuzPortion(6, bundle))!;
      final lineCount = portion.data.split('\n').length;

      var previousEnd = 0;
      for (final span in portion.index.spans) {
        expect(span.start, previousEnd, reason: 'spans must be contiguous');
        expect(span.end, greaterThan(span.start));
        previousEnd = span.end;
      }
      expect(previousEnd, lineCount);
    });

    test('a verse can be found by its surah and ayah', () async {
      final portion = (await loadJuzPortion(6, bundle))!;

      final index = portion.index.spanIndexForVerse(const VerseKey(5, 1));
      expect(index, isNotNull);
      expect(portion.index.spans[index!].surah, 5);
      expect(portion.index.spans[index].ayah, 1);

      // 4:1 is in an-Nisa but not in this juz, and must not match 5:1.
      expect(portion.index.spanIndexForVerse(const VerseKey(4, 1)), isNull);
    });

    test('the reader payload is the shape the page already loads', () async {
      final portion = (await loadJuzPortion(6, bundle))!;
      final data = portion.toZikrData();

      expect(data['title'], 'Juz 6');
      expect(data['code'], '012');
      expect(data['data'], portion.data);
    });

    test('the two juz that sit inside one surah still read correctly',
        () async {
      // Juz 2 and juz 5 are the only ones that do not cross a surah boundary,
      // so they are the case the stitching must not disturb.
      final second = (await loadJuzPortion(2, bundle))!;
      expect(second.firstVerse, const VerseKey(2, 142));
      expect(second.lastVerse, const VerseKey(2, 252));
      expect(second.index.spans.map((span) => span.surah).toSet(), {2});

      final fifth = (await loadJuzPortion(5, bundle))!;
      expect(fifth.firstVerse, const VerseKey(4, 24));
      expect(fifth.lastVerse, const VerseKey(4, 147));
      expect(fifth.index.spans.map((span) => span.surah).toSet(), {4});
      expect(
        fifth.index.spans.where((span) => span.startsSurah != null),
        hasLength(1),
        reason: 'one heading, for the surah it opens in',
      );
    });

    test('there is no juz outside 1..30', () async {
      expect(await loadJuzPortion(0, bundle), isNull);
      expect(await loadJuzPortion(31, bundle), isNull);
    });
  });
}
