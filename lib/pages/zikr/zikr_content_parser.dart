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

  /// Maps Indo-Pak pause marks encoded in Al Qalam's private-use area to
  /// standard Unicode 14 Quranic codepoints. Used for fonts like Scheherazade
  /// which lack Qalam's proprietary PUA glyphs.
  static const Map<String, String> _scheherazadePuaMarks = {
    '\uE01A': '\u0617', // small high zain (ز, jā'iz)
    '\uE01B': '\u08D5', // small high sad (ص, qad yuṣal)
    '\uE01C': '\u08D7', // small high qaf
    '\uE01D': '\u06D6', // small high sad-lam-alef (sal)
    '\uE01E': '\u08DE', // small high word qif
    '\uE01F': '\u08DF', // small high word waqfa
    '\uE021': '\u06D9', // small high lam alef
    '\uE022': '\u08D6', // small high ain (ruku)
  };

  /// In Al Qalam font, uniE01E (qif / قف) is a baseline word glyph (width 1200,
  /// yMin 398) rather than a high combining mark, which collides with preceding
  /// letters (such as in muqatta'at like الٓرٰ). Mapping it to uniE01C (small high
  /// qaf, yMin 1208) preserves the pause meaning while rendering as a clean,
  /// elevated Quranic pause sign that does not collide.
  static const Map<String, String> _qalamPuaMarks = {
    '\uE01E': '\uE01C', // small high qaf
  };

  // Typographic spaces that no font bundled here has ever had a glyph for,
  // Qalam included — 619 of them across the corpus, every one a box.
  static const Map<String, String> _spaces = {
    '\u2002': ' ', // en space
    '\u2003': ' ', // em space
  };

  /// Trailing waqf marks before ayah medallion:
  /// Errant PUA pause marks (like \uE01E qif, \uE01F waqfah) immediately before
  /// the trailing ayah medallion (n) must be stripped so they do not collide or
  /// get swallowed into the medallion (e.g. '(1 قف)').
  /// The ruku mark \uE022 and standard combining marks are preserved.
  static final RegExp _trailingWaqfBeforeAyah = RegExp(
    r'[\uE01A-\uE021]\s*(?=\u200f?\(\d+\)\s*$)',
  );

  /// Waqf marks: standard Quranic combining marks + Qalam PUA pause marks.
  /// \u0615: small high tah
  /// \u06D6-\u06DC: high sad-lam, qaf-lam, meem, lam-alef, jeem, three dots, seen
  /// \u08D5-\u08DF: Unicode 14 Quranic pause marks (sad, ain, qaf, qif, waqfa, etc.)
  /// \uE01A-\uE01C, \uE021: Indo-Pak small high pause marks
  /// Note: \uE022 and \u08D6 (ruku marks) are excluded so spacing before ruku is preserved.
  static final RegExp _leadingSpaceBeforeWaqf = RegExp(
    r'\s+([\u0615\u0617\u06D6-\u06DC\u08D5\u08D7-\u08DF\uE01A-\uE01C\uE021])',
  );

  // When Uthmani waqf marks (06D6, 06D7) are adjacent to Indo-Pak marks (E01A-E021),
  // retain the Indo-Pak mark consistent with the corpus and Qalam font.
  // The ruku mark \uE022 is a different kind of sign, not a pause mark, so it is
  // never merged with a neighbouring pause mark: 9 Quran lines in the corpus
  // end in a pause mark followed by it (e.g. Waqi'ah 40) and must keep both.
  static final RegExp _uthmaniBeforeIndoPakWaqf =
      RegExp(r'[\u06D6\u06D7]\s*([\uE01A-\uE021])');
  static final RegExp _indoPakBeforeUthmaniWaqf =
      RegExp(r'([\uE01A-\uE021])\s*[\u06D6\u06D7]');

  // When two or more pause marks are adjacent, keep the first one. The ruku
  // marks \uE022 and \u08D6 are left out for the reason above.
  static final RegExp _adjacentWaqfMarks = RegExp(
    r'([\u0615\u06D6-\u06DC\u08D5\u08D7-\u08DF\uE01A-\uE021])\s*[\u0615\u06D6-\u06DC\u08D5\u08D7-\u08DF\uE01A-\uE021]+',
  );

  // Ensure a space after a waqf mark when the next word follows it directly, so
  // the word is not glued to the mark. Deliberately narrow:
  // - Only a base letter counts as "the next word". A mark, a ZWNJ or a
  //   combining character after a pause mark belongs to the same cluster
  //   (`\u0615\u0614`), and a space there tears it apart.
  // - \u06D7 and \u06DC are left out. Indo-Pak text uses them mid-word as
  //   letter marks (\u0634\u064E\u0627\u06D7\u0621\u064E, \u0627\u064F\u0648\u0644\u0670\u06D7\u0649\u0650\u0655\u0643\u064E, \u064A\u064E\u0628\u0652\u0635\u064F\u06DC\u0637\u064F), where a space splits the word.
  static final RegExp _waqfFollowedByLetter = RegExp(
    r'([\u0615\u0617\u06D6\u06D8-\u06DB\u08D5-\u08DF\uE01A-\uE022])(?=[\u0621-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06FA-\u06FC\u06FF\u0750-\u077F])',
  );

  // Ensure clean spacing between preceding word and ruku mark \uE022 / \u08D6.
  static final RegExp _rukuSpacing = RegExp(r'([^\s])\s*([\uE022\u08D6])');

  // Spacing before trailing ayah number medallion (n)
  static final RegExp _trailingAyahSpacing = RegExp(r'\s*\u200f?\((\d+)\)\s*$');

  /// Fonts that draw the ayah medallion by enclosing the Arabic-Indic digits
  /// that follow [_endOfAyah].
  ///
  /// Qalam is deliberately absent. It draws its medallion from the ASCII
  /// parentheses the corpus is authored with, and renders U+06DD as an empty
  /// ornament with the digits swallowed — so for Qalam the number stays as
  /// ASCII `(n)`, only re-spaced.
  static const Set<String> _endOfAyahFonts = {'Scheherazade'};

  static const String _endOfAyah = '\u06DD';
  static const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

  // Verse numbers close a line: 6,187 of them across the corpus sit at the
  // end, 8 lead a line as ordinary list numbering, and none fall in between.
  // Anchoring to the line end converts the verse numbers and leaves the
  // list numbering alone.
  static final RegExp _trailingAyahNumber = RegExp(r'\((\d+)\)\s*$');

  /// The ayah number an Arabic line ends with, or null when it carries none -
  /// the Bismillah that heads every surah but at-Tawbah, and every line of a
  /// zikr that is not Quran at all.
  ///
  /// Reads the same marker [formatArabicText] converts into a medallion, so
  /// the number the reader sees and the number the app indexes by are by
  /// construction the same one.
  static int? ayahNumberOf(String line) {
    final match = _trailingAyahNumber.firstMatch(line.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String _toArabicIndic(String digits) =>
      digits.split('').map((d) => _arabicIndicDigits[int.parse(d)]).join();

  // Every step of [formatArabicText] is triggered by one of these: a
  // typographic space, a private-use mark, a waqf or ruku mark, or a trailing
  // (n). Most lines carry none of them, so they skip the regex passes below,
  // which run on every rebuild of a scrolling surah.
  static final RegExp _needsFormatting = RegExp(
    r'[\u2002\u2003\uE003\uE004\u0615\u06D6-\u06DC\u08D5-\u08DF\uE01A-\uE022]|\(\d+\)\s*$',
  );

  /// Prepares one Arabic line for display in [arabicFont].
  ///
  /// This normalises waqf (pause) signs by:
  /// - Deduplicating conflicting/overlapping pause marks from mixed Uthmani
  ///   and Indo-Pak traditions. The ruku mark is never merged into one.
  /// - Stripping errant pause marks immediately preceding the ayah medallion
  ///   so they do not collide or get swallowed into the medallion (e.g. `(1 قف)`).
  ///   This runs after the deduplication, which can leave such a mark
  ///   directly against the medallion.
  /// - Mapping proprietary PUA pause marks to standard Unicode Quranic marks
  ///   for non-Qalam fonts (like Scheherazade) and to non-colliding high marks
  ///   for Qalam.
  /// - Removing whitespace before combining waqf marks so they attach directly
  ///   to the preceding word rather than floating detached.
  /// - Separating a pause mark from a next word that follows it directly.
  /// - Preserving the rukūʿ mark (`\uE022`) outside the medallion with clean spacing.
  /// - Ensuring clean spacing before the ayah medallion `(n)`, which for
  ///   Qalam replaces the RLM the corpus authors before it with a plain space.
  static String formatArabicText(String str) {
    if (!_needsFormatting.hasMatch(str)) return str;

    var result = str;
    _spaces.forEach((from, to) => result = result.replaceAll(from, to));
    _privateUseMarks
        .forEach((from, to) => result = result.replaceAll(from, to));

    // 1. Deduplicate conflicting / adjacent waqf marks while in common encoding.
    result = result.replaceAllMapped(
      _uthmaniBeforeIndoPakWaqf,
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      _indoPakBeforeUthmaniWaqf,
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      _adjacentWaqfMarks,
      (match) => match.group(1)!,
    );

    // 2. Remove pause marks immediately before trailing ayah medallion so they
    // do not collide with the last word or get pulled inside the medallion (e.g. '(1 قف)').
    // After step 1, so a mark it leaves behind is not shielded by a neighbour
    // it would have removed. The ruku mark \uE022 is preserved.
    result = result.replaceAll(_trailingWaqfBeforeAyah, '');

    // 3. Map font-specific pause marks.
    if (_endOfAyahFonts.contains(arabicFont)) {
      _scheherazadePuaMarks.forEach((from, to) {
        result = result.replaceAll(from, to);
      });
    } else {
      _qalamPuaMarks.forEach((from, to) {
        result = result.replaceAll(from, to);
      });
    }

    // 4. Remove space before combining waqf marks so they attach to the preceding letter.
    result = result.replaceAllMapped(
      _leadingSpaceBeforeWaqf,
      (match) => match.group(1)!,
    );

    // 5. Ensure a space separates the waqf mark from the next word.
    result = result.replaceAllMapped(
      _waqfFollowedByLetter,
      (match) => '${match.group(1)} ',
    );

    // 6. Ensure clean spacing before ruku mark so it sits nicely before the medallion.
    result = result.replaceAllMapped(
      _rukuSpacing,
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // 7. Ensure clean spacing before the ayah medallion so marks do not overlap it.
    result = result.replaceFirstMapped(_trailingAyahSpacing, (match) {
      final number = match.group(1)!;
      return _endOfAyahFonts.contains(arabicFont)
          ? ' $_endOfAyah${_toArabicIndic(number)}'
          : ' ($number)';
    });

    return result;
  }
}
