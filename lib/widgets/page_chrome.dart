import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'outline_icon.dart';

/// The revamp's page chrome (docs/DESIGN_SPEC.md, "Navigation"): a large
/// title with up to two actions beside it, folding into a centred one-line
/// bar once it scrolls away, over one scroll of [slivers].
///
/// On a tab root the title shares its row with the actions. Pushed, the
/// page gets the round Back button top-left with the actions top-right, and
/// the title below them.
///
/// The slivers are laid out edge to edge; pad them with [pageGutter] to
/// line up with the title, or leave a row unpadded to let it run to the
/// screen's edge (a horizontal card strip).
class LargeTitlePage extends StatefulWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.slivers,
    this.maxWidth = largeTitlePageWidth,
    this.bottom,
    this.bottomBar,
  });

  final String title;

  /// One line under the title: a count, a date, what the page is for.
  final String? subtitle;

  final List<Widget> actions;
  final List<Widget> slivers;

  /// The widest the title and [pageGutter]-padded content get.
  final double maxWidth;

  /// A control floating at the bottom, over the content, which scrolls
  /// behind it under a fade: a [FindField]. As wide as the content, 26 px
  /// off the bottom, or just above the keyboard while that is up.
  final Widget? bottom;

  /// A bar docked below the content rather than floating over it: what a
  /// playlist is playing.
  final Widget? bottomBar;

  @override
  State<LargeTitlePage> createState() => _LargeTitlePageState();
}

/// How far a control floating at the bottom of the screen (the tab bar, a
/// find field) sits from it: 26, but never closer than 8 to the system's own
/// bottom inset (home indicator, gesture or button bar); and 8 above the
/// keyboard while that is up, which the page has already been raised clear
/// of.
double floatingBottomOffset(BuildContext context) {
  if (MediaQuery.viewInsetsOf(context).bottom > 0) return 8;
  return math.max(26, MediaQuery.viewPaddingOf(context).bottom + 8);
}

/// The fade over content scrolling beneath a floating bottom control, so
/// rows do not show through below and beside it. Taps pass through.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key});

  @override
  Widget build(BuildContext context) {
    final ground = ShiaColors.of(context).ground;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ground.withValues(alpha: 0),
              ground.withValues(alpha: 0.92),
              ground,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    );
  }
}

/// [style] on top of the theme's button text: a button's `textStyle`
/// replaces the theme's rather than merging with it, so a bare [ShiaText]
/// style would lose the font family the theme sets.
TextStyle buttonTextStyle(BuildContext context, TextStyle style) =>
    (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).merge(style);

/// The content width of a [LargeTitlePage] by default; the list width the
/// pages it replaced used.
const double largeTitlePageWidth = 900;

/// Horizontal padding that keeps a [LargeTitlePage]'s content in line with
/// its title: the 16 px phone gutter (32 from tablet width up), widened to
/// centre a [maxWidth] column on a wide screen.
EdgeInsets pageGutter(BuildContext context,
    {double maxWidth = largeTitlePageWidth}) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = width >= 600 ? 32.0 : 16.0;
  final side = math.max(gutter, (width - maxWidth) / 2);
  return EdgeInsets.symmetric(horizontal: side);
}

/// The height of a [LargeTitlePage.bottom] control: a [FindField]'s.
const double _bottomControlHeight = 62;

class _LargeTitlePageState extends State<LargeTitlePage> {
  /// Whether the large title has scrolled away, so the compact bar shows.
  final ValueNotifier<bool> _compact = ValueNotifier(false);

  @override
  void dispose() {
    _compact.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    // Only the page's own scroll: a card strip scrolling sideways inside it
    // says nothing about where the title is.
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _compact.value = notification.metrics.pixels > 56;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final insets = MediaQuery.paddingOf(context);
    final pushed = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final gutter = pageGutter(context, maxWidth: widget.maxWidth);

    final title = Semantics(
      header: true,
      child: Text(
        widget.title,
        style: ShiaText.largeTitle.copyWith(color: colors.text),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          widget.actions[i],
        ],
      ],
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pushed) ...[
          Row(
            children: [
              const PageBackButton(),
              const Spacer(),
              actions,
            ],
          ),
          const SizedBox(height: 10),
          title,
        ] else
          Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              actions,
            ],
          ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            style: ShiaText.secondary.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );

    final bottom = widget.bottom;
    final bottomOffset = floatingBottomOffset(context);
    // What the last row has to clear: the floating control, or on a tab
    // root the tab bar (its height is in the bottom inset), and otherwise
    // the home indicator.
    final endPadding = bottom != null
        ? bottomOffset + _bottomControlHeight + 24
        : insets.bottom + 24;

    return Scaffold(
      backgroundColor: colors.ground,
      bottomNavigationBar: widget.bottomBar,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              keyboardDismissBehavior: bottom != null
                  ? ScrollViewKeyboardDismissBehavior.onDrag
                  : ScrollViewKeyboardDismissBehavior.manual,
              slivers: [
                SliverPadding(
                  padding: gutter.copyWith(top: insets.top + 12, bottom: 14),
                  sliver: SliverToBoxAdapter(child: header),
                ),
                ...widget.slivers,
                SliverPadding(padding: EdgeInsets.only(bottom: endPadding)),
              ],
            ),
          ),
          if (bottom != null) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomOffset + _bottomControlHeight + 62,
              child: const BottomFade(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomOffset,
              child: Padding(
                padding: gutter,
                child: bottom,
              ),
            ),
          ],
          _CompactTitleBar(
            title: widget.title,
            visible: _compact,
            topInset: insets.top,
            showBack: pushed,
          ),
        ],
      ),
    );
  }
}

