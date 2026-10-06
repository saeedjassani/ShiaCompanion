import 'package:flutter/widgets.dart';

/// The revamp's line icons for everything that is not content: drawn on a
/// 24-unit grid with round caps and joins, path for path as in the agreed
/// mockups. Content keeps the [HomeGlyph] and [PrayerGlyph] painters.
enum OutlineGlyph {
  home,
  heart,
  search,
  profile,
  calendar,
  calendarCheck,
  compass,
  grid,
  share,
  pin,
  chevronDown,
  chevronLeft,
  chevronRight,
  playlist,
  plane,
  stats,
  sliders,
  plus,
  minus,
  dragHandle,
  check,
  close,
  history,
  folder,
  clock,
  arrowRight,
  playlistAdd,
  speaker,
  play,
  pause,
  download,
  more,
  trash,
  repeat,
  flame,
}

class OutlineIcon extends StatelessWidget {
  const OutlineIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    required this.color,
    this.strokeWidth = 1.8,
    this.filled = false,
  });

  final OutlineGlyph glyph;
  final double size;
  final Color color;

  /// In grid units; scales with [size].
  final double strokeWidth;

  /// Fills the shape as well as outlining it (a favourite's heart).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OutlinePainter(glyph, color, strokeWidth, filled),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.glyph, this.color, this.strokeWidth, this.filled);

  final OutlineGlyph glyph;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = _path(glyph);
    if (filled) {
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);
    }
    canvas.drawPath(path, paint);
  }

  static Path _line(double x1, double y1, double x2, double y2) => Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2);

  static Path _circle(double cx, double cy, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

  static Path _calendar() => Path()
    ..addRRect(RRect.fromLTRBR(4, 5, 20, 20, const Radius.circular(2.5)))
    ..addPath(_line(4, 10, 20, 10), Offset.zero)
    ..addPath(_line(8, 3, 8, 7), Offset.zero)
    ..addPath(_line(16, 3, 16, 7), Offset.zero);

  static Path _path(OutlineGlyph glyph) {
    switch (glyph) {
      case OutlineGlyph.home:
        return Path()
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
          ..close();
      case OutlineGlyph.heart:
        return Path()
          ..moveTo(12, 20)
          ..cubicTo(12, 20, 5, 15.6, 5, 10)
          ..arcToPoint(const Offset(12, 7.4), radius: const Radius.circular(4))
          ..arcToPoint(const Offset(19, 10), radius: const Radius.circular(4))
          ..cubicTo(19, 15.6, 12, 20, 12, 20)
          ..close();
      case OutlineGlyph.search:
        return _circle(11, 11, 6.5)
          ..addPath(_line(16, 16, 20, 20), Offset.zero);
      case OutlineGlyph.profile:
        return _circle(12, 8.5, 3.5)
          ..moveTo(5, 19.5)
          ..cubicTo(6.2, 16.2, 8.9, 14.5, 12, 14.5)
          ..cubicTo(15.1, 14.5, 17.8, 16.2, 19, 19.5);
      case OutlineGlyph.calendar:
        return _calendar();
      case OutlineGlyph.calendarCheck:
        return _calendar()
          ..moveTo(9, 15)
          ..lineTo(11, 17)
          ..lineTo(15, 13);
      case OutlineGlyph.compass:
        return _circle(12, 12, 8.5)
          ..moveTo(15.5, 8.5)
          ..lineTo(13.5, 13.5)
          ..lineTo(8.5, 15.5)
          ..lineTo(10.5, 10.5)
          ..close();
      case OutlineGlyph.grid:
        const r = Radius.circular(1.5);
        return Path()
          ..addRRect(RRect.fromLTRBR(4, 4, 10.5, 10.5, r))
          ..addRRect(RRect.fromLTRBR(13.5, 4, 20, 10.5, r))
          ..addRRect(RRect.fromLTRBR(4, 13.5, 10.5, 20, r))
          ..addRRect(RRect.fromLTRBR(13.5, 13.5, 20, 20, r));
      case OutlineGlyph.share:
        return _line(12, 15, 12, 4)
          ..moveTo(8, 8)
          ..lineTo(12, 4)
          ..lineTo(16, 8)
          ..moveTo(5, 12)
          ..lineTo(5, 18)
          ..arcToPoint(const Offset(7, 20),
              radius: const Radius.circular(2), clockwise: false)
          ..lineTo(17, 20)
          ..arcToPoint(const Offset(19, 18),
              radius: const Radius.circular(2), clockwise: false)
          ..lineTo(19, 12);
      case OutlineGlyph.pin:
        return Path()
          ..moveTo(12, 21)
          ..cubicTo(12, 21, 5.5, 15, 5.5, 10)
          ..arcToPoint(const Offset(18.5, 10),
              radius: const Radius.circular(6.5))
          ..cubicTo(18.5, 15, 12, 21, 12, 21)
          ..close()
          ..addPath(_circle(12, 10, 2.3), Offset.zero);
      case OutlineGlyph.chevronDown:
        return Path()
          ..moveTo(6, 9)
          ..lineTo(12, 15)
          ..lineTo(18, 9);
      case OutlineGlyph.chevronLeft:
        return Path()
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
      case OutlineGlyph.chevronRight:
        return Path()
          ..moveTo(9, 6)
          ..lineTo(15, 12)
          ..lineTo(9, 18);
      case OutlineGlyph.playlist:
        return _line(4, 6, 16, 6)
          ..addPath(_line(4, 11, 16, 11), Offset.zero)
          ..addPath(_line(4, 16, 11, 16), Offset.zero)
          ..moveTo(16, 14)
          ..lineTo(16, 20)
          ..lineTo(21, 17)
          ..close();
      case OutlineGlyph.plane:
        return Path()
          ..moveTo(21, 15.5)
          ..lineTo(21, 13.7)
          ..lineTo(13.5, 9)
          ..lineTo(13.5, 4.5)
          ..arcToPoint(const Offset(10.5, 4.5),
              radius: const Radius.circular(1.5), clockwise: false)
          ..lineTo(10.5, 9)
          ..lineTo(3, 13.7)
          ..lineTo(3, 15.5)
          ..lineTo(10.5, 13.3)
          ..lineTo(10.5, 18)
          ..lineTo(8.5, 19.5)
          ..lineTo(8.5, 21)
          ..lineTo(12, 20)
          ..lineTo(15.5, 21)
          ..lineTo(15.5, 19.5)
          ..lineTo(13.5, 18)
          ..lineTo(13.5, 13.3)
          ..close();
      case OutlineGlyph.stats:
        return _line(5, 20, 5, 11)
          ..addPath(_line(10, 20, 10, 5), Offset.zero)
          ..addPath(_line(15, 20, 15, 13), Offset.zero)
          ..addPath(_line(20, 20, 20, 8), Offset.zero);
      case OutlineGlyph.sliders:
        return _line(4, 7, 14, 7)
          ..addPath(_line(18, 7, 20, 7), Offset.zero)
          ..addPath(_line(4, 17, 8, 17), Offset.zero)
          ..addPath(_line(12, 17, 20, 17), Offset.zero)
          ..addPath(_circle(16, 7, 2), Offset.zero)
          ..addPath(_circle(10, 17, 2), Offset.zero);
      case OutlineGlyph.plus:
        return _line(12, 6, 12, 18)..addPath(_line(6, 12, 18, 12), Offset.zero);
      case OutlineGlyph.minus:
        return _line(6, 12, 18, 12);
      case OutlineGlyph.dragHandle:
        return _line(5, 9, 19, 9)..addPath(_line(5, 15, 19, 15), Offset.zero);
      case OutlineGlyph.check:
        return Path()
          ..moveTo(5, 12.5)
          ..lineTo(9.5, 17)
          ..lineTo(19, 7.5);
      case OutlineGlyph.close:
        return _line(6, 6, 18, 18)..addPath(_line(18, 6, 6, 18), Offset.zero);
      case OutlineGlyph.folder:
        const r = Radius.circular(1.5);
        return Path()
          ..moveTo(4, 7.5)
          ..arcToPoint(const Offset(5.5, 6), radius: r)
          ..lineTo(9.5, 6)
          ..lineTo(11.5, 8)
          ..lineTo(18.5, 8)
          ..arcToPoint(const Offset(20, 9.5), radius: r)
          ..lineTo(20, 17.5)
          ..arcToPoint(const Offset(18.5, 19), radius: r)
          ..lineTo(5.5, 19)
          ..arcToPoint(const Offset(4, 17.5), radius: r)
          ..close();
      case OutlineGlyph.clock:
        return _circle(12, 12, 8.5)
          ..moveTo(12, 7.5)
          ..lineTo(12, 12)
          ..lineTo(15, 14);
      case OutlineGlyph.arrowRight:
        return _line(5, 12, 19, 12)
          ..moveTo(13, 6)
          ..lineTo(19, 12)
          ..lineTo(13, 18);
      case OutlineGlyph.playlistAdd:
        return _line(4, 6, 16, 6)
          ..addPath(_line(4, 11, 16, 11), Offset.zero)
          ..addPath(_line(4, 16, 11, 16), Offset.zero)
          ..addPath(_line(18, 13, 18, 19), Offset.zero)
          ..addPath(_line(15, 16, 21, 16), Offset.zero);
      case OutlineGlyph.speaker:
        return Path()
          ..moveTo(4, 9.5)
          ..lineTo(7.5, 9.5)
          ..lineTo(12, 5.5)
          ..lineTo(12, 18.5)
          ..lineTo(7.5, 14.5)
          ..lineTo(4, 14.5)
          ..close()
          ..moveTo(15.5, 9)
          ..arcToPoint(const Offset(15.5, 15), radius: const Radius.circular(4))
          ..moveTo(18, 6.5)
          ..arcToPoint(const Offset(18, 17.5),
              radius: const Radius.circular(7.5));
      case OutlineGlyph.play:
        return Path()
          ..moveTo(8, 5.5)
          ..lineTo(8, 18.5)
          ..lineTo(18, 12)
          ..close();
      case OutlineGlyph.pause:
        return _line(8, 5.5, 8, 18.5)
          ..addPath(_line(16, 5.5, 16, 18.5), Offset.zero);
      case OutlineGlyph.download:
        return _line(12, 4, 12, 15)
          ..moveTo(7.5, 10.5)
          ..lineTo(12, 15)
          ..lineTo(16.5, 10.5)
          ..addPath(_line(5, 19.5, 19, 19.5), Offset.zero);
      case OutlineGlyph.more:
        // Three dots, drawn as round-capped strokes of no length.
        return _line(5.5, 12, 5.51, 12)
          ..addPath(_line(12, 12, 12.01, 12), Offset.zero)
          ..addPath(_line(18.5, 12, 18.51, 12), Offset.zero);
      case OutlineGlyph.trash:
        return _line(5, 7, 19, 7)
          ..moveTo(10, 7)
          ..lineTo(10, 5)
          ..lineTo(14, 5)
          ..lineTo(14, 7)
          ..moveTo(7, 7)
          ..lineTo(8, 20)
          ..lineTo(16, 20)
          ..lineTo(17, 7);
      case OutlineGlyph.repeat:
        return Path()
          ..moveTo(17, 3.5)
          ..lineTo(20, 6.5)
          ..lineTo(17, 9.5)
          ..moveTo(4, 11.5)
          ..lineTo(4, 10.5)
          ..arcToPoint(const Offset(8, 6.5), radius: const Radius.circular(4))
          ..lineTo(20, 6.5)
          ..moveTo(7, 20.5)
          ..lineTo(4, 17.5)
          ..lineTo(7, 14.5)
          ..moveTo(20, 12.5)
          ..lineTo(20, 13.5)
          ..arcToPoint(const Offset(16, 17.5), radius: const Radius.circular(4))
          ..lineTo(4, 17.5);
      case OutlineGlyph.flame:
        return Path()
          ..moveTo(12, 21)
          ..relativeCubicTo(-3.6, 0, -6, -2.5, -6, -5.7)
          ..relativeCubicTo(0, -3.5, 2.6, -5.3, 3.6, -8.6)
          ..relativeCubicTo(0.5, 1.9, 1.6, 3.1, 2.6, 3.5)
          ..relativeCubicTo(0.2, -2.7, 1.6, -5.3, 3.8, -7)
          ..relativeCubicTo(-0.4, 2.7, 0.8, 4.5, 2, 6.1)
          ..relativeCubicTo(0.9, 1.3, 1.6, 2.6, 1.6, 4.4)
          ..relativeCubicTo(0, 4, -2.7, 7.3, -7.6, 7.3)
          ..close();
      case OutlineGlyph.history:
        return Path()
          ..moveTo(4, 12)
          ..arcToPoint(const Offset(6.3, 6.4),
              radius: const Radius.circular(8),
              largeArc: true,
              clockwise: false)
          ..addPath(
              Path()
                ..moveTo(4, 4)
                ..lineTo(4, 8)
                ..lineTo(8, 8),
              Offset.zero)
          ..addPath(
              Path()
                ..moveTo(12, 8)
                ..lineTo(12, 12)
                ..lineTo(15, 14),
              Offset.zero);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled;
}
