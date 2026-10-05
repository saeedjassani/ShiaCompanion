import 'zikr_content_parser.dart';
import '../../l10n/l10n.dart';

/// Words an average reciter covers per minute of Arabic supplication text.
///
/// Deliberately Arabic-only - [ZikrTabReadingStats.minutes] drops the
/// transliteration and translation entirely once a tab has Arabic, so this
/// constant is not diluted by them either. It was originally 45, which reads
/// as if the reciter were also working through the other two lines word by
/// word: at 45wpm, Ziyarat Ashura's 734 Arabic words come out to 16
/// minutes, well past the 5-10 minutes it actually takes to recite aloud.
/// 100wpm lines up with that instead.
const double _arabicWordsPerMinute = 100;

/// Words per minute used for content that has no Arabic to recite.
const double _latinWordsPerMinute = 190;

/// Reading effort for a single zikr tab.
class ZikrTabReadingStats {
  const ZikrTabReadingStats({
    required this.arabicWords,
    required this.latinWords,
  });

  final int arabicWords;
  final int latinWords;

  bool get isEmpty => arabicWords == 0 && latinWords == 0;

  /// Transliteration and translation are read alongside the Arabic rather than
  /// after it, so a tab that has Arabic is timed by its Arabic alone.
  double get minutes => arabicWords > 0
      ? arabicWords / _arabicWordsPerMinute
      : latinWords / _latinWordsPerMinute;

  Duration get duration => Duration(seconds: (minutes * 60).round());
}

/// Reading effort for every visible tab of a zikr.
class ZikrReadingStats {
  const ZikrReadingStats({required this.tabs});

  static const ZikrReadingStats empty = ZikrReadingStats(tabs: []);

  final List<ZikrTabReadingStats> tabs;

  double get totalMinutes =>
      tabs.fold<double>(0, (total, tab) => total + tab.minutes);

  Duration get duration {
    final seconds = (totalMinutes * 60).round();
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }

  bool get hasContent => tabs.any((tab) => !tab.isEmpty);
}

/// Measures how long the given tabs take to recite.
///
/// [hideHeaderLine] mirrors the viewer, which drops the first line of every tab
/// when it is being rendered as the tab's chip label.
ZikrReadingStats analyzeZikrReadingStats(
  List<String> tabContents, {
  bool hideHeaderLine = false,
}) {
  return ZikrReadingStats(
    tabs: tabContents
        .map((content) => _analyzeTab(content, hideHeaderLine: hideHeaderLine))
        .toList(),
  );
}

ZikrTabReadingStats _analyzeTab(
  String content, {
  required bool hideHeaderLine,
}) {
  final lines = content.split('\n');
  if (hideHeaderLine && lines.isNotEmpty) {
    lines.removeAt(0);
  }

  var arabicWords = 0;
  var latinWords = 0;
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final words = _countWords(line);
    if (words == 0) continue;

    if (ZikrContentParser.isArabic(line)) {
      arabicWords += words;
    } else {
      latinWords += words;
    }
  }

  return ZikrTabReadingStats(
    arabicWords: arabicWords,
    latinWords: latinWords,
  );
}

int _countWords(String line) {
  final text = ZikrContentParser.parseLineSegments(line)
      .map((segment) => segment.text)
      .join();
  return text
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .length;
}

/// Each content line's share of its tab's reading effort, on the same basis
/// as [ZikrTabReadingStats.minutes]: a tab with Arabic is weighted by its
/// Arabic words alone - transliteration, translation, headings and notes weigh
/// nothing - and a tab without any by all of its words.
///
/// [lines] are the tab's lines as the viewer lays them out
/// (`ParsedZikrContent.lines`), so indexes line up with list items.
List<double> zikrLineWeights(List<String> lines) {
  final words = <int>[];
  final arabic = <bool>[];
  var hasArabic = false;
  for (final rawLine in lines) {
    final line = rawLine.trim();
    final count = line.isEmpty ? 0 : _countWords(line);
    final isArabic = count > 0 && ZikrContentParser.isArabic(line);
    words.add(count);
    arabic.add(isArabic);
    hasArabic |= isArabic;
  }
  return [
    for (var i = 0; i < lines.length; i++)
      hasArabic && !arabic[i] ? 0.0 : words[i].toDouble(),
  ];
}

