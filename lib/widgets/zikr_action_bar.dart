import 'package:flutter/material.dart';

import '../constants.dart';
import 'responsive_content.dart';

/// The docked bar along the bottom of a zikr.
///
/// It holds the actions that apply to the whole zikr — bookmark, share,
/// listen, counter — as labelled targets in the thumb zone. Bookmark in
/// particular was previously an unlabelled ribbon icon sharing a crowded app
/// bar, which is a poor affordance for the app's single most useful action.
///
/// When a recitation is playing the same bar hosts the player instead of the
/// action row. Both are [barHeight] tall, so swapping between them never
/// changes the bar's size and the text behind it never reflows.
class ZikrActionBar extends StatelessWidget {
  /// Height of the bar's content, excluding the bottom safe area. Callers pad
  /// the scroll view by this much so the last line clears the bar.
  static const double barHeight = 62;

  /// Shown in place of the action row — the recitation player.
  final Widget? player;

  final bool hasAudio;
  final bool canBookmark;
  final bool isBookmarked;
  final bool canShare;
  final bool isCounterVisible;

  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onListen;
  final VoidCallback onCounter;

  const ZikrActionBar({
    Key? key,
    this.player,
    required this.hasAudio,
    required this.canBookmark,
    required this.isBookmarked,
    required this.canShare,
    required this.isCounterVisible,
    required this.onBookmark,
    required this.onShare,
    required this.onListen,
    required this.onCounter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          SizedBox(
            height: barHeight,
            // The reading column is centred on wide screens, so the bar's
            // contents follow it rather than stretching the full width.
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: readingContentWidth),
                child: player ?? _buildActions(context),
              ),
            ),
          ),
          // Painted background continues under the home indicator; the
          // controls themselves stay above it.
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ZikrAction(
            icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            label: isBookmarked ? 'Saved' : 'Bookmark',
            isActive: isBookmarked,
            onTap: canBookmark ? onBookmark : null,
          ),
        ),
        Expanded(
          child: _ZikrAction(
            icon: Icons.share,
            label: 'Share',
            onTap: canShare ? onShare : null,
          ),
        ),
        if (hasAudio)
          Expanded(
            child: _ZikrAction(
              icon: Icons.headphones,
              label: 'Listen',
              onTap: onListen,
            ),
          ),
        Expanded(
          child: _ZikrAction(
            icon: tasbeehCounterIcon,
            label: 'Counter',
            isActive: isCounterVisible,
            onTap: onCounter,
          ),
        ),
      ],
    );
  }
}

class _ZikrAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ZikrAction({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onTap != null;

    final color = !isEnabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
        : isActive
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: isActive ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
