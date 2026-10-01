import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/activity_stats.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/models/stats_milestones.dart';

void main() {
  final now = DateTime(2026, 10, 1, 12);

  ActivitySummary summaryWith({
    Map<String, DayActivity> days = const {},
    int verses = 0,
  }) {
    return ActivitySummary(
      devices: [DeviceActivity(days: days)],
      quranVersesTotal: verses,
      now: now,
    );
  }

  test('a new reader has earned nothing and is shown the first rungs', () {
    final all = computeMilestones(summaryWith(), RecitationTrackerState.empty);

    expect(all.where((m) => m.isEarned), isEmpty);
    final next = nextMilestones(all);
    expect(next.map((m) => m.kind).toSet(), MilestoneKind.values.toSet());
    expect(
      next.firstWhere((m) => m.kind == MilestoneKind.streak).target,
      3,
    );
  });

  test('earned rungs count, and the next goal is the first unearned one', () {
    final summary = summaryWith(
      days: {
        for (var i = 0; i < 8; i++)
          activityDayKey(DateTime(2026, 10, 1 - i)):
              const DayActivity(zikrs: 2),
      },
      verses: 650,
    );
    final all = computeMilestones(summary, RecitationTrackerState.empty);

    final earned = all.where((m) => m.isEarned).toList();
    expect(
      earned.map((m) => (m.kind, m.target)),
      containsAll([
        (MilestoneKind.streak, 3),
        (MilestoneKind.streak, 7),
        (MilestoneKind.verses, 100),
        (MilestoneKind.verses, 500),
        (MilestoneKind.zikrs, 10),
      ]),
    );

    final next = {for (final m in nextMilestones(all)) m.kind: m};
    expect(next[MilestoneKind.streak]!.target, 14);
    expect(next[MilestoneKind.streak]!.remaining, 6);
    expect(next[MilestoneKind.verses]!.target, 1000);
    expect(next[MilestoneKind.verses]!.progress, closeTo(0.65, 1e-9));
  });

  test('next goals are ordered closest to done first', () {
    final summary = summaryWith(verses: 950);
    final next = nextMilestones(
      computeMilestones(summary, RecitationTrackerState.empty),
    );
    expect(next.first.kind, MilestoneKind.verses);
  });
}
