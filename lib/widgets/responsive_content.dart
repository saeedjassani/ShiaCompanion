import 'dart:math' as math;

import 'package:flutter/material.dart';

const double compactContentWidth = 720.0;
const double readingContentWidth = 840.0;
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
