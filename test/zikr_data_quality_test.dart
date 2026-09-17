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

/// Where the transliteration (or translation) of the Arabic line at
/// [arabicIndex] sits, per the tab's layout code - a copy of
/// ZikrContentParser's private `_englishCodeFor`, which this test needs to
/// walk the very same triplets the reader builds.
int? _englishCodeFor(int arabicIndex, bool transliteration, String? code) {
  switch (code) {
    case '102':
      return transliteration ? arabicIndex - 1 : arabicIndex + 1;
    case '012':
      return transliteration ? arabicIndex + 1 : arabicIndex + 2;
    case '02':
      return transliteration ? null : arabicIndex + 1;
    default:
      return null;
  }
}

/// Fraction of [s]'s letters that are uppercase, or null when it has none.
/// Across the corpus transliteration lines are ~78% uppercase on average
/// (e.g. "YAA MOHAMMADO YAA A'LIYYO") and translation lines are ~5% (plain
/// sentence-case prose) - a strong, cheap signature for telling the two
/// apart without understanding either language.
double? _uppercaseRatio(String s) {
  final letters = _latinLetter.allMatches(s).map((m) => s[m.start]).toList();
  if (letters.isEmpty) return null;
  final upper = letters.where((c) => c == c.toUpperCase()).length;
  return upper / letters.length;
}

void main() {
  test(
    'transliteration and translation lines are not swapped',
    () {
      // A real bug (assets/zikr/G6, "Ziyarat e Waaresa"): one verse's
      // translation and transliteration lines sat in each other's place -
      // "and His Prophets and His Messenger." printed where the
      // transliteration belongs, and "WA AMBEYAAA-AHU WA ROSOLAHU" printed
      // as if it were the translation. ZikrContentParser locates each line
      // purely by its fixed offset from the Arabic line (see
      // _englishCodeFor), so a swap like this renders exactly as authored -
      // nothing catches it at parse time.
      //
      // This walks every "012"/"102" tab the same way the reader does and
      // flags any triplet whose transliteration slot reads like prose
      // (mostly lowercase) while its translation slot reads like
      // transliteration (mostly uppercase) - the signature a swap leaves
      // behind.
      final offenders = <String>[];

      for (final file in Directory('assets/zikr').listSync().whereType<File>()) {
        final dynamic decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map) continue;

        final code = decoded['code']?.toString();
        if (code != '012' && code != '102') continue;

        final blocks = <String>[
          if (decoded['data'] is String) decoded['data'] as String,
          if (decoded['tabs'] is List)
            for (final tab in decoded['tabs'] as List)
              if (tab is String) tab,
        ];

        for (final block in blocks) {
          final lines = block.split('\n').map((l) => l.trim()).toList();
          final arabicIndexes = [
            for (var i = 0; i < lines.length; i++)
              if (lines[i].isNotEmpty && ZikrContentParser.isArabic(lines[i]))
                i,
          ];

          for (final arabicIndex in arabicIndexes) {
            final ti = _englishCodeFor(arabicIndex, true, code);
            final ta = _englishCodeFor(arabicIndex, false, code);
            if (ti == null ||
                ta == null ||
                ti < 0 ||
                ta < 0 ||
                ti >= lines.length ||
                ta >= lines.length ||
                arabicIndexes.contains(ti) ||
                arabicIndexes.contains(ta)) {
              continue;
            }

            final transliLine = lines[ti];
            final translaLine = lines[ta];
            if (transliLine.isEmpty || translaLine.isEmpty) continue;

            final transliRatio = _uppercaseRatio(transliLine);
            final translaRatio = _uppercaseRatio(translaLine);
            if (transliRatio == null || translaRatio == null) continue;

            if (transliRatio < 0.5 && translaRatio > 0.5) {
              offenders.add('${file.path}: transliteration slot has '
                  '"$transliLine", translation slot has "$translaLine"');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These triplets look like the transliteration and '
            'translation lines were swapped:\n${offenders.join('\n')}',
      );
    },
  );

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
