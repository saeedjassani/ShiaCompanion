import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../models/shrine_plan.dart';
import '../../models/ziyarat_guide.dart';
import '../../services/analytics_service.dart';
import '../../services/ziyarat_guide_repository.dart';
import '../../theme/shia_colors.dart';
import '../../utils/external_launch.dart';
import '../../utils/geo_utils.dart';
import '../../utils/maps_links.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import 'ziyarat_guide_widgets.dart';
import 'ziyarat_site_page.dart';

// The interactive shrine plan (docs/ZIYARAT_GUIDE.md, "Shrine plans"): a
// roof-plan drawing of the shrine from OpenStreetMap with its zarih, tombs,
// gates and doors on top. Tap a feature to see what it is and what to
// recite there; the ziyarat opens from the card.

/// Pixels per metre at which each kind of feature appears: doors crowd the
/// haram, so they wait for a closer look.
double _minPixelsPerMetre(PlanFeatureKind kind) => switch (kind) {
      PlanFeatureKind.zarih || PlanFeatureKind.place => 0,
      PlanFeatureKind.gate => 0.9,
      PlanFeatureKind.landmark => 1.1,
      PlanFeatureKind.tomb || PlanFeatureKind.maqam => 1.6,
      PlanFeatureKind.door => 3.2,
    };

/// How close the plan opens on its focus: about 160 m across a phone.
const double _focusPixelsPerMetre = 2.4;
const double _maxPixelsPerMetre = 16;

String guidePlanFeatureKindLabel(AppLocalizations l10n, PlanFeatureKind kind) =>
    switch (kind) {
      PlanFeatureKind.zarih => l10n.ziyaratGuideFeatureZarih,
      PlanFeatureKind.tomb => l10n.ziyaratGuideKindTomb,
      PlanFeatureKind.maqam => l10n.ziyaratGuideKindMaqam,
      PlanFeatureKind.place => l10n.ziyaratGuideFeaturePlace,
      PlanFeatureKind.gate => l10n.ziyaratGuideFeatureGate,
      PlanFeatureKind.door => l10n.ziyaratGuideFeatureDoor,
      PlanFeatureKind.landmark => l10n.ziyaratGuideFeatureLandmark,
    };

/// Which side of its site's zarih [feature] lies on, as "n", "ne", ... for
/// [AppLocalizations.ziyaratGuideMapSide]; null for the zarih itself or a
/// feature with nothing to be beside.
String? planFeatureSide(PlanFeature feature) {
  if (feature.kind == PlanFeatureKind.zarih ||
      feature.kind == PlanFeatureKind.place) {
    return null;
  }
  final siteId = feature.siteId;
  if (siteId == null) return null;
  final centre = feature.plan.focusFor(siteId);
  if (centre == null || centre == feature) return null;
  final metres =
      greatCircleDistanceKm(centre.location, feature.location) * 1000;
  if (metres < 3) return null;
  final bearing = initialBearingDegrees(centre.location, feature.location);
  const sides = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];
  return sides[((bearing + 22.5) % 360 ~/ 45)];
}

String _formatMetres(AppLocalizations l10n, double metres) {
  if (metres >= 1000) {
    return l10n.distanceKm(NumberFormat.decimalPattern()
        .format(double.parse((metres / 1000).toStringAsFixed(1))));
  }
  return l10n.ziyaratGuideMapMetres(
      NumberFormat.decimalPattern().format(metres.round()));
}

/// The colours a plan is drawn in, from the app theme.
class _PlanPalette {
  _PlanPalette(ShiaColors c, Brightness brightness)
      : dark = brightness == Brightness.dark,
        background = c.ground,
        precinct = Color.lerp(c.ground, c.gold, 0.10)!,
        court = Color.lerp(
            c.surface, c.gold, brightness == Brightness.dark ? 0.10 : 0.16)!,
        walk = Color.lerp(c.ground, c.surface, 0.7)!,
        green = Color.lerp(c.ground, c.success, 0.22)!,
        water = Color.lerp(c.ground, const Color(0xFF4A90C8), 0.35)!,
        road = c.surface,
        roadEdge = c.line,
        path = Color.lerp(c.surface, c.ground, 0.35)!,
        building = Color.lerp(
            c.well, c.text, brightness == Brightness.dark ? 0.12 : 0.08)!,
        buildingEdge = Color.lerp(c.well, c.text, 0.30)!,
        gate = Color.lerp(c.well, c.accent, 0.30)!,
        gold = c.gold,
        goldEdge = Color.lerp(c.gold, Colors.black, 0.28)!,
        wall = Color.lerp(c.line, c.text, 0.35)!;

  final bool dark;
  final Color background;
  final Color precinct;
  final Color court;
  final Color walk;
  final Color green;
  final Color water;
  final Color road;
  final Color roadEdge;
  final Color path;
  final Color building;
  final Color buildingEdge;
  final Color gate;
  final Color gold;
  final Color goldEdge;
  final Color wall;
}

