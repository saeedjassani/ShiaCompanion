import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_indopak.dart';
import 'package:shia_companion/utils/quran_portion.dart';
import 'package:shia_companion/utils/quran_script.dart';

class _DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  final quran = IndoPakQuran.parse(File(indoPakAsset).readAsStringSync());

  String surahData(int surah) =>
      (json.decode(File('assets/zikr/${uidForSurah(surah)}').readAsStringSync())
              as Map)['data']
          .toString();

  final medallion = RegExp('[-]\$');

  setUp(() => isUserAdmin = true);
  tearDown(() {
    arabicFont = 'Qalam';
    isUserAdmin = false;
  });

  test('the QuranWBW text has every verse of every surah', () {
    for (var surah = 1; surah <= surahCount; surah++) {
      final count = ayahCountOf(surah)!;
      for (var ayah = 1; ayah <= count; ayah++) {
        final verse = quran.verse(surah, ayah);
        expect(verse, isNotNull, reason: '$surah:$ayah');
        // Every verse closes on its own medallion, al-Fatiha's Bismillah
        // included: the Madinah edition numbers it, as the corpus does.
        expect(verse, matches(medallion), reason: '$surah:$ayah');
      }
      expect(quran.verse(surah, count + 1), isNull, reason: 'surah $surah');
    }
  });

  test('the header Bismillah is al-Fatiha verse 1 without its medallion', () {
    expect(quran.bismillah, startsWith('بِسْمِ'));
    expect(quran.bismillah.split(' '), hasLength(4));
    expect(medallion.hasMatch(quran.bismillah), isFalse);
    expect(quran.verse(1, 1), startsWith('${quran.bismillah}\u202F'));
  });

  test('every Arabic line of every surah becomes QuranWBW text, numbers kept',
      () {
    for (var surah = 1; surah <= surahCount; surah++) {
      final before = surahData(surah).split('\n');
      final after = toIndoPak(surah, surahData(surah), quran).split('\n');
      expect(after.length, before.length, reason: 'surah $surah');

      for (var i = 0; i < before.length; i++) {
        if (!ZikrContentParser.isArabic(before[i].trim())) {
          expect(after[i], before[i], reason: 'surah $surah line $i');
          continue;
        }
        final ayah = ZikrContentParser.ayahNumberOf(before[i]);
        expect(ZikrContentParser.ayahNumberOf(after[i]), ayah,
            reason: 'surah $surah line $i');
        expect(
            after[i],
            ayah == null
                ? quran.bismillah
                : '${quran.verse(surah, ayah)!} ($ayah)',
            reason: 'surah $surah line $i');
      }
    }
  });

  test('display hides the number the medallion already shows, nothing else',
      () {
    for (final font in ['Qalam', 'Scheherazade']) {
      arabicFont = font;
      for (var surah = 1; surah <= surahCount; surah++) {
        for (var ayah = 1; ayah <= ayahCountOf(surah)!; ayah++) {
          final verse = quran.verse(surah, ayah)!;
          // Also proves the text never uses Qalam's private-use marks, which
          // formatArabicText rewrites.
          expect(ZikrContentParser.formatArabicText('$verse ($ayah)'), verse,
              reason: '$surah:$ayah in $font');
        }
      }
    }
    expect(
        ZikrContentParser.formatArabicText(quran.bismillah), quran.bismillah);
  });

  test('copied text drops the private-use signs and keeps the letters', () {
    final line = '${quran.verse(2, 255)!} (255)';
    final plain = indoPakPlainText(line);
    expect(RegExp('[-]').hasMatch(plain), isFalse);
    expect(plain, startsWith('اَللّٰهُ لَاۤ اِلٰهَ'));
    expect(plain, endsWith('الْعَظِیْمُ (255)'));
    expect(plain, isNot(contains('  ')));
  });

  group('script by font', () {
    final bundle = _DiskAssetBundle();

    test('Qalam shows QuranWBW text in the QuranWBW font', () async {
      arabicFont = 'Qalam';
      final document = await applyQuranScript(
          uidForSurah(2)!, {'data': surahData(2), 'code': '012'}, bundle);
      expect(document['data'], toIndoPak(2, surahData(2), quran));
      expect(arabicFontFamilyOf(document), quranWbwFontFamily);
      expect(document[quranScriptFontKey], 'Qalam');
    });

    test('everyone but admins keeps the corpus text in Qalam', () async {
      isUserAdmin = false;
      arabicFont = 'Qalam';
      final surah = {'data': surahData(2), 'code': '012'};
      final document = await applyQuranScript(uidForSurah(2)!, surah, bundle);
      expect(document, same(surah));
      expect(arabicFontFamilyOf(document), 'Qalam');
      final portion = (await loadJuzPortion(30, bundle))!;
      expect(arabicFontFamilyOf(portion.toZikrData()), 'Qalam');
    });

    test('Scheherazade shows Uthmani text in Scheherazade', () async {
      arabicFont = 'Scheherazade';
      final document = await applyQuranScript(
          uidForSurah(2)!, {'data': surahData(2), 'code': '012'}, bundle);
      expect(document['data'], isNot(surahData(2)));
      expect(arabicFontFamilyOf(document), 'Scheherazade');
      expect(document[quranScriptFontKey], 'Scheherazade');
    });

    test('a zikr that is not a surah is left alone', () async {
      final zikr = {'data': 'بِسْمِ اللّٰهِ', 'code': '012'};
      final document = await applyQuranScript('G1', zikr, bundle);
      expect(document, same(zikr));
      expect(arabicFontFamilyOf(document), arabicFont);
    });

    test('a juz is in one script and carries its font', () async {
      arabicFont = 'Qalam';
      final portion = (await loadJuzPortion(30, bundle))!;
      final data = portion.toZikrData();
      expect(arabicFontFamilyOf(data), quranWbwFontFamily);
      expect(data[quranScriptFontKey], 'Qalam');
      expect(data['data'], contains(quran.verse(114, 6)!));
    });
  });
}
