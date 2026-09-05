import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/widgets/home_glyph.dart';

void main() {
  group('HomeGlyphType', () {
    test('contains the expected distinct spiritual glyph types', () {
      final types = HomeGlyphType.values.toSet();
      expect(types, hasLength(HomeGlyphType.values.length));
      expect(types, containsAll([
        HomeGlyphType.namaz,
        HomeGlyphType.duas,
        HomeGlyphType.surahs,
        HomeGlyphType.tasbeeh,
        HomeGlyphType.aamaal,
        HomeGlyphType.munajaat,
        HomeGlyphType.rakaat,
        HomeGlyphType.taqeebat,
        HomeGlyphType.todaysRecitations,
        HomeGlyphType.ziyaraat,
      ]));
    });

    test('all menu items with custom glyphs map to valid HomeGlyphTypes', () {
      final itemsWithGlyphs =
          homeMenuItems.where((item) => item.glyphType != null).toList();

      expect(itemsWithGlyphs.length, greaterThanOrEqualTo(8));

      for (final item in itemsWithGlyphs) {
        expect(HomeGlyphType.values, contains(item.glyphType));
      }
    });
  });

  group('HomeGlyph Widget', () {
    testWidgets('renders each glyph type cleanly without errors',
        (WidgetTester tester) async {
      for (final type in HomeGlyphType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: HomeGlyph(
                  type: type,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(HomeGlyph), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders all homeMenuItems icons and glyphs in home tile context',
        (WidgetTester tester) async {
      for (final item in homeMenuItems) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal,
                  child: item.buildIcon(size: 24, color: Colors.white),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: item.label);
      }
    });
  });
}
