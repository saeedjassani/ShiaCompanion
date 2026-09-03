import '../../constants.dart';

class ZikrLineSegment {
  final String text;
  final String? href;

  const ZikrLineSegment({required this.text, this.href});

  bool get hasHref => href != null && href!.trim().isNotEmpty;
}

class ParsedZikrContent {
  final List<String> lines;
  final Set<int> arabicCodes;
  final Set<int> transliCodes;
  final Set<int> translaCodes;

  const ParsedZikrContent({
    required this.lines,
    required this.arabicCodes,
    required this.transliCodes,
    required this.translaCodes,
  });
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

    return ParsedZikrContent(
      lines: split,
      arabicCodes: arabicCodes,
      transliCodes: _generateEnglishCodes(arabicCodes, true, code),
      translaCodes: _generateEnglishCodes(arabicCodes, false, code),
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

  static Set<int> _generateEnglishCodes(
    Set<int> arabicCodes,
    bool transliteration,
    String? code,
  ) {
    final englishCodes = <int>{};
    if (code == "102") {
      for (final i in arabicCodes) {
        englishCodes.add(transliteration ? i - 1 : i + 1);
      }
    } else if (code == "012") {
      for (final i in arabicCodes) {
        englishCodes.add(transliteration ? i + 1 : i + 2);
      }
    } else if (code == "02" && !transliteration) {
      for (final i in arabicCodes) {
        englishCodes.add(i + 1);
      }
    }
    return englishCodes;
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