/// One list item as currently laid out: where it starts in the tab's scroll
/// coordinates and how tall it is.
class ZikrLaidOutItem {
  const ZikrLaidOutItem({
    required this.index,
    required this.top,
    required this.extent,
  });

  final int index;
  final double top;
  final double extent;
}

/// Share of a tab's *text* that lies above [line] - a height in the tab's
/// scroll coordinates - weighting each list item by [itemWeights] (see
/// [zikrLineWeights]) and splitting the item [line] falls inside by how far
/// into it the line is.
///
/// This is what progress is measured by rather than pixels: a lazily built
/// list only ever knows the heights of the items it has laid out, and guesses
/// the rest from their average, so `scrollOffset / maxScrollExtent` is only as
/// good as that guess. In paragraph view a whole dua can be one item sitting
/// between one-line headings, and the guess can be off by several screens -
/// reading "Completed" with most of the dua still to come, or jumping from
/// 30% to 80% as a paragraph gets built. Word counts are known for every
/// item, built or not, and the items around [line] are always built, since
/// [line] is on screen.
///
/// [laidOut] must be in index order. Null when nothing is weighted or laid
/// out, for the caller to fall back to pixels.
double? zikrContentFractionAbove({
  required List<double> itemWeights,
  required List<ZikrLaidOutItem> laidOut,
  required double line,
}) {
  if (laidOut.isEmpty) return null;
  final total = itemWeights.fold<double>(0, (sum, weight) => sum + weight);
  if (total <= 0) return null;

  double weightOf(int index) =>
      index >= 0 && index < itemWeights.length ? itemWeights[index] : 0;

  // Everything ahead of the built range has been scrolled past: the built
  // range always covers the view, and [line] is in it.
  var above = 0.0;
  for (var i = 0; i < laidOut.first.index; i++) {
    above += weightOf(i);
  }
  for (final item in laidOut) {
    final weight = weightOf(item.index);
    if (weight == 0) continue;
    final share = item.extent <= 0
        ? (line >= item.top ? 1.0 : 0.0)
        : ((line - item.top) / item.extent).clamp(0.0, 1.0).toDouble();
    above += weight * share;
  }
  return (above / total).clamp(0.0, 1.0).toDouble();
}

/// Where in the view reading progress is measured at this offset, in scroll
/// coordinates: the top of the view at the start, sliding to the bottom by
/// the end.
///
/// Measuring at the top alone would leave the last screenful unread when the
/// list cannot scroll any further, and measuring at the bottom would count
/// the first screenful read before the reader has started. Only where the
/// line sits in the view leans on the estimated scroll extent - by the end,
/// where it matters, the last item is built and the extent is exact.
double zikrReadingLine({
  required double scrollOffset,
  required double maxScrollExtent,
  required double viewportDimension,
}) {
  final viewport = viewportDimension.isFinite && viewportDimension > 0
      ? viewportDimension
      : 0.0;
  final t = zikrTabScrollFraction(
    scrollOffset: scrollOffset,
    maxScrollExtent: maxScrollExtent,
  );
  return scrollOffset + viewport * t;
}

/// Fraction of a single tab that has been scrolled past.
///
/// A tab that fits on screen has nothing left to scroll, so it counts as read.
double zikrTabScrollFraction({
  required double scrollOffset,
  required double maxScrollExtent,
}) {
  if (!maxScrollExtent.isFinite || maxScrollExtent <= 0) return 1;
  return (scrollOffset / maxScrollExtent).clamp(0.0, 1.0).toDouble();
}

/// Fraction of a tab's text that has been on screen at this offset - measured
/// to the *bottom* of the view, not the top.
///
/// That is the difference between "has the reader seen the closing lines" and
/// "has the reader scrolled the closing lines up to the top of the screen",
/// which nobody does: Ziyarat Ashura's sajdah passage is its last ~5%, and
/// whoever is reciting it is in sujood, not scrolling.
double zikrTabSeenFraction({
  required double scrollOffset,
  required double maxScrollExtent,
  required double viewportDimension,
}) {
  if (!maxScrollExtent.isFinite || maxScrollExtent <= 0) return 1;
  final viewport = viewportDimension.isFinite && viewportDimension > 0
      ? viewportDimension
      : 0;
  final total = maxScrollExtent + viewport;
  return ((scrollOffset + viewport) / total).clamp(0.0, 1.0).toDouble();
}

