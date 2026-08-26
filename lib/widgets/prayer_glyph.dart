import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which of the eight prayer/time glyphs a name resolves to.
enum PrayerGlyphType {
  fajr,
  sunrise,
  zuhr,
  asr,
  sunset,
  maghrib,
  isha,
  midnight,
  unknown,
}

PrayerGlyphType prayerGlyphTypeFor(String prayerName) {
  final name = prayerName.toLowerCase();
  if (name.contains('fajr')) return PrayerGlyphType.fajr;
  if (name.contains('sunrise')) return PrayerGlyphType.sunrise;
  if (name.contains('zuhr') ||
      name.contains('dhuhr') ||
      name.contains('dhohr')) {
    return PrayerGlyphType.zuhr;
  }
  if (name.contains('asr')) return PrayerGlyphType.asr;
  if (name.contains('sunset')) return PrayerGlyphType.sunset;
  if (name.contains('maghrib')) return PrayerGlyphType.maghrib;
  if (name.contains('isha')) return PrayerGlyphType.isha;
  if (name.contains('midnight')) return PrayerGlyphType.midnight;
  return PrayerGlyphType.unknown;
}

/// A prayer/time icon built from a small shared grammar — horizon, sun disc,
/// rays, crescent, cloud, star — instead of a grab-bag of unrelated Material
/// icons. The sun is drawn open (stroke) so its rays read separately from
/// the disc; the moon, cloud and stars are solid, so a cloud crossing the
/// moon merges into one silhouette the way `Icons.nights_stay` used to.
///
/// Drop-in replacement for `Icon(prayerIconFor(name), size: s, color: c)`.
class PrayerGlyph extends StatelessWidget {
  const PrayerGlyph({
    super.key,
    required this.name,
    required this.size,
    required this.color,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PrayerGlyphPainter(prayerGlyphTypeFor(name), color),
      ),
    );
  }
}

class _PrayerGlyphPainter extends CustomPainter {
  _PrayerGlyphPainter(this.type, this.color);

  final PrayerGlyphType type;
  final Color color;

  /// Stroke width for the sun disc and the horizon line.
  static const double _discStroke = 2.0;

  /// Stroke width for rays — deliberately lighter than the disc so the sun
  /// doesn't read as a solid blob at small sizes.
  static const double _rayStroke = 1.7;

