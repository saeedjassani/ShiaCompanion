import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_uthmani.dart';

void main() {
  final quran = UthmaniQuran.parse(File(uthmaniAsset).readAsStringSync());

  String surahData(int surah) =>
      (json.decode(File('assets/zikr/${uidForSurah(surah)}').readAsStringSync())
              as Map)['data']
          .toString();

  test('the Tanzil text has every verse of every surah', () {
    for (var surah = 1; surah <= surahCount; surah++) {
      final count = ayahCountOf(surah)!;
      expect(quran.verse(surah, count), isNotNull, reason: 'surah $surah');
      expect(quran.verse(surah, count + 1), isNull, reason: 'surah $surah');
    }
  });

  test('the Bismillah comes off verse 1 and is served on its own', () {
    expect(quran.bismillah, startsWith('بِسْمِ'));
    expect(quran.verse(1, 1), quran.bismillah);
    expect(quran.verse(2, 1), 'الٓمٓ');
    for (var surah = 2; surah <= surahCount; surah++) {
      expect(quran.verse(surah, 1), isNot(startsWith(quran.bismillah)),
          reason: 'surah $surah');
    }
  });

  test('every Arabic line of every surah becomes Tanzil text, numbers kept', () {
    for (var surah = 1; surah <= surahCount; surah++) {
      final before = surahData(surah).split('\n');
      final after = toUthmani(surah, surahData(surah), quran).split('\n');
      expect(after.length, before.length, reason: 'surah $surah');

      for (var i = 0; i < before.length; i++) {
        if (!ZikrContentParser.isArabic(before[i].trim())) {
          expect(after[i], before[i], reason: 'surah $surah line $i');
          continue;
        }
        final ayah = ZikrContentParser.ayahNumberOf(before[i]);
        expect(ZikrContentParser.ayahNumberOf(after[i]), ayah,
            reason: 'surah $surah line $i');
        final expected = ayah == null
            ? quran.bismillah
            : quran.verse(surah, ayah)!;
        // Verbatim apart from the no-break space that holds a pause mark to
        // its word.
        expect(after[i].replaceAll(' ', ' '),
            ayah == null ? expected : '$expected ($ayah)',
            reason: 'surah $surah line $i');
      }
    }
  });

  test('a pause mark cannot start a line', () {
    final line = toUthmani(28, surahData(28), quran)
        .split('\n')
        .firstWhere((l) => ZikrContentParser.ayahNumberOf(l) == 31);
    expect(line, contains('عَصَاكَ ۖ'));
    expect(RegExp(' [ۖ-ۜ]').hasMatch(line), isFalse);
  });

  test('only Scheherazade switches the script', () {
    expect(usesUthmaniScript('Scheherazade'), isTrue);
    expect(usesUthmaniScript('Qalam'), isFalse);
  });
}
