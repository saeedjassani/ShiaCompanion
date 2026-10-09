import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/navigation/app_shell.dart';
import 'package:shia_companion/navigation/keyboard_shortcuts.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/widgets/choice_sheet.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

/// The tablet and web layouts (docs/DESIGN_SPEC.md, "Responsive
/// behaviour").
void main() {
  Future<void> setWidth(WidgetTester tester, double width,
      {double height = 900}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(theme: buildAppTheme(Brightness.light), home: home);

  test('screen classes split at 600 and 1024', () {
    expect(ScreenClass.forWidth(599), ScreenClass.phone);
    expect(ScreenClass.forWidth(600), ScreenClass.tablet);
    expect(ScreenClass.forWidth(1023), ScreenClass.tablet);
    expect(ScreenClass.forWidth(1024), ScreenClass.desktop);
  });

  group('a card list', () {
    Widget list(double width) => app(Scaffold(
          body: CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: (1440 - width) / 2),
              sliver: SliverCardList(
                itemCount: 5,
                itemBuilder: (context, i) => CardListRow(
                  first: i == 0,
                  last: i == 4,
                  title: Text('Row $i'),
                  // The third row is taller; its neighbour matches it.
                  subtitle: i == 2 ? const Text('A\nB\nC') : null,
                ),
              ),
            ),
          ]),
        ));

    testWidgets('goes two to a line on a wide page, in reading order',
        (tester) async {
      await setWidth(tester, 1440);
      await tester.pumpWidget(list(1120));

      final row0 = tester.getTopLeft(find.text('Row 0'));
      final row1 = tester.getTopLeft(find.text('Row 1'));
      final row2 = tester.getTopLeft(find.text('Row 2'));
      expect(row1.dy, row0.dy);
      expect(row1.dx, greaterThan(row0.dx));
      expect(row2.dy, greaterThan(row0.dy));
      expect(tester.getTopLeft(find.text('Row 4')).dx, row0.dx);
      // A line is as tall as its taller row.
      expect(
        tester.getSize(find.ancestor(
            of: find.text('Row 3'), matching: find.byType(CardListRow))),
        tester.getSize(find.ancestor(
            of: find.text('Row 2'), matching: find.byType(CardListRow))),
      );
    });

    testWidgets('stays one column where there is no room for two',
        (tester) async {
      await setWidth(tester, 1440);
      await tester.pumpWidget(list(720));

      expect(tester.getTopLeft(find.text('Row 1')).dx,
          tester.getTopLeft(find.text('Row 0')).dx);
    });
  });

  testWidgets('wide columns sit side by side only where there is room',
      (tester) async {
    Widget columns(double width) => app(Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: const WideColumns(
                start: [Text('Left')],
                end: [Text('Right')],
              ),
            ),
          ),
        ));

    await setWidth(tester, 1440);
    await tester.pumpWidget(columns(1120));
    expect(tester.getTopLeft(find.text('Right')).dy,
        tester.getTopLeft(find.text('Left')).dy);

    await tester.pumpWidget(columns(720));
    expect(tester.getTopLeft(find.text('Right')).dy,
        greaterThan(tester.getTopLeft(find.text('Left')).dy));
  });

  group('a picker', () {
    Widget opener() => app(Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChoiceSheet<int>(
                context,
                title: 'Pick one',
                current: 1,
                choices: const [Choice(1, 'One'), Choice(2, 'Two')],
              ),
              child: const Text('Open'),
            ),
          ),
        ));

    testWidgets('is a bottom sheet on a phone', (tester) async {
      await setWidth(tester, 393, height: 852);
      await tester.pumpWidget(opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SheetDragHandle), findsOneWidget);
    });

    testWidgets('is a centred dialog from tablet width up', (tester) async {
      await setWidth(tester, 820, height: 1180);
      await tester.pumpWidget(opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getCenter(find.text('Pick one')).dx, lessThan(410));
      expect(
          tester
              .getSize(find
                  .descendant(
                      of: find.byType(Dialog), matching: find.byType(Material))
                  .first)
              .width,
          lessThanOrEqualTo(560));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('Esc', () {
    Widget pages({bool dismissible = false}) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          builder: (context, child) => BackOnEscape(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(children: [
                const Text('First page'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        body: Column(children: [
                          const Text('Second page'),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              barrierDismissible: dismissible,
                              builder: (_) =>
                                  const AlertDialog(content: Text('Stay')),
                            ),
                            child: const Text('Ask'),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  child: const Text('Next'),
                ),
              ]),
            ),
          ),
        );

    testWidgets('goes back a page, but never past the first', (tester) async {
      await tester.pumpWidget(pages());
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second page'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Second page'), findsNothing);
      expect(find.text('First page'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('First page'), findsOneWidget);
    });

    testWidgets('leaves a dialog that asks to stay open, and its page',
        (tester) async {
      await tester.pumpWidget(pages());
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Second page'), findsOneWidget);
    });

    testWidgets('closes a dialog that can be closed, not its page too',
        (tester) async {
      await tester.pumpWidget(pages(dismissible: true));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Stay'), findsNothing);
      expect(find.text('Second page'), findsOneWidget);
    });
  });

  testWidgets('/ and Ctrl+K open search from the tab roots', (tester) async {
    var searches = 0;
    await tester.pumpWidget(app(AppShell(
      tabs: [
        for (final name in ['Home', 'Quran', 'Favorites'])
          AppShellTab(
            label: name,
            icon: (color) => Icon(Icons.circle, color: color),
            builder: (_) => Scaffold(body: Text('$name page')),
          ),
      ],
      onSearch: () => searches++,
    )));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    expect(searches, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(searches, 2);
  });
}
