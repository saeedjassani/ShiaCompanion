import 'package:flutter/widgets.dart';

/// The revamp's line icons for chrome (tab bar, search, profile): drawn on a
/// 24-unit grid with round caps and joins, as in the agreed mockups. Content
/// keeps the [HomeGlyph] and [PrayerGlyph] painters.
enum OutlineGlyph { home, heart, search, profile }

class OutlineIcon extends StatelessWidget {
  const OutlineIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    required this.color,
    this.strokeWidth = 1.8,
  });

  final OutlineGlyph glyph;
  final double size;
  final Color color;

  /// In grid units; scales with [size].
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OutlinePainter(glyph, color, strokeWidth),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.glyph, this.color, this.strokeWidth);

  final OutlineGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final path in _paths(glyph)) {
      canvas.drawPath(path, paint);
    }
  }

  static List<Path> _paths(OutlineGlyph glyph) {
    switch (glyph) {
      case OutlineGlyph.home:
        return [
          Path()
            ..moveTo(4, 11)
            ..lineTo(12, 4)
            ..lineTo(20, 11)
            ..lineTo(20, 19.5)
            ..arcToPoint(const Offset(18.5, 21),
                radius: const Radius.circular(1.5))
            ..lineTo(15, 21)
            ..lineTo(15, 15)
            ..lineTo(9, 15)
            ..lineTo(9, 21)
            ..lineTo(5.5, 21)
            ..arcToPoint(const Offset(4, 19.5),
                radius: const Radius.circular(1.5))
            ..close(),
        ];
      case OutlineGlyph.heart:
        return [
          Path()
            ..moveTo(12, 20)
            ..cubicTo(12, 20, 5, 15.6, 5, 10)
            ..arcToPoint(const Offset(12, 7.4),
                radius: const Radius.circular(4))
            ..arcToPoint(const Offset(19, 10), radius: const Radius.circular(4))
            ..cubicTo(19, 15.6, 12, 20, 12, 20)
            ..close(),
        ];
      case OutlineGlyph.search:
        return [
          Path()
            ..addOval(
                Rect.fromCircle(center: const Offset(11, 11), radius: 6.5)),
          Path()
            ..moveTo(16, 16)
            ..lineTo(20, 20),
        ];
      case OutlineGlyph.profile:
        return [
          Path()
            ..addOval(
                Rect.fromCircle(center: const Offset(12, 8.5), radius: 3.5)),
          Path()
            ..moveTo(5, 19.5)
            ..cubicTo(6.2, 16.2, 8.9, 14.5, 12, 14.5)
            ..cubicTo(15.1, 14.5, 17.8, 16.2, 19, 19.5),
        ];
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
