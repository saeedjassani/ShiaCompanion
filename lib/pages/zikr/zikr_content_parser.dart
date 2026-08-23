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

  // Maps the Indo-Pak/Qalam-style letterforms the Arabic text is authored in
  // to standard modern Arabic, for fonts other than Qalam that lack them.
  // Each entry replaces a single character in place, so it applies regardless
  // of what follows (line end, punctuation, another mark).
  //
  // Mirrors `font_runtime` in scripts/zikr_arabic/rules.json — keep the two in
  // step; scripts/zikr_arabic/audit.py checks the result against each font's
  // real cmap, so drift here shows up as an INV-2 failure.
  //
  // الٹا پیش / ulta pesh (ٗ) and کھڑی زیر / khaṛi zer (ٖ) ARE flattened here,
  // to a plain damma/kasra. This is a rendering decision, not a claim about
  // the text: both marks are correct and distinct in the stored Indo-Pak
  // text, and normalization must never strip them at the source. But the
  // codepoint being present in a font's cmap does not mean the font draws it
  // properly — Uthmani renders ulta pesh as a slanted stroke indistinguishable
  // from a fatha, so "عِلْمَهٗ" would read as "عِلْمَهَ", and MeQuran collides
  // the mark with the letter. A plain damma is the correct reading and both
  // fonts draw it cleanly.
  static const Map<String, String> _indoPakLetters = {
    'ی': 'ي', // Farsi/Urdu yeh -> Arabic yeh
    'ہ': 'ه', // Urdu heh goal -> Arabic heh
    'ھ': 'ه', // Urdu doachashmi heh -> Arabic heh
    'ک': 'ك', // Urdu keheh -> Arabic kaf
    'ۃ': 'ة', // Urdu teh marbuta goal -> Arabic teh marbuta
    'ٗ': 'ُ', // ulta pesh -> damma (Uthmani draws ٗ like a fatha)
    'ٖ': 'ِ', // khaṛi zer -> kasra, for the same reason
  };

  // MeQuran's font file carries none of the Indo-Pak letterforms above, and
  // also nothing for these two, which Qalam and Uthmani both have. Without
  // them the glyphs come from a system fallback font instead of the selected
  // one, so a line renders in two different faces at once.
  static const Map<String, String> _meQuranOnly = {
    'ؕ': '', // small high tah, the Indo-Pak waqf mark (3.4k in the corpus)
    'ٮ': 'ى', // dotless beh used as the dagger-alef carrier in mushaf rasm
  };

  static Map<String, String> _substitutionsFor(String font) => {
        ..._indoPakLetters,
        if (font == 'MeQuran') ..._meQuranOnly,
      };

  static String formatArabicText(String str) {
    if (arabicFont == 'Qalam') {
      return str;
    }
    var result = str;
    _substitutionsFor(arabicFont).forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result
        // Must run after the ہ/ھ -> ه mapping above so "اللہ" (Urdu
        // spelling) is also caught, not just "الله".
        .replaceAll('الله', 'اللّٰه')
        // Single-codepoint "Allah" ligature; Uthmani's font file has no
        // glyph for it. The ligature already carries the initial alif, so the
        // alif-prefixed spellings must be matched first — replacing the bare
        // ligature inside "اﷲ" yields a doubled alif ("االلّٰه").
        .replaceAll('اَﷲ', 'اَللّٰه')
        .replaceAll('اﷲ', 'اللّٰه')
        .replaceAll('ﷲ', 'اللّٰه')
        .replaceAll('اۤ', 'ا');
  }
}
