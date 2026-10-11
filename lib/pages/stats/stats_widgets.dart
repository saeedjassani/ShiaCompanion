import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/shia_colors.dart';

/// The rounded panel every section of My Stats sits in: the surface, a
/// 1 px line, 20 px corners.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final radius = BorderRadius.circular(20);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class StatsSectionTitle extends StatelessWidget {
  const StatsSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style:
            ShiaText.sectionTitle.copyWith(color: ShiaColors.of(context).text),
      ),
    );
  }
}

/// One headline number in a card: what it counts, and the number in large
/// type.
class StatsTile extends StatelessWidget {
  const StatsTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      container: true,
      child: StatsCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShiaText.secondary.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: ShiaText.largeTitle.copyWith(
                  fontSize: 26,
                  height: 32 / 26,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ring filled to [value] (0-1) with [center] inside it.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.center,
    this.size = 76,
    this.strokeWidth = 8,
    this.color,
    this.trackColor,
  });

  final double value;
  final Widget center;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RingPainter(
              value: value.clamp(0.0, 1.0).toDouble(),
              strokeWidth: strokeWidth,
              color: color ?? colorScheme.primary,
              trackColor:
                  trackColor ?? colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(strokeWidth + 2),
              child: FittedBox(fit: BoxFit.scaleDown, child: center),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
