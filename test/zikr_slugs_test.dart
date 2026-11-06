import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/slug_registry.dart';

// Slugs in assets/zikr.json are the only place a zikr's link comes from
// (lib/utils/slug_registry.dart just reads them), so nothing at runtime stops
// two entries from colliding. The rule, from cce1219 (whose Cloud Function
// enforced it until d74a4e0 removed Firestore as the zikr source):
//
// - an alias "<uid>|<target>" with its target's title (as a slug - so
//   "(...)" and "[...]" count as the same) reuses the target's slug verbatim;
// - an alias showing only some tabs, or with a title of its own, gets a slug
//   of its own;
// - no other two entries ever share a slug, so a new entry never needs a
//   "-2" suffix to tell it apart.
//
// Pairs the web build already merges into one page (MERGED_ZIKR_SLUGS in
// scripts/generate_zikr_seo_pages.js) are old links kept as they were. They
// are the only exceptions. scripts/zikr_structure/lint.py's ALIAS_SLUG is the
// same check.

const _indexPath = 'assets/zikr.json';

/// Slugs that shipped with a collision suffix before this test existed.
/// Slugs never change (shared links are keyed by them), so they stay.
const _shippedSuffixedSlugs = {
  // The Dhul Hijjah month list; "zilhajj" was already one of AC5's
  // slugAliases.
  'C~AC8': 'zilhajj-2',
};
const _seoGeneratorPath = 'scripts/generate_zikr_seo_pages.js';

Map<String, Map<String, dynamic>> _loadIndex() {
  final decoded =
      json.decode(File(_indexPath).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in decoded.entries)
      if (e.value is Map) e.key: Map<String, dynamic>.from(e.value as Map),
  };
}

/// MERGED_ZIKR_SLUGS' pairs, each as a two-slug set.
Set<Set<String>> _mergedWebSlugPairs() {
  final src = File(_seoGeneratorPath).readAsStringSync();
  final start = src.indexOf('MERGED_ZIKR_SLUGS = {');
  if (start == -1) throw StateError('MERGED_ZIKR_SLUGS not found');
  final block = src.substring(start, src.indexOf('};', start));
  return {
    for (final m in RegExp(r"'([^']+)':\s*'([^']+)'").allMatches(block))
      {m.group(1)!, m.group(2)!},
  };
}

String _slugOf(Map<String, dynamic> meta) => meta['slug']?.toString() ?? '';

List<String> _slugAliasesOf(Map<String, dynamic> meta) => [
      for (final a in (meta['slugAliases'] as List?) ?? const []) a.toString(),
    ];

bool _showsSomeTabs(Map<String, dynamic> meta) => meta['tabs'] is List;

void main() {
  final index = _loadIndex();
  final merged = _mergedWebSlugPairs();

  test('every entry has a slug, already in normalized form', () {
    final bad = <String>[];
    for (final e in index.entries) {
      for (final s in [_slugOf(e.value), ..._slugAliasesOf(e.value)]) {
        if (s.isEmpty || normalizeSlug(s) != s) bad.add('${e.key}: "$s"');
      }
    }
    expect(bad, isEmpty);
  });

  test('an alias with its target\'s title reuses the target\'s slug', () {
    final bad = <String>[];
    for (final e in index.entries) {
      final parts = e.key.split('|');
      if (parts.length != 2 || _showsSomeTabs(e.value)) continue;
      final target = index[parts[1]];
      if (target == null) continue;
      final sameTitle = normalizeSlug(e.value['title'].toString()) ==
          normalizeSlug(target['title'].toString());
      final slug = _slugOf(e.value);
      final targetSlug = _slugOf(target);
      if (sameTitle &&
          slug != targetSlug &&
          !merged.any((p) => p.containsAll([slug, targetSlug]))) {
        bad.add('${e.key}: "$slug" - copy ${parts[1]}\'s "$targetSlug"'
            ' (and add "$slug" to ${parts[1]}\'s slugAliases if it shipped)');
      }
    }
    expect(bad, isEmpty);
  });

  test('an alias showing only some tabs has a slug of its own', () {
    final bad = <String>[];
    for (final e in index.entries) {
      final parts = e.key.split('|');
      if (parts.length != 2 || !_showsSomeTabs(e.value)) continue;
      if (_slugOf(e.value) == _slugOf(index[parts[1]] ?? const {})) {
        bad.add('${e.key} shares ${parts[1]}\'s slug "${_slugOf(e.value)}"');
      }
    }
    expect(bad, isEmpty);
  });

  test('no slug opens two different zikrs', () {
    // A full-text alias and its target are one zikr; anything else sharing a
    // slug is a collision (the link opens whichever loads last).
    String zikrOf(String key) {
      final parts = key.split('|');
      return parts.length == 2 && !_showsSomeTabs(index[key]!) ? parts[1] : key;
    }

    final owners = <String, Set<String>>{};
    for (final e in index.entries) {
      for (final s in {_slugOf(e.value), ..._slugAliasesOf(e.value)}) {
        owners.putIfAbsent(s, () => {}).add(e.key);
      }
    }
    final bad = [
      for (final o in owners.entries)
        if (o.value.map(zikrOf).toSet().length > 1)
          '"${o.key}": ${o.value.join(', ')}',
    ];
    expect(bad, isEmpty);
  });

  test('no slug is another entry\'s slug with a number tacked on', () {
    // The "-2" an index builder mints for a collision. A number the title
    // itself ends with ("General Taqibaat - 1") is fine.
    final taken = {
      for (final e in index.entries) ...[
        _slugOf(e.value),
        ..._slugAliasesOf(e.value),
      ],
    };
    final suffixed = RegExp(r'^(.+)-(\d+)$');
    final bad = <String>[];
    for (final e in index.entries) {
      final slug = _slugOf(e.value);
      final m = suffixed.firstMatch(slug);
      if (m == null || !taken.contains(m.group(1))) continue;
      if (_shippedSuffixedSlugs[e.key] == slug) continue;
      final titleSlug = normalizeSlug(e.value['title'].toString());
      if (titleSlug.endsWith('-${m.group(2)}')) continue;
      bad.add('${e.key}: "$slug" (title "${e.value['title']}")');
    }
    expect(bad, isEmpty);
  });
}
