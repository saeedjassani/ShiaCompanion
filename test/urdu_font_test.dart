import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/language_provider.dart';
import 'package:shia_companion/utils/urdu_font.dart';

void main() {
  group('Urdu is set in Nastaliq', () {
    test('when the app is in Urdu, whatever the translation language', () {
      for (final translation in ['ur', 'en', 'fa', 'ar', 'gu']) {
        expect(LanguageProvider.usesUrduFontFor('ur', translation), isTrue);
      }
    });

    test('when zikrs are read in Urdu under English or Gujarati menus', () {
      expect(LanguageProvider.usesUrduFontFor('en', 'ur'), isTrue);
      expect(LanguageProvider.usesUrduFontFor('gu', 'ur'), isTrue);
    });

    test('but never over Persian or Arabic menus, nor without Urdu', () {
      expect(LanguageProvider.usesUrduFontFor('fa', 'ur'), isFalse);
      expect(LanguageProvider.usesUrduFontFor('ar', 'ur'), isFalse);
      expect(LanguageProvider.usesUrduFontFor('en', 'en'), isFalse);
      expect(LanguageProvider.usesUrduFontFor('fa', 'fa'), isFalse);
    });

    test('the Urdu theme sets it everywhere, with the system font behind', () {
      final theme =
          buildAppTheme(Brightness.light, fontFamily: UrduFont.family);
      for (final style in [
        theme.textTheme.bodyMedium!,
        theme.textTheme.titleLarge!,
        theme.appBarTheme.titleTextStyle!,
        theme.dialogTheme.titleTextStyle!,
        theme.dialogTheme.contentTextStyle!,
      ]) {
        expect(style.fontFamily, UrduFont.family);
        expect(style.fontFamilyFallback, isNotEmpty);
      }

      final plain = buildAppTheme(Brightness.light);
      expect(plain.textTheme.bodyMedium!.fontFamily, isNot(UrduFont.family));
      expect(plain.appBarTheme.titleTextStyle!.fontFamily, isNull);
    });
  });
}
