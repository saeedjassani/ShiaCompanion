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
import '../services/analytics_service.dart';
import '../services/community_stats_service.dart';
import '../services/recitation_tracker_manager.dart';
import '../widgets/responsive_content.dart';
import 'zikr/zikr_page.dart';

/// Personal stats and streak, with the anonymous community summary under it.
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
          return ResponsiveScrollableContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StreakCard(summary: summary, format: _count),
                const SizedBox(height: 18),
                _SectionTitle('This week'),
                const SizedBox(height: 10),
                _WeekRow(summary: summary),
                const SizedBox(height: 12),
                _MonthSentence(summary: summary),
                if (summary.zikrCounts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _SectionTitle('Your most recited'),
                  const SizedBox(height: 4),
                  ..._topZikrTiles(
                    context,
                    [
                      for (final entry in summary.topZikrs(5))
                        (entry.key, _titleFor(entry.key), entry.value),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary, required this.format});

  final ActivitySummary summary;
  final NumberFormat format;

  /// Deliberately gentle: a missed day is a fresh start, not a failure.
  String get _message {
    if (summary.isEmpty) {
      return 'Finish reading a dua, ziyarat or surah and your streak begins.';
    }
    final streak = summary.currentStreak;
    if (streak == 0) return 'Welcome back - every day is a fresh start.';
    if (summary.isActiveToday) return 'Today is counted. May Allah accept it.';
    return 'Read something today to keep it going.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final streak = summary.currentStreak;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current streak',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.76),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$streak',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          streak == 1 ? 'day' : 'days',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          _ChipRow(
            children: [
              _StatChip(
                label: 'Longest streak',
                value: summary.longestStreak == 1
                    ? '1 day'
                    : '${summary.longestStreak} days',
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Days active',
                value: format.format(summary.activeDayCount),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipRow(
            children: [
              _StatChip(
                label: 'Zikrs read',
                value: format.format(summary.totalZikrs),
              ),
              const SizedBox(width: 8),
              // Recitation is only logged from the Quran screen, which is
              // still dark-launched to admins; the chip appears on its own
              // once there is something to show.
              if (summary.quranVersesTotal > 0) ...[
                _StatChip(
                  label: 'Quran verses',
                  value: format.format(summary.quranVersesTotal),
                ),
                const SizedBox(width: 8),
              ],
              _StatChip(
                label: 'Qaza made up',
                value: format.format(summary.totalQaza),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row of [_StatChip]s kept the same height, so a label that wraps at a
/// large text size does not leave its neighbour looking shorter.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.76),
              ),
            ),
          ],
        ),
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
    return Semantics(
      label: '$label: ${done ? 'read' : 'not read'}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.06),
              border: isToday && !done
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: done
                ? Icon(Icons.check_rounded, color: colorScheme.onPrimary)
                : null,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One plain sentence for the longer view, in place of a calendar grid.
class _MonthSentence extends StatelessWidget {
  const _MonthSentence({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = summary.activeDaysInLast(30);
    final text = switch (days) {
      0 => 'No reading in the last 30 days yet.',
      1 => 'You read on 1 day in the last 30 days.',
      _ => 'You read on $days days in the last 30 days.',
    };
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
            Expanded(child: _SectionTitle('Across the community')),
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
          _SectionTitle('Most recited this week'),
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
