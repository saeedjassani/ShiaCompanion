import '../constants.dart';
import '../pages/zikr/zikr_content_parser.dart';

/// Everything the app knows about the Quran's structure.
///
/// The surahs are not a separate corpus - they are 114 ordinary zikr
/// documents, `A5` through `A118`. Nothing about that changes here; this file
/// is the single place that interprets those documents as Quran rather than as
/// generic zikr, so the reader, the deep links and the progress store all
/// agree on what "surah 23, ayah 56" means.

/// The uid of the first surah. Surah *n* lives at `A(n + _surahUidOffset)`,
/// the mapping the corpus was built with (see `scripts/update_quran.js`).
///
/// `A4` sits just below it and is Ayat al Kursi, not a surah - hence the
/// range checks on every conversion below rather than bare arithmetic.
const int _surahUidOffset = 4;

const int surahCount = 114;

/// Ayahs per surah, in order, surah 1 first.
///
/// Canonical and fixed - deliberately not derived from the documents. It is
/// what bounds "go to verse" input and sizes the juz rows, so that a gap in a
/// document can never silently become a smaller Quran.
const List<int> surahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, //
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135, //
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, //
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85, //
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, //
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13, //
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, //
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, //
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, //
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11, //
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, //
  5, 4, 5, 6, //
];

bool isSurahNumber(int surah) => surah >= 1 && surah <= surahCount;

/// How many ayahs surah [surah] has, or null if there is no such surah.
int? ayahCountOf(int surah) =>
    isSurahNumber(surah) ? surahAyahCounts[surah - 1] : null;

/// The zikr uid holding surah [surah], or null if [surah] is out of range.
String? uidForSurah(int surah) =>
    isSurahNumber(surah) ? 'A${surah + _surahUidOffset}' : null;

final RegExp _surahUidPattern = RegExp(r'^A(\d+)$');

/// Which surah [uid] holds, or null when it is not a surah document.
///
/// Takes the primary uid, so an alias like `X1|A9` resolves the same way the
/// reader does. Returns null for `A4` (Ayat al Kursi) and for every other
/// category, which is what keeps non-Quran zikrs on the unchanged code path.
int? surahForUid(String uid) {
  final match = _surahUidPattern.firstMatch(uid.split('|').last.trim());
  if (match == null) return null;
  final surah = int.parse(match.group(1)!) - _surahUidOffset;
  return isSurahNumber(surah) ? surah : null;
}

/// Splits `"2 : Al-Baqarah البقرة"` into its number, English and Arabic names.
///
/// The corpus titles are inconsistent about the spacing around the colon
/// (`"1: al-Faatehah"` vs `"2 : Al-Baqarah"` vs `"90 : Al-Balad"`), so the
/// separator is matched loosely rather than assumed.
final RegExp _surahTitlePattern = RegExp(r'^\s*(\d+)\s*:\s*(.*)$');

/// One surah, as the Quran screen needs to show it.
class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.englishName,
    required this.arabicName,
    required this.uid,
    required this.ayahCount,
    this.slug,
  });

  final int number;
  final String englishName;
  final String arabicName;
  final String uid;
  final int ayahCount;
  final String? slug;

  /// The title as the rest of the app knows it, for anything that still keys
  /// off the raw zikr title (sharing, favourites, analytics labels).
  String get fullTitle => arabicName.isEmpty
      ? '$number: $englishName'
      : '$number: $englishName $arabicName';
}

/// Every surah in order, built from the loaded zikr index.
///
/// Reads names out of the titles already in [items] rather than carrying a
/// second copy of them, so an admin retitling a surah is reflected here too.
/// Falls back to the uid-derived number when a title is missing or unparseable
/// so the list is always 114 long and never silently short.
List<SurahInfo> allSurahs() {
  final surahs = <SurahInfo>[];
  for (var number = 1; number <= surahCount; number++) {
    final uid = uidForSurah(number)!;
    surahs.add(
      surahInfoFor(number) ??
          SurahInfo(
            number: number,
            englishName: 'Surah $number',
            arabicName: '',
            uid: uid,
            ayahCount: surahAyahCounts[number - 1],
          ),
    );
  }
  return surahs;
}

/// Details for one surah, or null when [surah] is out of range.
SurahInfo? surahInfoFor(int surah) {
  final uid = uidForSurah(surah);
  if (uid == null) return null;

  final rawTitle = items[uid]?.toString().trim() ?? '';
  final match = _surahTitlePattern.firstMatch(rawTitle);
  final remainder = (match?.group(2) ?? rawTitle).trim();

  // The Arabic name is the trailing Arabic run; the English name is what is
  // left. Splitting on the first Arabic character keeps names like
  // "al-An'aam" intact, apostrophes and hyphens included.
  var splitAt = remainder.length;
  for (var i = 0; i < remainder.length; i++) {
    if (ZikrContentParser.isArabic(remainder[i])) {
      splitAt = i;
      break;
    }
  }

  final englishName = remainder.substring(0, splitAt).trim();
  final arabicName = remainder.substring(splitAt).trim();

  return SurahInfo(
    number: surah,
    englishName: englishName.isEmpty ? 'Surah $surah' : englishName,
    arabicName: arabicName,
    uid: uid,
    ayahCount: surahAyahCounts[surah - 1],
    slug: itemSlugs[uid],
  );
}

