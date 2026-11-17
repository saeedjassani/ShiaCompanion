import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/zikr_lists.dart';

/// A group row (`C~V13`, Aamaal's Jumada al-Awwal) opens the list named after
/// its `~`. Retiring the last entry of that list leaves the row leading to an
/// empty page, as retiring V1 into G52 once did.
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

  test('every group row opens a list with something in it', () {
    final empty = [
      for (final uid in corpus.keys)
        if (uid.contains('~') && zikrListEntries(uid.split('~')[1]).isEmpty)
          uid,
    ];
    expect(empty, isEmpty);
  });

  test('Jumada al-Awwal lists the Ziyarat of Lady Fatimah (s.a.)', () {
    final uids = zikrListEntries('V13').map((e) => e.uid);
    expect(uids, contains('V2|G52'));
  });
}
