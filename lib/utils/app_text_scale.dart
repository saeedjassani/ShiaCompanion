import 'package:flutter/widgets.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// The in-app "Text size" preference: a multiplier applied on top of
/// whatever text scale the operating system already asks for, so someone who
/// has bumped their phone's font size keeps that and can still nudge this app
/// further in either direction.
class AppTextScaleProvider extends ChangeNotifier {
  static const String prefsKey = 'app_text_scale';
  static const double defaultScale = 1.0;
  static const double minScale = 0.8;
  static const double maxScale = 1.5;

  /// Slider stops, 5% apart.
  static const int divisions = 14;

  double _scale = defaultScale;

  double get scale => _scale;

  AppTextScaleProvider() {
    _load();
  }

  Future<void> _load() async {
    await SP.init();
    final stored = SP.prefs.getDouble(prefsKey);
    if (stored == null) return;
    _scale = normalize(stored);
    notifyListeners();
  }

  /// Clamps to the supported range and snaps to a slider stop, so a value
  /// written by an older build (or a drag that landed between stops) can
  /// never leave the slider in an invalid position.
  static double normalize(double value) {
    final clamped = value.clamp(minScale, maxScale).toDouble();
    const step = (maxScale - minScale) / divisions;
    final snapped = minScale + ((clamped - minScale) / step).round() * step;
    return double.parse(snapped.toStringAsFixed(2));
  }

  /// Updates the live value immediately; persisting is left to [save] so a
  /// slider drag doesn't write to disk on every frame.
  void setScale(double value) {
    final next = normalize(value);
    if (next == _scale) return;
    _scale = next;
    notifyListeners();
  }

  Future<void> save() async {
    if (!SP.isInitialized) return;
    await SP.prefs.setDouble(prefsKey, _scale);
  }

  static String label(double scale) => '${(scale * 100).round()}%';

  /// Wraps [child] so every descendant's text is scaled by [scale] on top of
  /// the system text scale already in [context]'s MediaQuery.
  Widget apply(BuildContext context, Widget child) {
    if (_scale == defaultScale) return child;
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: AppTextScaler(mediaQuery.textScaler, _scale),
      ),
      child: child,
    );
  }
}

/// Multiplies an existing (possibly nonlinear) [TextScaler] by [factor],
/// rather than replacing it with a linear one, so Android 14's nonlinear
/// system font scaling keeps working underneath the in-app setting.
@immutable
class AppTextScaler implements TextScaler {
  const AppTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  @Deprecated('Use scale() instead.')
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    return AppTextScaler(
      base.clamp(
        minScaleFactor: minScaleFactor / factor,
        maxScaleFactor: maxScaleFactor / factor,
      ),
      factor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => 'AppTextScaler($base × $factor)';
}
