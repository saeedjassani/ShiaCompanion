import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which custom glyph to paint for home menu grid items.
enum HomeGlyphType {
  /// Sacred Mihrab (prayer arch) framing a hanging sanctuary lamp.
  namaz,

  /// Cupped hands raised upward in supplication (Qunoot / Dua).
  duas,

  /// The Holy Quran resting upon a traditional wooden Rihal (X-stand).
  surahs,

  /// Looped strand of prayer beads with an Imam bead and dangling tassel.
  tasbeeh,

  /// Traditional illuminated Islamic lantern (Fanoos) for holy night vigils.
  aamaal,

  /// Intimate nocturnal crescent moon with gentle whispering prayer waves and star.
  munajaat,

  /// Sacred Turbah (sajdah stone) with concentric proximity count waves.
  rakaat,

  /// Mihrab prayer arch with prayer beads draped across it.
  taqeebat,

  /// Open sacred book illuminated with morning dawn rays.
  todaysRecitations,
}

/// A custom-drawn vector glyph for the home screen grid, built from a shared
/// geometric grammar to complement [PrayerGlyph].
///
/// Drop-in replacement for [Icon] inside the home screen tile avatars.
class HomeGlyph extends StatelessWidget {
  const HomeGlyph({
    super.key,
    required this.type,
    required this.size,
    required this.color,
  });

  final HomeGlyphType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HomeGlyphPainter(type, color),
      ),
    );
  }
}

class _HomeGlyphPainter extends CustomPainter {
  _HomeGlyphPainter(this.type, this.color);

  final HomeGlyphType type;
  final Color color;

  /// Primary outline stroke width.
  static const double _strokePrimary = 1.9;

