import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/analytics_service.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import '../../widgets/responsive_content.dart';
import 'quran_navigation.dart';

/// Recitations logged under a label ("Family", "Personal", ...) as a real
/// verse range, with the numbers that make keeping the habit visible: a
/// streak and a per-label breakdown — all counted in verses
/// actually recited, not in how many times the log button was tapped.
class RecitationTrackerTab extends StatefulWidget {
  const RecitationTrackerTab({super.key});

  @override
  State<RecitationTrackerTab> createState() => _RecitationTrackerTabState();
}

class _RecitationTrackerTabState extends State<RecitationTrackerTab> {
  static final DateFormat _dayFormat = DateFormat('MMM d');
  static final DateFormat _dayTimeFormat = DateFormat('MMM d, h:mm a');

  @override
  void initState() {
    super.initState();
    unawaited(RecitationTrackerManager.instance.loadRecitations());
  }

  @override
  Widget build(BuildContext context) {
    final manager = RecitationTrackerManager.instance;

    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final state = manager.state;
        final shouldShowLoading =
            manager.isLoading && !manager.hasLoaded && state.isEmpty;

        if (shouldShowLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ResponsiveScrollableContent(
          maxWidth: listContentWidth,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: state.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummary(context, state),
                    const SizedBox(height: 18),
                    _buildLabelBreakdown(context, state),
                    const SizedBox(height: 18),
                    _buildRecentList(context, state),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No recitations logged yet',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Open a surah and start reading — verses you actually recite\n'
              'are tracked automatically. Add a track for "Family" or\n'
              '"Personal" from the Quran page to keep them separate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, RecitationTrackerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final versesThisWeek =
        state.versesSince(DateTime.now().subtract(const Duration(days: 7)));

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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${state.totalVersesRecited} verses recited · '
                      '$versesThisWeek this week',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${state.currentStreak}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 10),
                child: Text(
                  state.currentStreak == 1 ? 'day' : 'days',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statChip(context, 'Longest streak', '${state.longestStreak}d'),
              const SizedBox(width: 10),
              _statChip(context, 'Labels tracked', '${state.labels.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(BuildContext context, String label, String value) {
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
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.76),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelBreakdown(
    BuildContext context,
    RecitationTrackerState state,
  ) {
    final theme = Theme.of(context);
    final labels = [...state.labels, unlabeledRecitationLabel];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'By label',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final label in labels) ...[
          _buildLabelTile(context, state, label),
          if (label != labels.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildLabelTile(
    BuildContext context,
    RecitationTrackerState state,
    String label,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnlabeled = label == unlabeledRecitationLabel;
    final verses = state.versesByLabel[label] ?? 0;
    final sessions = state.sessionsByLabel[label] ?? 0;
    final last = state.lastRecitedFor(label);
    final percent = state.percentCompleteFor(label);

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _resumeLabel(context, state, label),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnlabeled
                          ? Icons.menu_book_outlined
                          : Icons.menu_book_rounded,
                      color: colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          last == null
                              ? 'No sessions yet'
                              : 'Last · ${_dayFormat.format(last.toLocal())} · '
                                  '$sessions ${sessions == 1 ? 'session' : 'sessions'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$verses',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        verses == 1 ? 'verse' : 'verses',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (percent > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}% of the Quran completed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resumeLabel(
    BuildContext context,
    RecitationTrackerState state,
    String label,
  ) async {
    final resume = state.resumePositionFor(label);
    await openQuranVerse(
      context,
      resume ?? const VerseKey(1),
      source: ZikrOpenSource.quranResume,
      recitationLabel: label,
    );
  }

  Widget _buildRecentList(BuildContext context, RecitationTrackerState state) {
    final theme = Theme.of(context);
    final entries = state.mostRecentFirst.take(20).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Recent',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text(_rangeLabel(entry)),
            subtitle: Text(
              '${entry.label} · ${_dayTimeFormat.format(entry.recitedAt.toLocal())}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.label_outline, size: 20),
                  tooltip: 'Move to another label',
                  onPressed: () => _showRelabelDialog(context, state, entry),
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
      ],
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

  String _rangeLabel(RecitationEntry entry) {
    final surahName =
        surahInfoFor(entry.surah)?.englishName ?? 'Surah ${entry.surah}';
    final range = entry.fromAyah == entry.toAyah
        ? '${entry.fromAyah}'
        : '${entry.fromAyah}–${entry.toAyah}';
    final verses = entry.versesRecited;
    return '$surahName $range · $verses ${verses == 1 ? 'verse' : 'verses'}';
  }
}
