import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/quran_progress_store.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import '../../widgets/responsive_content.dart';

/// Recitations logged under a label ("Family", "Personal", ...) as a real
/// verse range, with the numbers that make keeping the habit visible: a
/// streak, a heatmap and a per-label breakdown — all counted in verses
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

        return Stack(
          children: [
            ResponsiveScrollableContent(
              maxWidth: listContentWidth,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: state.isEmpty
                  ? _buildEmptyState(context)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummary(context, state),
                        const SizedBox(height: 18),
                        _buildHeatmap(context, state),
                        if (state.labels.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _buildLabelBreakdown(context, state),
                        ],
                        const SizedBox(height: 18),
                        _buildRecentList(context, state),
                      ],
                    ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton.extended(
                heroTag: 'log_recitation_fab',
                onPressed: () => _showLogDialog(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Log recitation'),
              ),
            ),
          ],
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
              'Log the verses you read under a label like "Family"\n'
              'or "Personal" to start tracking streaks and totals.',
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

  static const int _heatmapDays = 84;

  Widget _buildHeatmap(BuildContext context, RecitationTrackerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final counts = state.dailyVerseCounts(_heatmapDays);
    final sortedDays = counts.keys.toList()..sort();

    // Pad the front so columns line up on calendar weeks (Sun..Sat).
    final firstWeekdayOffset = sortedDays.first.weekday % 7;
    final paddedDays = <DateTime?>[
      for (var i = 0; i < firstWeekdayOffset; i++) null,
      ...sortedDays,
    ];

    final weeks = <List<DateTime?>>[];
    for (var i = 0; i < paddedDays.length; i += 7) {
      final end = i + 7 < paddedDays.length ? i + 7 : paddedDays.length;
      weeks.add(paddedDays.sublist(i, end));
    }

    final maxCount = counts.values.fold(0, (m, c) => c > m ? c : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verses recited, last 12 weeks',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final week in weeks) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var day = 0; day < 7; day++)
                      Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: _heatmapCell(
                          colorScheme,
                          day < week.length ? week[day] : null,
                          counts,
                          maxCount,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 3),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _heatmapCell(
    ColorScheme colorScheme,
    DateTime? day,
    Map<DateTime, int> counts,
    int maxCount,
  ) {
    if (day == null) {
      return const SizedBox(width: 13, height: 13);
    }

    final count = counts[day] ?? 0;
    final color = count == 0
        ? colorScheme.surfaceContainerHighest
        : Color.lerp(
            colorScheme.primary.withValues(alpha: 0.28),
            colorScheme.primary,
            maxCount == 0 ? 1.0 : (count / maxCount).clamp(0.3, 1.0).toDouble(),
          )!;

    return Tooltip(
      message: '${_dayFormat.format(day)}: '
          '$count ${count == 1 ? 'verse' : 'verses'}',
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildLabelBreakdown(
    BuildContext context,
    RecitationTrackerState state,
  ) {
    final theme = Theme.of(context);
    final labels = state.labels;

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
    final verses = state.versesByLabel[label] ?? 0;
    final sessions = state.sessionsByLabel[label] ?? 0;
    final last = state.lastRecitedFor(label);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
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
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Remove',
              onPressed: () =>
                  RecitationTrackerManager.instance.removeEntry(entry.id),
            ),
          ),
      ],
    );
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

  /// Parses "2:1"-style input for both ends of a range. Null unless both
  /// sides name the same surah and the range runs forward — that is the one
  /// shape a verse count can be derived from without guessing.
  ({int surah, int fromAyah, int toAyah})? _tryParseRange(
    String fromText,
    String toText,
  ) {
    final from = VerseKey.tryParse(fromText);
    final to = VerseKey.tryParse(toText);
    if (from?.ayah == null || to?.ayah == null) return null;
    if (from!.surah != to!.surah) return null;
    if (to.ayah! < from.ayah!) return null;
    return (surah: from.surah, fromAyah: from.ayah!, toAyah: to.ayah!);
  }

  Future<void> _showLogDialog(
    BuildContext context,
    RecitationTrackerState state,
  ) async {
    final labelController = TextEditingController();
    final fromController = TextEditingController();
    final toController = TextEditingController();
    String? selectedExisting;
    var selectedDate = DateTime.now();
    final existingLabels = state.labels;
    final lastProgress = QuranProgressStore.instance.read();

    try {
      final result = await showDialog<_LogResult>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final range =
                _tryParseRange(fromController.text, toController.text);

            return AlertDialog(
              title: const Text('Log a recitation'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (existingLabels.isNotEmpty) ...[
                      Text(
                        'Label',
                        style: Theme.of(dialogContext).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in existingLabels)
                            ChoiceChip(
                              label: Text(label),
                              selected: selectedExisting == label,
                              onSelected: (selected) => setDialogState(() {
                                selectedExisting = selected ? label : null;
                                if (selected) labelController.clear();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: labelController,
                      autofocus: existingLabels.isEmpty,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Or a new label',
                        hintText: 'e.g. Family, Personal',
                      ),
                      onChanged: (_) =>
                          setDialogState(() => selectedExisting = null),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Verses recited',
                      style: Theme.of(dialogContext).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fromController,
                            decoration: const InputDecoration(
                              labelText: 'From',
                              hintText: 'e.g. 2:1',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: toController,
                            decoration: const InputDecoration(
                              labelText: 'To',
                              hintText: 'e.g. 2:20',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (lastProgress != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setDialogState(() {
                            fromController.text =
                                '${lastProgress.surah}:${lastProgress.ayah}';
                            toController.text =
                                '${lastProgress.surah}:${lastProgress.ayah}';
                          }),
                          icon: const Icon(Icons.replay, size: 18),
                          label: const Text('Use where I left off'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      range == null
                          ? 'Both verses in one surah, e.g. 2:1 to 2:20'
                          : '${surahInfoFor(range.surah)?.englishName ?? "Surah ${range.surah}"} '
                              '${range.fromAyah}–${range.toAyah} · '
                              '${range.toAyah - range.fromAyah + 1} '
                              '${range.toAyah - range.fromAyah + 1 == 1 ? "verse" : "verses"}',
                      style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                            color: range == null
                                ? Theme.of(dialogContext).colorScheme.error
                                : Theme.of(dialogContext)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Date: ${_dayFormat.format(selectedDate)}'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: now.subtract(const Duration(days: 3650)),
                              lastDate: now,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    now.hour,
                                    now.minute,
                                  ));
                            }
                          },
                          child: const Text('Change'),
                        ),
                      ],
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
                  onPressed: range == null
                      ? null
                      : () {
                          final label =
                              (selectedExisting ?? labelController.text).trim();
                          if (label.isEmpty) return;
                          Navigator.pop(
                            dialogContext,
                            _LogResult(
                              label: label,
                              recitedAt: selectedDate,
                              surah: range.surah,
                              fromAyah: range.fromAyah,
                              toAyah: range.toAyah,
                            ),
                          );
                        },
                  child: const Text('Log'),
                ),
              ],
            );
          },
        ),
      );

      if (result == null) return;
      await RecitationTrackerManager.instance.logRecitation(
        label: result.label,
        recitedAt: result.recitedAt,
        surah: result.surah,
        fromAyah: result.fromAyah,
        toAyah: result.toAyah,
      );
    } finally {
      labelController.dispose();
      fromController.dispose();
      toController.dispose();
    }
  }
}

class _LogResult {
  const _LogResult({
    required this.label,
    required this.recitedAt,
    required this.surah,
    required this.fromAyah,
    required this.toAyah,
  });

  final String label;
  final DateTime recitedAt;
  final int surah;
  final int fromAyah;
  final int toAyah;
}
