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
                _SectionTitle('Your last few months'),
                const SizedBox(height: 8),
                _ActivityHeatmap(summary: summary),
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
          Row(
            children: [
              _StatChip(
                label: 'Longest streak',
                value: '${summary.longestStreak}d',
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Days active',
                value: format.format(summary.activeDayCount),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/// A GitHub-style calendar: one column per week, Sunday at the top, today in
/// the last column. As many weeks as fit the width, up to half a year.
class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({required this.summary});

  final ActivitySummary summary;

  static const double _gap = 3;
  static const int _maxWeeks = 26;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final weeks = math.max(
          8,
          math.min(_maxWeeks, ((width + _gap) / (14 + _gap)).floor()),
        );
        final cell = (width - _gap * (weeks - 1)) / weeks;
        // Column `weeks - 1` is the current week; row is weekday (Sun = 0).
        final todayRow = today.weekday % 7;
        final firstDay = DateTime(
          today.year,
          today.month,
          today.day - todayRow - (weeks - 1) * 7,
        );

        Color colorFor(int score) {
          if (score <= 0) {
            return colorScheme.onSurface.withValues(alpha: 0.07);
          }
          final level = score >= 6
              ? 1.0
              : score >= 3
                  ? 0.7
                  : 0.42;
          return colorScheme.primary.withValues(alpha: level);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: cell * 7 + _gap * 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var week = 0; week < weeks; week++) ...[
                    if (week > 0) const SizedBox(width: _gap),
                    Column(
                      children: [
                        for (var row = 0; row < 7; row++) ...[
                          if (row > 0) const SizedBox(height: _gap),
                          _cell(
                            DateTime(
                              firstDay.year,
                              firstDay.month,
                              firstDay.day + week * 7 + row,
                            ),
                            today,
                            cell,
                            colorFor,
                            colorScheme,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Less', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 4),
                for (final score in const [0, 1, 3, 6]) ...[
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: colorFor(score),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Text('More', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _cell(
    DateTime day,
    DateTime today,
    double size,
    Color Function(int) colorFor,
    ColorScheme colorScheme,
  ) {
    if (day.isAfter(today)) return SizedBox(width: size, height: size);
    final activity = summary.activityOn(day);
    final verses = summary.versesOn(day);
    final parts = [
      if (activity.zikrs > 0) '${activity.zikrs} zikr',
      if (verses > 0) '$verses verses',
      if (activity.qaza > 0) '${activity.qaza} qaza',
    ];
    return Tooltip(
      message: '${DateFormat('EEE, MMM d').format(day)}'
          '${parts.isEmpty ? '' : ' - ${parts.join(', ')}'}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorFor(summary.scoreOn(day)),
          borderRadius: BorderRadius.circular(3),
          border: day == today
              ? Border.all(color: colorScheme.primary, width: 1.2)
              : null,
        ),
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
