import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/qaza_tracker_state.dart';
import '../services/qaza_tracker_manager.dart';
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import 'stats/stats_widgets.dart';
import '../l10n/l10n.dart';

class QazaTrackerPage extends StatefulWidget {
  const QazaTrackerPage({super.key});

  @override
  State<QazaTrackerPage> createState() => _QazaTrackerPageState();
}

class _QazaTrackerPageState extends State<QazaTrackerPage> {
  /// Namaz-e-Ayat and Other show once they hold something, or once asked
  /// for: most people only ever owe the five daily prayers.
  bool _showExtras = false;

  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Qaza Tracker Page'));
    unawaited(QazaTrackerManager.instance.loadQaza());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final manager = QazaTrackerManager.instance;
    final gutter = pageGutter(context, maxWidth: compactContentWidth);

    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final state = manager.state;
        final shouldShowLoading =
            manager.isLoading && !manager.hasLoadedQaza && state.isEmpty;

        Widget section(Widget child, {double bottom = 18}) => SliverPadding(
              padding: gutter.copyWith(bottom: bottom),
              sliver: SliverToBoxAdapter(child: child),
            );

        bool used(QazaEntryType type) {
          final count = state.countFor(type);
          return count.remaining > 0 || count.completed > 0;
        }

        final extras = const [QazaEntryType.ayat, QazaEntryType.other];
        final showExtras = _showExtras || extras.any(used);
        final prayers = [
          ...qazaDailyPrayers,
          if (showExtras) ...extras,
        ];