/// How much of a tab has to have been on screen for it to count as recited.
///
/// Short of 1 on purpose: zikrs close with notes, merits, references or a
/// passage recited in sajdah, and the reader who has reached those has
/// recited the zikr.
const double zikrCompletionSeenThreshold = 0.9;

/// Share of a tab's estimated recitation time that has to have passed since
/// the page opened. Keeps a fling to the bottom from counting, without
/// demanding a fast reciter keep to [_arabicWordsPerMinute].
const double zikrCompletionTimeShare = 0.4;

/// The floor on that time, for a dua short enough to fit on one screen.
const Duration zikrCompletionMinTime = Duration(seconds: 10);

/// How much longer the reader has to stay on a tab before it counts as
/// recited: [Duration.zero] if it already does, null if not enough of it has
/// been on screen yet.
///
/// Judged **per tab**. A multi-tab zikr is usually a set of alternatives
/// (forms of a ziyarah, one taqeeb per prayer) or independent steps, and
/// finishing the one being recited is a recitation - it must not wait on
/// tabs the reader never meant to open, nor on the whole compilation's
/// reading time. [elapsed] is the time spent on *this* tab, so time spent
/// reciting one tab does not let a fling through the next one count too.
Duration? zikrTabCompletionWait({
  required double seenFraction,
  required ZikrTabReadingStats? tab,
  required Duration elapsed,
}) {
  if (seenFraction < zikrCompletionSeenThreshold) return null;
  final tabSeconds = tab == null ? 0.0 : tab.minutes * 60;
  final requiredMs = (tabSeconds * zikrCompletionTimeShare * 1000).round();
  final required = Duration(
    milliseconds: requiredMs > zikrCompletionMinTime.inMilliseconds
        ? requiredMs
        : zikrCompletionMinTime.inMilliseconds,
  );
  final wait = required - elapsed;
  return wait.isNegative ? Duration.zero : wait;
}

/// Guards a tab's scroll fraction against transient dips.
///
/// `ListView.builder` estimates `maxScrollExtent` from the average size of the
/// children it has laid out so far, and revises that estimate as further,
/// differently-sized children get built while the reader keeps scrolling.
/// Because the on-screen percentage is `scrollOffset / maxScrollExtent`, a
/// revised (larger) estimate can make the fraction momentarily drop even
/// though the reader has only moved forward - so it reads as progress going
/// backwards. Holding the displayed fraction at its best-so-far value while
/// the reader keeps moving forward (or stands still) hides that noise; an
/// actual backward scroll - the offset itself decreasing - is the one case
/// let through, since that is the reader deliberately looking back up.
double zikrSmoothedTabFraction({
  required double rawFraction,
  required double scrollOffset,
  required double? previousScrollOffset,
  required double? previousDisplayedFraction,
}) {
  final scrolledBackward =
      previousScrollOffset != null && scrollOffset < previousScrollOffset;
  if (scrolledBackward || previousDisplayedFraction == null) {
    return rawFraction;
  }
  return rawFraction > previousDisplayedFraction
      ? rawFraction
      : previousDisplayedFraction;
}

/// Human readable duration such as `under 1 min`, `8 min` or `1 hr 5 min`.
String formatZikrDuration(Duration duration) {
  final totalMinutes = (duration.inSeconds / 60).round();
  final l10n = L10n.current;
  if (totalMinutes < 1) return l10n.durationUnderOneMinute;
  if (totalMinutes < 60) return l10n.durationMinutes(totalMinutes);

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final hourLabel = l10n.durationHours(hours);
  return minutes == 0
      ? hourLabel
      : l10n.durationHoursMinutes(hourLabel, minutes);
}

/// Label for the estimated time to recite the whole zikr.
String zikrReadingTimeLabel(Duration duration) =>
    L10n.current.zikrReadingTime(formatZikrDuration(duration));

/// Label for how far through the tab being read the reader is.
///
/// "Completed" is kept for [completed] - the tab counting as recited by
/// [zikrTabCompletionWait], the same rule the activity stats go by - rather
/// than for the end of the text merely being on screen, which a short dua
/// is the moment it opens and any tab is after a fling to the bottom.
String zikrProgressLabel(double progress, {bool completed = false}) {
  if (completed) return L10n.current.zikrProgressCompleted;
  final clamped = progress.clamp(0.0, 1.0).toDouble();
  return L10n.current.commonPercent((clamped * 100).floor());
}
