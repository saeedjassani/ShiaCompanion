import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../stats/stats_widgets.dart';
import 'usage_charts.dart';
import 'usage_dashboard_page.dart';

/// The pieces the Usage dashboard is built from, in the revamp's style: the
/// same cards, type and colors as My Stats.

final NumberFormat usageCountFormat = NumberFormat.decimalPattern();
final NumberFormat usagePercentFormat =
    NumberFormat.decimalPercentPattern(decimalDigits: 0);

/// "+12%"-style change against the previous period: green up, red down.
class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.delta, this.caption});

  final PeriodDelta delta;

  /// What it is measured against ("the previous 7 days"), as a tooltip.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final color = switch (delta.direction) {
      DeltaDirection.up || DeltaDirection.isNew => colors.success,
      DeltaDirection.down => colors.danger,
      DeltaDirection.flat => colors.textMuted,
    };
    final arrow = switch (delta.direction) {
      DeltaDirection.up || DeltaDirection.isNew => '↑',
      DeltaDirection.down => '↓',
      DeltaDirection.flat => '',
    };
    final chip = Text(
      '$arrow${delta.label}',
      style: ShiaText.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
    if (caption == null || caption!.isEmpty) return chip;
    return Tooltip(message: 'vs $caption', child: chip);
  }
}

