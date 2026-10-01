import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/activity_stats.dart';
import '../models/stats_milestones.dart';
import '../services/activity_stats_store.dart';
import '../services/analytics_service.dart';
import '../services/community_stats_service.dart';
import '../services/recitation_tracker_manager.dart';
import '../widgets/responsive_content.dart';
import 'stats/milestones_section.dart';
import 'stats/quran_progress_section.dart';
import 'stats/stats_charts.dart';
import 'stats/stats_widgets.dart';
import 'zikr/zikr_page.dart';

/// The one stats screen: streak and week, history and consistency, Quran
/// progress per recitation track, milestones, most recited zikrs, and the
/// anonymous community summary at the end.
///
/// Everything personal is private to the reader (and their account, when
/// signed in) - there is deliberately no leaderboard or public profile.
class MyStatsPage extends StatefulWidget {
  const MyStatsPage({super.key});

  @override
  State<MyStatsPage> createState() => _MyStatsPageState();
}

class _MyStatsPageState extends State<MyStatsPage> {
  static final NumberFormat _count = NumberFormat.decimalPattern();

  CommunityStats? _community;

  @override
  void initState() {
    super.initState();
    trackScreen('My Stats Page');
    unawaited(RecitationTrackerManager.instance.loadRecitations());
    _community = CommunityStatsService.instance.cached;
    unawaited(_loadCommunity());
  }

  Future<void> _loadCommunity() async {
    final stats = await CommunityStatsService.instance.load();
    if (!mounted || stats == null) return;
    setState(() => _community = stats);
  }

