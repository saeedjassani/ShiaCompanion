import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/slug_registry.dart';
import 'package:shia_companion/utils/verse_query.dart';

void main() {
  setUpAll(() {
    // The real titles and slugs, since the point is matching how people
    // actually spell the names.
    final zikr = jsonDecode(File('assets/zikr.json').readAsStringSync())
        as Map<String, dynamic>;
    items = {
      for (final entry in zikr.entries)
        entry.key: (entry.value as Map)['title'],
    };
    itemSlugs = {
      for (final entry in zikr.entries)
        if ((entry.value as Map)['slug'] != null)
          entry.key: (entry.value as Map)['slug'] as String,
    };
  });

  tearDownAll(() {
    items = {};
    itemSlugs = {};
  });

  group('parseVerseQuery', () {
    test('reads surah:ayah in the usual forms', () {
      for (final text in ['2:255', '2 255', '2/255', '2.255', ' 2 : 255 ']) {
        expect(parseVerseQuery(text), const VerseKey(2, 255), reason: text);
      }
    });

    test('reads a surah name and an ayah', () {
      expect(parseVerseQuery('baqarah 255'), const VerseKey(2, 255));
      expect(parseVerseQuery('Al-Baqarah 255'), const VerseKey(2, 255));
      expect(parseVerseQuery('surah yasin 1'), const VerseKey(36, 1));
      expect(parseVerseQuery('Ya-Sin:12'), const VerseKey(36, 12));
      expect(parseVerseQuery('kahf 10'), const VerseKey(18, 10));
      expect(parseVerseQuery('ar-rahman 13'), const VerseKey(55, 13));
      expect(parseVerseQuery('imran 7'), const VerseKey(3, 7));
    });

    test('accepts the long-vowel spellings kept in the slugs', () {
      expect(parseVerseQuery('yaseen 1'), const VerseKey(36, 1));
      expect(parseVerseQuery('al-faatehah 2'), const VerseKey(1, 2));
      expect(parseVerseQuery('fatiha 2'), const VerseKey(1, 2));
    });

    test('needs both a surah and an ayah', () {
      expect(parseVerseQuery('36'), isNull);
      expect(parseVerseQuery('yasin'), isNull);
      expect(parseVerseQuery(''), isNull);
    });

    test('rejects what is not a verse', () {
      expect(parseVerseQuery('2:300'), isNull, reason: 'al-Baqarah has 286');
      expect(parseVerseQuery('115:1'), isNull, reason: 'there are 114');
      expect(parseVerseQuery('2:0'), isNull);
      expect(parseVerseQuery('dua kumayl 2'), isNull);
    });
  });

  group('matchSurahNames', () {
    test('finds a surah from the start of its name', () {
      expect(matchSurahNames('baq').map((s) => s.number), [2]);
    });

    test('prefers an exact spelling to a longer name starting with it', () {
      // "An-Nas" is exact; "An-Nasr" only starts with it.
      expect(matchSurahNames('nas').map((s) => s.number), [114]);
    });

    test('finds nothing for a name no surah has', () {
      expect(matchSurahNames('kumayl'), isEmpty);
    });
  });
}