/// Draws [plan] at [basePixelsPerMetre]; [zoom] (the viewer's transform)
/// keeps outlines a hairline wide however far it is zoomed.
class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.plan,
    required this.basePixelsPerMetre,
    required this.palette,
    required this.zoom,
  }) : super(repaint: zoom);

  final ShrinePlan plan;
  final double basePixelsPerMetre;
  final _PlanPalette palette;
  final ValueNotifier<Matrix4> zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    final scale = zoom.value.getMaxScaleOnAxis();
    // One screen pixel, in metres.
    final px = 1 / (basePixelsPerMetre * scale);
    canvas.save();
    canvas.scale(basePixelsPerMetre);
    canvas.translate(-plan.bounds.left, -plan.bounds.top);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    void area(Path path, Color color, {Color? edge, double edgePx = 0.8}) {
      canvas.drawPath(path, fill..color = color);
      if (edge != null) {
        canvas.drawPath(
            path,
            stroke
              ..color = edge
              ..strokeWidth = edgePx * px);
      }
    }

    void line(Path path, Color color, double widthMetres, {double minPx = 1}) {
      canvas.drawPath(
          path,
          stroke
            ..color = color
            ..strokeWidth = math.max(widthMetres, minPx * px));
    }

    for (final shape in plan.shapes) {
      final path = shape.path;
      switch (shape.kind) {
        case PlanShapeKind.precinct:
          area(path, palette.precinct);
        case PlanShapeKind.green:
          area(path, palette.green);
        case PlanShapeKind.walk:
          area(path, palette.walk);
        case PlanShapeKind.court:
          area(path, palette.court, edge: palette.buildingEdge, edgePx: 0.6);
        case PlanShapeKind.water:
          area(path, palette.water);
        case PlanShapeKind.road:
          line(path, palette.roadEdge, 9, minPx: 3);
          line(path, palette.road, 7.6, minPx: 2);
        case PlanShapeKind.path:
          line(path, palette.path, 3, minPx: 1.5);
        case PlanShapeKind.building:
          area(path, palette.building, edge: palette.buildingEdge);
        case PlanShapeKind.gate:
          area(path, palette.gate, edge: palette.buildingEdge);
        case PlanShapeKind.gold:
          area(path, palette.gold, edge: palette.goldEdge);
        case PlanShapeKind.minaret:
          area(path, palette.gold, edge: palette.goldEdge, edgePx: 1);
        case PlanShapeKind.wall:
          line(path, palette.wall, 0.6, minPx: 1);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanPainter old) =>
      old.plan != plan ||
      old.basePixelsPerMetre != basePixelsPerMetre ||
      old.palette.dark != palette.dark ||
      old.palette.background != palette.background;
}

/// The plan of [plan] for [site], loaded from its asset: [builder] once it
/// is in, a quiet placeholder until then, nothing if it can't be read.
class _PlanLoader extends StatelessWidget {
  const _PlanLoader({required this.plan, required this.builder});

  final GuidePlan plan;
  final Widget Function(BuildContext, ShrinePlan) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShrinePlan?>(
      future: ZiyaratGuideRepository.loadPlan(plan),
      builder: (context, snapshot) {
        final drawing = snapshot.data;
        if (drawing != null) return builder(context, drawing);
        if (snapshot.connectionState == ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return ColoredBox(color: ShiaColors.of(context).well);
      },
    );
  }
}

/// The plan on a site page: a still view centred on the site, its zarih,
/// gates and nearby places marked; a tap opens [ShrinePlanPage].
class ShrinePlanCard extends StatelessWidget {
  const ShrinePlanCard({super.key, required this.site, required this.plan});

  final GuideSite site;
  final GuidePlan plan;

