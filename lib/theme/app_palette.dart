import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'shia_colors.dart';

/// The Colour setting: the hue the whole app is drawn in.
///
/// [brown] is the revamp's own palette (docs/DESIGN_SPEC.md, "Colour
/// tokens"). Every other palette is that palette recoloured token by token
/// in OKLCH: each token keeps its perceived lightness, takes the palette's
/// hue, and has its colourfulness scaled. Lightness is what contrast
/// follows, so the spec's ratios carry over to every palette
/// (test/app_theme_test.dart checks them all).
///
/// The gold (the prayer card's one button, the current prayer's highlight)
/// is recoloured too, softer than the accent: a light mint in green, a
/// light grey in gray. Success and danger mean the same thing in every
/// palette and are left as they are.
///
/// [clear] is the exception to "recoloured": its prayer card is a white
/// card like any other, with the page's text on it and the accent for its
/// button, so nothing on the page is dark or strongly coloured.
enum AppPalette {
  brown(null),
  clear(_Tint(
      neutralHue: 250,
      neutral: 0,
      accentHue: 250,
      accent: 0.5,
      plainCard: true)),
  gray(_Tint(neutralHue: 0, neutral: 0, accentHue: 0, accent: 0)),
  green(_Tint(neutralHue: 150, neutral: 0.7, accentHue: 148, accent: 1.5)),
  teal(_Tint(neutralHue: 195, neutral: 0.7, accentHue: 195, accent: 1.3)),
  blue(_Tint(neutralHue: 266, neutral: 0.9, accentHue: 266, accent: 1.6)),
  purple(_Tint(neutralHue: 305, neutral: 0.8, accentHue: 305, accent: 1.4)),
  maroon(_Tint(neutralHue: 5, neutral: 0.7, accentHue: 5, accent: 1.4));

  const AppPalette(this._tint);

  final _Tint? _tint;

  static final Map<(AppPalette, Brightness), ShiaColors> _cache = {};

  /// This palette's tokens for [brightness].
  ShiaColors colors(Brightness brightness) =>
      _cache[(this, brightness)] ??= _tint == null
          ? ShiaColors.forBrightness(brightness)
          : _tint.apply(ShiaColors.forBrightness(brightness));

  static AppPalette? parse(String? value) {
    for (final palette in values) {
      if (palette.name == value) return palette;
    }
    return null;
  }

  /// The palette's name in the setting.
  String label([AppLocalizations? l10n]) {
    final s = l10n ?? L10n.current;
    return switch (this) {
      brown => s.paletteBrown,
      clear => s.paletteClear,
      gray => s.paletteGray,
      green => s.paletteGreen,
      teal => s.paletteTeal,
      blue => s.paletteBlue,
      purple => s.palettePurple,
      maroon => s.paletteMaroon,
    };
  }
}

/// How a palette recolours the brown one. The accent tokens (the accent,
/// the prayer card and what sits on it, the tinted notice) and the neutral
/// ones (grounds, text, lines, glass) each get a hue (OKLCH degrees) and a
/// factor for their chroma: 0 is grey, 1 as colourful as the brown. Gold
/// takes the accent's hue at a little over half its factor.
///
/// [plainCard] draws the prayer card as a surface card instead (see
/// [AppPalette.clear]).
class _Tint {
  const _Tint({
    required this.neutralHue,
    required this.neutral,
    required this.accentHue,
    required this.accent,
    this.plainCard = false,
  });

  final double neutralHue;
  final double neutral;
  final double accentHue;
  final double accent;
  final bool plainCard;

  ShiaColors apply(ShiaColors c) {
    Color n(Color color) => _recolour(color, neutralHue, neutral);
    Color a(Color color) => _recolour(color, accentHue, accent);
    final recoloured = _recoloured(c, n, a);
    if (!plainCard) return recoloured;
    final r = recoloured;
    return r.copyWith(
      prayerCard: r.surface,
      prayerCardBorder: r.line,
      onPrayerCard: r.text,
      onPrayerCardMuted: r.textMuted,
      gold: r.accent,
      onGold: r.onAccent,
      tintedNotice: r.well,
    );
  }

  ShiaColors _recoloured(
      ShiaColors c, Color Function(Color) n, Color Function(Color) a) {
    return ShiaColors(
      ground: n(c.ground),
      readerGround: n(c.readerGround),
      surface: n(c.surface),
      well: n(c.well),
      line: n(c.line),
      divider: n(c.divider),
      readerDivider: n(c.readerDivider),
      text: n(c.text),
      textMuted: n(c.textMuted),
      translation: n(c.translation),
      accent: a(c.accent),
      onAccent: n(c.onAccent),
      prayerCard: a(c.prayerCard),
      prayerCardBorder: a(c.prayerCardBorder),
      onPrayerCard: a(c.onPrayerCard),
      onPrayerCardMuted: a(c.onPrayerCardMuted),
      gold: _recolour(c.gold, accentHue, accent * 0.6),
      onGold: n(c.onGold),
      tintedNotice: a(c.tintedNotice),
      chevron: n(c.chevron),
      success: c.success,
      danger: c.danger,
      glass: n(c.glass),
      glassSolid: n(c.glassSolid),
      glassBorder: n(c.glassBorder),
      glassShadow: n(c.glassShadow),
    );
  }
}

/// [color] with its OKLCH hue set to [hue] and its chroma scaled by
/// [chroma], keeping its lightness and alpha. Chroma is pulled back until
/// the result fits in sRGB, so a vivid hue never clips to a different
/// lightness.
Color _recolour(Color color, double hue, double chroma) {
  final (l, c, _) = _toOklch(color);
  // White, black and greys stay as they are.
  if (c < 1e-4) return color;
  final target = c * chroma;
  var rgb = _fromOklch(l, target, hue);
  if (!_inGamut(rgb)) {
    var lo = 0.0, hi = target;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (_inGamut(_fromOklch(l, mid, hue))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    rgb = _fromOklch(l, lo, hue);
  }
  int channel(double linear) =>
      (_toSrgb(linear.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);
  return Color.fromARGB((color.a * 255).round(), channel(rgb.$1),
      channel(rgb.$2), channel(rgb.$3));
}

bool _inGamut((double, double, double) rgb) {
  const e = 1e-6;
  bool ok(double v) => v >= -e && v <= 1 + e;
  return ok(rgb.$1) && ok(rgb.$2) && ok(rgb.$3);
}

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double c) => c <= 0.0031308
    ? 12.92 * c
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

double _cbrt(double v) =>
    v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

/// Björn Ottosson's OKLab, as lightness, chroma and hue (degrees).
(double, double, double) _toOklch(Color color) {
  final r = _toLinear(color.r), g = _toLinear(color.g), b = _toLinear(color.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  return (
    lightness,
    math.sqrt(a * a + bb * bb),
    (math.atan2(bb, a) * 180 / math.pi) % 360,
  );
}

/// Linear sRGB, possibly out of range, for an OKLCH colour.
(double, double, double) _fromOklch(double lightness, double c, double hue) {
  final h = hue * math.pi / 180;
  final a = c * math.cos(h), b = c * math.sin(h);
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
  return (
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}