        return LargeTitlePage(
          title: l10n.qazaPageTitle,
          subtitle: l10n.qazaSubtitle,
          maxWidth: compactContentWidth,
          slivers: shouldShowLoading
              ? const [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ]
              : [
                  section(state.isEmpty
                      ? _buildBulkPrompt(context)
                      : _buildSummary(context, state)),
                  section(
                    Row(
                      children: [
                        Expanded(child: GroupLabel(l10n.qazaPrayers)),
                        if (!showExtras)
                          Flexible(
                            flex: 2,
                            child: PageTextAction(
                              label: l10n.qazaShowExtras,
                              onPressed: () =>
                                  setState(() => _showExtras = true),
                            ),
                          ),
                      ],
                    ),
                    bottom: 8,
                  ),
                  section(_buildCard(context, prayers, state)),
                  section(GroupLabel(l10n.qazaFasts), bottom: 8),
                  section(
                    _buildCard(context, const [QazaEntryType.fast], state),
                    bottom: 0,
                  ),
                ],
        );
      },
    );
  }

  /// Left to make up in large type, how many are done and a bar of the
  /// two, and the two ways to change many at once.
  Widget _buildSummary(BuildContext context, QazaTrackerState state) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final left = state.totalRemaining;
    final done = state.totalCompleted;
    final total = left + done;
    // A full day is one of each daily prayer, so it only makes sense while
    // every one of them still has something owed.
    final canLogFullDay =
        qazaDailyPrayers.every((type) => state.countFor(type).remaining > 0);

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCount(left),
                      style: ShiaText.largeTitle.copyWith(
                        fontSize: 40,
                        height: 46 / 40,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      l10n.qazaLeftToMakeUp,
                      style:
                          ShiaText.secondary.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.qazaDoneCount(_formatCount(done)),
                  style: ShiaText.cardTitle.copyWith(color: colors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              color: colors.accent,
              backgroundColor: colors.divider,
            ),
          ),
          const SizedBox(height: 12),
          PageButton(
            glyph: OutlineGlyph.check,
            label: l10n.qazaPrayedFullDay,
            onPressed: canLogFullDay ? _logFullDay : null,
          ),
          const SizedBox(height: 8),
          PageButton(
            glyph: OutlineGlyph.calendar,
            label: l10n.qazaWorkOut,
            onPressed: () => unawaited(_showEstimateSheet()),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    List<QazaEntryType> types,
    QazaTrackerState state,
  ) {
    return CardList(
      children: [
        for (var i = 0; i < types.length; i++)
          _buildRow(
            context,
            types[i],
            state.countFor(types[i]),
            first: i == 0,
            last: i == types.length - 1,
          ),
      ],
    );
  }

  /// One prayer, or the fasts: "248 left · 12 done", one Prayed button,
  /// and ⋯ for the rest.
  Widget _buildRow(
    BuildContext context,
    QazaEntryType type,
    QazaEntryCount count, {
    required bool first,
    required bool last,
  }) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final manager = QazaTrackerManager.instance;
    final left = _formatCount(count.remaining);
    final line = l10n.qazaLeftAndDone(left, _formatCount(count.completed));
    final at = line.indexOf(left);

    return CardListRow(
      first: first,
      last: last,
      minHeight: 64,
      title: Text(type.label),
      titleStyle: ShiaText.cardTitle,
      subtitle: Text.rich(
        TextSpan(
          children: at < 0
              ? [TextSpan(text: line)]
              : [
                  TextSpan(text: line.substring(0, at)),
                  TextSpan(
                    text: left,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  TextSpan(text: line.substring(at + left.length)),
                ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DoneButton(
            label: type.isPrayer ? l10n.qazaPrayed : l10n.qazaFasted,
            onPressed: count.remaining > 0
                ? () => unawaited(manager.markCompleted(type))
                : null,
          ),
          Builder(
            builder: (anchor) => MoreButton(
              label: l10n.qazaMoreFor(type.label),
              onPressed: () => _showRowMenu(anchor, type, count),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRowMenu(
    BuildContext anchor,
    QazaEntryType type,
    QazaEntryCount count,
  ) async {
    final l10n = anchor.l10n;
    final value = await showMenuAt<String>(anchor, [
      PopupMenuItem(value: 'missed', child: Text(l10n.qazaAddMissedOne)),
      if (count.completed > 0)
        PopupMenuItem(value: 'undo', child: Text(l10n.commonUndo)),
      PopupMenuItem(value: 'edit', child: Text(l10n.qazaEditCount)),
    ]);
    if (!mounted) return;
    final manager = QazaTrackerManager.instance;
    switch (value) {
      case 'missed':
        unawaited(manager.addMissed(type));
      case 'undo':
        unawaited(manager.undoCompleted(type));
      case 'edit':
        unawaited(_showEditDialog(type, count));
    }
  }

  Widget _buildBulkPrompt(BuildContext context) {
    final colors = ShiaColors.of(context);

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.qazaMissedAWhile,
            style: ShiaText.cardTitle.copyWith(color: colors.text),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.qazaMissedAWhileBody,
            style: ShiaText.secondary.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 14),
          PageButton(
            filled: true,
            glyph: OutlineGlyph.calendar,
            label: context.l10n.qazaWorkOut,
            onPressed: () => unawaited(_showEstimateSheet()),
          ),
        ],
      ),
    );
  }

  void _logFullDay() {
    final manager = QazaTrackerManager.instance;
    final marked = manager.markCompletedEach(qazaDailyPrayers);
    if (marked.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.qazaLoggedFullDay,
        ),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => manager.undoCompletedEach(marked),
        ),
      ),
    );
  }

  Future<void> _showEstimateSheet() async {
    final result = await showRevampSheet<_QazaEstimate>(
      context,
      title: context.l10n.qazaCalculate,
      closeLabel: context.l10n.commonCancel,
      builder: (context) => const _QazaEstimateSheet(),
    );
    if (result == null || result.isEmpty) return;

    await QazaTrackerManager.instance.addMissedCounts({
      for (final type in qazaDailyPrayers) type: result.prayerDays,
      QazaEntryType.fast: result.fasts,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.qazaAddedToList)),
    );
  }

  Future<void> _showEditDialog(
    QazaEntryType type,
    QazaEntryCount count,
  ) async {
    final remainingController = TextEditingController(
      text: count.remaining.toString(),
    );
    final completedController = TextEditingController(
      text: count.completed.toString(),
    );

    try {
      final result = await showDialog<_QazaEditResult>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(type.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: remainingController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.l10n.qazaRemainingLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: completedController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.l10n.qazaCompletedLabel,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const _QazaEditResult(remaining: 0, completed: 0),
              ),
              child: Text(context.l10n.commonClear),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _QazaEditResult(
                    remaining: int.tryParse(remainingController.text) ?? 0,
                    completed: int.tryParse(completedController.text) ?? 0,
                  ),
                );
              },
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      );

      if (result == null) return;
      await QazaTrackerManager.instance.setCount(
        type,
        remaining: result.remaining,
        completed: result.completed,
      );
    } finally {
      remainingController.dispose();
      completedController.dispose();
    }
  }
}

