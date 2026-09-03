import 'zikr_content_parser.dart';

/// Words an average reciter covers per minute of Arabic supplication text.
///
/// Deliberately Arabic-only - [ZikrTabReadingStats.minutes] drops the
/// transliteration and translation entirely once a tab has Arabic, so this
/// constant is not diluted by them either. It was originally 45, which reads
/// as if the reciter were also working through the other two lines word by
/// word: at 45wpm, Ziyaarat-e-Ashoora's 734 Arabic words come out to 16
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

  /// Share of the whole zikr each tab represents, so progress across tabs
  /// tracks content rather than tab count. Falls back to equal weights when
  /// nothing can be measured.
  List<double> get tabWeights {
    if (tabs.isEmpty) return const [];

    final total = totalMinutes;
    if (total <= 0) {
      return List<double>.filled(tabs.length, 1 / tabs.length);
    }
    return tabs.map((tab) => tab.minutes / total).toList();
  }
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

/// Overall progress through a zikr, weighting each tab by its reading time.
double zikrReadingProgress({
  required List<double> tabWeights,
  required int tabIndex,
  required double tabFraction,
}) {
  if (tabWeights.isEmpty) return 0;

  final index = tabIndex.clamp(0, tabWeights.length - 1);
  final fraction = tabFraction.clamp(0.0, 1.0).toDouble();

  var completed = 0.0;
  for (var i = 0; i < index; i++) {
    completed += tabWeights[i];
  }
  completed += tabWeights[index] * fraction;

  final total = tabWeights.fold<double>(0, (sum, weight) => sum + weight);
  if (total <= 0) return 0;

  return (completed / total).clamp(0.0, 1.0).toDouble();
}

/// Human readable duration such as `under 1 min`, `8 min` or `1 hr 5 min`.
String formatZikrDuration(Duration duration) {
  final totalMinutes = (duration.inSeconds / 60).round();
  if (totalMinutes < 1) return 'under 1 min';
  if (totalMinutes < 60) return '$totalMinutes min';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final hourLabel = hours == 1 ? '1 hr' : '$hours hrs';
  return minutes == 0 ? hourLabel : '$hourLabel $minutes min';
}

/// Label for the estimated time to recite the whole zikr.
String zikrReadingTimeLabel(Duration duration) =>
    '${formatZikrDuration(duration)} read';

/// Label for how far through the zikr the reader is.
String zikrProgressLabel(double progress) {
  final clamped = progress.clamp(0.0, 1.0).toDouble();
  if (clamped >= 0.995) return 'Completed';
  return '${(clamped * 100).floor()}%';
}