  bool get _isSignedIn =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          ActivityStatsStore.instance,
          RecitationTrackerManager.instance,
        ]),
        builder: (context, _) {
          final summary = ActivityStatsStore.instance.summary();
          final recitation = RecitationTrackerManager.instance.state;
          final milestones = computeMilestones(summary, recitation);
          return ResponsiveScrollableContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StreakCard(summary: summary, milestones: milestones),
                const SizedBox(height: 12),
                StatsPair(
                  left: StatTile(
                    icon: Icons.menu_book_rounded,
                    value: _count.format(summary.quranVersesTotal),
                    label: 'Verses recited',
                  ),
                  right: StatTile(
                    icon: Icons.auto_awesome_rounded,
                    value: _count.format(summary.totalZikrs),
                    label: 'Duas & ziyarats read',
                  ),
                ),
                const SizedBox(height: 10),
                StatsPair(
                  left: StatTile(
                    icon: Icons.event_available_rounded,
                    value: _count.format(summary.activeDayCount),
                    label: summary.activeDayCount == 1
                        ? 'Active day'
                        : 'Active days',
                  ),
                  right: StatTile(
                    icon: Icons.restore_rounded,
                    value: _count.format(summary.totalQaza),
                    label: 'Qaza made up',
                  ),
                ),
                const SizedBox(height: 18),
                StatsHistoryCard(summary: summary, recitation: recitation),
                const SizedBox(height: 18),
                ConsistencyHeatmap(summary: summary),
                const SizedBox(height: 22),
                QuranProgressSection(state: recitation),
                const SizedBox(height: 18),
                MilestonesSection(milestones: milestones),
                if (summary.zikrCounts.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  StatsCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatsSectionTitle('Your most recited'),
                        ..._topZikrTiles(
                          context,
                          [
                            for (final entry in summary.topZikrs(5))
                              (entry.key, _titleFor(entry.key), entry.value),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _PrivacyNote(isSignedIn: _isSignedIn),
                if (_community != null) ...[
                  const SizedBox(height: 26),
                  const Divider(),
                  const SizedBox(height: 14),
                  _CommunitySection(
                    stats: _community!,
                    format: _count,
                    topTiles: _topZikrTiles(
                      context,
                      [
                        for (final zikr in _community!.top)
                          (
                            zikr.uid,
                            _titleFor(zikr.uid, zikr.title),
                            zikr.recitations
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _titleFor(String uid, [String? fallback]) {
    final title = items[uid];
    if (title is String && title.trim().isNotEmpty) return title;
    return fallback ?? uid;
  }

  List<Widget> _topZikrTiles(
    BuildContext context,
    List<(String, String, int)> entries,
  ) {
    final theme = Theme.of(context);
    return [
      for (final (uid, title, count) in entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            '${_count.format(count)}×',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => pushPageRoute(
            context,
            ZikrPage(UidTitleData(uid, title), source: ZikrOpenSource.myStats),
          ),
        ),
    ];
  }
}

/// Streak, today, the week and the next streak goal - the top of the screen
/// is about today's habit, the rest is the longer view.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary, required this.milestones});

  final ActivitySummary summary;
  final List<Milestone> milestones;

  /// Deliberately gentle: a missed day is a fresh start, not a failure.
  String get _message {
    if (summary.isEmpty) {
      return 'Finish reading a dua, ziyarat or surah and your streak begins.';
    }
    final streak = summary.currentStreak;
    if (streak == 0) return 'Welcome back - every day is a fresh start.';
    if (summary.isActiveToday) {
      return streak == 1
          ? 'Done for today. Come back tomorrow to start a streak.'
          : 'Done for today - see you tomorrow, in sha Allah.';
    }
    return 'Read something today to keep it going.';
  }

  /// The next streak length to aim for, counted from the *current* streak
  /// (the milestone ladder counts the longest, so a badge is never lost).
  int? get _nextStreakGoal {
    final current = summary.currentStreak;
    for (final target in milestoneLadders[MilestoneKind.streak]!) {
      if (target > current) return target;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onCard = colorScheme.onPrimaryContainer;
    final streak = summary.currentStreak;
    final goal = _nextStreakGoal;
    final doneToday = summary.isActiveToday;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: streak > 0
                      ? colorScheme.primary
                      : onCard.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 28,
                  color: streak > 0 ? colorScheme.onPrimary : onCard,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$streak',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: onCard,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'day streak',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: onCard),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Best: ${summary.longestStreak} '
                      '${summary.longestStreak == 1 ? 'day' : 'days'}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: onCard.withValues(alpha: 0.76)),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: doneToday ? 'Today: done' : 'Today: not yet',
                excludeSemantics: true,
                child: Column(
                  children: [
                    ProgressRing(
                      value: doneToday ? 1 : 0,
                      size: 44,
                      strokeWidth: 5,
                      trackColor: onCard.withValues(alpha: 0.15),
                      center: Icon(
                        doneToday ? Icons.check_rounded : Icons.remove_rounded,
                        color: doneToday
                            ? colorScheme.primary
                            : onCard.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onCard,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _message,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: onCard.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 14),
          _WeekRow(summary: summary),
          if (goal != null && streak > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${goal - streak} more ${goal - streak == 1 ? 'day' : 'days'} '
                    'to a $goal-day streak',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onCard,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$streak/$goal',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: onCard.withValues(alpha: 0.76)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: math.min(1, streak / goal),
                minHeight: 7,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The last seven days as a row of circles, ticked on the days something was
/// read - the habit-tracker row most people already know from other apps,
/// needing no legend or explanation. Today is the last circle.
class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
    ];

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: _DayCircle(
              label: day == days.last ? 'Today' : DateFormat('EEE').format(day),
              done: summary.isActiveOn(day),
              isToday: day == days.last,
              colorScheme: colorScheme,
              textTheme: theme.textTheme,
            ),
          ),
      ],
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.label,
    required this.done,
    required this.isToday,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final bool done;
  final bool isToday;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final onCard = colorScheme.onPrimaryContainer;
    return Semantics(
      label: '$label: ${done ? 'read' : 'not read'}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? colorScheme.primary
                  : colorScheme.surface.withValues(alpha: 0.55),
              border: isToday && !done
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: done
                ? Icon(Icons.check_rounded,
                    size: 20, color: colorScheme.onPrimary)
                : null,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: textTheme.labelSmall?.copyWith(
                color: onCard,
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.isSignedIn});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      isSignedIn
          ? 'Your stats are private and sync across devices signed in to '
              'your account.'
          : 'Your stats are private and kept on this device. Sign in from '
              'Preferences to keep them across devices.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({
    required this.stats,
    required this.format,
    required this.topTiles,
  });

  final CommunityStats stats;
  final NumberFormat format;
  final List<Widget> topTiles;

  String _updatedAgo() {
    final age = DateTime.now().difference(stats.updatedAt);
    if (age.inMinutes < 60) return 'Updated within the hour';
    if (age.inHours < 24) {
      return 'Updated ${age.inHours} hour${age.inHours == 1 ? '' : 's'} ago';
    }
    return 'Updated ${DateFormat('MMM d').format(stats.updatedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxDay = stats.days.fold<int>(
      0,
      (max, day) => math.max(max, day.recitations),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: StatsSectionTitle('Across the community')),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                format.format(stats.weekRecitations),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                'duas, ziyarats and surahs recited this week',
                style: theme.textTheme.bodyMedium,
              ),
              if (stats.days.isNotEmpty && maxDay > 0) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in stats.days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The bar area is fixed; the day letter below it
                              // takes whatever height the text scale needs.
                              SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Tooltip(
                                    message:
                                        '${DateFormat('EEE, MMM d').format(day.day)}'
                                        ' - ${format.format(day.recitations)}',
                                    child: Container(
                                      height: math.max(
                                        3,
                                        40 * day.recitations / maxDay,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('E').format(day.day).substring(0, 1),
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (stats.allTimeRecitations > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${format.format(stats.allTimeRecitations)} all time',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (topTiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          StatsSectionTitle('Most recited this week'),
          const SizedBox(height: 4),
          ...topTiles,
        ],
        const SizedBox(height: 8),
        Text(
          'Anonymous totals from everyone using the app. ${_updatedAgo()}.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
