import 'package:flutter/material.dart';

import '../../theme/shia_colors.dart';

/// Home's breakpoint for its two-column layout (docs/DESIGN_SPEC.md,
/// "Responsive behaviour").
const double homeWideBreakpoint = 600;

bool isHomeWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= homeWideBreakpoint;

/// How tall a wide screen must be for Shortcuts to show every feature: the
/// extra row fits in the room a portrait tablet or a 1080p desktop leaves
/// under the hadith, where a laptop or a landscape tablet already scrolls.
const double homeAllFeaturesMinHeight = 900;

/// Whether Home's Shortcuts show every feature instead of the reader's picks
/// and an All features tile.
bool homeShowsAllFeatures(BuildContext context) =>
    isHomeWide(context) &&
    MediaQuery.sizeOf(context).height >= homeAllFeaturesMinHeight;

/// A section's title, with an optional text action on the right ("Edit",
/// "Calendar").
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionSemanticsLabel,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Read out instead of [actionLabel] where the word alone is ambiguous
  /// ("Edit" -> "Edit shortcuts").
  final String? actionSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final style = isHomeWide(context)
        ? ShiaText.sectionTitle.copyWith(fontSize: 21, height: 26 / 21)
        : ShiaText.sectionTitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: style.copyWith(color: colors.text)),
          ),
        ),
        if (actionLabel != null)
          Semantics(
            button: true,
            label: actionSemanticsLabel ?? actionLabel,
            excludeSemantics: true,
            onTap: onAction,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      actionLabel!,
                      style: ShiaText.secondary.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The white card with a 1 px line that most Home sections sit in.
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}
