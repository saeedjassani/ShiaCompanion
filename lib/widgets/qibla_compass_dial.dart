import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/geo_utils.dart';

/// The compass rose.
///
/// Everything is drawn in "bearing space" — a frame rotated by minus the
/// device heading — so a marker is placed at the bearing it actually has and
/// the whole rose turns underneath the fixed index at the top. That is how a
/// physical compass behaves, and it means the target needle needs no separate
/// bookkeeping: it sits at its true bearing like every other feature.
class QiblaCompassDial extends StatelessWidget {
  const QiblaCompassDial({
    super.key,
    required this.headingDegrees,
    required this.targetBearingDegrees,
    required this.targetLabel,
    this.qiblaBearingDegrees,
    this.isAligned = false,
    this.isLive = true,
  });

  /// Where the top of the device points, in degrees clockwise from true north.
  final double headingDegrees;

  /// True bearing of the selected destination, or null when we have no
  /// coordinates and there is nothing to point at.
  final double? targetBearingDegrees;

  /// Short name shown under the hub, e.g. `Karbala`.
  final String targetLabel;

  /// Bearing of the Kaaba, drawn as a faint second marker when the user has
  /// pointed the needle at some other shrine. The qibla is the reason this
  /// screen exists, so it should never be fully out of sight.
  final double? qiblaBearingDegrees;

  final bool isAligned;

