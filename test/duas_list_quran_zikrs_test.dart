import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/quran/quran_navigation.dart';
import 'package:shia_companion/utils/zikr_lists.dart';

/// Ayat al-Kursi and the two duas recited with the Quran left the Quran
/// screen's Duas collection for the Duas list, by alias, so their uids,
/// links, favourites and counts stay what they were.
void main() {
  late Map<String, dynamic> corpus;

  setUpAll(() {
    corpus = jsonDecode(File('assets/zikr.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  setUp(() {
    items = {
      for (final entry in corpus.entries) entry.key: entry.value['title'],
    };
    itemOrder = {
      for (final entry in corpus.entries)
        if (entry.value['order'] is num)
          entry.key: (entry.value['order'] as num).toDouble(),
    };
  });

  tearDown(() {
    items = {};
    itemOrder = {};
  });

  test('the Duas list opens with Ayat al-Kursi', () {
    final duas = zikrListEntries('E');
    expect(duas.first.getFirstUId(), 'A4');
  });

  test('the Duas list carries both Quran duas, by alias', () {
    final targets = zikrListEntries('E').map((e) => e.getFirstUId()).toSet();
    expect(targets, containsAll(['A2', duaKhatmQuranUid]));
  });

  test('each alias shares its canonical title and slug', () {
    for (final alias in ['E157|A4', 'E158|A2', 'E159|A3']) {
      final canonical = corpus[alias.split('|').last] as Map<String, dynamic>;
      final entry = corpus[alias] as Map<String, dynamic>;
      expect(entry['title'], canonical['title'], reason: alias);
      expect(entry['slug'], canonical['slug'], reason: alias);
    }
  });

  test('the end-of-Quran link points at Dua Khatm al-Quran', () {
    expect(items[duaKhatmQuranUid], 'Dua Khatm al-Quran');
  });
}
