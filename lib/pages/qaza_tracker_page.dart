import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/qaza_tracker_state.dart';
import '../services/qaza_tracker_manager.dart';
import '../widgets/responsive_content.dart';
import '../l10n/l10n.dart';

class QazaTrackerPage extends StatefulWidget {
  const QazaTrackerPage({super.key});

  @override
  State<QazaTrackerPage> createState() => _QazaTrackerPageState();
}

class _QazaTrackerPageState extends State<QazaTrackerPage> {
  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Qaza Tracker Page'));
    unawaited(QazaTrackerManager.instance.loadQaza());
  }

  @override
  Widget build(BuildContext context) {
    final manager = QazaTrackerManager.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.qazaTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.qazaCalculate,
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => unawaited(_showEstimateSheet()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final state = manager.state;
          final shouldShowLoading =
              manager.isLoading && !manager.hasLoadedQaza && state.isEmpty;

          if (shouldShowLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ResponsiveScrollableContent(
            maxWidth: compactContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isEmpty)
                  _buildBulkPrompt(context)
                else
                  _buildSummary(context, state),
                const SizedBox(height: 18),
                _buildSection(
                  context,
                  title: context.l10n.qazaPrayers,
                  trailing: _buildFullDayButton(state),
                  types: QazaEntryType.values
                      .where((type) => type.isPrayer)
                      .toList(growable: false),
                  manager: manager,
                  state: state,
                ),
                const SizedBox(height: 18),
                _buildSection(
                  context,
                  title: context.l10n.qazaFasts,
                  types: const [QazaEntryType.fast],
                  manager: manager,
                  state: state,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(BuildContext context, QazaTrackerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.qazaRemaining,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.qazaCompletedCount(state.totalCompleted),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.76),
                  ),
                ),
              ],
            ),
          ),
          Text(
            state.totalRemaining.toString(),
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    Widget? trailing,
    required List<QazaEntryType> types,
    required QazaTrackerManager manager,
    required QazaTrackerState state,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final type in types) ...[
          _buildEntryTile(
            context,
            type: type,
            count: state.countFor(type),
            manager: manager,
          ),
          if (type != types.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildEntryTile(
    BuildContext context, {
    required QazaEntryType type,
    required QazaEntryCount count,
    required QazaTrackerManager manager,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
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
                  _iconForType(type),
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
                      type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.qazaCompletedCount(count.completed),
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
                    count.remaining.toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'left',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              TextButton.icon(
                style: _compactButtonStyle,
                onPressed: count.completed > 0
                    ? () => unawaited(manager.undoCompleted(type))
                    : null,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(context.l10n.commonUndo),
              ),
              FilledButton.tonalIcon(
                style: _compactButtonStyle,
                onPressed: count.remaining > 0
                    ? () => unawaited(manager.markCompleted(type))
                    : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(type.isPrayer
                      ? context.l10n.qazaPrayed
                      : context.l10n.qazaFasted),
              ),
              TextButton.icon(
                style: _compactButtonStyle,
                onPressed: () => unawaited(manager.addMissed(type)),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.qazaMissed),
              ),
              IconButton(
                tooltip: context.l10n.qazaEditCount,
                onPressed: () => unawaited(_showEditDialog(type, count)),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final _compactButtonStyle = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 12),
    ),
  );

  Widget _buildBulkPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.qazaMissedAWhile,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.qazaMissedAWhileBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => unawaited(_showEstimateSheet()),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(context.l10n.qazaCalculate),
          ),
        ],
      ),
    );
  }

  Widget? _buildFullDayButton(QazaTrackerState state) {
    // A full day is one of each daily prayer, so it only makes sense while
    // every one of them still has something owed.
    final canLogFullDay = qazaDailyPrayers
        .every((type) => state.countFor(type).remaining > 0);

    return TextButton.icon(
      style: _compactButtonStyle,
      onPressed: canLogFullDay ? _logFullDay : null,
      icon: const Icon(Icons.done_all_rounded, size: 18),
      label: Text(context.l10n.qazaPrayedFullDay),
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
    final result = await showModalBottomSheet<_QazaEstimate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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

  IconData _iconForType(QazaEntryType type) {
    return switch (type) {
      QazaEntryType.fajr => Icons.wb_twilight_rounded,
      QazaEntryType.dhuhr => Icons.light_mode_outlined,
      QazaEntryType.asr => Icons.wb_sunny_outlined,
      QazaEntryType.maghrib => Icons.nightlight_round,
      QazaEntryType.isha => Icons.dark_mode_outlined,
      QazaEntryType.ayat => Icons.brightness_low_rounded,
      QazaEntryType.other => Icons.help_outline_rounded,
      QazaEntryType.fast => Icons.restaurant_menu_rounded,
    };
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
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final estimate = _estimate;

    final summaryLines = [
      if (estimate.prayerDays > 0)
        context.l10n.qazaEstimatePrayers(
            _formatCount(estimate.prayerDays),
            _formatCount(estimate.prayerDays * qazaDailyPrayers.length)),
      if (estimate.fasts > 0)
        context.l10n
            .qazaEstimateFasts(estimate.fasts, _formatCount(estimate.fasts)),
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.qazaCalculate,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.qazaCalculateBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(context.l10n.qazaPrayersMissedFor, style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numberField(_yearsController, context.l10n.qazaYears)),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_monthsController, context.l10n.qazaMonths)),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_daysController, context.l10n.qazaDays)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.qazaLunarNote(
                    qazaDaysPerLunarYear, qazaDaysPerMonth),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(context.l10n.qazaFastsMissed, style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              _numberField(_fastsController, context.l10n.qazaNumberOfFasts),
              const SizedBox(height: 20),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: summaryLines.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.qazaThisAdds,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            for (final line in summaryLines)
                              Text(
                                '• $line',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: estimate.isEmpty
                    ? null
                    : () => Navigator.pop(context, estimate),
                child: Text(context.l10n.qazaAddToList),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
