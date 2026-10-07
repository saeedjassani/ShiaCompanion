import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// The three layouts of docs/DESIGN_SPEC.md, "Responsive behaviour":
/// phones below [tabletBreakpoint], tablets (portrait) up to
/// [desktopBreakpoint], and web, desktop and tablet landscape from there.
enum ScreenClass {
  phone,
  tablet,
  desktop;

  static ScreenClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  static ScreenClass forWidth(double width) => width >= desktopBreakpoint
      ? ScreenClass.desktop
      : width >= tabletBreakpoint
          ? ScreenClass.tablet
          : ScreenClass.phone;

  bool get isPhone => this == ScreenClass.phone;

  /// Tablet or desktop: pickers open as centred dialogs rather than bottom
  /// sheets.
  bool get atLeastTablet => this != ScreenClass.phone;

  bool get isDesktop => this == ScreenClass.desktop;
}

const double tabletBreakpoint = 600.0;
const double desktopBreakpoint = 1024.0;

/// The reading column of the zikr, Quran and library readers: 640 on a
/// tablet, 720 from desktop width up, the whole width (less the gutters)
/// on a phone.
double readerColumnWidth(BuildContext context) =>
    ScreenClass.of(context).isDesktop ? 720.0 : 640.0;

const double compactContentWidth = 720.0;
const double listContentWidth = 900.0;
const double wideContentWidth = 1120.0;

EdgeInsets responsivePagePadding(
  double width, {
  double vertical = 0.0,
}) {
  final horizontal = width >= 1200
      ? 32.0
      : width >= 720
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = listContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
    this.fillHeight = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection =
            Directionality.maybeOf(context) ?? TextDirection.ltr;
        final resolvedPadding =
            (padding ?? responsivePagePadding(constraints.maxWidth))
                .resolve(textDirection);
        final availableWidth =
            math.max(0.0, constraints.maxWidth - resolvedPadding.horizontal);
        final contentWidth = math.min(maxWidth, availableWidth);

        Widget content = SizedBox(
          width: contentWidth,
          child: child,
        );

        if (fillHeight && constraints.hasBoundedHeight) {
          content = SizedBox(
            width: contentWidth,
            height:
                math.max(0.0, constraints.maxHeight - resolvedPadding.vertical),
            child: child,
          );
        }

        return Padding(
          padding: resolvedPadding,
          child: Align(
            alignment: alignment,
            child: content,
          ),
        );
      },
    );
  }
}

class ResponsiveScrollableContent extends StatelessWidget {
  const ResponsiveScrollableContent({
    super.key,
    required this.child,
    this.maxWidth = listContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding =
            padding ?? responsivePagePadding(constraints.maxWidth);
        return SingleChildScrollView(
          padding: resolvedPadding,
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Lets a mouse drag [child], a strip that scrolls sideways (cards, chips),
/// as a finger would. Flutter leaves mouse drags to text selection, which
/// suits a page but leaves a sideways strip unreachable on the web for
/// anyone without a trackpad or the Shift + wheel trick.
class MouseDragScroll extends StatelessWidget {
  const MouseDragScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          PointerDeviceKind.mouse,
        },
      ),
      child: child,
    );
  }
}
