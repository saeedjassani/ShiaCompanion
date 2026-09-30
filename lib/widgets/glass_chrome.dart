import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Whether navigation chrome (tab bars, and later the search field) should be
/// drawn as floating, bottom-anchored glass instead of Material's top bars.
///
/// iOS only: iOS 26's Liquid Glass puts tabs and search within thumb reach
/// at the bottom, and that is what iPhone users expect. Android keeps its
/// Material layout. Reads [ThemeData.platform] rather than `dart:io` so it
/// works on web (an iPhone browser gets the iOS layout) and tests can
/// override it.
bool useGlassChrome(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// The colors and blur of the glass chrome, kept on the theme so light and
/// dark each get a tint that reads well over the app's own surfaces.
@immutable
class GlassStyle extends ThemeExtension<GlassStyle> {
  const GlassStyle({
    required this.blurSigma,
    required this.tint,
    required this.highlight,
    required this.border,
    required this.shadow,
    required this.selectedFill,
    required this.selectedForeground,
    required this.unselectedForeground,
  });

  factory GlassStyle.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return GlassStyle(
      blurSigma: 18,
      tint: isDark
          ? scheme.surfaceContainerHigh.withValues(alpha: 0.55)
          : scheme.surface.withValues(alpha: 0.62),
      highlight: Colors.white.withValues(alpha: isDark ? 0.08 : 0.35),
      border: Colors.white.withValues(alpha: isDark ? 0.14 : 0.55),
      shadow: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
      selectedFill: scheme.primaryContainer.withValues(alpha: 0.75),
      selectedForeground: scheme.onPrimaryContainer,
      unselectedForeground: scheme.onSurface.withValues(alpha: 0.75),
    );
  }

  /// Gaussian blur applied to whatever scrolls behind the glass.
  final double blurSigma;

  /// Translucent fill laid over the blur.
  final Color tint;

  /// Top edge of the sheen gradient, fading into [tint].
  final Color highlight;

  /// Hairline rim that catches the light.
  final Color border;

  final Color shadow;
  final Color selectedFill;
  final Color selectedForeground;
  final Color unselectedForeground;

  static GlassStyle of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GlassStyle>() ??
        GlassStyle.fromScheme(theme.colorScheme);
  }

  @override
  GlassStyle copyWith({
    double? blurSigma,
    Color? tint,
    Color? highlight,
    Color? border,
    Color? shadow,
    Color? selectedFill,
    Color? selectedForeground,
    Color? unselectedForeground,
  }) {
    return GlassStyle(
      blurSigma: blurSigma ?? this.blurSigma,
      tint: tint ?? this.tint,
      highlight: highlight ?? this.highlight,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      selectedFill: selectedFill ?? this.selectedFill,
      selectedForeground: selectedForeground ?? this.selectedForeground,
      unselectedForeground: unselectedForeground ?? this.unselectedForeground,
    );
  }

  @override
  GlassStyle lerp(GlassStyle? other, double t) {
    if (other == null) return this;
    return GlassStyle(
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
      tint: Color.lerp(tint, other.tint, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      selectedForeground:
          Color.lerp(selectedForeground, other.selectedForeground, t)!,
      unselectedForeground:
          Color.lerp(unselectedForeground, other.unselectedForeground, t)!,
    );
  }
}

/// A frosted, translucent panel: blurs what is behind it, tints it, and adds
/// a soft top sheen and a bright rim.
///
/// With the system's increased-contrast setting on it becomes an opaque
/// surface instead, since text over a blur is exactly what that setting is
/// asking to avoid.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final style = GlassStyle.of(context);
    final opaque = MediaQuery.highContrastOf(context);
    final scheme = Theme.of(context).colorScheme;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: opaque ? scheme.surfaceContainerHighest : null,
        gradient: opaque
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(style.highlight, style.tint),
                  style.tint,
                ],
              ),
        border: Border.all(
          color: opaque ? scheme.outline : style.border,
          width: 0.8,
        ),
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: style.shadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: opaque
            ? panel
            : BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: style.blurSigma,
                  sigmaY: style.blurSigma,
                ),
                child: panel,
              ),
      ),
    );
  }
}

/// A floating glass capsule of tabs, for [Scaffold.bottomNavigationBar].
///
/// Drives the nearest [DefaultTabController] (or [controller]) exactly like
/// a Material [TabBar] - it is one, restyled - so a page only has to decide
/// where to put it. Pair it with `Scaffold(extendBody: true)` so content
/// scrolls behind the glass; the Scaffold then reports the capsule's height
/// as bottom padding, which scrolling lists should add to their own.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.labels, this.controller});

  final List<String> labels;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    final style = GlassStyle.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassSurface(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: controller,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: style.selectedFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  splashBorderRadius: BorderRadius.circular(999),
                  labelColor: style.selectedForeground,
                  unselectedLabelColor: style.unselectedForeground,
                  labelStyle: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  unselectedLabelStyle: textTheme.labelLarge,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  tabs: [
                    for (final label in labels)
                      Tab(
                        height: 40,
                        // Four labels share a phone-width capsule; at large
                        // text sizes they shrink to fit rather than clip.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, maxLines: 1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
