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

  static String formatArabicText(String str) {
    if (arabicFont == 'Qalam') {
      return str;
    } else {
      return str
          .replaceAll("ی", "ي")
          .replaceAll("ہ", "ه")
          .replaceAll("ک", "ك")
          .replaceAll("ۃ", "ة")
          .replaceAll('الله', 'اللّٰه')
          .replaceAll('ٗ ', '')
          .replaceAll('ٖ ', ' ِ')
          .replaceAll('اۤ', 'ا');
    }
  }
}
