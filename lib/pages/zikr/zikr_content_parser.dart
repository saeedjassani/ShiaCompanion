import 'dart:math' as math;

import '../../constants.dart';

class ZikrLineSegment {
  final String text;
  final String? href;

  const ZikrLineSegment({required this.text, this.href});

  bool get hasHref => href != null && href!.trim().isNotEmpty;
}

/// One Arabic line together with the transliteration and translation lines
/// that belong to it - the "triplet" a reader sees as a single unit. [start]
/// is inclusive, [end] exclusive, and the two are the outermost member lines
/// however the tab's code orders them (transliteration leads the Arabic in
/// code 102, follows it in 012).
class ZikrLineGroup {
  const ZikrLineGroup({required this.start, required this.end});

  final int start;
  final int end;

  bool contains(int lineIndex) => lineIndex >= start && lineIndex < end;
}

class ParsedZikrContent {
  final List<String> lines;
  final Set<int> arabicCodes;
  final Set<int> transliCodes;
  final Set<int> translaCodes;

  /// The triplet each member line belongs to, keyed by every one of its
  /// member indexes so a lookup works from the Arabic line, its
  /// transliteration or its translation alike. Lines that stand on their own
  /// - headings, instructions, blank lines - are simply absent.
  final Map<int, ZikrLineGroup> groupForLine;

  const ParsedZikrContent({
    required this.lines,
    required this.arabicCodes,
    required this.transliCodes,
    required this.translaCodes,
    this.groupForLine = const {},
  });

  /// The triplet [lineIndex] belongs to, or null when it stands alone.
  ZikrLineGroup? groupContaining(int lineIndex) => groupForLine[lineIndex];
}

class ZikrContentParser {
  static ParsedZikrContent parseContent(
    String content, {
    required bool hideHeaderLine,
    required String? code,
  }) {
    final split = content.split('\n');
    if (hideHeaderLine && split.isNotEmpty) {
      split.removeAt(0);
    }
    final arabicCodes = <int>{};

    for (int i = 0, n = split.length; i < n; i++) {
      split[i] = split[i].trim();
      if (split[i].isEmpty) continue;
      if (isArabic(split[i])) {
        arabicCodes.add(i);
      }
    }

    final transliCodes = <int>{};
    final translaCodes = <int>{};
    final groupForLine = <int, ZikrLineGroup>{};

    for (final arabicIndex in arabicCodes) {
      final members = <int>[arabicIndex];
      final transliIndex = _englishCodeFor(arabicIndex, true, code);
      final translaIndex = _englishCodeFor(arabicIndex, false, code);

      // An index that is itself Arabic is another verse, not this one's
      // English: the renderer already treats Arabic first, and letting it
      // into the triplet would stretch the span over two verses.
      if (transliIndex != null &&
          transliIndex >= 0 &&
          transliIndex < split.length &&
          !arabicCodes.contains(transliIndex)) {
        transliCodes.add(transliIndex);
        members.add(transliIndex);
      }
      if (translaIndex != null &&
          translaIndex >= 0 &&
          translaIndex < split.length &&
          !arabicCodes.contains(translaIndex)) {
        translaCodes.add(translaIndex);
        members.add(translaIndex);
      }

      final group = ZikrLineGroup(
        start: members.reduce(math.min),
        end: members.reduce(math.max) + 1,
      );
      for (final member in members) {
        groupForLine[member] = group;
      }
    }

    return ParsedZikrContent(
      lines: split,
      arabicCodes: arabicCodes,
      transliCodes: transliCodes,
      translaCodes: translaCodes,
      groupForLine: groupForLine,
    );
  }

  static bool isArabic(String s) {
    var scannedCharacters = 0;
    for (final rune in s.runes) {
      if (scannedCharacters >= 35) break;
      if (_isArabicRune(rune)) {
        return true;
      }
      scannedCharacters++;
    }
    return false;
  }

  static bool _isArabicRune(int rune) {
    return (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
  }

  static final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

  static List<ZikrLineSegment> parseLineSegments(String line) {
    final segments = <ZikrLineSegment>[];
    var currentIndex = 0;
    for (final match in _markdownLinkPattern.allMatches(line)) {
      if (match.start > currentIndex) {
        segments.add(ZikrLineSegment(
          text: line.substring(currentIndex, match.start),
        ));
      }
      final linkText = match.group(1) ?? '';
      final href = match.group(2) ?? '';
      segments.add(ZikrLineSegment(text: linkText, href: href));
      currentIndex = match.end;
    }
    if (currentIndex < line.length) {
      segments.add(ZikrLineSegment(text: line.substring(currentIndex)));
    }
    return segments;
  }

  /// Where the transliteration (or translation) of the Arabic line at
  /// [arabicIndex] sits, per the tab's layout code, or null when the layout
  /// has no such line at all. The index is not range-checked here.
  static int? _englishCodeFor(
    int arabicIndex,
    bool transliteration,
    String? code,
  ) {
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

  // Al Qalam encodes the ṣilah al-hā' marks at private-use codepoints whose
  // glyphs are named for the real ones (U+E003 -> uni0656, U+E004 -> uni0657).
  // Qalam maps the real codepoints to the very same glyphs, so writing them
  // out costs Qalam nothing and lets every other font draw the marks too.
  static const Map<String, String> _privateUseMarks = {
    '\uE003': '\u0656', // khaṛi zer / کھڑی زیر
    '\uE004': '\u0657', // ulta pesh / الٹا پیش
  };

  // Typographic spaces that no font bundled here has ever had a glyph for,
  // Qalam included — 619 of them across the corpus, every one a box.
  static const Map<String, String> _spaces = {
    '\u2002': ' ', // en space
    '\u2003': ' ', // em space
  };

  /// Fonts that draw the ayah medallion by enclosing the Arabic-Indic digits
  /// that follow [_endOfAyah].
  ///
  /// Qalam is deliberately absent. It draws its medallion from the ASCII
  /// parentheses the corpus is authored with, and renders U+06DD as an empty
  /// ornament with the digits swallowed — so for Qalam the text is left alone.
  static const Set<String> _endOfAyahFonts = {'Scheherazade'};

  static const String _endOfAyah = '\u06DD';
  static const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

  // Verse numbers close a line: 6,187 of them across the corpus sit at the
  // end, 8 lead a line as ordinary list numbering, and none fall in between.
  // Anchoring to the line end converts the verse numbers and leaves the
  // list numbering alone.
  static final RegExp _trailingAyahNumber = RegExp(r'\((\d+)\)\s*$');

  static String _toArabicIndic(String digits) =>
      digits.split('').map((d) => _arabicIndicDigits[int.parse(d)]).join();

  /// Prepares one Arabic line for display in [arabicFont].
  ///
  /// This used to carry a substitution table that rewrote Indo-Pak letterforms
  /// into standard Arabic, because neither non-Qalam font could draw them, and
  /// that table flattened ulta pesh and khaṛi zer to a plain damma and kasra
  /// purely because Uthmani drew ٗ as a fatha. Both fonts have been retired.
  /// Scheherazade New draws every one of those letterforms and both marks, so
  /// the text now renders as it was authored in every font the app ships.
  static String formatArabicText(String str) {
    var result = str;
    _spaces.forEach((from, to) => result = result.replaceAll(from, to));
    _privateUseMarks
        .forEach((from, to) => result = result.replaceAll(from, to));

    if (_endOfAyahFonts.contains(arabicFont)) {
      result = result.replaceFirstMapped(
        _trailingAyahNumber,
        (match) => '$_endOfAyah${_toArabicIndic(match.group(1)!)}',
      );
    }

    return result;
  }
}
