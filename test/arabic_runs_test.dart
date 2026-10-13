import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/l10n.dart';
import 'package:shia_companion/widgets/arabic_runs.dart';
import 'package:shia_companion/widgets/page_chrome.dart';

void main() {
  group('arabicRunSpans', () {
    test('is null for a title with no Arabic', () {
      expect(arabicRunSpans('Dua al-Hujjah (a.s.)'), isNull);
    });

    test('sets only the Arabic in the Arabic font', () {
      final spans = arabicRunSpans('Ziyarat Rajabiyah (الحمد لله …)')!;
      expect(spans.map((s) => s.text),
          ['Ziyarat Rajabiyah (', 'الحمد لله', ' …)']);
      expect(spans[0].style?.fontFamily, isNull);
      expect(spans[1].style?.fontFamily, arabicFont);
      expect(spans[2].style?.fontFamily, isNull);
    });

    test('keeps a style on every span', () {
      const bold = TextStyle(fontWeight: FontWeight.w700);
      final spans = arabicRunSpans('36: Ya-Sin يس', style: bold)!;
      expect(
          spans.map((s) => s.style?.fontWeight), everyElement(FontWeight.w700));
      expect(spans.last.style?.fontFamily, arabicFont);
    });
  });

  // The regression: Qalam in the title's fallback list set the whole title,
  // English included, in Qalam wherever the UI font ahead of it was not a
  // registered font.
  testWidgets("a card row's English title leaves Qalam out", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Material(child: CardListRow(title: Text('Dua Kumayl (a.s.)'))),
    ));
    final style = tester
        .widget<RichText>(find.descendant(
            of: find.byType(CardListRow), matching: find.byType(RichText)))
        .text
        .style!;
    expect(style.fontFamily, isNot('Qalam'));
    expect(style.fontFamilyFallback ?? const [], isNot(contains('Qalam')));
  });

  // In Urdu, Persian and Arabic, Arabic-script text in a title or a menu is
  // the app language itself: Qalam drew Urdu menus, and left out the ٢ of
  // an Arabic surah title "٢: البقرة".
  group('in a language written in Arabic script', () {
    tearDown(() => L10n.current = lookupAppLocalizations(const Locale('en')));

    for (final code in ['ur', 'fa', 'ar']) {
      test('$code titles stay in the app font', () {
        L10n.current = lookupAppLocalizations(Locale(code));
        expect(arabicFontForTitles, isFalse);
        expect(arabicRunSpans('٢: البقرة'), isNull);
        expect(arabicRunSpans('آیت محفوظ کریں'), isNull);
      });
    }

    testWidgets("an Urdu card row's title leaves Qalam out", (tester) async {
      L10n.current = lookupAppLocalizations(const Locale('ur'));
      await tester.pumpWidget(const MaterialApp(
        home: Material(child: CardListRow(title: Text('آیت محفوظ کریں'))),
      ));
      final text = tester
          .widget<RichText>(find.descendant(
              of: find.byType(CardListRow), matching: find.byType(RichText)))
          .text;
      final styles = <TextStyle>[];
      text.visitChildren((span) {
        if (span.style != null) styles.add(span.style!);
        return true;
      });
      for (final style in styles) {
        expect(style.fontFamily, isNot(anyOf('Qalam', 'Scheherazade')));
        expect(style.fontFamilyFallback ?? const [], isNot(contains('Qalam')));
      }
    });

    test('Gujarati keeps the Arabic font for a title\'s Arabic', () {
      L10n.current = lookupAppLocalizations(const Locale('gu'));
      expect(
          arabicRunSpans('36: Ya-Sin يس')!.last.style?.fontFamily, arabicFont);
    });
  });
}
