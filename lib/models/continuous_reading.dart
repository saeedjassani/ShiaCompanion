import 'package:flutter/foundation.dart';

import '../utils/quran_index.dart';
import 'activity_stats.dart';
import 'recitation_tracker_state.dart';

/// Whether someone has been reading the Quran straight through under a
/// track - in practice, under the everyday reading that was "My reading"
/// before Khatms had to be started (see [findContinuousReading]).
///
/// Before then, the everyday reading's card was the Quran screen's main way
/// back in, and many people read a whole khatm through it. That reading now
/// moves into a Khatm of its own ([planMyReadingPort]), so they keep their
/// place - but only for those who were reading through, not for someone who
/// reads Ya-Sin every Thursday and al-Kahf every Friday, whatever their share
/// of the Quran adds up to.
@immutable
class ContinuousReading {
  const ContinuousReading({
    required this.start,
    required this.end,
    required this.resumeAt,
    required this.readInJuz,
    required this.ranges,
    required this.continuations,
    required this.days,
  });

  /// The first and last verse read in order.
  final VerseKey start;
  final VerseKey end;

  /// The verse after [end]: where the reading carries on.
  final VerseKey resumeAt;

  /// Whether it was mostly read a juz at a time.
  final bool readInJuz;

  /// [start] to [end], by surah, as [RecitationTrackerState.coverage] keeps
  /// it.
  final Map<int, List<(int, int)>> ranges;

  /// How many times the reader picked up where they had left off.
  final int continuations;

  /// On how many days.
  final int days;
}

/// Picked up where they left off at least this many times...
///
/// Kept low on purpose. A reader who was reading a khatm through the old
/// "My reading" card and is not recognised here loses their place: nothing
/// else points to where they got to. One recognised wrongly only gets a
/// Khatm they can Undo (or delete), so the bar leans towards making one.
const int continuousReadingMinContinuations = 1;

/// ...and, picked up only once, either inside one surah and longer than
/// [continuousReadingLongStretch] verses (al-Baqarah's first 150), or
/// running into another surah with a sitting that stopped mid-surah
/// (al-Fatihah, then al-Baqarah 1-20). Picked up this many times, it
/// qualifies whatever it covers.
///
/// What is left out: Ya-Sin or al-Kahf, weekly favourites, read in two
/// sittings, and ar-Rahman then al-Waqiah, a pair often read together -
/// each whole in a sitting of its own.
const int continuousReadingManyContinuations = 2;

/// Verses read in order inside one surah that are more than a weekly
/// favourite - al-Kahf, the longest of them, has 110.
const int continuousReadingLongStretch = 120;

/// A session may start this many verses past where the last one stopped and
/// still carry on from it: the reader logs the verses on screen, so where a
/// session is said to stop can fall a verse or two short of the last one
/// read.
const int continuousReadingGap = 2;

/// Where each surah starts in the Quran read straight through: verse 1 of
/// surah n is index `_surahOffsets[n - 1] + 1`.
final List<int> _surahOffsets = () {
  final offsets = <int>[];
  var total = 0;
  for (final count in surahAyahCounts) {
    offsets.add(total);
    total += count;
  }
  return offsets;
}();

int _indexOf(int surah, int ayah) => _surahOffsets[surah - 1] + ayah;

VerseKey _verseAt(int index) {
  var surah = surahAyahCounts.length;
  while (surah > 1 && _surahOffsets[surah - 1] >= index) {
    surah--;
  }
  return VerseKey(surah, index - _surahOffsets[surah - 1]);
}

/// One stretch read in order, as [findContinuousReading] follows it.
class _Chain {
  _Chain(this.start, this.frontier, String day, this.last, bool? inJuz) {
    days.add(day);
    _vote(inJuz);
    _noteSitting(start, frontier);
  }

  int start;

  /// The last verse read in order so far.
  int frontier;
  int continuations = 0;
  final Set<String> days = {};
  DateTime last;
  int _juzVotes = 0;
  int _surahVotes = 0;

  bool get readInJuz => _juzVotes > _surahVotes;

  void _vote(bool? inJuz) {
    if (inJuz == null) return;
    if (inJuz) {
      _juzVotes++;
    } else {
      _surahVotes++;
    }
  }

  void extend(int from, int to, String day, DateTime at, bool? inJuz) {
    _noteSitting(from, to);
    if (from < start) start = from;
    frontier = to;
    continuations++;
    days.add(day);
    last = at;
    _vote(inJuz);
  }

  bool covers(int from, int to) => start <= from && to <= frontier;

  /// Whether this reads as a khatm under way rather than one or two
  /// favourite surahs read in a couple of sittings - see
  /// [continuousReadingMinContinuations].
  bool get qualifies {
    if (continuations < continuousReadingMinContinuations) return false;
    if (continuations >= continuousReadingManyContinuations) return true;
    final first = _verseAt(start);
    final last = _verseAt(frontier);
    if (first.surah == last.surah) {
      return frontier - start + 1 > continuousReadingLongStretch;
    }
    return _stoppedMidSurah;
  }

