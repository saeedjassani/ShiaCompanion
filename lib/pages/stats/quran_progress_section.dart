import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/analytics_service.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import '../quran/quran_navigation.dart';
import 'stats_widgets.dart';

final NumberFormat _count = NumberFormat.decimalPattern();

String _surahName(int surah) =>
    surahInfoFor(surah)?.englishName ?? 'Surah $surah';

String _percentText(double percent) =>
    '${percent.toStringAsFixed(percent > 0 && percent < 10 ? 1 : 0)}%';

/// Quran recitation as one card per track - how much of the Quran it has
/// covered, where it was left, and which juz are done - followed by the
/// recent sessions, which can be moved to another track or removed.
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
        StatsSectionTitle('Quran progress'),
        const SizedBox(height: 10),
        if (labels.isEmpty)
          const _EmptyQuranCard()
        else
          for (final label in labels) ...[
            QuranTrackCard(state: state, label: label),
            const SizedBox(height: 12),
          ],
        if (state.entries.isNotEmpty) ...[
          const SizedBox(height: 6),
          _RecentRecitations(state: state),
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
              'Open a surah and start reading - the verses you recite are '
              'tracked here automatically, with your progress towards a '
              'full khatm.',
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
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => openQuranVerse(
                  context,
                  state.resumePositionFor(label) ?? const VerseKey(1),
                  source: ZikrOpenSource.quranResume,
                  recitationLabel: label,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(last == null ? 'Start' : 'Continue'),
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
                    title: 'Recited till',
                    lines: last == null
                        ? const ['Not started']
                        : [
                            '${_surahName(last.surah)}: ${last.ayah}',
                            'Juz ${juzOf(last.surah, last.ayah!)}',
                          ],
                  ),
                ),
                const SizedBox(width: 8),
                _InfoPanel(
                  title: 'Juz done',
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
              '${_count.format(sessions)} ${sessions == 1 ? 'session' : 'sessions'}',
              '${_count.format(verses)} ${verses == 1 ? 'verse' : 'verses'} recited',
              if (lastAt != null)
                'last ${DateFormat('MMM d').format(lastAt.toLocal())}',
            ].join(' · '),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (distinct > 0 && remaining > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${_count.format(remaining)} verses left to complete a khatm',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (remaining <= 0) ...[
            const SizedBox(height: 2),
            Text(
              'Khatm complete - may it be accepted',
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
      label: '${coverage.where((f) => f >= 1).length} of 30 juz complete',
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
                          message: 'Juz ${i + 1}: '
                              '${(coverage[i] * 100).floor()}%',
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
                                '${i + 1}',
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

/// The latest sessions, each one movable to another track or removable -
/// what the Quran screen's old Recitations tab offered.
class _RecentRecitations extends StatefulWidget {
  const _RecentRecitations({required this.state});

  final RecitationTrackerState state;

  @override
  State<_RecentRecitations> createState() => _RecentRecitationsState();
}

class _RecentRecitationsState extends State<_RecentRecitations> {
  static const int _collapsedCount = 5;
  static final DateFormat _dayTimeFormat = DateFormat('MMM d, h:mm a');

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.state.mostRecentFirst;
    final shown = all.take(_expanded ? 50 : _collapsedCount).toList();

    return StatsCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatsSectionTitle('Recent sessions'),
          for (final entry in shown)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_rangeLabel(entry)),
              subtitle: Text(
                '${entry.label} · '
                '${_dayTimeFormat.format(entry.recitedAt.toLocal())}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.label_outline, size: 20),
                    tooltip: 'Move to another label',
                    onPressed: () =>
                        _showRelabelDialog(context, widget.state, entry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Remove',
                    onPressed: () =>
                        RecitationTrackerManager.instance.removeEntry(entry.id),
                  ),
                ],
              ),
            ),
          if (all.length > _collapsedCount)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show fewer' : 'Show more'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showRelabelDialog(
    BuildContext context,
    RecitationTrackerState state,
    RecitationEntry entry,
  ) async {
    final controller = TextEditingController();
    final choices = [...state.labels, unlabeledRecitationLabel]
        .where((label) => label != entry.label)
        .toList(growable: false);

    try {
      final newLabel = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Move "${_rangeLabel(entry)}"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (choices.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in choices)
                        ActionChip(
                          label: Text(label),
                          onPressed: () => Navigator.pop(dialogContext, label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Or a new label',
                  ),
                  onSubmitted: (value) => Navigator.pop(dialogContext, value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Move'),
            ),
          ],
        ),
      );

      final trimmed = newLabel?.trim() ?? '';
      if (trimmed.isEmpty || trimmed == entry.label) return;
      await RecitationTrackerManager.instance.logRecitation(
        id: entry.id,
        label: trimmed,
        recitedAt: entry.recitedAt,
        surah: entry.surah,
        fromAyah: entry.fromAyah,
        toAyah: entry.toAyah,
      );
    } finally {
      controller.dispose();
    }
  }

  static String _rangeLabel(RecitationEntry entry) {
    final range = entry.fromAyah == entry.toAyah
        ? '${entry.fromAyah}'
        : '${entry.fromAyah}–${entry.toAyah}';
    final verses = entry.versesRecited;
    return '${_surahName(entry.surah)} $range · '
        '$verses ${verses == 1 ? 'verse' : 'verses'}';
  }
}
