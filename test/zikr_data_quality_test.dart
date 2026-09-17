import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';

final RegExp _latinLetter = RegExp('[A-Za-z]');
final RegExp _arabicRune =
    RegExp('[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');

/// Collects every string in [json] that looks like a verse-content block
/// (Arabic/transliteration/translation lines joined by '\n'), rather than a
/// single-line metadata field like title, code or a URL.
void _collectContentBlocks(dynamic node, List<String> out) {
  if (node is String) {
    if ('\n'.allMatches(node).length >= 2) out.add(node);
  } else if (node is List) {
    for (final v in node) {
      _collectContentBlocks(v, out);
    }
  } else if (node is Map) {
    for (final v in node.values) {
      _collectContentBlocks(v, out);
    }
  }
}

void main() {
  test(
    'no zikr line is misclassified as Arabic by a stray Arabic character',
    () {
      // A real bug (assets/zikr/E20): a lone alif ("ا") sat in front of the
      // English translation line "O Muhammad, O Ali, O Ali, O Muhammad,"
      // instead of leading the Arabic verse below it. ZikrContentParser.
      // isArabic() only needs one Arabic rune in a line's first 35
      // characters, so that single stray character was enough to make the
      // reader treat an English line as the Arabic verse - reordering the
      // whole triplet and garbling the page (screenshot in issue report).
      //
      // This walks every bundled zikr asset and flags any predominantly
      // Latin line that isArabic() would still classify as Arabic, which is
      // exactly the condition that produced that bug.
      final offenders = <String>[];

      for (final file in Directory('assets/zikr').listSync().whereType<File>()) {
        final dynamic decoded = jsonDecode(file.readAsStringSync());
        final blocks = <String>[];
        _collectContentBlocks(decoded, blocks);

        for (final block in blocks) {
          for (final rawLine in block.split('\n')) {
            final line = rawLine.trim();
            if (line.isEmpty) continue;

            final latinCount = _latinLetter.allMatches(line).length;
            final arabicCount = _arabicRune.allMatches(line).length;

            // A line with only a couple of Arabic runes but a clearly
            // English body (5+ Latin letters) is a misplaced-character
            // symptom, not a legitimately bilingual line - the corpus has
            // none of those today.
            final looksLatin = latinCount >= 5 && arabicCount <= 2;

            if (looksLatin && ZikrContentParser.isArabic(line)) {
              offenders.add('${file.path}: "$line"');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These lines are mostly Latin text but contain a stray '
            'Arabic character that makes the app render them as the '
            "verse's Arabic line, scrambling the triplet order:\n"
            '${offenders.join('\n')}',
      );
    },
  );

  test('every bundled zikr asset is valid JSON with a non-empty title', () {
    final offenders = <String>[];

    for (final file in Directory('assets/zikr').listSync().whereType<File>()) {
      dynamic decoded;
      try {
        decoded = jsonDecode(file.readAsStringSync());
      } catch (e) {
        offenders.add('${file.path}: invalid JSON ($e)');
        continue;
      }

      if (decoded is! Map || (decoded['title'] as String?)?.trim().isEmpty != false) {
        offenders.add('${file.path}: missing or empty "title"');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
