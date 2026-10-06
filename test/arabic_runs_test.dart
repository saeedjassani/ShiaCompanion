import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
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
}