/// One headline number: what it counts, the number, and a line under it -
/// its change, or a note such as "12,345 finished".
class UsageKpiTile extends StatelessWidget {
  const UsageKpiTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaCaption,
    this.note,
  });

  final String label;
  final String value;
  final PeriodDelta? delta;
  final String? deltaCaption;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return StatsCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ShiaText.secondary.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: ShiaText.largeTitle.copyWith(
                fontSize: 26,
                height: 32 / 26,
                color: colors.text,
              ),
            ),
          ),
          if (delta != null || note != null)
            Wrap(
              spacing: 6,
              children: [
                if (delta != null)
                  DeltaChip(delta: delta!, caption: deltaCaption),
                if (note != null)
                  Text(
                    note!,
                    style: ShiaText.caption.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tiles in rows of equal height: three across from tablet width, two on a
/// phone.
class UsageKpiGrid extends StatelessWidget {
  const UsageKpiGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 600 ? 3 : 2;
      return Column(
        children: [
          for (var start = 0; start < tiles.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: 12),
                    Expanded(
                      child: i < tiles.length
                          ? tiles[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// A titled card: the title, its total and change at the end, a line on
/// what it shows, then [child].
class UsageCard extends StatelessWidget {
  const UsageCard({
    super.key,
    required this.title,
    this.subtitle,
    this.total,
    this.delta,
    this.deltaCaption,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final int? total;
  final PeriodDelta? delta;
  final String? deltaCaption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: StatsSectionTitle(title)),
              if (total != null)
                Text(
                  usageCountFormat.format(total),
                  style: ShiaText.secondary.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (delta != null) ...[
                const SizedBox(width: 8),
                DeltaChip(delta: delta!, caption: deltaCaption),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: ShiaText.caption.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// One ranked line: its place, the name (and a note under it), a bar
/// against the top row, and the count with its share and change.
class UsageRankedRow extends StatelessWidget {
  const UsageRankedRow({
    super.key,
    required this.rank,
    required this.row,
    required this.fraction,
    required this.share,
    this.delta,
    this.color,
  });

  final int rank;
  final UsageRow row;

  /// Of the top row, for the bar.
  final double fraction;

  /// Of the whole list's total.
  final double share;
  final PeriodDelta? delta;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final muted = ShiaText.caption.copyWith(color: colors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank',
                style: muted.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  row.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ShiaText.secondary.copyWith(color: colors.text),
                ),
                if (row.note != null) Text(row.note!, style: muted),
                const SizedBox(height: 6),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.well,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color ?? colors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                usageCountFormat.format(row.count),
                style: ShiaText.secondary.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(usagePercentFormat.format(share), style: muted),
              if (delta != null) DeltaChip(delta: delta!),
            ],
          ),
        ],
      ),
    );
  }
}

/// The figures a [UsageRankedRow] needs, worked out once for a whole list.
class _Ranking {
  _Ranking(this.rows, this.previousByKey)
      : max = rows.isEmpty ? 0 : rows.first.count,
        total = rows.fold<int>(0, (sum, row) => sum + row.count);

  final List<UsageRow> rows;
  final Map<String, int>? previousByKey;
  final int max;
  final int total;

  UsageRankedRow rowAt(int index, {Color? color}) {
    final row = rows[index];
    return UsageRankedRow(
      rank: index + 1,
      row: row,
      fraction: max == 0 ? 0 : row.count / max,
      share: total == 0 ? 0 : row.count / total,
      delta: previousByKey == null
          ? null
          : periodDelta(row.count, previousByKey![row.key] ?? 0),
      color: color,
    );
  }
}

/// A ranking as a card: its top [limit] rows, and "See all" to the full
/// list on a page of its own.
class UsageRankedCard extends StatelessWidget {
  const UsageRankedCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.rows,
    this.previousTotal,
    this.previousByKey,
    this.previousCaption,
    this.color,
    this.colorFor,
    this.header,
    this.limit = 5,
  });

  final String title;
  final String? subtitle;
  final List<UsageRow> rows;
  final int? previousTotal;
  final Map<String, int>? previousByKey;
  final String? previousCaption;
  final Color? color;

  /// A bar color per row, when the rows carry identity colors (see
  /// [header]); null falls back to [color].
  final Color? Function(UsageRow row)? colorFor;

  /// Above the rows: a share bar.
  final Widget? header;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ranking = _Ranking(rows, previousByKey);
    final shown = rows.length < limit ? rows.length : limit;
    return UsageCard(
      title: title,
      subtitle: subtitle,
      total: ranking.total,
      delta: previousTotal == null
          ? null
          : periodDelta(ranking.total, previousTotal!),
      deltaCaption: previousCaption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 8)],
          for (var i = 0; i < shown; i++)
            ranking.rowAt(i, color: colorFor?.call(rows[i]) ?? color),
          if (rows.length > shown)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SeeAllLink(
                label: 'See all ${rows.length}',
                onTap: () => pushPageRoute(
                  context,
                  UsageRankedPage(
                    title: title,
                    subtitle: subtitle,
                    rows: rows,
                    previousByKey: previousByKey,
                    color: color,
                    colorFor: colorFor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "See all", in the accent, as My Stats has it.
class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 26, end: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: ShiaText.secondary.copyWith(
                color: ShiaColors.of(context).accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A whole ranking, on its own page.
class UsageRankedPage extends StatelessWidget {
  const UsageRankedPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.rows,
    this.previousByKey,
    this.color,
    this.colorFor,
  });

  final String title;
  final String? subtitle;
  final List<UsageRow> rows;
  final Map<String, int>? previousByKey;
  final Color? color;
  final Color? Function(UsageRow row)? colorFor;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final ranking = _Ranking(rows, previousByKey);
    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: title,
      subtitle: '${usageCountFormat.format(ranking.total)} in all · '
          '${rows.length} rows',
      slivers: [
        if (subtitle != null)
          SliverPadding(
            padding: pageGutter(context, maxWidth: widePageWidth)
                .copyWith(bottom: 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                subtitle!,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
          ),
        SliverPadding(
          padding: pageGutter(context, maxWidth: widePageWidth)
              .copyWith(bottom: 32),
          sliver: SliverCardList(
            itemCount: rows.length,
            itemBuilder: (context, index) => Container(
              decoration: index == rows.length - 1
                  ? null
                  : BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: colors.divider)),
                    ),
              padding: const EdgeInsetsDirectional.only(start: 14, end: 14),
              child: ranking.rowAt(index,
                  color: colorFor?.call(rows[index]) ?? color),
            ),
          ),
        ),
      ],
    );
  }
}

/// One area of the app in the "What people do" grid: its color, its total
/// and change, and what was done most there. Opens the area's actions.
class UsageAreaTile extends StatelessWidget {
  const UsageAreaTile({
    super.key,
    required this.title,
    required this.color,
    required this.total,
    required this.share,
    this.delta,
    this.top,
    required this.onTap,
  });

  final String title;
  final Color color;
  final int total;
  final double share;
  final PeriodDelta? delta;
  final String? top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final muted = ShiaText.caption.copyWith(color: colors.textMuted);
    return Material(
      color: colors.well,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShiaText.secondary.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlineIcon(OutlineGlyph.chevronRight,
                      size: 16, color: colors.chevron),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                usageCountFormat.format(total),
                style: ShiaText.cardTitle.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  Text(usagePercentFormat.format(share), style: muted),
                  if (delta != null) DeltaChip(delta: delta!),
                ],
              ),
              if (top != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Most: $top',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiles two to a line, each line as tall as its taller tile.
class UsageTileGrid extends StatelessWidget {
  const UsageTileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var start = 0; start < tiles.length; start += 2) ...[
          if (start > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[start]),
                const SizedBox(width: 10),
                Expanded(
                  child: start + 1 < tiles.length
                      ? tiles[start + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Steps of a funnel side by side - each a number and what it counts - with
/// an arrow between them.
class UsageFunnel extends StatelessWidget {
  const UsageFunnel({super.key, required this.steps, this.note});

  final List<({String label, int value, PeriodDelta? delta})> steps;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final muted = ShiaText.caption.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: OutlineIcon(OutlineGlyph.arrowRight,
                          size: 16, color: colors.chevron),
                    ),
                  ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.well,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            usageCountFormat.format(steps[i].value),
                            style: ShiaText.cardTitle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                        ),
                        Text(steps[i].label, style: muted),
                        if (steps[i].delta != null)
                          DeltaChip(delta: steps[i].delta!),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 10),
          Text(note!, style: muted),
        ],
      ],
    );
  }
}

/// The share bar's segments for a ranking: each of [namedKeys] present, in
/// rank order, colored by its slot in [namedKeys] - so a key keeps its color
/// whichever range is showing - and every other row folded into one neutral
/// "Other".
List<ShareSegment> namedShareSegments(
  List<UsageRow> rows,
  List<String> namedKeys,
  Brightness brightness,
  Color otherColor,
) {
  var rest = 0;
  final segments = <ShareSegment>[];
  for (final row in rows) {
    final slot = namedKeys.indexOf(row.key);
    if (slot < 0) {
      rest += row.count;
    } else {
      segments.add(ShareSegment(
        label: row.label,
        value: row.count,
        color: categoricalColor(slot, brightness),
      ));
    }
  }
  if (rest > 0) {
    segments.add(ShareSegment(label: 'Other', value: rest, color: otherColor));
  }
  return segments;
}
