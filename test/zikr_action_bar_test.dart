import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/widgets/zikr_action_bar.dart';

/// Narrow enough to be the real squeeze case: four icon-and-label targets on
/// a small phone is where the bar would overflow if it were going to.
const Size _smallPhone = Size(320, 640);

Widget _host(Widget child, {Size size = _smallPhone}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [Positioned(left: 0, right: 0, bottom: 0, child: child)],
        ),
      ),
    ),
  );
}

ZikrActionBar _bar({
  Widget? player,
  bool hasAudio = true,
  bool canBookmark = true,
  bool isBookmarked = false,
  bool canShare = true,
  bool isCounterVisible = false,
  VoidCallback? onBookmark,
  VoidCallback? onListen,
}) {
  return ZikrActionBar(
    player: player,
    hasAudio: hasAudio,
    canBookmark: canBookmark,
    isBookmarked: isBookmarked,
    canShare: canShare,
    isCounterVisible: isCounterVisible,
    onBookmark: onBookmark ?? () {},
    onShare: () {},
    onListen: onListen ?? () {},
    onCounter: () {},
  );
}

void main() {
  group('ZikrActionBar', () {
    testWidgets('shows every action labelled, on a narrow phone', (t) async {
      await t.binding.setSurfaceSize(_smallPhone);
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(_bar()));

      expect(find.text('Bookmark'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Counter'), findsOneWidget);
      // A RenderFlex overflow is reported as a thrown exception, so this is
      // what catches the bar being too cramped for icon-plus-label.
      expect(t.takeException(), isNull);
    });

    testWidgets('drops Listen when the zikr has no audio', (t) async {
      await t.binding.setSurfaceSize(_smallPhone);
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(_bar(hasAudio: false)));

      expect(find.text('Listen'), findsNothing);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('bookmark reads Saved once the zikr is bookmarked', (t) async {
      await t.pumpWidget(_host(_bar(isBookmarked: true)));

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Bookmark'), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('a zikr with no content cannot be bookmarked', (t) async {
      var taps = 0;
      await t.pumpWidget(_host(_bar(
        canBookmark: false,
        onBookmark: () => taps++,
      )));

      await t.tap(find.text('Bookmark'));
      await t.pump();

      expect(taps, 0);
    });

    testWidgets('tapping Listen calls through', (t) async {
      var taps = 0;
      await t.pumpWidget(_host(_bar(onListen: () => taps++)));

      await t.tap(find.text('Listen'));
      await t.pump();

      expect(taps, 1);
    });

    testWidgets('the player replaces the action row', (t) async {
      await t.pumpWidget(_host(_bar(
        player: const Text('player', key: Key('player')),
      )));

      expect(find.byKey(const Key('player')), findsOneWidget);
      expect(find.text('Bookmark'), findsNothing);
      expect(find.text('Listen'), findsNothing);
    });

    testWidgets('swapping in the player does not change the bar height',
        (t) async {
      await t.binding.setSurfaceSize(_smallPhone);
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(_bar()));
      final actionsHeight = t.getSize(find.byType(ZikrActionBar)).height;

      await t.pumpWidget(_host(_bar(
        player: const SizedBox(height: 20, child: Text('player')),
      )));
      final playerHeight = t.getSize(find.byType(ZikrActionBar)).height;

      // The bar sits over the reading area, and the text is padded to clear
      // exactly this height — if the two modes differed, opening the player
      // would either hide a line or leave a gap.
      expect(playerHeight, actionsHeight);
      expect(actionsHeight, ZikrActionBar.barHeight + 1); // + divider
    });

    testWidgets('reserves the bottom safe area below the controls', (t) async {
      await t.pumpWidget(_host(
        _bar(),
        size: _smallPhone,
      ));
      final withoutInset = t.getSize(find.byType(ZikrActionBar)).height;

      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(
          size: _smallPhone,
          padding: EdgeInsets.only(bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(children: [
              Positioned(left: 0, right: 0, bottom: 0, child: _bar()),
            ]),
          ),
        ),
      ));
      final withInset = t.getSize(find.byType(ZikrActionBar)).height;

      expect(withInset, withoutInset + 34);
    });
  });
}
