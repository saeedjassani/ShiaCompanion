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
      appBar: AppBar(title: const Text('Qaza Tracker')),
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
                _buildSummary(context, state),
                const SizedBox(height: 18),
                _buildSection(
                  context,
                  title: 'Prayers',
                  types: QazaEntryType.values
                      .where((type) => type.isPrayer)
                      .toList(growable: false),
                  manager: manager,
                  state: state,
                ),
                const SizedBox(height: 18),
                _buildSection(
                  context,
                  title: 'Fasts',
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
                  'Qaza remaining',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${state.totalCompleted} completed',
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
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                      '${count.completed} completed',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Undo completed',
                onPressed: count.completed > 0
                    ? () => unawaited(manager.undoCompleted(type))
                    : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Complete one',
                onPressed: count.remaining > 0
                    ? () => unawaited(manager.markCompleted(type))
                    : null,
                icon: const Icon(Icons.check_rounded),
              ),
              IconButton(
                tooltip: 'Add missed',
                onPressed: () => unawaited(manager.addMissed(type)),
                icon: const Icon(Icons.add_rounded),
              ),
              IconButton(
                tooltip: 'Edit count',
                onPressed: () => unawaited(_showEditDialog(type, count)),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
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
                decoration: const InputDecoration(
                  labelText: 'Remaining',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: completedController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Completed',
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
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Save'),
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