  void _open(BuildContext context, {PlanFeature? feature}) {
    AnalyticsService.feature(
      'ziyarat_guide_plan_open',
      label: site.englishName,
      parameters: {'site': site.id, 'plan': plan.id},
    );
    pushPageRoute(
      context,
      ShrinePlanPage(plan: plan, site: site, initialFeature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      label: l10n.ziyaratGuideOpenMap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SliverCardList.radius),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 230,
                child: _PlanLoader(
                  plan: plan,
                  builder: (context, drawing) => IgnorePointer(
                    child: ShrinePlanView(
                      plan: plan,
                      drawing: drawing,
                      site: site,
                      interactive: false,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.ziyaratGuideOpenMap,
                            style: ShiaText.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.ziyaratGuideMapHint,
                            style: ShiaText.caption
                                .copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    OutlineIcon(OutlineGlyph.chevronRight,
                        size: 18, color: colors.chevron),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full-screen plan: pinch and drag it, tap a feature for its card.
class ShrinePlanPage extends StatefulWidget {
  const ShrinePlanPage({
    super.key,
    required this.plan,
    required this.site,
    this.initialFeature,
  });

  final GuidePlan plan;

  /// The site the plan was opened from: it opens centred on its zarih.
  final GuideSite site;
  final PlanFeature? initialFeature;

  @override
  State<ShrinePlanPage> createState() => _ShrinePlanPageState();
}

class _ShrinePlanPageState extends State<ShrinePlanPage> {
  final _view = GlobalKey<_ShrinePlanViewState>();
  PlanFeature? _selected;
  GeoPoint? _me;
  double? _meAccuracy;
  StreamSubscription<Position>? _positions;
  bool _locating = false;
  final _pixelsPerMetre = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _selected = widget.initialFeature;
    trackScreen('Ziyarat Guide Plan');
  }

  @override
  void dispose() {
    _positions?.cancel();
    _pixelsPerMetre.dispose();
    super.dispose();
  }

  void _select(PlanFeature? feature, {bool move = false}) {
    setState(() => _selected = feature);
    if (feature == null) return;
    AnalyticsService.feature(
      'ziyarat_guide_plan_feature',
      label: feature.englishName,
      parameters: {'plan': widget.plan.id, 'feature': feature.id},
    );
    // After the frame, when the view knows how much the card covers.
    if (move) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _view.currentState?.showFeature(feature);
      });
    }
  }

  Future<void> _locate() async {
    final l10n = context.l10n;
    if (_positions != null) {
      if (_me != null) _view.currentState?.showPoint(_me!);
      return;
    }
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        showToast(l10n.ziyaratGuideMapNoLocation);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showToast(l10n.ziyaratGuideMapNoLocation);
        return;
      }
      AnalyticsService.feature('ziyarat_guide_plan_locate',
          parameters: {'plan': widget.plan.id});
      var first = true;
      _positions = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        ),
      ).listen((position) {
        if (!mounted) return;
        final me = GeoPoint(position.latitude, position.longitude);
        setState(() {
          _me = me;
          _meAccuracy = position.accuracy;
          _locating = false;
        });
        if (first) {
          first = false;
          final view = _view.currentState;
          if (view != null && view.covers(me)) {
            view.showPoint(me);
          } else {
            final focus = widget.plan.focusFor(widget.site.id);
            final km = focus == null
                ? null
                : greatCircleDistanceKm(me, focus.location);
            if (km != null) {
              showToast(
                  l10n.ziyaratGuideMapAway(_formatMetres(l10n, km * 1000)));
            }
          }
        }
      }, onError: (Object error) {
        if (!mounted) return;
        setState(() => _locating = false);
        showToast(l10n.ziyaratGuideMapNoLocation);
      });
    } catch (error) {
      debugPrint('Ziyarat guide plan: no location ($error)');
      if (mounted) showToast(l10n.ziyaratGuideMapNoLocation);
    } finally {
      if (mounted && _me == null && _positions == null) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _showList() async {
    final feature = await showPlanFeatureList(context, widget.plan);
    if (feature != null && mounted) _select(feature, move: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final selected = _selected;

    return Scaffold(
      backgroundColor: colors.ground,
      body: _PlanLoader(
        plan: widget.plan,
        builder: (context, drawing) => Stack(
          children: [
            Positioned.fill(
              child: ShrinePlanView(
                key: _view,
                plan: widget.plan,
                drawing: drawing,
                site: widget.site,
                selected: selected,
                onSelect: (feature) => _select(feature, move: true),
                me: _me,
                meAccuracy: _meAccuracy,
                pixelsPerMetre: _pixelsPerMetre,
                bottomInset: padding.bottom +
                    (selected == null
                        ? 150
                        : math.min(
                                MediaQuery.sizeOf(context).height * 0.48, 420) +
                            60),
              ),
            ),
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  const PageBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GlassPill(
                      child: Text(
                        widget.site.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiaText.secondary.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  RoundIconButton(
                    label: l10n.ziyaratGuideMapPlaces,
                    icon: OutlineIcon(OutlineGlyph.lines,
                        size: 20, color: colors.accent),
                    onPressed: _showList,
                  ),
                ],
              ),
            ),
            Positioned(
              top: padding.top + 64,
              right: 12,
              child: Column(
                children: [
                  _NorthAndQibla(origin: drawing.origin),
                  const SizedBox(height: 10),
                  RoundIconButton(
                    label: l10n.ziyaratGuideMapLocate,
                    icon: _locating
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.accent),
                          )
                        : OutlineIcon(OutlineGlyph.pin,
                            size: 20,
                            color: colors.accent,
                            filled: _me != null),
                    onPressed: _locate,
                  ),
                  const SizedBox(height: 10),
                  RoundIconButton(
                    label: l10n.ziyaratGuideMapRecenter,
                    icon: OutlineIcon(OutlineGlyph.reset,
                        size: 20, color: colors.accent),
                    onPressed: () => _view.currentState?.recentre(),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: padding.bottom + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ValueListenableBuilder<double>(
                        valueListenable: _pixelsPerMetre,
                        builder: (context, ppm, _) =>
                            _ScaleBar(pixelsPerMetre: ppm),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          drawing.attribution,
                          textAlign: TextAlign.end,
                          style: ShiaText.caption.copyWith(
                            fontSize: 10,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: selected == null
                        ? _HintCard(
                            key: const ValueKey('hint'),
                            onList: _showList,
                          )
                        : _FeatureCard(
                            key: ValueKey(selected.id),
                            feature: selected,
                            currentSite: widget.site,
                            me: _me,
                            onClose: () => _select(null),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The plan itself: the drawing in a pan-and-zoom viewer with the features
/// on top at a constant size. Still when not [interactive] (the card).
class ShrinePlanView extends StatefulWidget {
  const ShrinePlanView({
    super.key,
    required this.plan,
    required this.drawing,
    required this.site,
    this.interactive = true,
    this.selected,
    this.onSelect,
    this.me,
    this.meAccuracy,
    this.pixelsPerMetre,
    this.bottomInset = 0,
  });

  final GuidePlan plan;
  final ShrinePlan drawing;
  final GuideSite site;
  final bool interactive;
  final PlanFeature? selected;
  final ValueChanged<PlanFeature>? onSelect;

  /// Where the reader is, once they asked; [meAccuracy] in metres.
  final GeoPoint? me;
  final double? meAccuracy;

  /// Told the screen pixels per metre as the reader zooms (the scale bar).
  final ValueNotifier<double>? pixelsPerMetre;

  /// How much of the bottom the page's card covers: features are centred in
  /// the part above it.
  final double bottomInset;

  @override
  State<ShrinePlanView> createState() => _ShrinePlanViewState();
}

class _ShrinePlanViewState extends State<ShrinePlanView>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Animation<Matrix4>? _tween;
  Size _viewport = Size.zero;
  double _basePpm = 1;
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    _motion.addListener(() {
      if (_tween != null) _controller.value = _tween!.value;
    });
    _controller.addListener(_reportScale);
  }

  @override
  void dispose() {
    _motion.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _reportScale() {
    final notifier = widget.pixelsPerMetre;
    if (notifier == null) return;
    final ppm = _basePpm * _controller.value.getMaxScaleOnAxis();
    // Not during build: the first report comes from layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.value = ppm;
    });
  }

  Offset _base(GeoPoint point) =>
      (widget.drawing.project(point) - widget.drawing.bounds.topLeft) *
      _basePpm;

  bool covers(GeoPoint point) =>
      widget.drawing.bounds.inflate(60).contains(widget.drawing.project(point));

  Matrix4 _matrixFor(Offset base, double ppm) {
    final scale = (ppm / _basePpm).clamp(1.0, _maxScale);
    final visibleHeight =
        math.max(_viewport.height * 0.4, _viewport.height - widget.bottomInset);
    final centre = Offset(_viewport.width / 2, visibleHeight / 2 + 30);
    final t = centre - base * scale;
    return Matrix4.identity()
      ..translateByDouble(t.dx, t.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  double get _maxScale => math.max(1.0, _maxPixelsPerMetre / _basePpm);

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _controller.value, end: target)
        .animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward(from: 0);
  }

  void showFeature(PlanFeature feature) {
    final ppm = math.max(_basePpm * _controller.value.getMaxScaleOnAxis(),
        _minPixelsPerMetre(feature.kind) * 1.3 + 0.8);
    _animateTo(_matrixFor(_base(feature.location), ppm));
  }

  void showPoint(GeoPoint point) {
    final ppm = math.max(_basePpm * _controller.value.getMaxScaleOnAxis(), 3.0);
    _animateTo(_matrixFor(_base(point), ppm));
  }

  void recentre() => _animateTo(_initialMatrix());

  Matrix4 _initialMatrix() {
    final focus = widget.selected ?? widget.plan.focusFor(widget.site.id);
    final point = focus?.location ?? widget.site.location;
    return _matrixFor(_base(point), _focusPixelsPerMetre);
  }

  /// The page's top bar and its column of round buttons on the right.
  List<Rect> _chromeRects(double topPadding) => [
        Rect.fromLTWH(0, 0, _viewport.width, topPadding + 60),
        Rect.fromLTWH(_viewport.width - 68, 0, 68, topPadding + 222),
      ];

  void _layout(Size viewport) {
    if (viewport == _viewport) return;
    _viewport = viewport;
    final bounds = widget.drawing.bounds;
    // At scale 1 the whole plan fits.
    _basePpm = math.min(
        viewport.width / bounds.width, viewport.height / bounds.height);
    if (!_placed || !widget.interactive) {
      _controller.value = _initialMatrix();
      _placed = true;
    }
    _reportScale();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final palette = _PlanPalette(colors, Theme.of(context).brightness);
    return LayoutBuilder(builder: (context, constraints) {
      _layout(constraints.biggest);
      final bounds = widget.drawing.bounds;
      final canvasSize = Size(bounds.width, bounds.height) * _basePpm;
      final drawing = CustomPaint(
        size: canvasSize,
        painter: _PlanPainter(
          plan: widget.drawing,
          basePixelsPerMetre: _basePpm,
          palette: palette,
          zoom: _controller,
        ),
      );
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: palette.background),
            ),
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                panEnabled: widget.interactive,
                scaleEnabled: widget.interactive,
                minScale: 1,
                maxScale: _maxScale,
                boundaryMargin: EdgeInsets.symmetric(
                  horizontal: _viewport.width * 0.5,
                  vertical: _viewport.height * 0.5,
                ),
                onInteractionStart: (_) => _motion.stop(),
                child: drawing,
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _MarkerLayer(
                  features: widget.plan.features,
                  position: (point) => MatrixUtils.transformPoint(
                      _controller.value, _base(point)),
                  pixelsPerMetre:
                      _basePpm * _controller.value.getMaxScaleOnAxis(),
                  viewport: _viewport,
                  selected: widget.selected,
                  onSelect: widget.interactive ? widget.onSelect : null,
                  showLabels: true,
                  compact: !widget.interactive,
                  me: widget.me,
                  meAccuracy: widget.meAccuracy,
                  reserved: widget.interactive
                      ? _chromeRects(MediaQuery.paddingOf(context).top)
                      : const [],
                  reservedBottom: widget.bottomInset,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// The features at their screen positions, labelled where labels fit.
class _MarkerLayer extends StatelessWidget {
  const _MarkerLayer({
    required this.features,
    required this.position,
    required this.pixelsPerMetre,
    required this.viewport,
    required this.selected,
    required this.onSelect,
    required this.showLabels,
    required this.compact,
    required this.me,
    required this.meAccuracy,
    this.reserved = const [],
    this.reservedBottom = 0,
  });

  final List<PlanFeature> features;
  final Offset Function(GeoPoint) position;
  final double pixelsPerMetre;
  final Size viewport;
  final PlanFeature? selected;
  final ValueChanged<PlanFeature>? onSelect;
  final bool showLabels;

  /// The card's still view: only the zarih, places and gates.
  final bool compact;
  final GeoPoint? me;
  final double? meAccuracy;

  /// What the page's buttons cover, and the height its card covers.
  final List<Rect> reserved;
  final double reservedBottom;

  static double _markerSize(PlanFeatureKind kind) => switch (kind) {
        PlanFeatureKind.zarih => 30,
        PlanFeatureKind.place => 26,
        PlanFeatureKind.tomb => 20,
        PlanFeatureKind.gate => 20,
        PlanFeatureKind.maqam => 16,
        PlanFeatureKind.landmark => 14,
        PlanFeatureKind.door => 12,
      };

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    // Measured in the style the label is drawn in: the app font included.
    final labelStyle = DefaultTextStyle.of(context).style.merge(
          ShiaText.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        );
    final direction = Directionality.of(context);

    // Selected first, then by priority, so they win a label.
    final ordered = [...features]..sort((a, b) {
        if (a == selected) return -1;
        if (b == selected) return 1;
        return b.kind.labelPriority.compareTo(a.kind.labelPriority);
      });
    // The page's chrome: no label goes under it.
    final chrome = <Rect>[
      ...reserved,
      Rect.fromLTWH(
          0, viewport.height - reservedBottom, viewport.width, reservedBottom),
    ];
    final markers = <Widget>[];
    final labels = <Widget>[];
    final screen = (Offset.zero & viewport).inflate(40);
    final visible = Offset.zero & viewport;

    // Markers first, so a label never hides a marker: one on top of a
    // bigger one is left out until zoomed apart.
    final markerRects = <Rect>[];
    final placed = <(PlanFeature, Offset, double)>[];
    for (final feature in ordered) {
      final isSelected = feature == selected;
      if (compact &&
          !{PlanFeatureKind.zarih, PlanFeatureKind.place, PlanFeatureKind.gate}
              .contains(feature.kind)) {
        continue;
      }
      if (!isSelected && pixelsPerMetre < _minPixelsPerMetre(feature.kind)) {
        continue;
      }
      final at = position(feature.location);
      if (!screen.contains(at)) continue;
      final size = _markerSize(feature.kind) * (isSelected ? 1.25 : 1);
      final markerRect = Rect.fromCenter(center: at, width: size, height: size);
      if (!isSelected &&
          markerRects.any((r) => r.overlaps(markerRect.deflate(3)))) {
        continue;
      }
      markerRects.add(markerRect);
      placed.add((feature, at, size));
      markers.add(Positioned(
        left: at.dx - 22,
        top: at.dy - 22,
        width: 44,
        height: 44,
        child: _Marker(
          feature: feature,
          size: size,
          selected: isSelected,
          onTap: onSelect == null ? null : () => onSelect!(feature),
        ),
      ));
    }

    // Then labels, in the same order, where they fit.
    final taken = [...chrome, ...markerRects];
    for (final (feature, at, size) in placed) {
      if (!showLabels || !visible.contains(at)) continue;
      if (compact && feature.kind == PlanFeatureKind.gate) continue;
      final isSelected = feature == selected;
      final painter = TextPainter(
        text: TextSpan(text: feature.name, style: labelStyle),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 170);
      final labelSize = Size(painter.width + 14, painter.height + 6);
      Rect? place;
      for (final dy in [size / 2 + 3, -(size / 2 + 3 + labelSize.height)]) {
        // Kept on screen: slid sideways rather than cut off at an edge.
        final double left = (at.dx - labelSize.width / 2)
            .clamp(6.0, math.max(6.0, viewport.width - labelSize.width - 6));
        final rect =
            Rect.fromLTWH(left, at.dy + dy, labelSize.width, labelSize.height);
        if (!taken.any((r) => r.overlaps(rect))) {
          place = rect;
          break;
        }
      }
      if (place == null) continue;
      taken.add(place);
      labels.add(Positioned.fromRect(
        rect: place,
        // The marker already says the name to a screen reader.
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: _Label(
              text: feature.name,
              style: labelStyle,
              selected: isSelected,
            ),
          ),
        ),
      ));
    }

    final meAt = me == null ? null : position(me!);
    final accuracyPx =
        meAccuracy == null ? 0.0 : (meAccuracy! * pixelsPerMetre).clamp(0, 400);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (meAt != null && screen.contains(meAt)) ...[
          Positioned(
            left: meAt.dx - accuracyPx,
            top: meAt.dy - accuracyPx,
            width: accuracyPx * 2,
            height: accuracyPx * 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2F80ED).withValues(alpha: 0.14),
                  border: Border.all(
                      color: const Color(0xFF2F80ED).withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
        ],
        ...labels,
        // Later markers draw on top: put the important ones last.
        ...markers.reversed,
        if (meAt != null && screen.contains(meAt))
          Positioned(
            left: meAt.dx - 9,
            top: meAt.dy - 9,
            width: 18,
            height: 18,
            child: IgnorePointer(
              child: Semantics(
                label: context.l10n.ziyaratGuideMapYou,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2F80ED),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: colors.glassShadow,
                          blurRadius: 6,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.style,
    required this.selected,
  });

  final String text;
  final TextStyle style;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? colors.accent
            : colors.glassSolid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: selected ? colors.accent : colors.glassBorder),
        boxShadow: [
          BoxShadow(
              color: colors.glassShadow,
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: selected ? style.copyWith(color: colors.onAccent) : style,
        ),
      ),
    );
  }
}

/// One feature's marker: gold for a zarih or tomb, the accent for gates
/// and doors, a pin for another place.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.feature,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final PlanFeature feature;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final ring = selected ? colors.accent : Colors.white;
    final shadow = [
      BoxShadow(
          color: colors.glassShadow, blurRadius: 5, offset: const Offset(0, 1)),
      if (selected)
        BoxShadow(
            color: colors.accent.withValues(alpha: 0.35),
            blurRadius: 0,
            spreadRadius: 5),
    ];
    final Widget mark = switch (feature.kind) {
      PlanFeatureKind.zarih => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.lerp(colors.gold, Colors.white, 0.35)!,
                colors.gold
              ],
            ),
            border: Border.all(color: ring, width: 2.5),
            boxShadow: shadow,
          ),
          child: CustomPaint(painter: _DomeGlyph(colors.onGold)),
        ),
      PlanFeatureKind.tomb => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.gold,
            border: Border.all(color: ring, width: 2),
            boxShadow: shadow,
          ),
        ),
      PlanFeatureKind.maqam => Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.gold, width: 2.5),
              boxShadow: shadow,
            ),
          ),
        ),
      PlanFeatureKind.place => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: shadow,
          ),
          child: Center(
            child: OutlineIcon(OutlineGlyph.pin,
                size: size * 0.55, color: colors.onAccent, strokeWidth: 2.2),
          ),
        ),
      PlanFeatureKind.gate => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: selected ? colors.accent : colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.accent, width: 2),
            boxShadow: shadow,
          ),
          child: CustomPaint(
              painter: _ArchGlyph(selected ? colors.onAccent : colors.accent)),
        ),
      PlanFeatureKind.door => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: shadow,
          ),
        ),
      PlanFeatureKind.landmark => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.textMuted,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: shadow,
          ),
        ),
    };
    return Semantics(
      button: onTap != null,
      selected: selected,
      label:
          '${feature.name}, ${guidePlanFeatureKindLabel(l10n, feature.kind)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: mark),
      ),
    );
  }
}