  /// Whether a sitting of this stretch began or ended part-way through a
  /// surah.
  bool _stoppedMidSurah = false;

  void _noteSitting(int from, int to) {
    final a = _verseAt(from);
    final b = _verseAt(to);
    if (a.ayah != 1 || b.ayah != surahAyahCounts[b.surah - 1]) {
      _stoppedMidSurah = true;
    }
  }
}

/// One verse range read, in the order [findContinuousReading] walks them.
typedef _Read = ({DateTime at, String day, int from, int to, bool? inJuz});

/// The reading [label] has been doing straight through the Quran, or null
/// if it has not.
///
/// Walks every range read under [label] in the order it was read - each
/// session of the last [recitationSessionRetentionDays] days, and before
/// that each day's ranges, kept for [recitationDayRangesRetentionDays] -
/// following each stretch read in order. A range that starts where a
/// stretch stopped (or within [continuousReadingGap] verses of it) carries
/// it on; one inside a stretch is a re-read and changes nothing; anything
/// else - Ya-Sin on a Thursday - starts a stretch of its own, and leaves
/// the others where they were.
///
/// The latest stretch to qualify wins: one picked up again at least
/// [continuousReadingMinContinuations] times that is more than a favourite
/// surah or two read in a couple of sittings (see
/// [continuousReadingManyContinuations]). A stretch that
/// reached the end of an-Nas is a finished khatm, with no place left to
/// keep, so it gives null.
ContinuousReading? findContinuousReading(
  RecitationTrackerState state, {
  String label = unlabeledRecitationLabel,
}) {
  final reads = <_Read>[];
  for (final entry in state.entries.values) {
    if (entry.label != label) continue;
    final at = entry.recitedAt.toLocal();
    reads.add((
      at: at,
      day: activityDayKey(at),
      from: _indexOf(entry.surah, entry.fromAyah),
      to: _indexOf(entry.surah, entry.toAyah),
      inJuz: entry.readInJuz,
    ));
  }
  state.archive.forEach((day, byLabel) {
    final date = parseActivityDay(day);
    final summary = byLabel[label];
    if (date == null || summary == null) return;
    summary.ranges.forEach((surah, ranges) {
      if (surah < 1 || surah > surahAyahCounts.length) return;
      for (final (from, to) in ranges) {
        reads.add((
          at: date,
          day: day,
          from: _indexOf(surah, from),
          to: _indexOf(surah, to),
          inJuz: null,
        ));
      }
    });
  });
  // In time, and a day's ranges (which keep no time of their own) in
  // mushaf order - the order someone reading through reads them.
  reads.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.from.compareTo(b.from);
  });

  final chains = <_Chain>[];
  for (final read in reads) {
    _Chain? carried;
    for (final chain in chains) {
      final carriesOn =
          read.from <= chain.frontier + 1 + continuousReadingGap &&
          read.to > chain.frontier;
      if (!carriesOn) continue;
      if (carried == null ||
          chain.frontier - chain.start > carried.frontier - carried.start) {
        carried = chain;
      }
    }
    if (carried != null) {
      carried.extend(read.from, read.to, read.day, read.at, read.inJuz);
    } else if (!chains.any((chain) => chain.covers(read.from, read.to))) {
      chains.add(_Chain(read.from, read.to, read.day, read.at, read.inJuz));
    }
  }

  _Chain? latest;
  for (final chain in chains) {
    if (chain.qualifies &&
        (latest == null || chain.last.isAfter(latest.last))) {
      latest = chain;
    }
  }
  if (latest == null || latest.frontier >= quranTotalAyahCount) return null;

  final ranges = <int, List<(int, int)>>{};
  final start = _verseAt(latest.start);
  final end = _verseAt(latest.frontier);
  for (var surah = start.surah; surah <= end.surah; surah++) {
    final from = surah == start.surah ? start.ayah! : 1;
    final to = surah == end.surah ? end.ayah! : surahAyahCounts[surah - 1];
    ranges[surah] = [(from, to)];
  }
  return ContinuousReading(
    start: start,
    end: end,
    resumeAt: _verseAt(latest.frontier + 1),
    readInJuz: latest.readInJuz,
    ranges: ranges,
    continuations: latest.continuations,
    days: latest.days.length,
  );
}

/// The everyday reading to move into a Khatm called [name], or null when
/// there is none to move: it was not read straight through, [name] is
/// already a Khatm (moved by another device, or made by hand), or a Khatm
/// already holds the same reading.
ContinuousReading? planMyReadingPort(
  RecitationTrackerState state,
  String name,
) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (state.customLabels.any((label) => label.toLowerCase() == lower)) {
    return null;
  }
  final reading = findContinuousReading(state);
  if (reading == null) return null;
  for (final label in state.customLabels) {
    if (state.trackIncludes(label, reading.start) &&
        state.trackIncludes(label, reading.end)) {
      return null;
    }
  }
  return reading;
}
