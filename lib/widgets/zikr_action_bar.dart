import 'package:flutter/material.dart';

import '../constants.dart';
import 'responsive_content.dart';

/// The docked bar along the bottom of a zikr.
///
/// It holds the actions that apply to the whole zikr — bookmark, share,
/// listen, reading settings, counter — as labelled targets in the thumb
/// zone. Bookmark in particular was previously an unlabelled ribbon icon
/// sharing a crowded app bar, which is a poor affordance for the app's
/// single most useful action.
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
  final VoidCallback onSettings;
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
    required this.onSettings,
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
            icon: Icons.tune,
            label: 'Settings',
            onTap: onSettings,
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

/// One action in the bar. Toggle-style actions (bookmark, counter) render
/// their active state as a filled pill behind the icon rather than just a
/// tint — a reader glancing down should see at once whether the zikr is
/// bookmarked, not have to notice a subtler color/weight change on text
/// that scrolled away with the rest of the bar a moment ago.
class _ZikrAction extends StatefulWidget {
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
  State<_ZikrAction> createState() => _ZikrActionState();
}

class _ZikrActionState extends State<_ZikrAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 65),
    ]).animate(CurvedAnimation(parent: _popController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _ZikrAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bookmarking is worth a little celebration; un-bookmarking is not - a
    // bounce on the way out would read as an error shake rather than an undo.
    if (widget.isActive && !oldWidget.isActive) {
      _popController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = widget.onTap != null;

    final iconColor = !isEnabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
        : widget.isActive
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant;
    final labelColor = !isEnabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
        : widget.isActive
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        // The pill's own padding already pushes the icon outward, so this
        // outer padding is tighter than a plain icon+label would need - at
        // 320px wide (5 actions, the real squeeze case) the two together
        // were 1px from overflowing the bar's fixed height.
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _popScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, size: 22, color: iconColor),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: widget.isActive ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