/// One ayah's position inside a parsed document.
///
/// [start] is the ayah's Arabic line; [end] is exclusive and runs up to the
/// next ayah's Arabic line, so the transliteration and translation that belong
/// to this ayah fall inside the span. Same `[start, end)` convention the
/// bookmark highlight already uses.
class AyahSpan {
  const AyahSpan({
    required this.surah,
    required this.ayah,
    required this.start,
    required this.end,
    this.startsSurah,
  });

  /// Which surah this verse belongs to.
  ///
  /// Carried per span rather than per index because a juz runs across surah
  /// boundaries, so the index as a whole cannot answer it. Everything that
  /// records or links to a position speaks in `(surah, ayah)` for that reason.
  final int surah;

  /// The ayah number from the line's `(n)` marker, or null for an unnumbered
  /// leading line - the Bismillah that heads every surah but at-Tawbah.
  final int? ayah;
  final int start;
  final int end;

  /// Set on the first span of each surah in a portion that spans several, so
  /// the reader can draw a heading where one surah gives way to the next.
  /// Null everywhere else, including throughout a single-surah reading, where
  /// the page's own title already says which surah this is.
  final SurahInfo? startsSurah;

  VerseKey? get verse => ayah == null ? null : VerseKey(surah, ayah);

  bool contains(int lineIndex) => lineIndex >= start && lineIndex < end;

  AyahSpan shifted(int lineOffset, {SurahInfo? startsSurah}) => AyahSpan(
        surah: surah,
        ayah: ayah,
        start: start + lineOffset,
        end: end + lineOffset,
        startsSurah: startsSurah ?? this.startsSurah,
      );
}

/// The ayahs of a readable stretch of Quran, in reading order.
///
/// Usually one surah, but a juz portion is several stitched together - hence
/// keying by `(surah, ayah)` rather than by ayah alone, which repeats once more
/// than one surah is in play.
///
/// Built from the `(n)` markers the corpus already carries rather than by
/// counting Arabic lines, so an unnumbered Bismillah - present in 113 surahs,
/// absent in at-Tawbah - shifts nothing.
class AyahIndex {
  const AyahIndex._(this.spans, this._spanIndexByVerse);

  factory AyahIndex.fromSpans(List<AyahSpan> spans) {
    final spanIndexByVerse = <String, int>{};
    for (var i = 0; i < spans.length; i++) {
      final verse = spans[i].verse;
      // First marker wins: a duplicate number should not move an ayah that
      // was already placed correctly.
      if (verse != null) spanIndexByVerse.putIfAbsent(_verseKey(verse), () => i);
    }

    return AyahIndex._(
      List.unmodifiable(spans),
      Map.unmodifiable(spanIndexByVerse),
    );
  }

  /// Indexes one surah document.
  factory AyahIndex.fromParsedContent(
    ParsedZikrContent content, {
    required int surah,
  }) {
    return AyahIndex.fromSpans(spansOfParsedContent(content, surah: surah));
  }

  /// Every span in reading order, the unnumbered Bismillah headers included -
  /// they are content the reader has to draw, they just are not ayahs.
  final List<AyahSpan> spans;

  final Map<String, int> _spanIndexByVerse;

  bool get isEmpty => spans.isEmpty;

  /// Every verse present, in reading order.
  List<VerseKey> get verses =>
      spans.map((span) => span.verse).whereType<VerseKey>().toList();

  /// The index into [spans] holding [verse], by marker value rather than by
  /// position, or null when this portion does not carry it.
  int? spanIndexForVerse(VerseKey verse) => _spanIndexByVerse[_verseKey(verse)];

  /// [spanIndexForVerse], falling back to the nearest earlier verse of the same
  /// surah when this portion does not carry the one asked for.
  ///
  /// Landing a reader somewhere sensible beats landing them nowhere, so a link
  /// to a verse a document happens not to hold still opens near it rather than
  /// at the top.
  int? nearestSpanIndexForVerse(VerseKey verse) {
    final exact = spanIndexForVerse(verse);
    if (exact != null) return exact;
    if (verse.ayah == null) return null;

    int? best;
    var bestAyah = 0;
    for (var i = 0; i < spans.length; i++) {
      final ayah = spans[i].ayah;
      if (spans[i].surah != verse.surah || ayah == null) continue;
      if (ayah <= verse.ayah! && ayah > bestAyah) {
        bestAyah = ayah;
        best = i;
      }
    }
    return best;
  }

