import 'package:flutter/material.dart';

import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'home_glyph.dart';
import 'outline_icon.dart';
import '../l10n/l10n.dart';

/// The reader's tools capsule (docs/DESIGN_SPEC.md, "Reading"): a floating
/// glass capsule in the tab bar's style holding Bookmark · Listen · Text ·
/// Counter · Share as labelled targets in the thumb zone.
///
/// When a recitation is playing the same capsule hosts the player instead of
/// the tools. Both are [barHeight] tall, so swapping between them never
/// changes its size and the text behind it never reflows.
///
/// The capsule only draws itself; the page places it ([floatingBottomOffset]
/// from the bottom, 16 from the sides) over a [BottomFade].
class ZikrActionBar extends StatelessWidget {
  /// Height of the capsule. Callers pad the scroll view by this much plus
  /// its offset from the bottom, so the last line clears it.
  static const double barHeight = 62;

  /// The capsule's width from tablet width up, centred, like the web
  /// mockup's; on a phone it runs between the 16 px gutters.
  static const double maxToolsWidth = 440;

  /// Wider while the player is in it: a title, a seek bar and its buttons
  /// need more room than five tools do.
  static const double maxPlayerWidth = 560;

  /// Shown in place of the tools - the recitation player.
  final Widget? player;

  final bool hasAudio;

  /// False drops the bookmark action altogether, as for Quran, where a
  /// recitation track keeps the reader's place instead.
  final bool showBookmark;
  final bool canBookmark;
  final bool isBookmarked;
  final bool canShare;
  final bool isCounterVisible;

  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onListen;

  /// Opens the Text & reading sheet.
  final VoidCallback onText;
  final VoidCallback onCounter;

  const ZikrActionBar({
    Key? key,
    this.player,
    required this.hasAudio,
    this.showBookmark = true,
    required this.canBookmark,
    required this.isBookmarked,
    required this.canShare,
    required this.isCounterVisible,
    required this.onBookmark,
    required this.onShare,
    required this.onListen,
    required this.onText,
    required this.onCounter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(barHeight / 2);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: player != null ? maxPlayerWidth : maxToolsWidth,
        ),
        child: GlassSurface(
          borderRadius: radius,
          child: SizedBox(
            height: barHeight,
            child: Material(
              type: MaterialType.transparency,
              child: player != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: player,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(4),
                      child: _buildActions(context),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        if (showBookmark)
          Expanded(
            child: _ZikrAction(
              icon: (color) => OutlineIcon(
                OutlineGlyph.bookmark,
                size: 22,
                color: color,
                strokeWidth: 1.9,
                filled: isBookmarked,
              ),
              label: isBookmarked
                  ? context.l10n.actionSaved
                  : context.l10n.actionBookmark,
              isActive: isBookmarked,
              onTap: canBookmark ? onBookmark : null,
            ),
          ),
        if (hasAudio)
          Expanded(
            child: _ZikrAction(
              icon: (color) => OutlineIcon(
                OutlineGlyph.play,
                size: 22,
                color: color,
                strokeWidth: 1.6,
                filled: true,
              ),
              label: context.l10n.actionListen,
              onTap: onListen,
            ),
          ),
        Expanded(
          child: _ZikrAction(
            icon: (color) => SizedBox(
              height: 22,
              child: Center(
                child: Text(
                  // A glyph, not a word - but in the reader's own letters.
                  context.l10n.textSizeGlyph,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
            label: context.l10n.actionText,
            onTap: onText,
          ),
        ),
        Expanded(
          child: _ZikrAction(
            icon: (color) => HomeGlyph(
              type: HomeGlyphType.tasbeeh,
              size: 22,
              color: color,
            ),
            label: context.l10n.actionCounter,
            isActive: isCounterVisible,
            onTap: onCounter,
          ),
        ),
        Expanded(
          child: _ZikrAction(
            icon: (color) => OutlineIcon(
              OutlineGlyph.share,
              size: 22,
              color: color,
              strokeWidth: 1.9,
            ),
            label: context.l10n.actionShare,
            onTap: canShare ? onShare : null,
          ),
        ),
      ],
    );
  }
}

/// One tool in the capsule. Toggle-style tools (bookmark, counter) show
/// their on state as a tinted pill behind the whole tool, like the selected
/// tab in the tab bar, so a glance down says whether the zikr is bookmarked.
class _ZikrAction extends StatefulWidget {
  final Widget Function(Color color) icon;
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
    // Nothing that moves on its own for someone who asked for less motion.
    if (widget.isActive &&
        !oldWidget.isActive &&
        !MediaQuery.disableAnimationsOf(context)) {
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
    final colors = ShiaColors.of(context);
    final isEnabled = widget.onTap != null;
    final iconColor =
        isEnabled ? colors.accent : colors.accent.withValues(alpha: 0.38);
    final labelColor =
        isEnabled ? colors.text : colors.text.withValues(alpha: 0.38);
    final radius = BorderRadius.circular(27);

    return Semantics(
      button: true,
      enabled: isEnabled,
      toggled: widget.isActive ? true : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: widget.isActive ? colors.selectedTint : Colors.transparent,
          borderRadius: radius,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _popScale,
                  child: ExcludeSemantics(child: widget.icon(iconColor)),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The capsule is a fixed 62 px; its labels stay at the
                  // tab bar's size however large the system text is, as
                  // the tab bar's do.
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.3),
                  style: (widget.isActive
                          ? ShiaText.tabLabelSelected
                          : ShiaText.tabLabel)
                      .copyWith(
                    color: widget.isActive && isEnabled
                        ? colors.accent
                        : labelColor,
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
