import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/widgets/balanced_columns.dart';

Widget _box(String key, double height) =>
    SizedBox(key: ValueKey(key), height: height);

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    Directionality(
      textDirection: direction,
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 410, child: child),
        ),
      ),
    );

void main() {
  testWidgets('each floating card goes under the shorter column',
      (tester) async {
    await tester.pumpWidget(_app(BalancedColumns(
      gap: 10,
      start: [_box('prayer', 300), _box('today', 400)],
      end: [_box('shortcuts', 300)],
      floating: [_box('hadith', 200), _box('app', 150)],
    )));

    Offset at(String key) => tester.getTopLeft(find.byKey(ValueKey(key)));
    expect(at('today'), const Offset(0, 300));
    expect(at('shortcuts'), const Offset(210, 0));
    // The end column is shorter (300 to 700), and still is after the
    // hadith (500 to 700), so both go there.
    expect(at('hadith'), const Offset(210, 300));
    expect(at('app'), const Offset(210, 500));
    expect(tester.getSize(find.byType(BalancedColumns)), const Size(410, 700));
    expect(tester.getSize(find.byKey(const ValueKey('hadith'))).width, 200);
  });

  testWidgets('a floating card can go under the start column', (tester) async {
    await tester.pumpWidget(_app(BalancedColumns(
      start: [_box('prayer', 100)],
      end: [_box('shortcuts', 300)],
      floating: [_box('hadith', 200)],
    )));
    expect(tester.getTopLeft(find.byKey(const ValueKey('hadith'))),
        const Offset(0, 100));
  });

  testWidgets('shares the width by flex, start on the right in RTL',
      (tester) async {
    await tester.pumpWidget(_app(
      BalancedColumns(
        startFlex: 3,
        endFlex: 1,
        gap: 10,
        start: [_box('prayer', 100)],
        end: [_box('shortcuts', 100)],
      ),
      direction: TextDirection.rtl,
    ));
    expect(tester.getRect(find.byKey(const ValueKey('prayer'))),
        const Rect.fromLTWH(110, 0, 300, 100));
    expect(tester.getRect(find.byKey(const ValueKey('shortcuts'))),
        const Rect.fromLTWH(0, 0, 100, 100));
  });
}
