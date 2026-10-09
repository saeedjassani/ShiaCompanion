import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../l10n/l10n.dart';
import '../../services/analytics_service.dart';
import '../../utils/todays_recitation.dart';
import '../../widgets/page_chrome.dart';
import '../todays_recitation_page.dart';
import 'home_section.dart';

/// One row of Home's Today section: a recitation and the occasion it is for.
typedef TodayPick = ({TodaysRecitationKind kind, UidTitleData entry});

/// The few of today's recitations Home shows, from [groups] (most specific
/// occasion first, as [buildTodaysRecitationGroups] gives them).
///
/// Each occasion gets up to [perGroup] rows first, so a month full of aamal
/// (Ramazan, Rajab) cannot push tonight's weekday duas off Home; the rows
/// left over go to the most specific occasions. Every-day recitations only
/// fill what is left, since they are the same every day. The rows keep the
/// groups' order.
@visibleForTesting
List<TodayPick> todayPicks(
  List<TodaysRecitationGroup> groups, {
  int limit = TodaySection.maxRows,
  int perGroup = 2,
}) {
  final counts = List<int>.filled(groups.length, 0);
  var total = 0;
  for (var i = 0; i < groups.length && total < limit; i++) {
    if (groups[i].kind == TodaysRecitationKind.everyDay) continue;
    final take = [perGroup, groups[i].items.length, limit - total]
        .reduce((a, b) => a < b ? a : b);
    counts[i] = take;
    total += take;
  }
  for (var i = 0; i < groups.length && total < limit; i++) {
    final take = [groups[i].items.length - counts[i], limit - total]
        .reduce((a, b) => a < b ? a : b);
    counts[i] += take;
    total += take;
  }
  return [
    for (var i = 0; i < groups.length; i++)
      for (final entry in groups[i].items.take(counts[i]))
        (kind: groups[i].kind, entry: entry),
  ];
}

/// "Today": the first few of today's recitations - tonight's and today's
/// occasions, the month's, the weekday's - each with what it is for, and
/// See all for the full Today's Recitations. Hidden until the zikr index
/// has loaded, and when nothing is for today.
///
/// Checked once a minute, so it moves on by itself at Maghrib (tonight's
/// recitations) and at midnight.
class TodaySection extends StatefulWidget {
  const TodaySection({super.key, required this.onSeeAll, this.topSpacing = 0});

  final VoidCallback onSeeAll;

  /// Space above the section, only when it shows.
  final double topSpacing;

  /// How many recitations Home shows; See all has the rest.
  static const int maxRows = 4;

  /// Lets tests pin "now".
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  State<TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<TodaySection> {
  Timer? _timer;

  /// What the section last showed, to rebuild only when the day moves on.
  String _shown = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _signature(_rows(context.l10n)) != _shown) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<(String, UidTitleData)> _rows(AppLocalizations l10n) {
    if (!zikrIndexReady.value) return const [];
    final now = TodaySection.debugNow();
    final today = todaysLunarDays(now: now);
    return [
      for (final pick in todayPicks(buildTodaysRecitationGroups(now: now)))
        (todaysRecitationGroupLabel(pick.kind, today, l10n), pick.entry),
    ];
  }

  static String _signature(List<(String, UidTitleData)> rows) =>
      rows.map((row) => '${row.$1}\u0000${row.$2.uid}').join('\u0001');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: zikrIndexReady,
      builder: (context, _, __) {
        final l10n = context.l10n;
        final rows = _rows(l10n);
        _shown = _signature(rows);
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: widget.topSpacing),
            HomeSectionHeader(
              title: l10n.homeTodayTitle,
              actionLabel: l10n.homeTodaySeeAll,
              actionSemanticsLabel: l10n.homeTodaySeeAllSemantics,
              onAction: widget.onSeeAll,
            ),
            const SizedBox(height: 10),
            CardList(
              children: [
                for (var i = 0; i < rows.length; i++)
                  TodaysRecitationRow(
                    entry: rows[i].$2,
                    subtitle: rows[i].$1,
                    source: ZikrOpenSource.homeToday,
                    first: i == 0,
                    last: i == rows.length - 1,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
