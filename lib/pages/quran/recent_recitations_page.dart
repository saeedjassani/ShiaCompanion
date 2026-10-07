import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import '../../l10n/l10n.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';

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
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final manager = RecitationTrackerManager.instance;
    final gutter = pageGutter(context);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final state = manager.state;
        final entries = state.mostRecentFirst;
        return LargeTitlePage(
          title: l10n.quranRecentSessions,
          slivers: [
            if (entries.isEmpty)
              SliverPadding(
                padding: gutter,
                sliver: SliverToBoxAdapter(
                  child: EmptyStateCard(
                    glyph: OutlineGlyph.history,
                    title: l10n.quranRecentSessions,
                    body: l10n.quranNoSessions,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: gutter,
                sliver: SliverCardList(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final range = _rangeLabel(entry);
                    return CardListRow(
                      first: index == 0,
                      last: index == entries.length - 1,
                      title: Text(range),
                      subtitle: Text(
                        '${entry.label} · '
                        '${_dayTimeFormat.format(entry.recitedAt.toLocal())}',
                      ),
                      trailing: Builder(
                        builder: (anchor) => MoreButton(
                          label: range,
                          onPressed: () async {
                            final action = await showMenuAt<_EntryAction>(
                              anchor,
                              [
                                PopupMenuItem(
                                  value: _EntryAction.move,
                                  child: Text(l10n.quranMoveToLabel),
                                ),
                                PopupMenuItem(
                                  value: _EntryAction.remove,
                                  child: Text(
                                    l10n.commonRemove,
                                    style: TextStyle(color: colors.danger),
                                  ),
                                ),
                              ],
                            );
                            if (!context.mounted) return;
                            switch (action) {
                              case _EntryAction.move:
                                await _showRelabelSheet(context, state, entry);
                              case _EntryAction.remove:
                                await manager.removeEntry(entry.id);
                              case null:
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showRelabelSheet(
    BuildContext context,
    RecitationTrackerState state,
    RecitationEntry entry,
  ) async {
    final choices = [...state.labels, unlabeledRecitationLabel]
        .where((label) => label != entry.label)
        .toList(growable: false);

    final newLabel = await showRevampSheet<String>(
      context,
      title: context.l10n.quranMoveEntry(_rangeLabel(entry)),
      builder: (_) => _RelabelForm(choices: choices),
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

enum _EntryAction { move, remove }

/// The other tracks as pills, or a new one typed in. Pops the label chosen.
class _RelabelForm extends StatefulWidget {
  const _RelabelForm({required this.choices});

  final List<String> choices;

  @override
  State<_RelabelForm> createState() => _RelabelFormState();
}

class _RelabelFormState extends State<_RelabelForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.choices.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in widget.choices)
                ChoicePill(
                  label: label,
                  onTap: () => Navigator.pop(context, label),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.words,
          decoration: revampFieldDecoration(context, label: l10n.quranNewLabel),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        const SizedBox(height: 14),
        PageButton(
          label: l10n.quranMove,
          filled: true,
          onPressed: () => Navigator.pop(context, _controller.text),
        ),
      ],
    );
  }
}
