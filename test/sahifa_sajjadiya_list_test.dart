import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/zikr_lists.dart';

/// Al-Sahifa al-Sajjadiyya is a group of the Duas list (`E~AS0`) holding
/// its 54 supplications as `AS1`-`AS54`. The ones that already lived
/// elsewhere (Dua Amaan, the Ramazan duas) are aliases, not copies.
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

  test('the Duas list leads with Ayat al-Kursi, then the Sahifa', () {
    final duas = zikrListEntries('E').map((e) => e.uid).toList();
    expect(duas.take(2), ['E157|A4', 'E~AS0']);
  });

  test('the Sahifa group lists all 54 supplications in order', () {
    final entries = zikrListEntries('AS0');
    expect(entries, hasLength(54));
    for (var i = 0; i < 54; i++) {
      final uid = entries[i].uid.split('|').first;
      expect(uid, 'AS${i + 1}');
    }
  });

  test('every supplication without an alias has its own content', () {
    for (var n = 1; n <= 54; n++) {
      final own = corpus.containsKey('AS$n');
      final alias = corpus.keys.where((k) => k.startsWith('AS$n|'));
      expect(own || alias.isNotEmpty, isTrue, reason: 'AS$n');
      if (own) {
        expect(File('assets/zikr/AS$n').existsSync(), isTrue, reason: 'AS$n');
      }
    }
  });
}
