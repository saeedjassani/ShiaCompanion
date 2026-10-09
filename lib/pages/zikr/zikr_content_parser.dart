import 'dart:math' as math;
import 'dart:ui' show TextDirection;

import '../../constants.dart';
import '../../l10n/app_language.dart';
import '../../services/zikr_translations.dart';

class ZikrLineSegment {
  final String text;
  final String? href;

  const ZikrLineSegment({required this.text, this.href});

  bool get hasHref => href != null && href!.trim().isNotEmpty;
}

/// One Arabic line together with the transliteration and translation lines
/// that belong to it - the "triplet" a reader sees as a single unit. [start]
/// is inclusive, [end] exclusive, and the two are the outermost member lines -
/// the Arabic and, below it, its transliteration and translation, or just its
/// translation when the content carries no transliteration at all.
class ZikrLineGroup {
  const ZikrLineGroup({required this.start, required this.end});

  final int start;
  final int end;

  bool contains(int lineIndex) => lineIndex >= start && lineIndex < end;
}

/// One numbered unit a translation is keyed by - see
/// [ZikrDocumentTranslation]. A verse (an Arabic line, with the
/// transliteration and translation that belong to it) or a line that stands
/// on its own: an instruction, a heading, a citation.
class ZikrSegment {
  const ZikrSegment({required this.anchorLine, this.slotLine});

  /// The line the segment is: the Arabic of a verse, or the standalone line.
  final int anchorLine;

  /// The line a translation is drawn in place of: the verse's translation
  /// line, or the standalone line itself. Null for a verse that carries no
  /// translation line at all, which has nowhere to show one.
  final int? slotLine;
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

  /// This content's segments, in reading order.
  final List<ZikrSegment> segments;

  /// Line index -> the text to show in place of that line, for the
  /// translation lines and standalone English lines (instructions, headings,
  /// citations) a [ZikrDocumentTranslation] covers.
  ///
  /// [lines] itself always stays English. Bookmarks, verse matching and
  /// reading-time estimates are all keyed to it, and the parse that sorted
  /// lines into Arabic, transliteration and translation must not be redone on
  /// translated text: Urdu, Persian and Arabic translations are in Arabic
  /// script, and would read as verses.
  final Map<int, String> translatedLines;

  /// Which way [translatedLines] read.
  final TextDirection translationDirection;

  /// Whether the reader is reading in a language other than English, so
  /// every English line [translatedLines] does not cover is left out rather
  /// than shown - see [isHiddenEnglish].
  final bool hidesEnglish;

  const ParsedZikrContent({
    required this.lines,
    required this.arabicCodes,
    required this.transliCodes,
    required this.translaCodes,
    this.groupForLine = const {},
    this.segments = const [],
    this.translatedLines = const {},
    this.translationDirection = TextDirection.ltr,
    this.hidesEnglish = false,
  });

  /// The triplet [lineIndex] belongs to, or null when it stands alone.
  ZikrLineGroup? groupContaining(int lineIndex) => groupForLine[lineIndex];

  /// Line [lineIndex] as the reader sees it: translated where a translation
  /// covers it, the corpus text otherwise.
  String displayLine(int lineIndex) =>
      translatedLines[lineIndex] ?? lines[lineIndex];

  /// The direction line [lineIndex] reads in. Every untranslated line other
  /// than the Arabic is English (and only shown in English), and is set
  /// left-to-right explicitly so it still reads correctly when the app itself
  /// is in a right-to-left language.
  TextDirection directionOf(int lineIndex) {
    if (arabicCodes.contains(lineIndex)) return TextDirection.rtl;
    if (translatedLines.containsKey(lineIndex)) return translationDirection;
    return TextDirection.ltr;
  }

  /// Whether line [lineIndex] is English the reader is not shown: someone
  /// reading in Urdu, say, sees a zikr's Arabic and whatever of it has been
  /// translated into Urdu, never the English of a line nobody has
  /// translated yet. Blank lines stay - they space the text.
  bool isHiddenEnglish(int lineIndex) =>
      hidesEnglish &&
      !arabicCodes.contains(lineIndex) &&
      !translatedLines.containsKey(lineIndex) &&
      lines[lineIndex].trim().isNotEmpty;

  /// This content as read in [language]: unchanged in English, and otherwise
  /// with [translation] (if any) laid over it and the English it does not
  /// cover hidden. [firstSegment] is the number of this content's first
  /// segment within the whole zikr - see [ZikrContentParser.segmentOffsets].
  ParsedZikrContent localizedTo(
    AppLanguage language,
    ZikrDocumentTranslation? translation, {
    required int firstSegment,
  }) {
    if (language.code == englishLanguageCode) return this;
    final translated = <int, String>{};
    for (var i = 0; i < segments.length; i++) {
      final slot = segments[i].slotLine;
      if (slot == null) continue;
      final line = translation?.segment(firstSegment + i);
      if (line != null) translated[slot] = line;
    }
    return ParsedZikrContent(
      lines: lines,
      arabicCodes: arabicCodes,
      transliCodes: transliCodes,
      translaCodes: translaCodes,
      groupForLine: groupForLine,
      segments: segments,
      translatedLines: translated,
      translationDirection: language.textDirection,
      hidesEnglish: true,
    );
  }
}

