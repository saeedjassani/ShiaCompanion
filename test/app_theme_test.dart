import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/theme/shia_colors.dart';

/// WCAG 2 contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const light = ShiaColors.light;
  const dark = ShiaColors.dark;

  group('contrast matches the token table in DESIGN_SPEC.md', () {
    void expectRatio(Color fg, Color bg, double stated) =>
        expect(_contrast(fg, bg), closeTo(stated, 0.05));

    test('light', () {
      expectRatio(light.text, light.ground, 14.9);
      expectRatio(light.textMuted, light.ground, 6.1);
      expectRatio(light.translation, light.readerGround, 9.4);
      expectRatio(light.accent, light.ground, 7.1);
      expectRatio(light.onAccent, light.accent, 7.7);
      expectRatio(light.onPrayerCard, light.prayerCard, 10.8);
      expectRatio(light.onPrayerCardMuted, light.prayerCard, 7.3);
      expectRatio(light.onGold, light.gold, 9.5);
      expectRatio(light.text, light.tintedNotice, 12.9);
      expectRatio(light.chevron, light.surface, 3.3);
      expectRatio(light.success, light.surface, 6.3);
      expectRatio(light.danger, light.surface, 6.5);
    });

    test('dark', () {
      expectRatio(dark.text, dark.ground, 15.9);
      expectRatio(dark.textMuted, dark.ground, 8.9);
      expectRatio(dark.translation, dark.readerGround, 10.4);
      expectRatio(dark.accent, dark.ground, 11.2);
      expectRatio(dark.onAccent, dark.accent, 9.7);
      expectRatio(dark.onGold, dark.gold, 9.5);
    });

    test('every text token clears 4.5 : 1 on every surface it sits on', () {
      for (final c in [light, dark]) {
        for (final bg in [c.ground, c.surface, c.well, c.glassSolid]) {
          expect(_contrast(c.text, bg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.textMuted, bg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.accent, bg), greaterThanOrEqualTo(4.5));
        }
        expect(_contrast(c.onPrayerCardMuted, c.prayerCard),
            greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('buildAppTheme', () {
    for (final brightness in Brightness.values) {
      test('maps the tokens onto Material roles (${brightness.name})', () {
        final theme = buildAppTheme(brightness);
        final c = ShiaColors.forBrightness(brightness);
        final scheme = theme.colorScheme;

        expect(theme.brightness, brightness);
        expect(theme.extension<ShiaColors>(), same(c));
        expect(theme.scaffoldBackgroundColor, c.ground);
        expect(scheme.surface, c.ground);
        expect(scheme.surfaceContainerLow, c.surface);
        expect(scheme.primary, c.accent);
        expect(scheme.onPrimary, c.onAccent);
        expect(scheme.onSurface, c.text);
        expect(scheme.onSurfaceVariant, c.textMuted);
        expect(scheme.outlineVariant, c.line);
        expect(scheme.error, c.danger);
        // The pink cast came from tinting elevated surfaces.
        expect(scheme.surfaceTint, Colors.transparent);
        expect(theme.appBarTheme.backgroundColor, c.ground);
      });
    }
  });

  test('ShiaColors.of falls back to the brightness when the theme has none',
      () {
    expect(ShiaColors.forBrightness(Brightness.dark), same(dark));
    expect(ShiaColors.forBrightness(Brightness.light), same(light));
    expect(light.lerp(dark, 1).ground, dark.ground);
    expect(light.copyWith(accent: dark.accent).accent, dark.accent);
  });
}
