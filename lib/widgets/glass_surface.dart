import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/shia_colors.dart';

/// The frosted surface of the floating tab bar, the search button and the
/// reader's tools capsule: a translucent fill over a backdrop blur, a 1 px
/// border and a soft shadow (docs/DESIGN_SPEC.md, "Glass").
///
/// Falls back to the same tone, opaque and unblurred, when [blurEnabled] is
/// off or the system asks for more contrast - translucency is the first
/// thing to go for someone who has turned that on.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  /// Global switch for the blur, for devices where it proves too costly.
  static bool blurEnabled = true;

  static const double blurSigma = 18;

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final solid = !blurEnabled || MediaQuery.highContrastOf(context);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? colors.glassSolid : colors.glass,
        borderRadius: borderRadius,
        border: Border.all(color: colors.glassBorder),
      ),
      child: child,
    );
    if (!solid) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    }

    return CustomPaint(
      painter: _OuterShadowPainter(borderRadius, colors.glassShadow),
      child: ClipRRect(borderRadius: borderRadius, child: surface),
    );
  }
}

/// `0 8 28` in CSS terms, painted only outside the shape. A plain
/// [BoxShadow] would also darken the area under the translucent fill, which
/// CSS's box-shadow never does.
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter(this.borderRadius, this.color);

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(64))
      ..addRRect(rrect));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 8)),
      Paint()
        ..color = color
        // A CSS blur radius is twice the Gaussian sigma.
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.borderRadius != borderRadius || old.color != color;
}