  /// False when there is no live heading and the rose is pinned north-up.
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _CompassDialPainter(
          headingDegrees: headingDegrees,
          targetBearingDegrees: targetBearingDegrees,
          qiblaBearingDegrees: qiblaBearingDegrees,
          isAligned: isAligned,
          isLive: isLive,
          // Light and dark want opposite gradients. On a pale page the dial has
          // to be lighter than its surroundings at the centre and shade darker
          // at the rim to read as a raised disc; on a dark page the same disc
          // reads by being lighter in the middle of a darker field.
          face: isDark ? scheme.surfaceContainerHigh : scheme.surface,
          faceEdge: isDark
              ? scheme.surfaceContainerLowest
              : scheme.surfaceContainerHighest,
          ring: scheme.outlineVariant,
          tick: scheme.onSurfaceVariant,
          label: scheme.onSurface,
          northAccent: scheme.error,
          accent: isAligned ? alignedAccentColor(isDark) : scheme.primary,
          muted: scheme.onSurfaceVariant.withValues(alpha: 0.45),
          textDirection: Directionality.of(context),
          hubLabel: targetLabel,
          hubLabelColor: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Green for "you are facing it", chosen for contrast rather than pulled from
/// the brown seed palette — the whole point is that it reads as a different
/// state at a glance, from arm's length, in sunlight.
Color alignedAccentColor(bool isDark) =>
    isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

class _CompassDialPainter extends CustomPainter {
  _CompassDialPainter({
    required this.headingDegrees,
    required this.targetBearingDegrees,
    required this.qiblaBearingDegrees,
    required this.isAligned,
    required this.isLive,
    required this.face,
    required this.faceEdge,
    required this.ring,
    required this.tick,
    required this.label,
    required this.northAccent,
    required this.accent,
    required this.muted,
    required this.textDirection,
    required this.hubLabel,
    required this.hubLabelColor,
  });

  final double headingDegrees;
  final double? targetBearingDegrees;
  final double? qiblaBearingDegrees;
  final bool isAligned;
  final bool isLive;
  final Color face;
  final Color faceEdge;
  final Color ring;
  final Color tick;
  final Color label;
  final Color northAccent;
  final Color accent;
  final Color muted;
  final TextDirection textDirection;
  final String hubLabel;
  final Color hubLabelColor;

  static const double _degreesToRadians = math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    _paintFace(canvas, center, radius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-headingDegrees * _degreesToRadians);

    _paintTicks(canvas, radius);
    _paintCardinals(canvas, radius);

    final qibla = qiblaBearingDegrees;
    if (qibla != null) _paintQiblaMarker(canvas, radius, qibla);

    final target = targetBearingDegrees;
    if (target != null) _paintNeedle(canvas, radius, target);

    canvas.restore();

    _paintIndex(canvas, center, radius);
    _paintHub(canvas, center, radius);
  }

  void _paintFace(Canvas canvas, Offset center, double radius) {
    final faceRadius = radius * 0.94;

    // Lifts the dial off the page. Kept tight and low-opacity so it reads as a
    // physical instrument rather than a floating card.
    canvas.drawCircle(
      center.translate(0, radius * 0.012),
      faceRadius,
      Paint()
        ..color = ring.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05),
    );

    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [face, faceEdge],
          stops: const [0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: faceRadius)),
    );

    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.012
        ..color = ring,
    );

    // A second hairline just inside the rim gives the face some depth without
    // resorting to a drop shadow, which reads as grubby on a dark background.
    canvas.drawCircle(
      center,
      faceRadius * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.004
        ..color = ring.withValues(alpha: 0.5),
    );

    if (isAligned) {
      canvas.drawCircle(
        center,
        faceRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.02
          ..color = accent.withValues(alpha: 0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02),
      );
    }
  }

  /// Degree ticks: every 3° hairline, every 15° longer, every 45° longest.
  void _paintTicks(Canvas canvas, double radius) {
    final outer = radius * 0.9;

    for (var degrees = 0; degrees < 360; degrees += 3) {
      final isMajor = degrees % 45 == 0;
      final isMedium = degrees % 15 == 0;
      final length =
          radius * (isMajor ? 0.085 : (isMedium ? 0.055 : 0.028));
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * (isMajor ? 0.016 : (isMedium ? 0.010 : 0.006))
        ..color = degrees == 0
            ? northAccent
            : (isMedium ? tick.withValues(alpha: 0.75) : muted);

      final angle = degrees * _degreesToRadians;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(direction * outer, direction * (outer - length), paint);
    }
  }

  void _paintCardinals(Canvas canvas, double radius) {
    const cardinals = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    const intercardinals = {45: 'NE', 135: 'SE', 225: 'SW', 315: 'NW'};

    intercardinals.forEach((degrees, text) {
      _paintRoseLabel(
        canvas,
        radius: radius,
        degrees: degrees.toDouble(),
        text: text,
        color: muted,
        fontSize: radius * 0.075,
        weight: FontWeight.w500,
      );
    });

    cardinals.forEach((degrees, text) {
      _paintRoseLabel(
        canvas,
        radius: radius,
        degrees: degrees.toDouble(),
        text: text,
        color: degrees == 0 ? northAccent : label,
        fontSize: radius * 0.115,
        weight: degrees == 0 ? FontWeight.w800 : FontWeight.w700,
      );
    });
  }

  /// Places a rose label at its bearing but keeps it upright on screen.
  ///
  /// A printed compass card carries its letters radially, so `W` lies on its
  /// side when west is to your left. That is authentic and it is also hard to
  /// read on a phone, so the label is counter-rotated out of the dial's frame:
  /// it travels around the rim with the rose, and stays the right way up.
  void _paintRoseLabel(
    Canvas canvas, {
    required double radius,
    required double degrees,
    required String text,
    required Color color,
    required double fontSize,
    required FontWeight weight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.0,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    canvas.save();
    canvas.rotate(degrees * _degreesToRadians);
    canvas.translate(0, -radius * 0.735);
    // Undo both rotations in force here — the dial's and this label's — so the
    // glyph lands square to the viewport.
    canvas.rotate((headingDegrees - degrees) * _degreesToRadians);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  /// The faint "the qibla is still over there" marker.
  void _paintQiblaMarker(Canvas canvas, double radius, double bearing) {
    canvas.save();
    canvas.rotate(bearing * _degreesToRadians);

    final paint = Paint()
      ..color = muted
      ..strokeWidth = radius * 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, -radius * 0.9),
      Offset(0, -radius * 0.62),
      paint,
    );
    canvas.drawCircle(
      Offset(0, -radius * 0.58),
      radius * 0.028,
      Paint()..color = muted,
    );

    canvas.restore();
  }

  void _paintNeedle(Canvas canvas, double radius, double bearing) {
    canvas.save();
    canvas.rotate(bearing * _degreesToRadians);

    final tip = -radius * 0.78;
    final arrow = Path()
      ..moveTo(0, tip)
      ..lineTo(radius * 0.095, tip + radius * 0.225)
      ..lineTo(radius * 0.033, tip + radius * 0.19)
      ..lineTo(radius * 0.033, radius * 0.16)
      ..lineTo(-radius * 0.033, radius * 0.16)
      ..lineTo(-radius * 0.033, tip + radius * 0.19)
      ..lineTo(-radius * 0.095, tip + radius * 0.225)
      ..close();

    canvas.drawPath(
      arrow,
      Paint()
        ..color = accent.withValues(alpha: isAligned ? 0.55 : 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.035),
    );
    canvas.drawPath(arrow, Paint()..color = accent);

    canvas.restore();
  }

  /// The fixed marker at 12 o'clock: what the device is actually pointing at.
  void _paintIndex(Canvas canvas, Offset center, double radius) {
    final top = center.dy - radius * 0.99;
    final marker = Path()
      ..moveTo(center.dx, top + radius * 0.115)
      ..lineTo(center.dx - radius * 0.055, top)
      ..lineTo(center.dx + radius * 0.055, top)
      ..close();

    canvas.drawPath(
      marker,
      Paint()..color = isLive ? accent : muted,
    );
  }

  void _paintHub(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 0.155,
      Paint()..color = face,
    );
    canvas.drawCircle(
      center,
      radius * 0.155,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.01
        ..color = accent.withValues(alpha: 0.55),
    );
    canvas.drawCircle(center, radius * 0.035, Paint()..color = accent);

    final painter = TextPainter(
      text: TextSpan(
        text: hubLabel,
        style: TextStyle(
          color: hubLabelColor,
          fontSize: radius * 0.062,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: radius * 0.62);

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy + radius * 0.205),
    );
  }

  @override
  bool shouldRepaint(_CompassDialPainter old) {
    // Heading changes ~30 times a second, so this is the hot comparison and is
    // checked first; the rest change only on a user action or a theme switch.
    return old.headingDegrees != headingDegrees ||
        old.targetBearingDegrees != targetBearingDegrees ||
        old.qiblaBearingDegrees != qiblaBearingDegrees ||
        old.isAligned != isAligned ||
        old.isLive != isLive ||
        old.accent != accent ||
        old.face != face ||
        old.hubLabel != hubLabel;
  }
}

/// `NNE · 34°` — the compass point and the number, which answer different
/// questions: the letters say roughly where to turn, the number confirms it.
String formatBearing(double bearing) =>
    '${compassLabel(bearing)} · ${normalizeBearing(bearing).round()}°';