  static const List<double> _rays8 = [0, 45, 90, 135, 180, 225, 270, 315];
  static const List<double> _rays5 = [30, 60, 90, 120, 150];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);

    final discPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _discStroke
      ..strokeCap = StrokeCap.round;
    final rayPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rayStroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case PrayerGlyphType.fajr:
        _line(canvas, discPaint, 3.5, 17, 20.5, 17);
        _line(canvas, rayPaint, 12, 16, 12, 10.6);
        _line(canvas, rayPaint, 8.9, 16, 6.9, 11.7);
        _line(canvas, rayPaint, 15.1, 16, 17.1, 11.7);
      case PrayerGlyphType.sunrise:
        _line(canvas, discPaint, 3.5, 17, 20.5, 17);
        _openDome(canvas, discPaint, 12, 17, 4.5);
        _rays(canvas, rayPaint, 12, 17, 4.5, 0.8, 1.7, _rays5);
      case PrayerGlyphType.zuhr:
        _ring(canvas, discPaint, 12, 11.6, 4);
        _rays(canvas, rayPaint, 12, 11.6, 4, 0.9, 1.9, _rays8);
      case PrayerGlyphType.asr:
        _ring(canvas, discPaint, 7.8, 7.8, 3.0);
        _rays(canvas, rayPaint, 7.8, 7.8, 3.0, 0.85, 1.4, _rays8);
        _cloud(canvas, fillPaint, 9.8, 20.2, 0.74);
      case PrayerGlyphType.sunset:
        _line(canvas, discPaint, 3.5, 17, 20.5, 17);
        _openDome(canvas, discPaint, 12, 17, 2.8);
        _rays(canvas, rayPaint, 12, 17, 2.8, 0.8, 1.3, _rays5);
        _cloud(canvas, fillPaint, 11.3, 10.4, 0.72);
      case PrayerGlyphType.maghrib:
        _crescent(canvas, fillPaint, 1, 0, 0);
      case PrayerGlyphType.isha:
        _crescent(canvas, fillPaint, 0.78, 3.2, -0.6);
        _cloud(canvas, fillPaint, 1.2, 20.5, 0.52);
      case PrayerGlyphType.midnight:
        _star(canvas, fillPaint, 13, 10, 4.4);
        _star(canvas, fillPaint, 7, 16, 2.6);
        _star(canvas, fillPaint, 18, 17, 2);
      case PrayerGlyphType.unknown:
        // Never actually shown — every known prayer/time name resolves
        // above — but keeps the same grammar rather than reaching for a
        // borrowed Material icon: horizon, dome, pinnacle.
        _line(canvas, discPaint, 4, 19, 20, 19);
        _openDome(canvas, discPaint, 12, 19, 4);
        _line(canvas, rayPaint, 12, 15, 12, 11.5);
    }

    canvas.restore();
  }

  static void _line(
    Canvas canvas,
    Paint paint,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
  }

  static void _ring(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double r,
  ) {
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  /// The upper half of a circle, open at the bottom — sunrise/sunset's
  /// half-disc, resting on the horizon line drawn separately.
  static void _openDome(
    Canvas canvas,
    Paint paint,
    double cx,
    double y,
    double r,
  ) {
    final path = Path()
      ..moveTo(cx - r, y)
      ..arcToPoint(Offset(cx + r, y), radius: Radius.circular(r));
    canvas.drawPath(path, paint);
  }

  /// Radiating bars around a disc. `gap` is the space between the disc's
  /// stroke and where each ray starts; `len` is each ray's length.
  static void _rays(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double r,
    double gap,
    double len,
    List<double> anglesDeg,
  ) {
    final inner = r + _discStroke / 2 + gap;
    final outer = inner + len;
    for (final a in anglesDeg) {
      final rad = a * math.pi / 180;
      final c = math.cos(rad);
      final s = math.sin(rad);
      canvas.drawLine(
        Offset(cx + c * inner, cy - s * inner),
        Offset(cx + c * outer, cy - s * outer),
        paint,
      );
    }
  }

  /// Three overlapping lobes on a flat base — the one non-celestial shape
  /// in the set, always solid so it merges into whatever it covers.
  /// `(x0, y1)` is the cloud's left/bottom corner before scaling.
  static void _cloud(
    Canvas canvas,
    Paint paint,
    double x0,
    double y1,
    double scale,
  ) {
    final tx = x0 - 3.5 * scale;
    final ty = y1 - 18 * scale;
    Offset p(double x, double y) => Offset(tx + x * scale, ty + y * scale);
    final path = Path()
      ..moveTo(p(7, 18).dx, p(7, 18).dy)
      ..arcToPoint(p(7, 11), radius: Radius.circular(3.5 * scale))
      ..arcToPoint(p(16, 12.2), radius: Radius.circular(5 * scale))
      ..arcToPoint(p(16, 18), radius: Radius.circular(3 * scale))
      ..close();
    canvas.drawPath(path, paint);
  }

  /// A crescent moon, solid. `(tx, ty)` position and `scale` size it within
  /// the 24×24 grid — Maghrib uses it at full size, Isha shrinks and shifts
  /// it to leave room for a cloud at its foot.
  static void _crescent(
    Canvas canvas,
    Paint paint,
    double scale,
    double tx,
    double ty,
  ) {
    Offset p(double x, double y) => Offset(tx + x * scale, ty + y * scale);
    final path = Path()
      ..moveTo(p(21, 12.79).dx, p(21, 12.79).dy)
      ..arcToPoint(
        p(11.21, 3),
        radius: Radius.circular(9 * scale),
        largeArc: true,
      )
      ..arcToPoint(
        p(21, 12.79),
        radius: Radius.circular(7 * scale),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  /// A four-point sparkle, solid — the one filled shape used on its own
  /// (Midnight), since a star that small disappears if only stroked.
  static void _star(
    Canvas canvas,
    Paint paint,
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PrayerGlyphPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