  /// Secondary detail stroke width.
  static const double _strokeDetail = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokePrimary
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final detailPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeDetail
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case HomeGlyphType.namaz:
        _paintNamaz(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.duas:
        _paintDuas(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.surahs:
        _paintSurahs(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.tasbeeh:
        _paintTasbeeh(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.aamaal:
        _paintAamaal(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.munajaat:
        _paintMunajaat(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.rakaat:
        _paintRakaat(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.taqeebat:
        _paintTaqeebat(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.todaysRecitations:
        _paintTodaysRecitations(canvas, strokePaint, detailPaint, fillPaint);
    }

    canvas.restore();
  }

  /// 1. NAMAZ: Mihrab arch with hanging sanctuary lamp (Qandeel).
  void _paintNamaz(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Base line
    canvas.drawLine(const Offset(3.5, 21), const Offset(20.5, 21), stroke);

    // Mihrab arch
    final arch = Path()
      ..moveTo(5.5, 21)
      ..lineTo(5.5, 12)
      ..cubicTo(5.5, 7.2, 9.2, 3.8, 12, 3.2)
      ..cubicTo(14.8, 3.8, 18.5, 7.2, 18.5, 12)
      ..lineTo(18.5, 21);
    canvas.drawPath(arch, stroke);

    // Hanging chain
    canvas.drawLine(const Offset(12, 3.5), const Offset(12, 9), detail);

    // Lamp body (almond / droplet)
    final lamp = Path()
      ..moveTo(12, 9)
      ..cubicTo(10.2, 10.4, 10.2, 12.8, 12, 14.5)
      ..cubicTo(13.8, 12.8, 13.8, 10.4, 12, 9)
      ..close();
    canvas.drawPath(lamp, fill);
  }

  /// 2. DUAS: Cupped hands raised upward in supplication (Qunoot / Dua).
  void _paintDuas(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Left hand
    final leftHand = Path()
      ..moveTo(6.5, 21.5)
      ..cubicTo(5.2, 16.5, 4.6, 12.0, 5.8, 7.8) // pinky
      ..cubicTo(6.4, 5.8, 8.2, 5.2, 9.0, 5.5) // fingertips
      ..cubicTo(9.6, 7.0, 10.2, 9.0, 10.8, 11.2) // thumb
      ..cubicTo(10.5, 14.5, 9.8, 18.2, 9.2, 21.5);
    canvas.drawPath(leftHand, stroke);

    // Right hand (mirrored)
    final rightHand = Path()
      ..moveTo(17.5, 21.5)
      ..cubicTo(18.8, 16.5, 19.4, 12.0, 18.2, 7.8) // pinky
      ..cubicTo(17.6, 5.8, 15.8, 5.2, 15.0, 5.5) // fingertips
      ..cubicTo(14.4, 7.0, 13.8, 9.0, 13.2, 11.2) // thumb
      ..cubicTo(13.5, 14.5, 14.2, 18.2, 14.8, 21.5);
    canvas.drawPath(rightHand, stroke);

    // Blessing rays / sparkle rising between the palms
    canvas.drawLine(const Offset(12, 5.8), const Offset(12, 2.5), detail);
    canvas.drawLine(const Offset(9.8, 4.2), const Offset(8.8, 2.2), detail);
    canvas.drawLine(const Offset(14.2, 4.2), const Offset(15.2, 2.2), detail);
  }

  /// 3. SURAHS: The Holy Quran resting on a traditional wooden Rihal stand.
  void _paintSurahs(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Rihal stand legs (crossing in X)
    canvas.drawLine(const Offset(5.2, 21), const Offset(18.8, 10.5), stroke);
    canvas.drawLine(const Offset(18.8, 21), const Offset(5.2, 10.5), stroke);

    // Base feet bar
    canvas.drawLine(const Offset(4, 21), const Offset(6.5, 21), stroke);
    canvas.drawLine(const Offset(17.5, 21), const Offset(20, 21), stroke);

    // The Holy Quran pages resting in the cradle
    final leftPage = Path()
      ..moveTo(12, 6.2)
      ..cubicTo(9.5, 5.2, 6.2, 5.8, 4.5, 6.8)
      ..lineTo(4.5, 12.2)
      ..cubicTo(6.5, 11.2, 9.8, 11.0, 12, 12.5)
      ..close();
    canvas.drawPath(leftPage, stroke);

    final rightPage = Path()
      ..moveTo(12, 6.2)
      ..cubicTo(14.5, 5.2, 17.8, 5.8, 19.5, 6.8)
      ..lineTo(19.5, 12.2)
      ..cubicTo(17.5, 11.2, 14.2, 11.0, 12, 12.5)
      ..close();
    canvas.drawPath(rightPage, stroke);

    // Center book spine
    canvas.drawLine(const Offset(12, 6.0), const Offset(12, 12.8), stroke);

    // Elegant text line hints on the pages
    canvas.drawLine(const Offset(6.8, 8.6), const Offset(10.2, 8.2), detail);
    canvas.drawLine(const Offset(13.8, 8.2), const Offset(17.2, 8.6), detail);
  }

  /// 4. TASBEEH: Loop of prayer beads with an Imam bead and tassel.
  void _paintTasbeeh(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    const cx = 12.0;
    const cy = 8.5;
    const rx = 6.2;
    const ry = 5.2;

    // Draw string loop
    final loop = Path()
      ..addOval(Rect.fromCenter(center: const Offset(cx, cy), width: rx * 2, height: ry * 2));
    canvas.drawPath(loop, detail);

    // 10 beads around the loop
    const numBeads = 10;
    for (int i = 0; i < numBeads; i++) {
      final angle = i * (2 * math.pi / numBeads) - math.pi / 2;
      final bx = cx + rx * math.cos(angle);
      final by = cy + ry * math.sin(angle);
      canvas.drawCircle(Offset(bx, by), 1.35, fill);
    }

    // Imam bead at bottom junction
    final imamBead = Path()
      ..moveTo(11.0, 13.8)
      ..lineTo(13.0, 13.8)
      ..lineTo(12.6, 17.2)
      ..lineTo(11.4, 17.2)
      ..close();
    canvas.drawPath(imamBead, fill);

    // Tassel knot
    canvas.drawCircle(const Offset(12, 17.8), 0.9, fill);

    // Dangling silk tassels
    canvas.drawLine(const Offset(12, 18.2), const Offset(9.8, 22.0), detail);
    canvas.drawLine(const Offset(12, 18.2), const Offset(12.0, 22.5), detail);
    canvas.drawLine(const Offset(12, 18.2), const Offset(14.2, 22.0), detail);
  }

  /// 5. AAMAAL: Traditional Islamic Lantern (Fanoos) for blessed night devotions.
  void _paintAamaal(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Hanging ring at top
    canvas.drawCircle(const Offset(12, 3.2), 1.6, detail);

    // Lantern cap (pointed hood)
    final cap = Path()
      ..moveTo(12, 4.8)
      ..lineTo(7.2, 7.8)
      ..lineTo(16.8, 7.8)
      ..close();
    canvas.drawPath(cap, stroke);

    // Lantern glass body
    final body = Path()
      ..moveTo(7.8, 7.8)
      ..lineTo(8.8, 16.0)
      ..lineTo(15.2, 16.0)
      ..lineTo(16.2, 7.8);
    canvas.drawPath(body, stroke);

    // Base plinth
    final base = Path()
      ..moveTo(8.2, 16.0)
      ..lineTo(7.0, 19.2)
      ..lineTo(17.0, 19.2)
      ..lineTo(15.8, 16.0);
    canvas.drawPath(base, stroke);
    canvas.drawLine(const Offset(6.0, 19.2), const Offset(18.0, 19.2), stroke);

    // Inner glowing flame (solid droplet)
    final flame = Path()
      ..moveTo(12, 10.2)
      ..cubicTo(10.8, 11.5, 10.8, 13.5, 12, 14.5)
      ..cubicTo(13.2, 13.5, 13.2, 11.5, 12, 10.2)
      ..close();
    canvas.drawPath(flame, fill);

    // Light rays radiating from the sides
    canvas.drawLine(const Offset(5.2, 11.8), const Offset(3.2, 11.8), detail);
    canvas.drawLine(const Offset(18.8, 11.8), const Offset(20.8, 11.8), detail);
  }

  /// 6. MUNAJAAT: Nocturnal crescent moon with whispering prayer ripples and star.
  void _paintMunajaat(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Slender crescent moon on the left
    final crescent = Path()
      ..moveTo(10.5, 3.2)
      ..arcToPoint(
        const Offset(10.5, 20.8),
        radius: const Radius.circular(9.5),
        largeArc: true,
      )
      ..arcToPoint(
        const Offset(10.5, 3.2),
        radius: const Radius.circular(7.8),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(crescent, fill);

    // Sparkling 4-point star on upper right
    _drawStar(canvas, fill, 17.0, 6.2, 2.6);

    // Whispering prayer waves radiating softly on lower right
    _drawArc(canvas, detail, const Offset(13.2, 16.2), 3.2, -0.4, 1.2);
    _drawArc(canvas, detail, const Offset(13.2, 16.2), 5.5, -0.4, 1.2);
    _drawArc(canvas, detail, const Offset(13.2, 16.2), 7.8, -0.4, 1.2);
  }

  /// 7. RAKAAT COUNTER: Sacred Turbah (sajdah stone) with count pulse rings.
  void _paintRakaat(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // The Turbah: rounded clay tablet
    final turbahRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(12, 15.0), width: 14.5, height: 8.5),
      const Radius.circular(4.2),
    );
    canvas.drawRRect(turbahRect, stroke);

    // Inner embossed seal of Turbah
    canvas.drawCircle(const Offset(12, 15.0), 1.8, stroke);

    // Concentric proximity count waves above the Turbah
    _drawArc(canvas, detail, const Offset(12, 11.0), 3.8, -math.pi * 0.8, math.pi * 0.6);
    _drawArc(canvas, detail, const Offset(12, 11.0), 6.5, -math.pi * 0.8, math.pi * 0.6);

    // Center pulse dot
    canvas.drawCircle(const Offset(12, 3.2), 1.2, fill);
  }

  /// 8. TAQEEBAT: Prayer arch with cascading prayer beads.
  void _paintTaqeebat(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Base line
    canvas.drawLine(const Offset(4, 21), const Offset(20, 21), stroke);

    // Outer arch
    final arch = Path()
      ..moveTo(6, 21)
      ..lineTo(6, 12.5)
      ..cubicTo(6, 7.8, 9.5, 4.2, 12, 3.6)
      ..cubicTo(14.5, 4.2, 18, 7.8, 18, 12.5)
      ..lineTo(18, 21);
    canvas.drawPath(arch, stroke);

    // Draped tasbeeh string across the arch
    final beadArc = Path()
      ..moveTo(7.5, 10.5)
      ..cubicTo(8.5, 14.8, 15.5, 14.8, 16.5, 10.5);
    canvas.drawPath(beadArc, detail);

    // Beads along the draped arc
    canvas.drawCircle(const Offset(8.0, 11.2), 1.1, fill);
    canvas.drawCircle(const Offset(9.8, 13.0), 1.1, fill);
    canvas.drawCircle(const Offset(12.0, 13.8), 1.3, fill); // center bead
    canvas.drawCircle(const Offset(14.2, 13.0), 1.1, fill);
    canvas.drawCircle(const Offset(16.0, 11.2), 1.1, fill);

    // Center tassel hanging down from center bead
    canvas.drawLine(const Offset(12, 14.5), const Offset(12, 18.5), detail);
    canvas.drawCircle(const Offset(12, 19.2), 0.9, fill);
  }

  /// 9. TODAY'S RECITATIONS: Open sacred book with rising dawn rays.
  void _paintTodaysRecitations(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Open book pages at bottom
    final leftPage = Path()
      ..moveTo(12, 13.5)
      ..cubicTo(9.5, 12.2, 6.2, 12.8, 4.2, 14.0)
      ..lineTo(4.2, 20.0)
      ..cubicTo(6.2, 18.8, 9.5, 18.5, 12, 19.8)
      ..close();
    canvas.drawPath(leftPage, stroke);

    final rightPage = Path()
      ..moveTo(12, 13.5)
      ..cubicTo(14.5, 12.2, 17.8, 12.8, 19.8, 14.0)
      ..lineTo(19.8, 20.0)
      ..cubicTo(17.8, 18.8, 14.5, 18.5, 12, 19.8)
      ..close();
    canvas.drawPath(rightPage, stroke);

    // Spine
    canvas.drawLine(const Offset(12, 13.5), const Offset(12, 19.8), stroke);

    // Rising sun half-disc above the book
    final sunDome = Path()
      ..moveTo(9.2, 13.0)
      ..arcToPoint(const Offset(14.8, 13.0), radius: const Radius.circular(2.8));
    canvas.drawPath(sunDome, stroke);

    // 5 radiating dawn rays
    const angles = [30.0, 60.0, 90.0, 120.0, 150.0];
    const cx = 12.0;
    const cy = 13.0;
    const rInner = 3.6;
    const rOuter = 6.8;
    for (final deg in angles) {
      final rad = deg * math.pi / 180.0;
      final x1 = cx + rInner * math.cos(rad);
      final y1 = cy - rInner * math.sin(rad);
      final x2 = cx + rOuter * math.cos(rad);
      final y2 = cy - rOuter * math.sin(rad);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), detail);
    }
  }

  /// Four-pointed sparkle star.
  static void _drawStar(
    Canvas canvas,
    Paint fill,
    double cx,
    double cy,
    double r,
  ) {
    final i = r * 0.36;
    final path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + i * 0.6, cy - i * 0.6, cx + r, cy)
      ..quadraticBezierTo(cx + i * 0.6, cy + i * 0.6, cx, cy + r)
      ..quadraticBezierTo(cx - i * 0.6, cy + i * 0.6, cx - r, cy)
      ..quadraticBezierTo(cx - i * 0.6, cy - i * 0.6, cx, cy - r)
      ..close();
    canvas.drawPath(path, fill);
  }

  /// Arc helper.
  static void _drawArc(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeGlyphPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