/// A small dome with a finial, on the zarih's marker.
class _DomeGlyph extends CustomPainter {
  _DomeGlyph(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()..color = color;
    final base = size.height * 0.68;
    final dome = Path()
      ..moveTo(w * 0.27, base)
      ..quadraticBezierTo(w * 0.25, w * 0.32, w * 0.5, w * 0.30)
      ..quadraticBezierTo(w * 0.75, w * 0.32, w * 0.73, base)
      ..close();
    canvas.drawPath(dome, paint);
    canvas.drawRect(
        Rect.fromLTRB(w * 0.24, base, w * 0.76, base + w * 0.06), paint);
    canvas.drawLine(Offset(w * 0.5, w * 0.30), Offset(w * 0.5, w * 0.18),
        paint..strokeWidth = w * 0.05);
  }

  @override
  bool shouldRepaint(_DomeGlyph old) => old.color != color;
}

/// A doorway arch, on a gate's marker.
class _ArchGlyph extends CustomPainter {
  _ArchGlyph(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    final arch = Path()
      ..moveTo(w * 0.3, h * 0.78)
      ..lineTo(w * 0.3, h * 0.48)
      ..arcToPoint(Offset(w * 0.7, h * 0.48), radius: Radius.circular(w * 0.2))
      ..lineTo(w * 0.7, h * 0.78);
    canvas.drawPath(arch, paint);
  }

