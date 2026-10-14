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
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
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

  /// What History plots; a tile picks it too.
  StatsMetric _metric = StatsMetric.zikrs;
  final GlobalKey _historyKey = GlobalKey();

  void _showInHistory(StatsMetric metric) {
    setState(() => _metric = metric);
    final history = _historyKey.currentContext;
    if (history != null) {
      unawaited(Scrollable.ensureVisible(
        history,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ));
    }
  }

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
    final l10n = context.l10n;
    final gutter = pageGutter(context, maxWidth: widePageWidth);

    return ListenableBuilder(
      listenable: Listenable.merge([
        ActivityStatsStore.instance,
        RecitationTrackerManager.instance,
      ]),
      builder: (context, _) {
        final summary = ActivityStatsStore.instance.summary();
        final recitation = RecitationTrackerManager.instance.state;
        final community = _community;
        // Qaza is offered only to someone who keeps qaza.
        final metrics = [
          StatsMetric.zikrs,
          StatsMetric.verses,
          if (summary.totalQaza > 0) StatsMetric.qaza,
        ];
        final metric = metrics.contains(_metric) ? _metric : metrics.first;

        // The streak and its history on the left; what was recited, the
        // Quran and the community on the right, once a desktop has room.
        return LargeTitlePage(
          maxWidth: widePageWidth,
          title: l10n.statsTitle,
          slivers: [
            SliverPadding(
              padding: gutter,
              sliver: SliverToBoxAdapter(
                child: WideColumns(
                  spacing: 18,
                  start: [
                    // Nothing read yet: one card on how it starts, not a
                    // page of zeros.
                    if (summary.isEmpty)
                      EmptyStateCard(
                        glyph: OutlineGlyph.flame,
                        title: l10n.statsWelcomeTitle,
                        body: l10n.statsStreakStart,
                      )
                    else ...[
                      _StreakCard(summary: summary),
                      _TotalsTiles(
                        summary: summary,
                        metrics: metrics,
                        onSelect: _showInHistory,
                      ),
                      StatsHistoryCard(
                        key: _historyKey,
                        summary: summary,
                        metric: metric,
                        metrics: metrics,
                        onMetricChanged: (metric) =>
                            setState(() => _metric = metric),
                      ),
                    ],
                  ],
                  end: [
                    if (summary.zikrCounts.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SeeAllHeader(
                            title: l10n.statsYourMostRecited,
                            onSeeAll: summary.zikrCounts.length > _topCount
                                ? () => pushPageRoute(
                                    context, const _AllRecitedPage())
                                : null,
                          ),
                          const SizedBox(height: 8),
                          _RankedZikrList(entries: [
                            for (final entry in summary.topZikrs(_topCount))
                              (entry.key, _titleFor(entry.key), entry.value),
                          ]),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuranProgressSection(state: recitation),
                        const SizedBox(height: 6),
                        _PrivacyNote(isSignedIn: _isSignedIn),
                      ],
                    ),
                    if (community != null)
                      _CommunitySection(
                        stats: community,
                        format: _count,
                        top: [
                          for (final zikr in community.top)
                            (
                              zikr.uid,
                              _titleFor(zikr.uid, zikr.title),
                              zikr.recitations
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How many of the reader's most recited show before "See all".
const int _topCount = 5;

String _titleFor(String uid, [String? fallback]) {
  final title = items[uid];
  if (title is String && title.trim().isNotEmpty) {
    return zikrDisplayTitle(uid, title);
  }
  return fallback ?? uid;
}

/// A group label with "See all" at the end when [onSeeAll] is set.
class _SeeAllHeader extends StatelessWidget {
  const _SeeAllHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Row(
      children: [
        Expanded(child: GroupLabel(title)),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    context.l10n.statsSeeAll,
                    style: ShiaText.secondary.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Every zikr the reader has finished, most recited first.
class _AllRecitedPage extends StatelessWidget {
  const _AllRecitedPage();

  @override
  Widget build(BuildContext context) {
    final gutter = pageGutter(context);
    return ListenableBuilder(
      listenable: ActivityStatsStore.instance,
      builder: (context, _) {
        final summary = ActivityStatsStore.instance.summary();
        return LargeTitlePage(
          title: context.l10n.statsYourMostRecited,
          slivers: [
            SliverPadding(
              padding: gutter,
              sliver: SliverToBoxAdapter(
                child: _RankedZikrList(entries: [
                  for (final entry
                      in summary.topZikrs(summary.zikrCounts.length))
                    (entry.key, _titleFor(entry.key), entry.value),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Zikr with how often each was recited, most first, numbered: Your most
/// recited, and the community's. A row opens its zikr.
class _RankedZikrList extends StatelessWidget {
  const _RankedZikrList({required this.entries});

  final List<(String uid, String title, int count)> entries;

  static final NumberFormat _count = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final muted = ShiaText.secondary.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.textMuted,
    );
    return CardList(
      children: [
        for (var i = 0; i < entries.length; i++)
          CardListRow(
            first: i == 0,
            last: i == entries.length - 1,
            minHeight: 48,
            leading: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(localizeDigits('${i + 1}', context.l10n),
                  style: muted.copyWith(fontWeight: FontWeight.w700)),
            ),
            title: Text(entries[i].$2,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
              child: Text(
                localizeDigits(_count.format(entries[i].$3), context.l10n),
                style: muted,
              ),
            ),
            onTap: () => pushPageRoute(
              context,
              ZikrPage(UidTitleData(entries[i].$1, entries[i].$2),
                  source: ZikrOpenSource.myStats),
            ),
          ),
      ],
    );
  }
}

/// Lifetime totals as tiles: zikrs, verses, qaza (only for someone who
/// keeps qaza) and active days - two by two, or three in a row. A metric's
/// tile shows it in History.
class _TotalsTiles extends StatelessWidget {
  const _TotalsTiles({
    required this.summary,
    required this.metrics,
    required this.onSelect,
  });

  final ActivitySummary summary;
  final List<StatsMetric> metrics;
  final ValueChanged<StatsMetric> onSelect;

  static final NumberFormat _count = NumberFormat.decimalPattern();
  static final NumberFormat _compact = NumberFormat.compact();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String number(int value) => localizeDigits(
        value < 10000 ? _count.format(value) : _compact.format(value), l10n);

    final tiles = [
      for (final metric in metrics)
        StatsTile(
          label: metric.label,
          value: number(switch (metric) {
            StatsMetric.zikrs => summary.totalZikrs,
            StatsMetric.verses => summary.quranVersesTotal,
            StatsMetric.qaza => summary.totalQaza,
          }),
          onTap: () => onSelect(metric),
        ),
      StatsTile(
        label: l10n.statsActiveDays,
        value: number(summary.activeDayCount),
      ),
    ];

    Widget row(List<Widget> tiles) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );

    if (tiles.length < 4) return row(tiles);
    return Column(
      children: [
        row(tiles.sublist(0, 2)),
        const SizedBox(height: 12),
        row(tiles.sublist(2)),
      ],
    );
  }
}

/// The streak: days in a row in large type, the best, and today's state in
/// words - with a tick once something has been read today.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});

  final ActivitySummary summary;

  /// Deliberately gentle: a missed day is a fresh start, not a failure.
  String get _notYetMessage {
    if (summary.currentStreak == 0) return L10n.current.statsWelcomeBack;
    return L10n.current.statsReadToday;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final streak = summary.currentStreak;
    final best = summary.longestStreak;
    final doneToday = summary.isActiveToday;
    // One day is not a streak yet: "Day 1", with the best so far if there
    // was one, rather than "1 day in a row".
    final firstDay = doneToday && streak <= 1;
    final message = ShiaText.secondary.copyWith(
      height: 21 / 15,
      color: colors.translation,
    );

    Widget todayLine;
    if (doneToday) {
      final done = l10n.statsDoneTodayLabel;
      // A first day is not a streak yet, so it says to come back.
      final sentence = streak <= 1
          ? l10n.statsDoneTodayFirst
          : l10n.statsDoneTodayLine(done);
      final at = sentence.indexOf(done);
      todayLine = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: OutlineIcon(OutlineGlyph.check,
                size: 18, color: colors.success, strokeWidth: 2.4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: at < 0
                    ? [TextSpan(text: sentence)]
                    : [
                        TextSpan(text: sentence.substring(0, at)),
                        TextSpan(
                          text: done,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.success,
                          ),
                        ),
                        TextSpan(text: sentence.substring(at + done.length)),
                      ],
              ),
              style: message,
            ),
          ),
        ],
      );
    } else {
      todayLine = Text(_notYetMessage, style: message);
    }

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.well,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: OutlineIcon(OutlineGlyph.flame,
                    size: 28, color: colors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstDay
                          ? l10n.statsDayOne
                          : l10n.statsStreakDays(streak),
                      style: ShiaText.largeTitle.copyWith(
                        fontSize: 28,
                        height: 34 / 28,
                        color: colors.text,
                      ),
                    ),
                    if (!firstDay || best > 1)
                      Text(
                        firstDay
                            ? l10n.statsYourBest(best)
                            : best > streak
                                ? l10n.statsStreakInARowBest(best)
                                : l10n.statsStreakInARow,
                        style: ShiaText.secondary
                            .copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          todayLine,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        isSignedIn
            ? context.l10n.statsPrivateSynced
            : context.l10n.statsPrivateLocal,
        style: ShiaText.caption.copyWith(
          height: 18 / 13,
          color: ShiaColors.of(context).textMuted,
        ),
      ),
    );
  }
}

/// The anonymous community summary, as a card: the week's recitations
/// across everyone, a bar per day, the all-time total, and what was
/// recited most.
class _CommunitySection extends StatelessWidget {
  const _CommunitySection({
    required this.stats,
    required this.format,
    required this.top,
  });

  final CommunityStats stats;
  final NumberFormat format;
  final List<(String, String, int)> top;

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
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final caption = ShiaText.caption.copyWith(color: colors.textMuted);
    final maxDay = stats.days.fold<int>(
      0,
      (max, day) => math.max(max, day.recitations),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatsSectionTitle(l10n.statsAcrossCommunity),
              const SizedBox(height: 10),
              Text(
                format.format(stats.weekRecitations),
                style: ShiaText.largeTitle.copyWith(
                  fontSize: 28,
                  height: 34 / 28,
                  color: colors.accent,
                ),
              ),
              Text(
                l10n.statsRecitedThisWeek,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
              if (stats.days.isNotEmpty && maxDay > 0) ...[
                const SizedBox(height: 14),
                StatsBarChart(
                  values: [for (final day in stats.days) day.recitations],
                  labels: [
                    for (final day in stats.days)
                      DateFormat('E').format(day.day).substring(0, 1),
                  ],
                  tooltips: [
                    for (final day in stats.days)
                      '${DateFormat('EEE, MMM d').format(day.day)}'
                          ' - ${format.format(day.recitations)}',
                  ],
                  highlightLast: false,
                  barArea: 56,
                  format: (value) => localizeDigits(
                      value < 1000
                          ? format.format(value)
                          : NumberFormat.compact().format(value),
                      l10n),
                ),
              ],
              if (stats.allTimeRecitations > 0) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.statsAllTime(format.format(stats.allTimeRecitations)),
                  style: caption,
                ),
              ],
            ],
          ),
        ),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 18),
          GroupLabel(l10n.statsMostRecitedThisWeek),
          const SizedBox(height: 8),
          _RankedZikrList(entries: top),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.statsCommunityNote(_updatedAgo()),
            style: caption.copyWith(height: 18 / 13),
          ),
        ),
      ],
    );
  }
}
