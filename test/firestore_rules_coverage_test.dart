import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Firestore collection the app reads or writes needs a `match` in
/// firestore.rules, or Firestore denies it by default. The
/// rules-deployed.yml workflow only checks that production matches the
/// file, so a collection missing from both would slip past it.
void main() {
  test('every Firestore collection used in lib/ has a rule', () {
    final rules = File('firestore.rules').readAsStringSync();
    final matched = RegExp(r'match\s+(/[^\s{]*(?:\{[^}]*\}[^\s{]*)*)')
        .allMatches(rules)
        .expand((m) => m.group(1)!.split('/'))
        .where((segment) => segment.isNotEmpty && !segment.startsWith('{'))
        .toSet();

    final used = <String, String>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      // `static const String _fooCollection = 'foo';` and the like.
      final constants = {
        for (final m in RegExp(r"const\s+String\s+(\w+)\s*=\s*'([^']+)'")
            .allMatches(source))
          m.group(1)!: m.group(2)!,
      };
      for (final m
          in RegExp(r"\.collection(?:Group)?\(\s*(?:'([^']+)'|(\w+))\s*\)")
              .allMatches(source)) {
        final name = m.group(1) ?? constants[m.group(2)];
        if (name == null) {
          fail('${file.path}: cannot resolve .collection(${m.group(2)}) - '
              'use a string literal or a const String in the same file.');
        }
        used[name] = file.path;
      }
    }

    expect(used, isNotEmpty);
    final missing = {
      for (final e in used.entries)
        if (!matched.contains(e.key)) e.key: e.value,
    };
    expect(missing, isEmpty,
        reason: 'These collections have no match in firestore.rules, so '
            'Firestore denies them: $missing');
  });
}
