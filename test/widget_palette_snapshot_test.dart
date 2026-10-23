import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/theme/app_palette.dart';

/// `widget_<token>` colours from an Android colors.xml, as `#AARRGGBB`.
Map<String, String> _androidColors(String dir) {
  final xml =
      File('android/app/src/main/res/$dir/colors.xml').readAsStringSync();
  return {
    for (final m
        in RegExp(r'<color name="widget_(\w+)">(#[0-9A-Fa-f]{8})</color>')
            .allMatches(xml))
      m[1]!: m[2]!.toUpperCase(),
  };
}

void main() {
  final service = HomeScreenWidgetService.instance;
  String key(String token, Brightness b) =>
      HomeScreenWidgetService.widgetColorKey(token, b);

  test('brown is what the Android widgets draw without the setting', () {
    final snapshot = service.buildPaletteSnapshot(AppPalette.brown);
    for (final (dir, brightness) in [
      ('values', Brightness.light),
      ('values-night', Brightness.dark),
    ]) {
      final xml = _androidColors(dir);
      for (final token in HomeScreenWidgetService.widgetColorTokens) {
        // No border in light mode: the surface stands in for it (a tint
        // can't draw transparent).
        final expected = token == 'border' && brightness == Brightness.light
            ? xml['surface']
            : xml[token];
        expect(snapshot[key(token, brightness)], expected,
            reason: '$token in $dir');
      }
    }
  });

  test('every palette publishes every colour, opaque but the divider', () {
    for (final palette in AppPalette.values) {
      final snapshot = service.buildPaletteSnapshot(palette);
      expect(snapshot,
          hasLength(HomeScreenWidgetService.widgetColorTokens.length * 2));
      snapshot.forEach((k, v) {
        expect(v, matches(RegExp(r'^#[0-9A-F]{8}$')), reason: k);
        if (!k.contains('divider')) expect(v, startsWith('#FF'), reason: k);
      });
    }
    expect(
        service.buildPaletteSnapshot(
            AppPalette.green)[key('surface', Brightness.light)],
        isNot(service.buildPaletteSnapshot(
            AppPalette.brown)[key('surface', Brightness.light)]));
  });
}
