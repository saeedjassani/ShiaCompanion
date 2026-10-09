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
                    _StreakCard(summary: summary),
                    StatsHistoryCard(summary: summary),
                  ],
                  end: [
                    if (summary.zikrCounts.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GroupLabel(l10n.statsYourMostRecited),
                          const SizedBox(height: 8),
                          _RankedZikrList(entries: [
                            for (final entry in summary.topZikrs(5))
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

  static String _titleFor(String uid, [String? fallback]) {
    final title = items[uid];
    if (title is String && title.trim().isNotEmpty) {
      return zikrDisplayTitle(uid, title);
    }
    return fallback ?? uid;
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
            leading: SizedBox(
              width: 20,
              child: Text('${i + 1}',
                  style: muted.copyWith(fontWeight: FontWeight.w700)),
            ),
            title: Text(entries[i].$2,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
              child: Text(
                context.l10n
                    .statsTimes(entries[i].$3, _count.format(entries[i].$3)),
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

/// The streak: days in a row in large type, the best, and today's state in
/// words - with a tick once something has been read today.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});

  final ActivitySummary summary;

  /// Deliberately gentle: a missed day is a fresh start, not a failure.
  String get _notYetMessage {
    if (summary.isEmpty) return L10n.current.statsStreakStart;
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
                      l10n.statsStreakDays(streak),
                      style: ShiaText.largeTitle.copyWith(
                        fontSize: 28,
                        height: 34 / 28,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      best > streak
                          ? l10n.statsStreakInARowBest(best)
                          : l10n.statsStreakInARow,
                      style:
                          ShiaText.secondary.copyWith(color: colors.textMuted),
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
                              // The bar area is fixed; the day letter below
                              // it takes whatever height the text scale needs.
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
                                        color: Color.lerp(
                                            colors.line, colors.chevron, 0.25),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('E').format(day.day).substring(0, 1),
                                style: caption,
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
