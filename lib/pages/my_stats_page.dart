import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/activity_stats.dart';
import '../services/activity_stats_store.dart';
import '../services/zikr_translations.dart';
import '../services/analytics_service.dart';
import '../services/community_stats_service.dart';
import '../services/recitation_tracker_manager.dart';
import '../widgets/responsive_content.dart';
import 'stats/quran_progress_section.dart';
import 'stats/stats_charts.dart';
import 'stats/stats_widgets.dart';
import 'zikr/zikr_page.dart';
import '../l10n/l10n.dart';

/// The one stats screen: streak and week, history, most recited zikrs,
/// and Quran progress per recitation track, with the anonymous community
/// summary at the end.
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
      appBar: AppBar(title: Text(context.l10n.statsTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          ActivityStatsStore.instance,
          RecitationTrackerManager.instance,
        ]),
        builder: (context, _) {
          final summary = ActivityStatsStore.instance.summary();
          final recitation = RecitationTrackerManager.instance.state;
          return ResponsiveScrollableContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StreakCard(summary: summary),
                const SizedBox(height: 18),
                StatsHistoryCard(summary: summary),
                const SizedBox(height: 18),
                if (summary.zikrCounts.isNotEmpty) ...[
                  StatsCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatsSectionTitle(context.l10n.statsYourMostRecited),
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
                  const SizedBox(height: 18),
                ],
                const SizedBox(height: 4),
                QuranProgressSection(state: recitation),
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
    if (title is String && title.trim().isNotEmpty) {
      return zikrDisplayTitle(uid, title);
    }
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
  const _StreakCard({required this.summary});

  final ActivitySummary summary;

  /// Deliberately gentle: a missed day is a fresh start, not a failure.
  String get _message {
    if (summary.isEmpty) {
      return L10n.current.statsStreakStart;
    }
    final streak = summary.currentStreak;
    if (streak == 0) return L10n.current.statsWelcomeBack;
    if (summary.isActiveToday) {
      return streak == 1
          ? L10n.current.statsDoneTodayFirst
          : L10n.current.statsDoneToday;
    }
    return L10n.current.statsReadToday;
  }

  /// Streak lengths worth aiming for - close together early, so a new
  /// reader always has a goal within reach.
  static const List<int> _streakGoals = [3, 7, 14, 30, 40, 100, 365];

  /// The next streak length to aim for from the current streak.
  int? get _nextStreakGoal {
    final current = summary.currentStreak;
    for (final target in _streakGoals) {
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
                            context.l10n.statsDayStreak,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: onCard),
                          ),
                        ),
                      ],
                    ),
                    Text(
                                          context.l10n.statsBestStreak(summary.longestStreak),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: onCard.withValues(alpha: 0.76)),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: doneToday
                    ? context.l10n.statsTodayDone
                    : context.l10n.statsTodayNotYet,
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
                      context.l10n.statsToday,
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
                    context.l10n.statsDaysToGoal(goal - streak, goal),
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
              label: day == days.last ? context.l10n.statsToday : DateFormat('EEE').format(day),
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
      label: done
          ? context.l10n.statsDayRead(label)
          : context.l10n.statsDayNotRead(label),
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
          ? context.l10n.statsPrivateSynced
          : context.l10n.statsPrivateLocal,
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
    if (age.inMinutes < 60) return L10n.current.statsUpdatedWithinHour;
    if (age.inHours < 24) {
      return L10n.current.statsUpdatedHoursAgo(age.inHours);
    }
    return L10n.current
        .statsUpdatedOn(DateFormat('MMM d').format(stats.updatedAt));
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
            Expanded(child: StatsSectionTitle(context.l10n.statsAcrossCommunity)),
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
                context.l10n.statsRecitedThisWeek,
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
                  context.l10n.statsAllTime(format.format(stats.allTimeRecitations)),
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
          StatsSectionTitle(context.l10n.statsMostRecitedThisWeek),
          const SizedBox(height: 4),
          ...topTiles,
        ],
        const SizedBox(height: 8),
        Text(
          context.l10n.statsCommunityNote(_updatedAgo()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
