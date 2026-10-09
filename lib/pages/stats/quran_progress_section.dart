import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recitation_tracker_state.dart';
import '../../utils/quran_index.dart';
import 'stats_widgets.dart';
import '../../l10n/l10n.dart';

final NumberFormat _count = NumberFormat.decimalPattern();

String _surahName(int surah) =>
    surahInfoFor(surah)?.displayName ?? L10n.current.quranSurahNumber(surah);

String _percentText(double percent) =>
    '${percent.toStringAsFixed(percent > 0 && percent < 10 ? 1 : 0)}%';

/// Quran recitation as one card per track - how much of the Quran it has
/// covered, where it was left, and which juz are done. The sessions behind
/// it are listed on the Quran screen (see RecentRecitationsPage).
class QuranProgressSection extends StatelessWidget {
  const QuranProgressSection({super.key, required this.state});

  final RecitationTrackerState state;

  @override
  Widget build(BuildContext context) {
    final labels = [
      ...state.labels,
      // The catch-all only earns a card once something is in it.
      if ((state.sessionsByLabel[unlabeledRecitationLabel] ?? 0) > 0)
        unlabeledRecitationLabel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsSectionTitle(context.l10n.statsQuranProgress),
        const SizedBox(height: 10),
        if (labels.isEmpty)
          const _EmptyQuranCard()
        else
          for (final label in labels) ...[
            QuranTrackCard(state: state, label: label),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _EmptyQuranCard extends StatelessWidget {
  const _EmptyQuranCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StatsCard(
      child: Row(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.l10n.statsQuranEmpty,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// One recitation track: a ring for how much of the Quran it has covered,
/// "recited till" for where it stopped, and a thirty-cell map of the juz.
class QuranTrackCard extends StatelessWidget {
  const QuranTrackCard({super.key, required this.state, required this.label});

  final RecitationTrackerState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = state.percentCompleteFor(label);
    final coverage = state.juzCoverageFor(label);
    final juzDone = coverage.where((fraction) => fraction >= 1).length;
    final last = state.lastRecitedVerseFor(label);
    final lastAt = state.lastRecitedFor(label);
    final sessions = state.sessionsByLabel[label] ?? 0;
    final verses = state.versesByLabel[label] ?? 0;
    final distinct = state.distinctVersesRecitedFor(label);
    final remaining = quranTotalAyahCount - distinct;

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                label == unlabeledRecitationLabel
                    ? Icons.menu_book_outlined
                    : Icons.menu_book_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recitationTrackName(label, context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProgressRing(
                  value: percent / 100,
                  center: Text(
                    _percentText(percent),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoPanel(
                    title: context.l10n.statsRecitedTill,
                    lines: last == null
                        ? [context.l10n.statsNotStarted]
                        : [
                            '${_surahName(last.surah)}: ${last.ayah}',
                            context.l10n.quranJuzNumber(juzOf(last.surah, last.ayah!)),
                          ],
                  ),
                ),
                const SizedBox(width: 8),
                _InfoPanel(
                  title: context.l10n.statsJuzDone,
                  big: '$juzDone',
                  lines: const ['of 30'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _JuzMap(coverage: coverage),
          const SizedBox(height: 12),
          Text(
            [
              context.l10n.statsSessionCount(sessions, _count.format(sessions)),
              context.l10n.statsVersesRecited(verses, _count.format(verses)),
              if (lastAt != null)
                context.l10n.statsLastOn(
                    DateFormat('MMM d').format(lastAt.toLocal())),
            ].join(' · '),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (distinct > 0 && remaining > 0) ...[
            const SizedBox(height: 2),
            Text(
              context.l10n.statsVersesLeft(_count.format(remaining)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (remaining <= 0) ...[
            const SizedBox(height: 2),
            Text(
              context.l10n.statsKhatmComplete,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.lines, this.big});

  final String title;
  final String? big;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          if (big != null)
            Text(
              big!,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          for (final line in lines)
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// The thirty juz as a strip of cells, filled by how much of each is done -
/// a khatm read out of order still shows exactly which parts are left.
class _JuzMap extends StatelessWidget {
  const _JuzMap({required this.coverage});

  final List<double> coverage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      label: context.l10n
          .statsJuzComplete(coverage.where((f) => f >= 1).length),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in [0, 15])
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
              child: Row(
                children: [
                  for (var i = row; i < row + 15; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Tooltip(
                          message: context.l10n.statsJuzCoverage(
                              i + 1, (coverage[i] * 100).floor()),
                          child: Container(
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: coverage[i] >= 1
                                  ? colorScheme.primary
                                  : coverage[i] > 0
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.15 + 0.45 * coverage[i])
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FittedBox(
                              child: Text(
                                localizeDigits('${i + 1}', context.l10n),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: coverage[i] >= 1
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
