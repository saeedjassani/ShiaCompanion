import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

void main() {
  testWidgets('reports scroll metrics before the reader scrolls',
      (tester) async {
    final positions = <ZikrContentScrollPosition>[];
    await _pumpViewer(tester, _longContent(), positions.add);

    expect(positions, isNotEmpty);
    expect(positions.last.tabIndex, 0);
    expect(positions.last.scrollOffset, 0);
    expect(positions.last.maxScrollExtent, greaterThan(0));
  });

  testWidgets('reports the offset and extent while scrolling',
      (tester) async {
    final positions = <ZikrContentScrollPosition>[];
    await _pumpViewer(tester, _longContent(), positions.add);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(positions.last.scrollOffset, greaterThan(0));
    expect(
      positions.last.scrollOffset,
      lessThanOrEqualTo(positions.last.maxScrollExtent),
    );
  });

  testWidgets('content that fits reports nothing left to scroll',
      (tester) async {
    final positions = <ZikrContentScrollPosition>[];
    await _pumpViewer(tester, 'اللهم صل على محمد', positions.add);

    expect(positions.last.maxScrollExtent, 0);
  });
}

String _longContent() =>
    List.generate(80, (index) => 'اللهم صل على محمد وآل محمد').join('\n');

Future<void> _pumpViewer(
  WidgetTester tester,
  String content,
  ValueChanged<ZikrContentScrollPosition> onPosition,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: <String>[content],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          onScrollPositionChanged: onPosition,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
