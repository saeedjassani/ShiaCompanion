import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
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

  testWidgets('reports the offset and extent while scrolling', (tester) async {
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
    expect(positions.last.progressFraction, 1);
    expect(positions.last.seenFraction, 1);
  });

  group('in Arabic-only paragraph view', () {
    setUp(() {
      showTransliteration = false;
      showTranslation = false;
      showArabicAsParagraph = true;
    });
    tearDown(() {
      showTransliteration = true;
      showTranslation = true;
      showArabicAsParagraph = false;
    });

    // Headings between runs of verses of very uneven length, as a real
    // compilation has: each run is one list item in this view, so the list's
    // own extent estimate - extrapolated from whichever items happen to be
    // built - was off by several screens either way.
    String sectioned() => [
          for (final verses in [2, 3, 1, 2, 120, 2, 90]) ...[
            'Heading for the next part',
            for (var v = 0; v < verses; v++) ...[
              'اللهم صل على محمد وآل محمد',
              'Allahumma salli ala Muhammad',
              'O Allah bless Muhammad',
            ],
          ],
        ].join('\n');

    testWidgets('progress tracks the text, from 0 to 1, never backwards',
        (tester) async {
      final positions = <ZikrContentScrollPosition>[];
      await _pumpViewer(tester, sectioned(), positions.add);
      expect(positions.last.progressFraction, 0);

      final list = find.byType(ListView);
      var previous = 0.0;
      for (var i = 0; i < 200; i++) {
        await tester.drag(list, const Offset(0, -150));
        await tester.pump();
        final progress = positions.last.progressFraction!;
        expect(progress, greaterThanOrEqualTo(previous - 1e-9));
        // A 150px drag is a line or two, never a leap through the text.
        expect(progress - previous, lessThan(0.05));
        expect(positions.last.seenFraction!,
            greaterThanOrEqualTo(progress - 1e-9));
        previous = progress;
        if (positions.last.scrollOffset >= positions.last.maxScrollExtent) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(positions.last.progressFraction, 1);
      expect(positions.last.seenFraction, 1);
    });

    testWidgets('halfway through the text reads as about half', (tester) async {
      final positions = <ZikrContentScrollPosition>[];
      await _pumpViewer(tester, sectioned(), positions.add);
      final list = find.byType(ListView);

      // Scroll to the end once so the list knows its true height.
      await tester.fling(list, const Offset(0, -100000), 10000);
      await tester.pumpAndSettle();
      final max = positions.last.maxScrollExtent;
      final viewport = positions.last.viewportDimension;

      // Back to where the reading line is at the middle of the content.
      // The line sits at offset * (1 + viewport / max), so solving for half
      // of (max + viewport) gives max / 2.
      final controller = tester.widget<ListView>(list).controller!;
      controller.jumpTo(max / 2);
      await tester.pumpAndSettle();
      expect(positions.last.scrollOffset, max / 2);
      expect(viewport, greaterThan(0));
      expect(positions.last.progressFraction, closeTo(0.5, 0.05));
    });
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
