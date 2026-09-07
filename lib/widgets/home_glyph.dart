import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which custom glyph to paint for home menu grid items.
enum HomeGlyphType {
  /// Sacred Mihrab (prayer arch) framing a hanging sanctuary lamp.
  namaz,

  /// Cupped hands raised in supplication (Dua / Qunoot).
  duas,

  /// The Holy Quran resting upon a traditional wooden Rihal (X-stand).
  surahs,

  /// Looped strand of prayer beads with an Imam bead and dangling tassel.
  tasbeeh,

  /// Traditional illuminated Islamic lantern (Fanoos) for holy night vigils.
  aamaal,

  /// Nocturnal crescent moon with celestial stars for intimate night supplication.
  munajaat,

  /// Sacred Turbah (sajdah stone) with concentric count pulse rings.
  rakaat,

  /// Mihrab prayer arch with prayer beads draped across it.
  taqeebat,

  /// Open sacred book illuminated with morning dawn rays.
  todaysRecitations,

  /// The Holy Shrine of Ahlulbayt with golden dome, minarets, and the waving Alam.
  ziyaraat,

  /// Three library volumes on a shelf plinth with the right tome resting against the centerpiece.
  library,
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
      case HomeGlyphType.ziyaraat:
        _paintZiyaraat(canvas, strokePaint, detailPaint, fillPaint);
      case HomeGlyphType.library:
        _paintLibrary(canvas, strokePaint, detailPaint, fillPaint);
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

