import 'package:flutter/foundation.dart';

import 'activity_stats.dart';
import 'recitation_tracker_state.dart';

/// What a milestone counts.
enum MilestoneKind { streak, verses, zikrs, juz, khatm }

/// One step on a ladder of goals - a 7-day streak, 1,000 verses - with how
/// far along the reader is, so the stats screen can show the next one to aim
/// for rather than only what is already behind them.
@immutable
class Milestone {
  const Milestone({
    required this.kind,
    required this.target,
    required this.current,
  });

  final MilestoneKind kind;
  final int target;
  final int current;

  bool get isEarned => current >= target;

  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0.0, 1.0).toDouble();

  int get remaining => isEarned ? 0 : target - current;
}

/// The ladders, smallest goal first. Early rungs are close together so a new
/// reader earns something in their first days; later ones are spaced out so
/// there is always a next goal worth reaching.
const Map<MilestoneKind, List<int>> milestoneLadders = {
  MilestoneKind.streak: [3, 7, 14, 30, 40, 100, 365],
  MilestoneKind.verses: [100, 500, 1000, 3000, 6236, 12472, 31180],
  MilestoneKind.zikrs: [10, 40, 100, 313, 500, 1000],
  MilestoneKind.juz: [1, 5, 10, 15, 30],
  MilestoneKind.khatm: [1, 2, 3, 5, 10],
};

/// Every milestone on every ladder, measured against the reader's stats.
///
/// Streaks count the longest one ever reached, so a broken streak does not
/// take back a badge already earned. Juz counts the best single recitation
/// track, since coverage is per track, and khatms count the tracks that have
/// covered the whole Quran.
List<Milestone> computeMilestones(
  ActivitySummary summary,
  RecitationTrackerState recitation,
) {
  var bestJuz = 0;
  var khatms = 0;
  for (final label in [...recitation.labels, unlabeledRecitationLabel]) {
    final juz = recitation.completedJuzCountFor(label);
    if (juz > bestJuz) bestJuz = juz;
    if (juz >= 30) khatms++;
  }

  final current = <MilestoneKind, int>{
    MilestoneKind.streak: summary.longestStreak,
    MilestoneKind.verses: summary.quranVersesTotal,
    MilestoneKind.zikrs: summary.totalZikrs,
    MilestoneKind.juz: bestJuz,
    MilestoneKind.khatm: khatms,
  };

  return [
    for (final ladder in milestoneLadders.entries)
      for (final target in ladder.value)
        Milestone(
          kind: ladder.key,
          target: target,
          current: current[ladder.key] ?? 0,
        ),
  ];
}

/// The first unearned rung of each ladder, closest to done first - "what to
/// aim for next".
List<Milestone> nextMilestones(List<Milestone> all) {
  final next = <MilestoneKind, Milestone>{};
  for (final milestone in all) {
    if (milestone.isEarned) continue;
    next.putIfAbsent(milestone.kind, () => milestone);
  }
  return next.values.toList()..sort((a, b) => b.progress.compareTo(a.progress));
}