  /// The verse showing at [spanIndex], or null when that span is a Bismillah.
  VerseKey? verseAtSpanIndex(int spanIndex) =>
      spanIndex >= 0 && spanIndex < spans.length ? spans[spanIndex].verse : null;

  static String _verseKey(VerseKey verse) => '${verse.surah}:${verse.ayah}';
}

/// The spans of one parsed surah document, before any trimming or stitching.
///
/// Split out from [AyahIndex.fromParsedContent] so a portion builder can take
/// the spans of several surahs, keep the ones it wants and shift them onto its
/// own line numbering.
List<AyahSpan> spansOfParsedContent(
  ParsedZikrContent content, {
  required int surah,
}) {
  final arabicLines = content.arabicCodes.toList()..sort();
  final spans = <AyahSpan>[];

  for (var i = 0; i < arabicLines.length; i++) {
    final start = arabicLines[i];
    final end =
        i + 1 < arabicLines.length ? arabicLines[i + 1] : content.lines.length;
    spans.add(
      AyahSpan(
        surah: surah,
        ayah: ZikrContentParser.ayahNumberOf(content.lines[start]),
        start: start,
        end: end,
      ),
    );
  }

  return spans;
}

/// A `surah:ayah` reference, as typed by a reader or carried in a link.
class VerseKey {
  const VerseKey(this.surah, [this.ayah]);

  final int surah;

  /// Null means the whole surah - `/quran/23` rather than `/quran/23/56`.
  final int? ayah;

  /// Accepts `23:56`, `23/56`, `23-56`, `23.56`, `23 56` and a bare `23`.
  ///
  /// Out-of-range input is clamped rather than rejected, so `2:300` opens
  /// al-Baqarah at its last ayah instead of failing; a surah outside 1..114
  /// has nothing to clamp to and returns null.
  static VerseKey? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final match = _versePattern.firstMatch(trimmed);
    if (match == null) return null;

    final surah = int.tryParse(match.group(1)!);
    if (surah == null || !isSurahNumber(surah)) return null;

    final rawAyah = match.group(2);
    if (rawAyah == null || rawAyah.isEmpty) return VerseKey(surah);

    final ayah = int.tryParse(rawAyah);
    if (ayah == null || ayah < 1) return VerseKey(surah);

    final maxAyah = surahAyahCounts[surah - 1];
    return VerseKey(surah, ayah > maxAyah ? maxAyah : ayah);
  }

  static final RegExp _versePattern =
      RegExp(r'^(\d{1,3})(?:\s*[:/.\-\s]\s*(\d{1,3}))?$');

  @override
  String toString() => ayah == null ? '$surah' : '$surah:$ayah';

  @override
  bool operator ==(Object other) =>
      other is VerseKey && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}

/// One of the thirty parts the Quran is traditionally divided into.
class Juz {
  const Juz({
    required this.number,
    required this.start,
    required this.end,
  });

  final int number;

  /// First verse of the juz, and its last - inclusive at both ends.
  final VerseKey start;
  final VerseKey end;
}

/// The thirty juz boundaries.
///
/// Each juz starts where the previous one ends, so only the starts are written
/// out; the ends are derived in [allJuz] to keep the two from drifting apart.
const List<List<int>> _juzStarts = [
  [1, 1], [2, 142], [2, 253], [3, 93], [4, 24], [4, 148], [5, 82], [6, 111], //
  [7, 88], [8, 41], [9, 93], [11, 6], [12, 53], [15, 1], [17, 1], [18, 75], //
  [21, 1], [23, 1], [25, 21], [27, 56], [29, 46], [33, 31], [36, 28], //
  [39, 32], [41, 47], [46, 1], [51, 31], [58, 1], [67, 1], [78, 1], //
];

/// All thirty juz, in order.
List<Juz> allJuz() {
  final juzList = <Juz>[];
  for (var i = 0; i < _juzStarts.length; i++) {
    final start = VerseKey(_juzStarts[i][0], _juzStarts[i][1]);
    juzList.add(Juz(number: i + 1, start: start, end: _juzEndAt(i)));
  }
  return juzList;
}

/// The last verse of juz [index], being the verse right before the next juz
/// starts - or the very end of the Quran for the thirtieth.
VerseKey _juzEndAt(int index) {
  if (index + 1 >= _juzStarts.length) {
    return VerseKey(surahCount, surahAyahCounts[surahCount - 1]);
  }

  final nextSurah = _juzStarts[index + 1][0];
  final nextAyah = _juzStarts[index + 1][1];
  if (nextAyah > 1) return VerseKey(nextSurah, nextAyah - 1);

  // The next juz starts on a surah boundary, so this one ends on the last
  // ayah of the surah before it.
  final previousSurah = nextSurah - 1;
  return VerseKey(previousSurah, surahAyahCounts[previousSurah - 1]);
}
