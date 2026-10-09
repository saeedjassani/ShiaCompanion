import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/saved_verse.dart';
import 'package:shia_companion/pages/favorites_page.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/services/saved_verses_manager.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  setUpAll(setUpFirebaseForRenderTests);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    SavedVersesManager.instance.resetForTesting();
  });

  tearDown(() => isUserAdmin = false);

  /// Signed out, so the favourites are the device's own.
  Future<void> keep(WidgetTester tester, List<String> titles) async {
    await SP.prefs.setString(
      'favorites_guest',
      jsonEncode([
        for (var i = 0; i < titles.length; i++)
          {'uid': 'E${i + 1}', 'title': titles[i], 'type': 0},
      ]),
    );
    await tester
        .runAsync(() => FavoritesManager.instance.loadFavorites(force: true));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: FavoritesPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('says how to keep one before anything is kept', (tester) async {
    await keep(tester, []);
    await pump(tester);

    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.textContaining('Tap the heart'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('lists favorites in their order, with no handles until Edit',
      (tester) async {
    await keep(tester, ['Dua Kumayl', 'Ziyarat Ashura']);
    await pump(tester);

    expect(
      tester.getTopLeft(find.text('Dua Kumayl')).dy,
      lessThan(tester.getTopLeft(find.text('Ziyarat Ashura')).dy),
    );
    expect(find.bySemanticsLabel('Reorder Dua Kumayl'), findsNothing);
    expect(find.bySemanticsLabel('Remove Dua Kumayl from favorites'),
        findsNothing);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Reorder Dua Kumayl'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Edit removes a favorite', (tester) async {
    await keep(tester, ['Dua Kumayl', 'Ziyarat Ashura']);
    await pump(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester
          .tap(find.bySemanticsLabel('Remove Dua Kumayl from favorites'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Dua Kumayl'), findsNothing);
    expect(find.text('Ziyarat Ashura'), findsOneWidget);
    expect(FavoritesManager.instance.favorites.map((f) => f.title),
        ['Ziyarat Ashura']);
  });

  testWidgets('offers Quran verses beside the duas before any is saved',
      (tester) async {
    await keep(tester, ['Dua Kumayl']);
    await pump(tester);

    expect(find.text('Duas & more'), findsOneWidget);
    expect(find.text('Quran verses'), findsOneWidget);
  });

  testWidgets('shows saved Quran verses beside the duas', (tester) async {
    await keep(tester, ['Dua Kumayl']);
    await tester.runAsync(
      () => SavedVersesManager.instance.save(
        SavedVerse(
          surah: 2,
          ayah: 255,
          surahName: 'Al-Baqarah',
          excerpt: '',
          savedAt: DateTime.now().toUtc(),
        ),
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Quran verses'));
    await tester.pumpAndSettle();

    expect(find.text('Al-Baqarah 255'), findsOneWidget);
    expect(find.text('Dua Kumayl'), findsNothing);
    // Nothing to reorder among verses, which keep mushaf order.
    expect(find.text('Edit'), findsNothing);
  });
}