  @override
  bool shouldRepaint(_ArchGlyph old) => old.color != color;
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      height: 44,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.glassSolid.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.glassBorder),
        boxShadow: [
          BoxShadow(
              color: colors.glassShadow,
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

/// North up (the plan never turns), with the qibla's direction from here.
class _NorthAndQibla extends StatelessWidget {
  const _NorthAndQibla({required this.origin});

  final GeoPoint origin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final qibla = qiblaBearingDegrees(origin);
    return Semantics(
      label:
          l10n.qiblaBearingFromNorth(l10n.qiblaPageTitle, '${qibla.round()}°'),
      excludeSemantics: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: colors.line),
        ),
        child: CustomPaint(
          painter: _CompassGlyph(
            north: colors.danger,
            qibla: colors.gold,
            muted: colors.textMuted,
            qiblaDegrees: qibla,
          ),
        ),
      ),
    );
  }
}

class _CompassGlyph extends CustomPainter {
  _CompassGlyph({
    required this.north,
    required this.qibla,
    required this.muted,
    required this.qiblaDegrees,
  });

  final Color north;
  final Color qibla;
  final Color muted;
  final double qiblaDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final needle = Path()
      ..moveTo(c.dx, c.dy - r * 0.72)
      ..lineTo(c.dx + r * 0.17, c.dy)
      ..lineTo(c.dx - r * 0.17, c.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = north);
    final tail = Path()
      ..moveTo(c.dx, c.dy + r * 0.72)
      ..lineTo(c.dx + r * 0.17, c.dy)
      ..lineTo(c.dx - r * 0.17, c.dy)
      ..close();
    canvas.drawPath(tail, Paint()..color = muted.withValues(alpha: 0.5));
    // The qibla: a gold dot on the rim.
    final a = qiblaDegrees * math.pi / 180;
    final q = c + Offset(math.sin(a), -math.cos(a)) * (r * 0.78);
    canvas.drawCircle(q, r * 0.16, Paint()..color = qibla);
    canvas.drawCircle(
        q,
        r * 0.16,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_CompassGlyph old) =>
      old.qiblaDegrees != qiblaDegrees || old.north != north;
}