/// The tinted pill that marks one made up: "Prayed", "Fasted".
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final enabled = onPressed != null;
    final foreground = enabled ? colors.accent : colors.chevron;
    return Material(
      color: colors.accent.withValues(alpha: enabled ? 0.16 : 0.06),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlineIcon(OutlineGlyph.check,
                    size: 18, color: foreground, strokeWidth: 2.4),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: ShiaText.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QazaEditResult {
  const _QazaEditResult({
    required this.remaining,
    required this.completed,
  });

  final int remaining;
  final int completed;
}

String _formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _QazaEstimate {
  const _QazaEstimate({required this.prayerDays, required this.fasts});

  final int prayerDays;
  final int fasts;

  bool get isEmpty => prayerDays == 0 && fasts == 0;
}

class _QazaEstimateSheet extends StatefulWidget {
  const _QazaEstimateSheet();

  @override
  State<_QazaEstimateSheet> createState() => _QazaEstimateSheetState();
}

class _QazaEstimateSheetState extends State<_QazaEstimateSheet> {
  final _yearsController = TextEditingController();
  final _monthsController = TextEditingController();
  final _daysController = TextEditingController();
  final _fastsController = TextEditingController();

  @override
  void dispose() {
    _yearsController.dispose();
    _monthsController.dispose();
    _daysController.dispose();
    _fastsController.dispose();
    super.dispose();
  }

  int _read(TextEditingController controller) =>
      int.tryParse(controller.text) ?? 0;

  _QazaEstimate get _estimate => _QazaEstimate(
        prayerDays: qazaDaysForSpan(
          years: _read(_yearsController),
          months: _read(_monthsController),
          days: _read(_daysController),
        ),
        fasts: _read(_fastsController),
      );

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: ShiaText.body.copyWith(color: ShiaColors.of(context).text),
      decoration: revampFieldDecoration(context, label: label, hint: '0'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final estimate = _estimate;

    final summaryLines = [
      if (estimate.prayerDays > 0)
        l10n.qazaEstimatePrayers(_formatCount(estimate.prayerDays),
            _formatCount(estimate.prayerDays * qazaDailyPrayers.length)),
      if (estimate.fasts > 0)
        l10n.qazaEstimateFasts(estimate.fasts, _formatCount(estimate.fasts)),
    ];
    Widget note(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            style: ShiaText.caption.copyWith(
              height: 18 / 13,
              color: colors.textMuted,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.qazaCalculateBody,
            style: ShiaText.secondary.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: 18),
        GroupLabel(l10n.qazaPrayersMissedFor),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _numberField(_yearsController, l10n.qazaYears)),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_monthsController, l10n.qazaMonths)),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_daysController, l10n.qazaDays)),
          ],
        ),
        const SizedBox(height: 6),
        note(l10n.qazaLunarNote(qazaDaysPerLunarYear, qazaDaysPerMonth)),
        const SizedBox(height: 18),
        GroupLabel(l10n.qazaFastsMissed),
        const SizedBox(height: 8),
        _numberField(_fastsController, l10n.qazaNumberOfFasts),
        const SizedBox(height: 18),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          child: summaryLines.isEmpty
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.tintedNotice,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.qazaThisAdds,
                        style: ShiaText.secondary.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final line in summaryLines)
                        Text(
                          '• $line',
                          style: ShiaText.secondary.copyWith(color: colors.text),
                        ),
                    ],
                  ),
                ),
        ),
        PageButton(
          label: l10n.qazaAddToList,
          glyph: OutlineGlyph.plus,
          filled: true,
          onPressed: estimate.isEmpty
              ? null
              : () => Navigator.pop(context, estimate),
        ),
      ],
    );
  }
}
