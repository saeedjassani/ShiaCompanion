import 'dart:math' as math;
import 'dart:ui';

import '../utils/geo_utils.dart';

/// The drawing of a shrine plan: `assets/ziyarat_plans/<id>.json`, written
/// by `scripts/ziyarat_maps/build_plans.py` from OpenStreetMap (see "Shrine
/// plans" in docs/ZIYARAT_GUIDE.md).
///
/// Coordinates are metres east ([Offset.dx]) and south ([Offset.dy], so a
/// canvas draws north up) of [origin], on the same equirectangular
/// projection the script uses.
class ShrinePlan {
  ShrinePlan({
    required this.origin,
    required this.bounds,
    required this.shapes,
    required this.attribution,
  });

  final GeoPoint origin;

  /// The area the plan covers, in metres.
  final Rect bounds;
  final List<PlanShape> shapes;
  final String attribution;

  static const double _mPerDegLat = 110574.0;
  static const double _mPerDegLng = 111320.0;

  double get _cosOrigin => math.cos(origin.latitude * math.pi / 180);

  /// [point] in the plan's metres.
  Offset project(GeoPoint point) => Offset(
        (point.longitude - origin.longitude) * _mPerDegLng * _cosOrigin,
        -(point.latitude - origin.latitude) * _mPerDegLat,
      );

  /// The point at [offset] metres from [origin].
  GeoPoint unproject(Offset offset) => GeoPoint(
        origin.latitude - offset.dy / _mPerDegLat,
        origin.longitude + offset.dx / (_mPerDegLng * _cosOrigin),
      );

  factory ShrinePlan.fromJson(Map<String, dynamic> json) {
    final origin = (json['origin'] as List).cast<num>();
    final b = (json['bounds'] as List).cast<num>();
    // Stored in decimetres, north up (y grows northwards).
    Offset at(num x, num y) => Offset(x / 10, -y / 10);
    final shapes = <PlanShape>[];
    for (final raw in (json['shapes'] as List? ?? const [])) {
      final shape = (raw as Map).cast<String, dynamic>();
      final kind = PlanShapeKind.parse(shape['k']);
      final path = Path()..fillType = PathFillType.evenOdd;
      if (shape['l'] case final List line) {
        _addPolyline(path, line.cast<num>(), at, close: false);
        shapes.add(PlanShape(kind, path, isLine: true));
      } else if (shape['r'] case final List rings) {
        for (final ring in rings) {
          _addPolyline(path, (ring as List).cast<num>(), at, close: true);
        }
        shapes.add(PlanShape(kind, path, isLine: false));
      }
    }
    return ShrinePlan(
      origin: GeoPoint(origin[0].toDouble(), origin[1].toDouble()),
      bounds: Rect.fromPoints(at(b[0], b[1]), at(b[2], b[3])),
      shapes: shapes,
      attribution:
          json['attribution'] as String? ?? '© OpenStreetMap contributors',
    );
  }

  static void _addPolyline(
    Path path,
    List<num> flat,
    Offset Function(num, num) at, {
    required bool close,
  }) {
    if (flat.length < 4) return;
    final start = at(flat[0], flat[1]);
    path.moveTo(start.dx, start.dy);
    for (var i = 2; i + 1 < flat.length; i += 2) {
      final p = at(flat[i], flat[i + 1]);
      path.lineTo(p.dx, p.dy);
    }
    if (close) path.close();
  }
}

/// The layer a shape draws in; the script sorts shapes bottom to top.
enum PlanShapeKind {
  precinct,
  green,
  walk,
  court,
  road,
  path,
  water,
  building,
  gate,

  /// A tiled (blue or turquoise) dome.
  tile,

  /// A green dome: the Prophet's (s.a.w.a.) in Madinah.
  greenDome,
  gold,
  minaret,
  wall;

  static PlanShapeKind parse(Object? raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return building;
  }
}

class PlanShape {
  const PlanShape(this.kind, this.path, {required this.isLine});

  final PlanShapeKind kind;

  /// In plan metres.
  final Path path;
  final bool isLine;
}