class ZikrContentParser {
  static ParsedZikrContent parseContent(
    String content, {
    required bool hideHeaderLine,
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
    final translationLineOf = <int, int>{};
    final hasTransliteration = _hasTransliteration(arabicCodes);

    for (final arabicIndex in arabicCodes) {
      final members = <int>[arabicIndex];
      final transliIndex = hasTransliteration ? arabicIndex + 1 : null;
      final translaIndex =
          hasTransliteration ? arabicIndex + 2 : arabicIndex + 1;

      // An index that is itself Arabic is another verse, not this one's
      // English: the renderer already treats Arabic first, and letting it
      // into the triplet would stretch the span over two verses.
      if (transliIndex != null &&
          transliIndex < split.length &&
          !arabicCodes.contains(transliIndex)) {
        transliCodes.add(transliIndex);
        members.add(transliIndex);
      }
      if (translaIndex < split.length && !arabicCodes.contains(translaIndex)) {
        translaCodes.add(translaIndex);
        members.add(translaIndex);
        translationLineOf[arabicIndex] = translaIndex;
      }

      final group = ZikrLineGroup(
        start: members.reduce(math.min),
        end: members.reduce(math.max) + 1,
      );
      for (final member in members) {
        groupForLine[member] = group;
      }
    }

    final segments = <ZikrSegment>[];
    for (var i = 0; i < split.length; i++) {
      if (split[i].isEmpty ||
          transliCodes.contains(i) ||
          translaCodes.contains(i)) {
        continue;
      }
      if (arabicCodes.contains(i)) {
        segments
            .add(ZikrSegment(anchorLine: i, slotLine: translationLineOf[i]));
      } else {
        segments.add(ZikrSegment(anchorLine: i, slotLine: i));
      }
    }

    return ParsedZikrContent(
      lines: split,
      arabicCodes: arabicCodes,
      transliCodes: transliCodes,
      translaCodes: translaCodes,
      groupForLine: groupForLine,
      segments: segments,
    );
  }

  /// The tab label of [content] - its first non-empty line - as a tabbed
  /// zikr shows it, or null when the tab has none.
  static String? tabHeaderLine(String content) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// The number of the first segment of each of [tabContents] - the tabs a
  /// zikr shows, in order - within the whole zikr. Where there is more than
  /// one tab, each tab's label is a segment of its own and comes first.
  static List<int> segmentOffsets(List<String> tabContents) {
    final hasHeaders = tabContents.length > 1;
    final offsets = <int>[];
    var next = 0;
    for (final content in tabContents) {
      offsets.add(next);
      if (hasHeaders) next++;
      next += parseContent(content, hideHeaderLine: hasHeaders).segments.length;
    }
    return offsets;
  }

  /// The label of tab [tabIndex] (whose text is [content]) as read in
  /// [language], or null when it has none to show - the caller numbers the
  /// tab instead. [offsets] are the zikr's [segmentOffsets].
  ///
  /// In English the label is the tab's first line. In another language it is
  /// that line's translation, or the line itself when it is Arabic; an
  /// untranslated English label is not shown.
  static String? localizedTabHeader(
    String content,
    int tabIndex, {
    required List<int> offsets,
    required AppLanguage language,
    ZikrDocumentTranslation? translation,
  }) {
    final header = tabHeaderLine(content);
    if (header == null || language.code == englishLanguageCode) return header;
    final translated = tabIndex < offsets.length
        ? translation?.segment(offsets[tabIndex])
        : null;
    if (translated != null) return translated;
    return isArabic(header) ? header : null;
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

  /// Whether [arabicIndexes] are laid out Arabic / transliteration /
  /// translation, rather than Arabic / translation with no transliteration.
  ///
  /// The content does not say which, so the spacing between consecutive
  /// Arabic lines does: two apart is a verse and its translation, three apart
  /// a verse, its transliteration and its translation. Whichever spacing is
  /// the more common wins, and a tie - including content with a single verse,
  /// or none - goes to the transliterated layout, which is how the corpus is
  /// written save for a handful of duas with no transliteration at all.
  static bool _hasTransliteration(Set<int> arabicIndexes) {
    final sorted = arabicIndexes.toList()..sort();
    var twoApart = 0;
    var threeApart = 0;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i] - sorted[i - 1];
      if (gap == 2) twoApart++;
      if (gap == 3) threeApart++;
    }
    return twoApart <= threeApart;
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

  // QuranWBW's IndoPak text ends each verse with its own ayah medallion, a
  // private-use glyph (U+E820 on 4:157, U+F500-U+F6FF everywhere else). The
  // ` (N)` after it is kept for [ayahNumberOf] and hidden here: drawn, it
  // would number the verse a second time.
  static final RegExp _numberAfterQuranWbwMedallion =
      RegExp('(?<=[\uE820\uF500-\uF6FF])\\s*\\(\\d+\\)\\s*\$');

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
    result = result.replaceFirst(_numberAfterQuranWbwMedallion, '');

    if (_endOfAyahFonts.contains(arabicFont)) {
      result = result.replaceFirstMapped(
        _trailingAyahNumber,
        (match) => '$_endOfAyah${_toArabicIndic(match.group(1)!)}',
      );
    }

    return result;
  }
}