  /// 2. DUAS: Cupped hands raised in supplication (Dua / Qunoot).
  void _paintDuas(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    final handStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final handDetail = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawHand() {
      // Outer hand contour (outer wrist -> thumb -> 3 fingertips -> inner edge -> inner wrist)
      final hand = Path()
        ..moveTo(2.6, 21.0)
        ..cubicTo(1.5, 19.2, 0.9, 17.0, 0.9, 14.8)
        ..cubicTo(0.9, 13.0, 1.2, 11.5, 1.5, 9.8)
        ..cubicTo(1.6, 8.5, 2.0, 7.8, 2.6, 7.8)
        ..cubicTo(3.2, 7.8, 3.5, 8.4, 3.6, 9.3)
        ..cubicTo(3.7, 10.0, 3.8, 10.6, 4.3, 11.0)
        ..cubicTo(4.8, 9.2, 5.8, 6.2, 6.8, 4.2)
        ..cubicTo(7.2, 3.3, 7.8, 3.5, 7.7, 4.7)
        ..cubicTo(7.9, 3.5, 8.5, 2.8, 9.1, 2.9)
        ..cubicTo(9.6, 3.0, 9.8, 3.8, 9.6, 4.8)
        ..cubicTo(9.9, 3.8, 10.6, 3.8, 10.9, 4.6)
        ..cubicTo(11.2, 5.5, 11.3, 7.0, 11.3, 9.2)
        ..cubicTo(11.2, 11.0, 10.1, 12.2, 9.9, 13.8)
        ..cubicTo(9.8, 15.2, 10.6, 16.5, 10.6, 17.6)
        ..cubicTo(10.5, 18.8, 9.9, 20.0, 9.2, 21.0);
      canvas.drawPath(hand, handStroke);

      // Finger divider 1 (between index and middle finger)
      final div1 = Path()
        ..moveTo(7.7, 4.7)
        ..cubicTo(7.9, 6.8, 7.2, 8.8, 5.8, 11.0);
      canvas.drawPath(div1, handDetail);

      // Finger divider 2 (between middle and inner finger)
      final div2 = Path()
        ..moveTo(9.6, 4.8)
        ..cubicTo(9.8, 6.8, 9.2, 9.0, 8.0, 11.4);
      canvas.drawPath(div2, handDetail);

      // Thumb crease line separating thenar eminence from palm
      final thumbCrease = Path()
        ..moveTo(4.3, 11.0)
        ..cubicTo(4.3, 12.8, 4.1, 14.2, 5.8, 15.6);
      canvas.drawPath(thumbCrease, handDetail);
    }

    // Left hand
    drawHand();

    // Right hand (mirrored across vertical center x = 12.0)
    canvas.save();
    canvas.translate(24.0, 0.0);
    canvas.scale(-1.0, 1.0);
    drawHand();
    canvas.restore();
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

  /// 6. MUNAJAAT: Material Symbols moon_stars (night crescent with twin celestial stars).
  void _paintMunajaat(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      // Star 1 (upper diamond)
      ..moveTo(15.0, 8.0)
      ..lineTo(12.0, 5.0)
      ..lineTo(15.0, 2.0)
      ..lineTo(18.0, 5.0)
      ..close()
      // Star 2 (lower diamond)
      ..moveTo(20.0, 11.0)
      ..lineTo(18.0, 9.0)
      ..lineTo(20.0, 7.0)
      ..lineTo(22.0, 9.0)
      ..close()
      // Crescent Moon Outer Contour
      ..moveTo(12.07, 22.0)
      ..quadraticBezierTo(9.97, 22.0, 8.14, 21.2)
      ..quadraticBezierTo(6.30, 20.4, 4.94, 19.04)
      ..quadraticBezierTo(3.58, 17.68, 2.77, 15.84)
      ..quadraticBezierTo(1.98, 14.0, 1.98, 11.9)
      ..quadraticBezierTo(1.98, 8.25, 4.30, 5.46)
      ..quadraticBezierTo(6.62, 2.67, 10.22, 2.0)
      ..quadraticBezierTo(9.78, 4.47, 10.50, 6.84)
      ..quadraticBezierTo(11.22, 9.20, 13.00, 10.97)
      ..quadraticBezierTo(14.78, 12.75, 17.14, 13.47)
      ..quadraticBezierTo(19.50, 14.2, 21.98, 13.75)
      ..quadraticBezierTo(21.32, 17.35, 18.52, 19.68)
      ..quadraticBezierTo(15.72, 22.0, 12.07, 22.0)
      ..close()
      // Crescent Moon Inner Cutout (Hollow outline)
      ..moveTo(12.07, 20.0)
      ..quadraticBezierTo(14.28, 20.0, 16.15, 18.9)
      ..quadraticBezierTo(18.02, 17.8, 19.10, 15.88)
      ..quadraticBezierTo(16.95, 15.68, 15.03, 14.79)
      ..quadraticBezierTo(13.10, 13.9, 11.57, 12.38)
      ..quadraticBezierTo(10.05, 10.85, 9.15, 8.93)
      ..quadraticBezierTo(8.25, 7.0, 8.07, 4.85)
      ..quadraticBezierTo(6.15, 5.92, 5.06, 7.81)
      ..quadraticBezierTo(3.98, 9.7, 3.98, 11.9)
      ..quadraticBezierTo(3.98, 15.28, 6.34, 17.64)
      ..quadraticBezierTo(8.70, 20.0, 12.07, 20.0)
      ..close();

    canvas.drawPath(path, fill);
  }

  /// 7. RAKAAT COUNTER: Physical Sajdagah / Rakaat counter prayer device with empty readout window and sajdah Turbah.
  void _paintRakaat(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Outer pointed arch casing with subtle saddle-curve base
    final casing = Path()
      ..moveTo(12.0, 1.6)
      ..cubicTo(9.6, 3.0, 5.0, 6.6, 5.0, 11.2)
      ..lineTo(5.0, 19.5)
      ..cubicTo(5.0, 21.0, 6.5, 21.8, 8.0, 21.6)
      ..cubicTo(10.2, 21.3, 13.8, 21.3, 16.0, 21.6)
      ..cubicTo(17.5, 21.8, 19.0, 21.0, 19.0, 19.5)
      ..lineTo(19.0, 11.2)
      ..cubicTo(19.0, 6.6, 14.4, 3.0, 12.0, 1.6)
      ..close();
    canvas.drawPath(casing, stroke);

    // Inner compartment divider bar
    canvas.drawLine(const Offset(5.4, 11.4), const Offset(18.6, 11.4), detail);

    // Empty square counter readout window in upper arch
    final counterWindow = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10.2, 5.0, 3.6, 3.6),
      const Radius.circular(0.8),
    );
    canvas.drawRRect(counterWindow, detail);