/// A bar some round number of metres long, 50-110 px.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar({required this.pixelsPerMetre});

  final double pixelsPerMetre;

  @override
  Widget build(BuildContext context) {
    if (pixelsPerMetre <= 0) return const SizedBox.shrink();
    final colors = ShiaColors.of(context);
    const steps = [5, 10, 20, 25, 50, 100, 200, 250, 500, 1000];
    var metres = steps.last;
    for (final step in steps) {
      if (step * pixelsPerMetre >= 50) {
        metres = step;
        break;
      }
    }
    final width = metres * pixelsPerMetre;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatMetres(context.l10n, metres.toDouble()),
          style: ShiaText.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: width,
          height: 6,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colors.text, width: 1.5),
              right: BorderSide(color: colors.text, width: 1.5),
              bottom: BorderSide(color: colors.text, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(ShiaColors colors) => BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: colors.line),
      boxShadow: [
        BoxShadow(
            color: colors.glassShadow,
            blurRadius: 16,
            offset: const Offset(0, 4)),
      ],
    );

class _HintCard extends StatelessWidget {
  const _HintCard({super.key, required this.onList});

  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    // The whole card opens the list: no button to squeeze the hint at a
    // large text size.
    return Semantics(
      button: true,
      label: '${l10n.ziyaratGuideMapHint} ${l10n.ziyaratGuideMapPlaces}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: _cardDecoration(colors),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onList,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.ziyaratGuideMapHint,
                          style: ShiaText.secondary
                              .copyWith(color: colors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.ziyaratGuideMapPlaces,
                          style: ShiaText.secondary.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlineIcon(OutlineGlyph.lines,
                      size: 22, color: colors.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the selected feature is, where, and what to recite there.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.feature,
    required this.currentSite,
    required this.me,
    required this.onClose,
  });

  final PlanFeature feature;
  final GuideSite currentSite;
  final GeoPoint? me;
  final VoidCallback onClose;

  Future<void> _directions(BuildContext context) async {
    AnalyticsService.feature(
      'ziyarat_guide_plan_directions',
      label: feature.englishName,
      parameters: {'plan': feature.plan.id, 'feature': feature.id},
    );
    final opened = await launchExternalUri(mapsUriFor(
        feature.location, feature.arabicName ?? feature.englishName));
    if (!opened && context.mounted) {
      showToast(context.l10n.ziyaratGuideMapsFailed);
    }
  }

  void _openSite(BuildContext context, GuideSite site) {
    pushPageRoute(context, ZiyaratSitePage(site: site));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final side = planFeatureSide(feature);
    final person = feature.person;
    final note = feature.note ?? person?.note;
    final site = feature.site;
    final otherSite = site != null && site.id != currentSite.id ? site : null;
    final refs = [
      for (final ref in feature.ziyarat)
        if (items.containsKey(ref.uid)) ref,
    ];
    final distance =
        me == null ? null : greatCircleDistanceKm(me!, feature.location) * 1000;
    final meta = [
      guidePlanFeatureKindLabel(l10n, feature.kind),
      if (side != null) l10n.ziyaratGuideMapSide(side),
      if (distance != null)
        l10n.ziyaratGuideMapFromYou(_formatMetres(l10n, distance)),
    ].join(' · ');

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.48),
      child: Container(
        decoration: _cardDecoration(colors),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta,
                          style: ShiaText.caption.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          feature.name,
                          style:
                              ShiaText.cardTitle.copyWith(color: colors.text),
                        ),
                        if (feature.arabicName != null &&
                            feature.arabicName != feature.name)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              feature.arabicName!,
                              textDirection: TextDirection.rtl,
                              style: ShiaText.body.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: onClose,
                    icon: OutlineIcon(OutlineGlyph.close,
                        size: 18, color: colors.textMuted),
                  ),
                ],
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Text(
                    note,
                    style: ShiaText.secondary.copyWith(color: colors.text),
                  ),
                ),
              if (refs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CardList(children: [
                    for (var i = 0; i < refs.length; i++)
                      ZikrRefRow(
                        ref: refs[i],
                        first: i == 0,
                        last: i == refs.length - 1,
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PageButton(
                    label: l10n.ziyaratGuideDirections,
                    glyph: OutlineGlyph.pin,
                    onPressed: () => _directions(context),
                  ),
                  if (otherSite != null)
                    PageButton(
                      label: otherSite.name,
                      glyph: OutlineGlyph.arrowRight,
                      onPressed: () => _openSite(context, otherSite),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every feature of [plan] in a sheet, grouped; returns the one tapped.
Future<PlanFeature?> showPlanFeatureList(BuildContext context, GuidePlan plan) {
  final colors = ShiaColors.of(context);
  return showModalBottomSheet<PlanFeature>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.ground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.94,
      builder: (context, scroll) =>
          PlanFeatureList(plan: plan, controller: scroll),
    ),
  );
}

/// The list inside [showPlanFeatureList]; public for tests.
class PlanFeatureList extends StatelessWidget {
  const PlanFeatureList({super.key, required this.plan, this.controller});

  final GuidePlan plan;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final groups = <(String, List<PlanFeature>)>[
      (
        l10n.ziyaratGuideMapTombs,
        [
          for (final f in plan.features)
            if (f.kind == PlanFeatureKind.zarih ||
                f.kind == PlanFeatureKind.tomb ||
                f.kind == PlanFeatureKind.maqam)
              f
        ]
      ),
      (
        l10n.ziyaratGuideMapGates,
        [
          for (final f in plan.features)
            if (f.kind == PlanFeatureKind.gate) f
        ]
      ),
      (
        l10n.ziyaratGuideMapDoors,
        [
          for (final f in plan.features)
            if (f.kind == PlanFeatureKind.door) f
        ]
      ),
      (
        l10n.ziyaratGuideMapNearby,
        [
          for (final f in plan.features)
            if (f.kind == PlanFeatureKind.place ||
                f.kind == PlanFeatureKind.landmark)
              f
        ]
      ),
    ];
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.ziyaratGuideMapPlaces,
                      style:
                          ShiaText.sectionTitle.copyWith(color: colors.text)),
                ),
              ],
            ),
          ),
        ),
        for (final (label, features) in groups)
          if (features.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverMainAxisGroup(slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GroupLabel(label),
                  ),
                ),
                SliverCardList(
                  itemCount: features.length,
                  itemBuilder: (context, i) {
                    final feature = features[i];
                    final side = planFeatureSide(feature);
                    final count = feature.ziyarat
                        .where((r) => items.containsKey(r.uid))
                        .length;
                    return CardListRow(
                      first: i == 0,
                      last: i == features.length - 1,
                      title: Text(feature.name),
                      subtitle: Text([
                        if (side != null) l10n.ziyaratGuideMapSide(side),
                        if (count > 0) l10n.listCountZiyarats(count),
                      ].join(' · ')),
                      onTap: () => Navigator.of(context).pop(feature),
                    );
                  },
                ),
              ]),
            ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}
