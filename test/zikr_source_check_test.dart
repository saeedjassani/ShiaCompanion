import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Restored zikr entries (uids purged in 8c5f8258 and brought back from
// history) checked against their source: every Arabic line shipped is in
// the source or an entry it links, and every Arabic block of the source is
// in the entry or an entry it links. A port of
// scripts/zikr_arabic/source_check.py - keep the two in step.
//
// The sources live in git history, which CI's clone doesn't have, so they
// are read from scripts/zikr_arabic/source_snapshot.json. What the check
// flags today - text from other sources (duas.org, Wikisource, Iqbal),
// cited typo fixes, gaps not yet filled - is accepted in
// scripts/zikr_arabic/source_baseline.json; this test fails on anything new,
// and on accepted flags that no longer fire.

const _snapshotPath = 'scripts/zikr_arabic/source_snapshot.json';
const _baselinePath = 'scripts/zikr_arabic/source_baseline.json';
const _minLength = 12;
const _threshold = 0.85;

final _marks = RegExp('[ً-ٰٟۖ-ۭـ'
    'ؐ-ؚ‌‍‏۔]');
final _notLetter = RegExp('[^ء-ي]');
const _letters = {
  'ٱ': 'ا', // ٱ
  'أ': 'ا', // أ
  'إ': 'ا', // إ
  'آ': 'ا', // آ
  'ى': 'ي', // ى
  'ة': 'ه', // ة
  'ہ': 'ه', // ہ
  'ھ': 'ه', // ھ
  'ی': 'ي', // ی
  'ې': 'ي', // ې
  'ک': 'ك', // ک
  'ؤ': 'و', // ؤ
  'ئ': 'ي', // ئ
  'ء': '', // ء
};
final _link = RegExp(r'\]\(([A-Z]+\d+)\)');

/// Arabic letters only, without vowels and with variant letters folded -
/// `norm` in source_check.py. (That one also unescapes HTML entities, which
/// only the old items in history carry.)
String norm(String s) {
  s = s.replaceAll('ﷲ', 'الله').replaceAll(_marks, '');
  for (final e in _letters.entries) {
    s = s.replaceAll(e.key, e.value);
  }
  return s.replaceAll(_notLetter, '');
}

/// The share of [n]'s 8-letter shingles (every 3rd) found in [hay].
double cov(String n, String hay, {int k = 8, int step = 3}) {
  final shingles = [
    for (var j = 0; j < max(1, n.length - k + 1); j += step)
      n.substring(j, min(j + k, n.length)),
  ];
  return shingles.where(hay.contains).length / shingles.length;
}

/// Normalized texts to search, kept apart so no shingle spans two.
String _hay(Iterable<String> texts) => texts.map(norm).join('|');

String _key(String n) =>
    sha1.convert(utf8.encode(n)).toString().substring(0, 12);

Map<String, dynamic> _entry(String uid) => Map<String, dynamic>.from(
    jsonDecode(File('assets/zikr/$uid').readAsStringSync()) as Map);

String _text(Map<String, dynamic> d) => [
      d['data'] as String? ?? '',
      ...((d['tabs'] as List?) ?? const [])
    ].join('\n');

typedef _Flags = ({
  Map<String, String> notInSource,
  Map<String, String> missing
});

/// Flagged lines and missing source blocks of [uid], each by key.
_Flags _check(String uid, Map source) {
  final d = _entry(uid);
  final t = _text(d);
  final linked = {
    for (final m in _link.allMatches('$t\n${d['merits'] as String? ?? ''}'))
      m.group(1)!,
  }.toList()
    ..sort();
  final linkedTexts = [
    for (final l in linked)
      if (File('assets/zikr/$l').existsSync()) _text(_entry(l)),
  ];
  final haySource = '${source['source']}|${_hay(linkedTexts)}';
  final hayEntry = _hay([t, ...linkedTexts]);

  final notInSource = <String, String>{};
  for (final line in t.split('\n')) {
    final n = norm(line);
    if (n.length < _minLength || notInSource.containsKey(_key(n))) continue;
    final c = cov(n, haySource);
    if (c < _threshold) {
      final preview = line.trim();
      notInSource[_key(n)] = '${c.toStringAsFixed(2)} '
          '${preview.substring(0, min(70, preview.length))}';
    }
  }
  final missing = <String, String>{};
  for (final n in (source['blocks'] as List).cast<String>()) {
    final c = cov(n, hayEntry);
    if (c < _threshold) {
      missing[_key(n)] =
          '${c.toStringAsFixed(2)} ${n.substring(0, min(70, n.length))}';
    }
  }
  return (notInSource: notInSource, missing: missing);
}

String _list(List<String> items) => [
      ...items.take(25),
      if (items.length > 25) '... and ${items.length - 25} more',
    ].join('\n');

void main() {
  test('norm keeps bare letters, as source_check.py does', () {
    expect(norm('اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ'), 'اللهمصلعليمحمد');
    expect(norm('ﷲ'), 'الله');
    expect(norm('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), 'الحمدللهربالعلمين');
    expect(norm('أَؤُمُّ إِلَىٰ سَمَآءٍ ۚ'), 'اوماليسما');
    expect(norm('یہ ھے کتاب ON TOP'), 'يههكتاب');
    expect(cov('ابتثجحخدذرزس', 'ابتثجحخدذرزس'), 1);
    expect(cov('ابتثجحخدذرزس', 'سزرذدخحجثتبا'), 0);
  });

  test('restored zikrs ship only Arabic their source has, and all of it', () {
    final snapshot = jsonDecode(File(_snapshotPath).readAsStringSync()) as Map;
    final baseline = jsonDecode(File(_baselinePath).readAsStringSync()) as Map;
    final added = <String>[];
    final fixed = <String>[];
    for (final uid in snapshot.keys.cast<String>().toList()..sort()) {
      if (!File('assets/zikr/$uid').existsSync()) continue;
      final flags = _check(uid, snapshot[uid] as Map);
      final accepted = (baseline[uid] as Map?) ?? const {};
      for (final (kind, found) in [
        ('not_in_source', flags.notInSource),
        ('missing', flags.missing),
      ]) {
        final known = ((accepted[kind] as List?) ?? const []).toSet();
        for (final e in found.entries) {
          if (!known.contains(e.key)) {
            added.add('$uid ${kind == 'missing' ? 'MISSING' : 'NOT IN SOURCE'}'
                ' ${e.value}');
          }
        }
        for (final k in known.difference(found.keys.toSet())) {
          fixed.add('$uid $kind $k');
        }
      }
    }
    const how = 'Check them with `python3 -I scripts/zikr_arabic/'
        'source_check.py . <uids>`; if the change is deliberate, run '
        '`python3 -I scripts/zikr_arabic/source_check.py . baseline` and '
        'commit scripts/zikr_arabic/source_baseline.json.';
    expect(added, isEmpty,
        reason: 'Restored zikrs now have Arabic not in their source, or lack '
            'part of it:\n${_list(added)}\n$how');
    expect(fixed, isEmpty,
        reason: 'These accepted flags no longer fire (fixed, or the line '
            'changed):\n${_list(fixed)}\n$how');
  });
}