    // Lower Sajdah Turbah tablet (recessed clay pad)
    final turbah = Path()
      ..moveTo(7.2, 13.4)
      ..cubicTo(7.2, 12.6, 16.8, 12.6, 16.8, 13.4)
      ..lineTo(16.8, 18.8)
      ..cubicTo(16.8, 19.8, 7.2, 19.8, 7.2, 18.8)
      ..close();
    canvas.drawPath(turbah, stroke);
  }

  /// 10. ZIYARAAT: The Holy Shrine of Ahlulbayt with golden dome, twin minarets, and the waving Alam (flag of Karbala).
  void _paintZiyaraat(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Ground line
    canvas.drawLine(const Offset(2.0, 21.0), const Offset(22.0, 21.0), stroke);

    // Left minaret
    canvas.drawLine(const Offset(3.5, 21.0), const Offset(3.5, 8.5), stroke);
    canvas.drawLine(const Offset(5.5, 21.0), const Offset(5.5, 8.5), stroke);
    canvas.drawLine(const Offset(2.5, 8.5), const Offset(6.5, 8.5), stroke); // balcony
    canvas.drawLine(const Offset(4.5, 8.5), const Offset(4.5, 5.0), detail); // lantern shaft
    canvas.drawCircle(const Offset(4.5, 4.2), 1.0, fill); // spire peak

    // Right minaret
    canvas.drawLine(const Offset(18.5, 21.0), const Offset(18.5, 8.5), stroke);
    canvas.drawLine(const Offset(20.5, 21.0), const Offset(20.5, 8.5), stroke);
    canvas.drawLine(const Offset(17.5, 8.5), const Offset(21.5, 8.5), stroke); // balcony
    canvas.drawLine(const Offset(19.5, 8.5), const Offset(19.5, 5.0), detail); // lantern shaft
    canvas.drawCircle(const Offset(19.5, 4.2), 1.0, fill); // spire peak

    // Central Shrine Dome (swelling onion dome)
    final dome = Path()
      ..moveTo(7.8, 14.5)
      ..cubicTo(7.6, 10.2, 9.4, 6.6, 12.0, 5.2)
      ..cubicTo(14.6, 6.6, 16.4, 10.2, 16.2, 14.5)
      ..close();
    canvas.drawPath(dome, stroke);

    // Wider Shrine Hall Roofline (wider than the dome)
    canvas.drawLine(const Offset(6.0, 14.5), const Offset(18.0, 14.5), stroke);

    // Shrine Hall Side Walls down to ground line
    canvas.drawLine(const Offset(6.8, 14.5), const Offset(6.8, 21.0), stroke);
    canvas.drawLine(const Offset(17.2, 14.5), const Offset(17.2, 21.0), stroke);

    // Sacred Flag of Karbala (Alam) mounted on the dome pinnacle
    canvas.drawLine(const Offset(12.0, 5.2), const Offset(12.0, 1.8), detail); // pole
    final flag = Path()
      ..moveTo(12.0, 1.8)
      ..quadraticBezierTo(14.0, 1.3, 16.0, 2.2)
      ..lineTo(15.2, 3.8)
      ..quadraticBezierTo(13.6, 3.0, 12.0, 4.0)
      ..close();
    canvas.drawPath(flag, fill);
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

  /// 11. LIBRARY: Three library volumes on a shelf plinth with the right tome resting against the centerpiece.
  void _paintLibrary(
    Canvas canvas,
    Paint stroke,
    Paint detail,
    Paint fill,
  ) {
    // Shelf baseline plinth
    canvas.drawLine(const Offset(2.2, 21.0), const Offset(21.8, 21.0), stroke);

    // Book 1 (Left upright volume)
    final book1 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.6, 6.8, 4.0, 14.2),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(book1, stroke);
    canvas.drawLine(const Offset(3.6, 10.0), const Offset(7.6, 10.0), detail);
    canvas.drawLine(const Offset(3.6, 17.6), const Offset(7.6, 17.6), detail);

    // Book 2 (Middle upright volume, centerpiece)
    final book2 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8.6, 3.6, 4.2, 17.4),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(book2, stroke);
    canvas.drawLine(const Offset(8.6, 7.2), const Offset(12.8, 7.2), detail);
    canvas.drawLine(const Offset(8.6, 17.6), const Offset(12.8, 17.6), detail);

    // Book 3 (Right volume: rotated counter-clockwise by -15.5° to lean left against Book 2)
    const pivotX = 16.6;
    canvas.save();
    canvas.translate(pivotX, 21.0);
    canvas.rotate(-15.5 * math.pi / 180.0);
    canvas.translate(-pivotX, -21.0);

    final book3 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(pivotX, 6.8, 4.0, 14.2),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(book3, stroke);
    canvas.drawLine(const Offset(pivotX, 10.0), const Offset(pivotX + 4.0, 10.0), detail);
    canvas.drawLine(const Offset(pivotX, 17.6), const Offset(pivotX + 4.0, 17.6), detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomeGlyphPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
