import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every lunar pattern lunar_date_matcher.dart understands: "MM-DD",
/// "MM-*", "MM-*-D", "*-*-D" and "*-*", each optionally "N"-prefixed.
final _dayPattern = RegExp(
  r'^N?(?:(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|30)'
  r'|(?:0[1-9]|1[0-2])-\*(?:-[0-6])?'
  r'|\*-\*(?:-[0-6])?)$',
);

List<String> _patterns(Object? day) => switch (day) {
      null => const [],
      String value => value.split(',').map((p) => p.trim()).toList(),
      List value => value.cast<String>(),
      _ => throw ArgumentError('unexpected day value: $day'),
    };

void main() {
  final zikr = json.decode(File('assets/zikr.json').readAsStringSync())
      as Map<String, dynamic>;

  String? dayOf(String uid) {
    final entry = zikr[uid];
    return entry is Map ? _patterns(entry['day']).join(',') : null;
  }

  test('every zikr day pattern is one the matcher understands', () {
    for (final entry in zikr.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      for (final pattern in _patterns(value['day'])) {
        expect(_dayPattern.hasMatch(pattern), isTrue,
            reason: '${entry.key}: "$pattern"');
      }
    }
  });

  test('only canonical zikrs carry a day, never an alias', () {
    // Today's Recitation lists matches as-is, with no de-duplication, so a
    // `day` on an alias ("<uid>|<target>") would list the same zikr twice.
    final aliasesWithDay = zikr.entries
        .where((e) => e.key.contains('|') && e.value is Map)
        .where((e) => (e.value as Map)['day'] != null)
        .map((e) => e.key);
    expect(aliasesWithDay, isEmpty);
  });

  test('every weekday-chapter zikr recurs on its weekday', () {
    // The Friday..Thursday chapters (J, K, L, M, N, O, Q); an alias in one
    // points at the canonical zikr that carries the weekday.
    const weekdayOf = {
      'J': '5',
      'K': '6',
      'L': '0',
      'M': '1',
      'N': '2',
      'O': '3',
      'Q': '4',
    };
    for (final uid in zikr.keys) {
      final chapter = uid.replaceAll(RegExp('[0-9].*'), '');
      final weekday = weekdayOf[chapter];
      if (weekday == null) continue;
      final canonical = uid.split('|').last;
      expect(_patterns(dayOf(canonical)), contains('*-*-$weekday'),
          reason: '$uid -> $canonical');
    }
  });

  test('the daily recitations are tagged every day', () {
    for (final uid in ['E18', 'G6', 'G4', 'E37']) {
      expect(dayOf(uid), '*-*', reason: uid);
    }
  });

  test('events.json is keyed by fixed "MM-DD" lunar dates', () {
    final events = json.decode(File('assets/events.json').readAsStringSync())
        as Map<String, dynamic>;
    for (final entry in events.entries) {
      expect(
          RegExp(r'^(0[1-9]|1[0-2])-(0[1-9]|[12]\d|30)$').hasMatch(entry.key),
          isTrue,
          reason: entry.key);
      final event = entry.value as Map<String, dynamic>;
      expect(event.keys.toSet(), {'content', 'color'}, reason: entry.key);
      expect([0, 1, null], contains(event['color']), reason: entry.key);
      expect(event['content'], isNot(startsWith('Evening')),
          reason: '${entry.key}: night occasions belong on a zikr\'s "N" day');
    }
  });
}
