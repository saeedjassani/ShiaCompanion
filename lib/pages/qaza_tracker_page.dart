import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/qaza_tracker_state.dart';
import '../services/qaza_tracker_manager.dart';
import '../widgets/responsive_content.dart';

class QazaTrackerPage extends StatefulWidget {
  const QazaTrackerPage({super.key});

  @override
  State<QazaTrackerPage> createState() => _QazaTrackerPageState();
}

class _QazaTrackerPageState extends State<QazaTrackerPage> {
  /// Set when someone on the empty state picks "enter counts myself", so the
  /// per-prayer rows show before anything has been counted.
  bool _showEmptyRows = false;

  /// Namaz e Ayat and Other are rarely used, so they stay tucked away until
  /// they hold a count or someone asks for them.
  bool _showOtherPrayers = false;

  static const _otherPrayers = [QazaEntryType.ayat, QazaEntryType.other];

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
        title: const Text('Qaza Tracker'),
        actions: [
          IconButton(
            tooltip: 'How it works',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => unawaited(_showHelpSheet()),
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

          final showRows = !state.isEmpty || _showEmptyRows;
          final showOtherPrayers = _showOtherPrayers ||
              _otherPrayers.any((type) => !state.countFor(type).isEmpty);

          return ResponsiveScrollableContent(
            maxWidth: compactContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isEmpty)
                  _buildWelcome(context)
                else
                  _buildSummary(context, state),
                if (showRows) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    context,
                    title: 'Daily prayers',
                    trailing: _buildFullDayButton(context, state),
                  ),
                  for (final type in qazaDailyPrayers)
                    _buildEntryRow(context, type, state.countFor(type)),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, title: 'Fasts'),
                  _buildEntryRow(
                    context,
                    QazaEntryType.fast,
                    state.countFor(QazaEntryType.fast),
                  ),
                  const SizedBox(height: 16),
                  if (showOtherPrayers) ...[
                    _buildSectionHeader(context, title: 'Other prayers'),
                    for (final type in _otherPrayers)
                      _buildEntryRow(context, type, state.countFor(type)),
                  ] else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _showOtherPrayers = true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Track Namaz e Ayat or other prayers'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_showEstimateSheet()),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Add a missed period'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 36,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 12),
          Text(
            'Keep track of prayers and fasts you need to make up',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by telling us roughly how much you missed. Then, every '
            'time you pray a qaza, tap its button here and watch the '
            'count go down.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => unawaited(_showEstimateSheet()),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Work it out from time missed'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _showEmptyRows
                  ? null
                  : () => setState(() => _showEmptyRows = true),
              child: const Text('I know my exact counts'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, QazaTrackerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = state.totalRemaining + state.totalCompleted;
    final progress = total == 0 ? 0.0 : state.totalCompleted / total;
    final fastsLeft = state.countFor(QazaEntryType.fast).remaining;
    final prayersLeft = state.totalRemaining - fastsLeft;
    final allDone = state.totalRemaining == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allDone ? 'All caught up' : 'Still to make up',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (allDone)
            Text(
              'Alhamdulillah - nothing left on your list.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 4,
              children: [
                if (prayersLeft > 0)
                  _buildSummaryFigure(
                    context,
                    value: prayersLeft,
                    label: prayersLeft == 1 ? 'prayer' : 'prayers',
                  ),
                if (fastsLeft > 0)
                  _buildSummaryFigure(
                    context,
                    value: fastsLeft,
                    label: fastsLeft == 1 ? 'fast' : 'fasts',
                  ),
              ],
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.onPrimaryContainer.withValues(
                alpha: 0.12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatCount(state.totalCompleted)} of ${_formatCount(total)} '
            'made up (${(progress * 100).floor()}%)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryFigure(
    BuildContext context, {
    required int value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _formatCount(value),
            style: theme.textTheme.displaySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
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
    );
  }

  Widget? _buildFullDayButton(BuildContext context, QazaTrackerState state) {
    final owedPrayers = qazaDailyPrayers
        .where((type) => state.countFor(type).remaining > 0)
        .length;
    if (owedPrayers < 2) return null;

    return TextButton.icon(
      onPressed: _logFullDay,
      icon: const Icon(Icons.done_all_rounded, size: 18),
      label: const Text('Prayed a full day'),
    );
  }

  Widget _buildEntryRow(
    BuildContext context,
    QazaEntryType type,
    QazaEntryCount count,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFinished = count.remaining == 0 && count.completed > 0;
    final progress = count.total == 0 ? 0.0 : count.completed / count.total;

    final String subtitle;
    if (count.isEmpty) {
      subtitle = 'Nothing owed - tap to set';
    } else if (isFinished) {
      subtitle = 'All ${_formatCount(count.completed)} made up';
    } else {
      subtitle = '${_formatCount(count.completed)} of '
          '${_formatCount(count.total)} made up';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_showEditSheet(type)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFinished ? Icons.check_rounded : _iconForType(type),
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (count.remaining > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${_formatCount(count.remaining)} left',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!count.isEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (count.remaining > 0)
                  FilledButton.tonal(
                    onPressed: () => _logOne(type),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(type.isPrayer ? 'Prayed' : 'Fasted'),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logOne(QazaEntryType type) {
    final manager = QazaTrackerManager.instance;
    unawaited(HapticFeedback.lightImpact());
    unawaited(manager.markCompleted(type));

    final left = manager.state.countFor(type).remaining;
    _showUndoSnackBar(
      '${type.label} qaza logged - ${_formatCount(left)} left',
      () => unawaited(manager.undoCompleted(type)),
    );
  }

  void _logFullDay() {
    final manager = QazaTrackerManager.instance;
    final marked = manager.markCompletedEach(qazaDailyPrayers);
    if (marked.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());

    _showUndoSnackBar(
      marked.length == qazaDailyPrayers.length
          ? 'Logged one of each daily prayer'
          : 'Logged ${marked.map((type) => type.label).join(', ')}',
      () => manager.undoCompletedEach(marked),
    );
  }

  void _showUndoSnackBar(String message, VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
  }

  Future<void> _showEditSheet(QazaEntryType type) async {
    final count = QazaTrackerManager.instance.state.countFor(type);
    final result = await showModalBottomSheet<QazaEntryCount>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _QazaEditSheet(type: type, initial: count),
    );
    if (result == null) return;

    await QazaTrackerManager.instance.setCount(
      type,
      remaining: result.remaining,
      completed: result.completed,
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
      const SnackBar(content: Text('Added to your qaza list')),
    );
  }

  Future<void> _showHelpSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        Widget step(IconData icon, String title, String body) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(body, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How the Qaza Tracker works',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                step(
                  Icons.calculate_outlined,
                  '1. Add what you owe',
                  'Use "Add a missed period" to add a span of days, months '
                      'or years at once - one of each daily prayer is added '
                      'per day. Or tap any prayer to type an exact number.',
                ),
                step(
                  Icons.check_circle_outline_rounded,
                  '2. Log each qaza you pray',
                  'Tap "Prayed" (or "Fasted") after offering one. Praying '
                      'a whole day\'s worth? Use "Prayed a full day" to log '
                      'one of each daily prayer.',
                ),
                step(
                  Icons.undo_rounded,
                  '3. Fix mistakes',
                  'Tap "Undo" on the message that appears, or tap the '
                      'prayer to correct its numbers directly.',
                ),
                step(
                  Icons.cloud_done_outlined,
                  'Private and synced',
                  'Your counts are only visible to you. Sign in to keep '
                      'them backed up across devices.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForType(QazaEntryType type) {
    return switch (type) {
      QazaEntryType.fajr => Icons.wb_twilight_rounded,
      QazaEntryType.dhuhr => Icons.light_mode_outlined,
      QazaEntryType.asr => Icons.wb_sunny_outlined,
      QazaEntryType.maghrib => Icons.nightlight_round,
      QazaEntryType.isha => Icons.dark_mode_outlined,
      QazaEntryType.ayat => Icons.brightness_low_rounded,
      QazaEntryType.other => Icons.more_horiz_rounded,
      QazaEntryType.fast => Icons.restaurant_menu_rounded,
    };
  }
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

/// A number field with - / + buttons either side, for the edit sheet.
class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final TextEditingController controller;
  final VoidCallback onChanged;

  int get _value => int.tryParse(controller.text) ?? 0;

  void _set(int value) {
    controller.text = (value < 0 ? 0 : value).toString();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            tooltip: 'Decrease $label',
            onPressed: _value > 0 ? () => _set(_value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            tooltip: 'Increase $label',
            onPressed: () => _set(_value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _QazaEditSheet extends StatefulWidget {
  const _QazaEditSheet({required this.type, required this.initial});

  final QazaEntryType type;
  final QazaEntryCount initial;

  @override
  State<_QazaEditSheet> createState() => _QazaEditSheetState();
}

class _QazaEditSheetState extends State<_QazaEditSheet> {
  late final _remainingController =
      TextEditingController(text: widget.initial.remaining.toString());
  late final _completedController =
      TextEditingController(text: widget.initial.completed.toString());

  @override
  void dispose() {
    _remainingController.dispose();
    _completedController.dispose();
    super.dispose();
  }

  QazaEntryCount get _current => QazaEntryCount(
        remaining: int.tryParse(_remainingController.text) ?? 0,
        completed: int.tryParse(_completedController.text) ?? 0,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noun = widget.type.isPrayer ? 'prayers' : 'fasts';
    final hasCounts = !widget.initial.isEmpty;

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
                widget.type.isPrayer
                    ? '${widget.type.label} qaza'
                    : 'Qaza fasts',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set the exact numbers if you already know them.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _StepperField(
                label: 'Still to make up',
                helper: '$noun you still owe',
                controller: _remainingController,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              _StepperField(
                label: 'Already made up',
                helper: '$noun you have prayed back so far',
                controller: _completedController,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, _current),
                child: const Text('Save'),
              ),
              if (hasCounts) ...[
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () => unawaited(_confirmReset()),
                  child: Text('Reset ${widget.type.label} to zero'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset ${widget.type.label}?'),
        content: const Text(
          'This clears both what you still owe and what you have made up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, QazaEntryCount.zero);
    }
  }
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
        '${_formatCount(estimate.prayerDays)} of each daily prayer '
            '(${_formatCount(estimate.prayerDays * qazaDailyPrayers.length)} '
            'prayers)',
      if (estimate.fasts > 0)
        '${_formatCount(estimate.fasts)} '
            '${estimate.fasts == 1 ? 'fast' : 'fasts'}',
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
                'Add a missed period',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Roughly how long did you not pray? A best estimate is fine '
                '- you can adjust any prayer later.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('Prayers missed for', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numberField(_yearsController, 'Years')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_monthsController, 'Months')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_daysController, 'Days')),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Counted as lunar years of $qazaDaysPerLunarYear days and '
                'months of $qazaDaysPerMonth days.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('Fasts missed', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              _numberField(_fastsController, 'Number of fasts'),
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
                              'This adds to your list:',
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
                child: const Text('Add to my list'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
