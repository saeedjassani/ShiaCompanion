import 'dart:math' as math;

import 'quran_index.dart';

/// Lets verses count as read no faster than they could have been recited.
///
/// The Quran reader reports what is on screen: every verse from the top of
/// the view to the last one wholly shown, and the rest of the surah once the
/// end is reached. Crediting that straight away let a flick count as reading
/// - and in Arabic-only paragraph view, where a whole short surah is one
/// screen of text, opening a surah and nudging it marked it Completed, with
/// the Khatm, streak and stats to match.
///
/// So what is seen only queues up here. It is paid for in words, out of a
/// budget that grows with time on the page at [wordsPerSecond], and leaves in
/// the order it was seen. The budget never holds more than [maxBankedTime]'s
/// worth, so time spent with the page open but idle cannot be cashed in by a
/// fling later.
///
/// Set generously, so that no real reader - however fast - loses a verse:
/// the pace is far beyond any recitation, and the bank holds more words than
/// any screen shows, so a screen read slowly before the first scroll still
/// counts in full. Only a scroll faster than reading, or closing the page
/// before the text on it could have been read, is held back.
class RecitationPacer {
  RecitationPacer({
    required this.start,
    required this.wordsPerSecond,
    required this.wordsOf,
    this.maxBankedTime = const Duration(minutes: 1),
  }) : _budgetAt = start;

  /// When reading began - the page opening.
  final DateTime start;

  /// The fastest believable recitation, in Arabic words a second.
  final double wordsPerSecond;

  /// How many Arabic words a verse has.
  final int Function(VerseKey verse) wordsOf;

  /// The most unspent reading time the budget keeps.
  final Duration maxBankedTime;

  final List<VerseKey> _queue = [];
  final Set<VerseKey> _seen = {};
  final Map<int, int> _firstSeenAyah = {};
  double _budget = 0;
  DateTime _budgetAt;

  double get _maxBudget =>
      wordsPerSecond * maxBankedTime.inMilliseconds / 1000;

  /// Whether anything has been reported as seen yet.
  bool get hasSeen => _seen.isNotEmpty;

  /// Whether anything is still waiting to count.
  bool get hasPending => _queue.isNotEmpty;

  /// The lowest ayah of [surah] seen this visit, if any.
  int? firstSeenAyah(int surah) => _firstSeenAyah[surah];

  /// Queues [verses], in reading order, leaving out any seen before.
  void see(Iterable<VerseKey> verses) {
    for (final verse in verses) {
      final ayah = verse.ayah;
      if (ayah == null || !_seen.add(verse)) continue;
      _queue.add(verse);
      final first = _firstSeenAyah[verse.surah];
      if (first == null || ayah < first) _firstSeenAyah[verse.surah] = ayah;
    }
  }

  void _accrue(DateTime now) {
    if (!now.isAfter(_budgetAt)) return;
    final seconds = now.difference(_budgetAt).inMicroseconds / 1e6;
    _budgetAt = now;
    // While verses wait, the budget goes to them as fast as it grows, so the
    // cap only bites on time nothing was waiting for - except where one
    // verse alone costs more than the cap, which must still be reachable.
    final cap = _queue.isEmpty
        ? _maxBudget
        : math.max(_maxBudget, _costOf(_queue.first));
    _budget = math.min(cap, _budget + seconds * wordsPerSecond);
  }

  double _costOf(VerseKey verse) => math.max(1, wordsOf(verse)).toDouble();

  /// The queued verses that count by [now], oldest first.
  List<VerseKey> release(DateTime now) {
    _accrue(now);
    final released = <VerseKey>[];
    while (_queue.isNotEmpty && _budget >= _costOf(_queue.first)) {
      _budget -= _costOf(_queue.first);
      released.add(_queue.removeAt(0));
    }
    return released;
  }

  /// How long from [now] until the next queued verse can count, or null
  /// with nothing queued.
  Duration? untilNext(DateTime now) {
    if (_queue.isEmpty) return null;
    _accrue(now);
    final short = _costOf(_queue.first) - _budget;
    return short <= 0
        ? Duration.zero
        : Duration(microseconds: (short / wordsPerSecond * 1e6).ceil());
  }
}
