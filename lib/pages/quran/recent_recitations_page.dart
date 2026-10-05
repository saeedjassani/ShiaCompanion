import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import '../../l10n/l10n.dart';

String _surahName(int surah) =>
    surahInfoFor(surah)?.englishName ?? L10n.current.quranSurahNumber(surah);

/// Every logged recitation session, newest first, each one movable to
/// another track or removable - opened from the Quran screen's app bar,
/// beside the reading it records. The totals built from these live on
/// My Stats.
class RecentRecitationsPage extends StatelessWidget {
  const RecentRecitationsPage({super.key});

  static final DateFormat _dayTimeFormat = DateFormat('MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = RecitationTrackerManager.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.quranRecentSessions)),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final state = manager.state;
          final entries = state.mostRecentFirst;
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.quranNoSessions,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
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
                      tooltip: context.l10n.quranMoveToLabel,
                      onPressed: () =>
                          _showRelabelDialog(context, state, entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: context.l10n.commonRemove,
                      onPressed: () => manager.removeEntry(entry.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
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
          title: Text(context.l10n.quranMoveEntry(_rangeLabel(entry))),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.quranNewLabel,
                  ),
                  onSubmitted: (value) => Navigator.pop(dialogContext, value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(context.l10n.quranMove),
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
        readInJuz: entry.readInJuz,
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
        '${L10n.current.statsVerseCount(verses, '$verses')}';
  }
}
