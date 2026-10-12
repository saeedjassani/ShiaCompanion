import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:yaml/yaml.dart';

/// The theme's fallback fonts must have nothing but Arabic script.
///
/// Flutter only asks the system for its default font when none of a style's
/// families can be found. When the theme's own family can't be (Android has
/// no font it calls "Roboto"), the fallback list is all a style has, and a
/// fallback with Latin letters then draws every English word in the app -
/// which is how the full Scheherazade turned the apps' text serif. A font
/// with no Latin glyphs can't: those characters still go to the system.
///
/// `flutter test` can't show this by rendering, because its font manager
/// answers to any family name; so this reads the fonts' character maps.
void main() {
  test("the theme's fallback fonts have no Latin, digits or punctuation", () {
    final fallback = buildAppTheme(Brightness.light)
        .textTheme
        .bodyMedium!
        .fontFamilyFallback;
    expect(fallback, isNotEmpty);

    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final fonts = (pubspec['flutter'] as Map)['fonts'] as YamlList;
    final assetsByFamily = {
      for (final font in fonts)
        font['family'] as String: [
          for (final file in font['fonts'] as YamlList) file['asset'] as String,
        ],
    };

    for (final family in fallback!) {
      final assets = assetsByFamily[family];
      expect(assets, isNotNull, reason: '"$family" is not a bundled font');
      for (final asset in assets!) {
        final stray = _codePoints(File(asset).readAsBytesSync())
            // Below the Arabic block, only the combining grapheme joiner,
            // which never draws anything.
            .where((cp) => cp < 0x0600 && cp != 0x034F)
            .toList();
        expect(
          stray,
          isEmpty,
          reason: '$asset can draw '
              '${stray.take(10).map((cp) => String.fromCharCode(cp)).join(' ')}'
              ' - as a theme fallback it would draw them in English text too.',
        );
      }
    }
  });
}

/// Every code point a TrueType/OpenType font's `cmap` maps to a glyph, from
/// its format 4 and format 12 subtables (which between them cover what a
/// Unicode font carries).
Set<int> _codePoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final numTables = data.getUint16(4);
  int? cmap;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    if (String.fromCharCodes(bytes, record, record + 4) == 'cmap') {
      cmap = data.getUint32(record + 8);
    }
  }
  if (cmap == null) throw StateError('No cmap table');

  final codePoints = <int>{};
  final numSubtables = data.getUint16(cmap + 2);
  for (var i = 0; i < numSubtables; i++) {
    final sub = cmap + data.getUint32(cmap + 4 + i * 8 + 4);
    switch (data.getUint16(sub)) {
      case 4:
        final segCount = data.getUint16(sub + 6) ~/ 2;
        final ends = sub + 14;
        final starts = ends + segCount * 2 + 2;
        final deltas = starts + segCount * 2;
        final rangeOffsets = deltas + segCount * 2;
        for (var s = 0; s < segCount; s++) {
          final end = data.getUint16(ends + s * 2);
          final start = data.getUint16(starts + s * 2);
          final delta = data.getUint16(deltas + s * 2);
          final rangeOffset = data.getUint16(rangeOffsets + s * 2);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            int glyph;
            if (rangeOffset == 0) {
              glyph = (c + delta) & 0xFFFF;
            } else {
              final at = rangeOffsets + s * 2 + rangeOffset + (c - start) * 2;
              glyph = data.getUint16(at);
              if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
            }
            if (glyph != 0) codePoints.add(c);
          }
        }
      case 12:
        final groups = data.getUint32(sub + 12);
        for (var g = 0; g < groups; g++) {
          final group = sub + 16 + g * 12;
          final start = data.getUint32(group);
          final end = data.getUint32(group + 4);
          final firstGlyph = data.getUint32(group + 8);
          for (var c = start; c <= end; c++) {
            if (firstGlyph + (c - start) != 0) codePoints.add(c);
          }
        }
    }
  }
  return codePoints;
}
