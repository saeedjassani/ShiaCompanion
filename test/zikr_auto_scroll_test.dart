import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/widgets/zikr_auto_scroll.dart';

void main() {
  group('autoScrollPixelsPerSecond', () {
    test('gets faster with every step', () {
      for (var s = minAutoScrollSpeed; s < maxAutoScrollSpeed; s++) {
        expect(autoScrollPixelsPerSecond(s + 1),
            greaterThan(autoScrollPixelsPerSecond(s)));
      }
    });

    test('keeps the reading pace when the text is made bigger', () {
      expect(autoScrollPixelsPerSecond(4, arabicFontSize: 40),
          closeTo(autoScrollPixelsPerSecond(4) * 40 / 32, 1e-9));
    });

    test('clamps steps out of range', () {
      expect(autoScrollPixelsPerSecond(0),
          autoScrollPixelsPerSecond(minAutoScrollSpeed));
      expect(autoScrollPixelsPerSecond(99),
          autoScrollPixelsPerSecond(maxAutoScrollSpeed));
    });
  });

  group('ZikrAutoScrollController', () {
    test('is off until started, and stopping clears a pause', () {
      final c = ZikrAutoScrollController();
      expect(c.active, isFalse);
      expect(c.running, isFalse);

      c.start();
      expect(c.running, isTrue);
      c.togglePause();
      expect(c.active, isTrue);
      expect(c.running, isFalse);

      c.stop();
      expect(c.active, isFalse);
      expect(c.paused, isFalse);
    });

    test('speed stays within its range', () {
      final c = ZikrAutoScrollController();
      for (var i = 0; i < 20; i++) {
        c.faster();
      }
      expect(c.speed, maxAutoScrollSpeed);
      expect(c.canGoFaster, isFalse);
      for (var i = 0; i < 20; i++) {
        c.slower();
      }
      expect(c.speed, minAutoScrollSpeed);
      expect(c.canGoSlower, isFalse);
    });
  });

  group('the viewer', () {
    testWidgets('moves the text only while running', (tester) async {
      final autoScroll = ZikrAutoScrollController();
      await _pumpViewer(tester, autoScroll);
      final controller = _listController(tester);

      await tester.pump(const Duration(seconds: 1));
      expect(controller.offset, 0);

      autoScroll.start();
      await _advance(tester, const Duration(seconds: 2));
      final moved = controller.offset;
      expect(moved, greaterThan(0));

      autoScroll.togglePause();
      await _advance(tester, const Duration(seconds: 2));
      expect(controller.offset, moved);
    });

    testWidgets('holds while a finger is on the text', (tester) async {
      final autoScroll = ZikrAutoScrollController();
      await _pumpViewer(tester, autoScroll);
      autoScroll.start();
      final controller = _listController(tester);
      await _advance(tester, const Duration(seconds: 1));

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(ListView)));
      final held = controller.offset;
      await _advance(tester, const Duration(seconds: 2));
      expect(controller.offset, held);

      await gesture.up();
      await _advance(tester, const Duration(seconds: 1));
      expect(controller.offset, greaterThan(held));
    });

    testWidgets('pauses at the end of the text', (tester) async {
      final autoScroll = ZikrAutoScrollController();
      await _pumpViewer(tester, autoScroll);
      autoScroll.start();
      final controller = _listController(tester);
      controller.jumpTo(controller.position.maxScrollExtent - 5);
      await tester.pump();

      await _advance(tester, const Duration(seconds: 2));
      expect(autoScroll.active, isTrue);
      expect(autoScroll.paused, isTrue);
      expect(controller.offset, controller.position.maxScrollExtent);
    });
  });
}

ScrollController _listController(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).controller!;

Future<void> _advance(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < duration; t += frame) {
    await tester.pump(frame);
  }
}

Future<void> _pumpViewer(
  WidgetTester tester,
  ZikrAutoScrollController autoScroll,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: <String>[
            List.generate(80, (_) => 'اللهم صل على محمد وآل محمد').join('\n'),
          ],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          autoScroll: autoScroll,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
