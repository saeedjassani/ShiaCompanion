import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/stats_milestones.dart';
import 'stats_widgets.dart';

final NumberFormat _count = NumberFormat.decimalPattern();

IconData _iconFor(MilestoneKind kind) => switch (kind) {
      MilestoneKind.streak => Icons.local_fire_department_rounded,
      MilestoneKind.verses => Icons.format_quote_rounded,
      MilestoneKind.zikrs => Icons.auto_awesome_rounded,
      MilestoneKind.juz => Icons.grid_view_rounded,
      MilestoneKind.khatm => Icons.workspace_premium_rounded,
    };

String milestoneTitle(Milestone milestone) {
  final target = milestone.target;
  return switch (milestone.kind) {
    MilestoneKind.streak => '$target-day streak',
    MilestoneKind.verses => '${_count.format(target)} verses',
    MilestoneKind.zikrs => '${_count.format(target)} zikrs',
    MilestoneKind.juz => target == 1 ? 'First juz' : '$target juz',
    MilestoneKind.khatm => switch (target) {
        1 => 'First khatm',
        _ => '$target khatms',
      },
  };
}

String _remainingText(Milestone milestone) {
  final left = milestone.remaining;
  return switch (milestone.kind) {
    MilestoneKind.streak => '$left more ${left == 1 ? 'day' : 'days'} in a row',
    MilestoneKind.verses => '${_count.format(left)} more verses',
    MilestoneKind.zikrs => '${_count.format(left)} more',
    MilestoneKind.juz => '$left more juz',
    MilestoneKind.khatm => '$left more',
  };
}

/// The next goal on each ladder with a bar for how close it is, then every
/// badge already earned.
class MilestonesSection extends StatelessWidget {
  const MilestonesSection({super.key, required this.milestones});

  final List<Milestone> milestones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final next = nextMilestones(milestones).take(3).toList();
    final earned = milestones.where((m) => m.isEarned).toList();

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: StatsSectionTitle('Milestones')),
              Text(
                '${earned.length} of ${milestones.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Up next',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            for (final milestone in next) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _iconFor(milestone.kind),
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                milestoneTitle(milestone),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _remainingText(milestone),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: milestone.progress,
                            minHeight: 6,
                            backgroundColor:
                                colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (earned.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Earned',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final milestone in earned)
                  Chip(
                    avatar: Icon(
                      _iconFor(milestone.kind),
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    label: Text(milestoneTitle(milestone)),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