/// The one-line bar a [LargeTitlePage]'s title folds into. Decorative but
/// for the Back button: the large title already headed the page.
class _CompactTitleBar extends StatelessWidget {
  const _CompactTitleBar({
    required this.title,
    required this.visible,
    required this.topInset,
    required this.showBack,
  });

  final String title;
  final ValueListenable<bool> visible;
  final double topInset;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final solid =
        !GlassSurface.blurEnabled || MediaQuery.highContrastOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget bar = Container(
      height: topInset + 52,
      padding: EdgeInsets.only(top: topInset, left: 12, right: 12),
      decoration: BoxDecoration(
        color: solid ? colors.ground : colors.ground.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: ExcludeSemantics(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.cardTitle.copyWith(color: colors.text),
              ),
            ),
          ),
          if (showBack)
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: PageBackButton(),
            ),
        ],
      ),
    );
    if (!solid) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bar,
        ),
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, show, child) => IgnorePointer(
          ignoring: !show,
          child: ExcludeSemantics(
            excluding: !show,
            child: AnimatedOpacity(
              opacity: show ? 1 : 0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              child: child,
            ),
          ),
        ),
        child: bar,
      ),
    );
  }
}

/// A 44 px round button on the page's surface with a 1 px line: the
/// revamp's icon-only page actions (Back, Recent sessions, My Stats).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// Drawn in [ShiaColors.accent] by the caller.
  final Widget icon;

  /// Read out and shown as the tooltip.
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          color: colors.surface,
          shape: CircleBorder(side: BorderSide(color: colors.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round Back button of every pushed page.
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return RoundIconButton(
      label: MaterialLocalizations.of(context).backButtonTooltip,
      icon: OutlineIcon(OutlineGlyph.chevronLeft,
          size: 22, color: colors.accent, strokeWidth: 2),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// A text action beside a large title ("Edit", "Done").
class PageTextAction extends StatelessWidget {
  const PageTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Read out instead of [label] where the word alone is ambiguous.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              // Wraps rather than overflows where a row gives it less room
              // than it would like.
              child: Text(
                label,
                textAlign: TextAlign.end,
                style: ShiaText.body.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice of a [SegmentedSwitcher].
class Segment<T> {
  const Segment(this.value, this.label);

  final T value;
  final String label;
}

/// The revamp's segmented switcher ("Surahs / Juz / Collections"): equal
/// segments in a well, the chosen one raised on the surface.
class SegmentedSwitcher<T> extends StatelessWidget {
  const SegmentedSwitcher({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // A shade between the well and the line (#EDE5DA in light): a
        // plain well would barely stand off a white card beneath.
        color: Color.lerp(colors.well, colors.line, 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _SegmentButton(
                label: segments[i].label,
                selected: segments[i].value == selected,
                position: i,
                count: segments.length,
                reduceMotion: reduceMotion,
                onTap: () => onChanged(segments[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.position,
    required this.count,
    required this.reduceMotion,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int position;
  final int count;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final radius = BorderRadius.circular(11);

    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.shellTabSemantics(label, position + 1, count),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: radius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: colors.glassShadow,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: ShiaText.secondary.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? colors.text : colors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded pill: the quick picks and verse ranges of Go to a verse, the
/// Quran collections. Filled with the accent when [selected].
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final shape = StadiumBorder(
      side: selected
          ? BorderSide.none
          : BorderSide(color: Color.lerp(colors.line, colors.chevron, 0.25)!),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? colors.accent : colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: ShiaText.secondary.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? colors.onAccent : colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A list drawn as one white card with a 1 px line (16 px corners), its
/// rows built lazily; give each row a [CardListRow].
class SliverCardList extends StatelessWidget {
  const SliverCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      sliver: SliverPadding(
        // Inside the 1 px line, so rows never paint over it.
        padding: const EdgeInsets.all(1),
        sliver: SliverList.builder(
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}

/// [SliverCardList]'s box twin, for a short list inside other content.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SliverCardList.radius),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// One row of a card list: optional [leading], a title with an optional
/// sub-line, optional [trailing]; at least 54 px tall, with a divider
/// under it unless it is the [last].
class CardListRow extends StatelessWidget {
  const CardListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.first = false,
    this.last = false,
    this.minHeight = 54,
    this.titleStyle,
  });

  /// Usually a [Text]; anything else for a title that needs more than one
  /// style (an Arabic name beside it).
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Round the ink to the card's corners at the top or bottom.
  final bool first;
  final bool last;
  final double minHeight;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    const corner = Radius.circular(SliverCardList.radius - 1);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: first ? corner : Radius.zero,
          bottom: last ? corner : Radius.zero,
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: last
              ? null
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.divider)),
                ),
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle.merge(
                        // A title's trailing Arabic ("36: Ya-Sin يس") in
                        // the Arabic font rather than whatever the UI font
                        // falls back to.
                        style: (titleStyle ?? ShiaText.body).copyWith(
                          color: colors.text,
                          fontFamilyFallback: const ['Qalam'],
                        ),
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        DefaultTextStyle.merge(
                          style: ShiaText.caption
                              .copyWith(color: colors.textMuted),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 34 px numbered well at the start of a surah or juz row; filled with
/// the accent when [selected].
class NumberWell extends StatelessWidget {
  const NumberWell(this.number,
      {super.key, this.selected = false, this.size = 34});

  final int number;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.accent : colors.well,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$number',
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? colors.onAccent : colors.text,
          ),
        ),
      ),
    );
  }
}

/// A small upper-case label over a group ("QUICK PICKS", "FROM THE QURAN").
///
/// [upperCase] off for a name, which upper-casing would mangle ("Adam
/// (a.s.)").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.upperCase = true});

  final String text;
  final bool upperCase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Semantics(
        header: true,
        child: Text(
          upperCase ? text.toUpperCase() : text,
          style: upperCase
              ? ShiaText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: ShiaColors.of(context).textMuted,
                )
              : ShiaText.secondary.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ShiaColors.of(context).text,
                ),
        ),
      ),
    );
  }
}

/// What an empty list shows instead: a glyph in a well, a line saying what
/// is missing and one on how to fill it, and an optional way forward
/// (docs/DESIGN_SPEC.md, "Never a dead end").
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.glyph,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final OutlineGlyph glyph;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SliverCardList.radius),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(17),
              ),
              child: OutlineIcon(glyph, size: 28, color: colors.accent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ShiaText.cardTitle.copyWith(color: colors.text),
            ),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  shape: const StadiumBorder(),
                  textStyle: buttonTextStyle(context, ShiaText.secondary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full-width, 50 px, fully rounded button with a glyph before its label:
/// the revamp's labelled page actions ("Continue · chapter 4, page 4",
/// "Save for offline", "Add a reminder"). [filled] for the page's main one,
/// in the accent; the rest outlined on the surface.
class PageButton extends StatelessWidget {
  const PageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.glyph,
    this.icon,
    this.filled = false,
    this.busy = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final OutlineGlyph? glyph;

  /// Drawn instead of [glyph]: a progress ring, say.
  final Widget? icon;
  final bool filled;

  /// Shows a spinner in place of the glyph, and ignores taps.
  final bool busy;

  /// Danger text on the outline, for an action that removes something.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final foreground = filled
        ? colors.onAccent
        : danger
            ? colors.danger
            : colors.accent;
    final textStyle = buttonTextStyle(context, ShiaText.body)
        .copyWith(fontWeight: FontWeight.w600);
    final glyph = this.glyph;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (icon != null)
          icon!
        else if (glyph != null)
          OutlineIcon(
            glyph,
            size: 20,
            color: foreground,
            strokeWidth: 2,
            // A play triangle reads as one when it is solid.
            filled: glyph == OutlineGlyph.play,
          ),
        if (busy || icon != null || glyph != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
    final onTap = busy ? null : onPressed;
    const minimumSize = Size.fromHeight(50);
    const padding = EdgeInsets.symmetric(horizontal: 18, vertical: 8);

    return filled
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: minimumSize,
              padding: padding,
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              disabledBackgroundColor: colors.accent.withValues(alpha: 0.6),
              disabledForegroundColor: colors.onAccent,
              shape: const StadiumBorder(),
              textStyle: textStyle,
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: minimumSize,
              padding: padding,
              foregroundColor: foreground,
              disabledForegroundColor: foreground.withValues(alpha: 0.6),
              backgroundColor: colors.surface,
              side: BorderSide(
                  color: Color.lerp(colors.line, colors.chevron, 0.25)!),
              shape: const StadiumBorder(),
              textStyle: textStyle,
            ),
            child: child,
          );
  }
}
