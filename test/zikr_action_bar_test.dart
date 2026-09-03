import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/widgets/zikr_action_bar.dart';

/// Narrow enough to be the real squeeze case: five icon-and-label targets on
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
  VoidCallback? onSettings,
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
    onSettings: onSettings ?? () {},
    onCounter: () {},
  );
}

/// The active-state pill's fill color; [Colors.transparent] when inactive.
/// Scoped to the action's own InkWell rather than a Column - the bar itself
/// is one too, so a Column-based search would match twice.
Color? _pillColor(WidgetTester t, String label) {
  final container = t.widget<AnimatedContainer>(
    find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      ),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration?)?.color;
}

/// The pop animation's current scale for the action labelled [label]. Scoped
/// the same way as [_pillColor]: every action has its own ScaleTransition, so
/// an unscoped [find.byType] would match all five.
double _popScale(WidgetTester t, String label) {
  return t
      .widget<ScaleTransition>(
        find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;
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
      expect(find.text('Settings'), findsOneWidget);
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

    testWidgets('a bookmarked action shows a filled pill, not just tinted text',
        (t) async {
      await t.pumpWidget(_host(_bar(isBookmarked: false)));
      expect(_pillColor(t, 'Bookmark'), Colors.transparent);

      await t.pumpWidget(_host(_bar(isBookmarked: true)));
      await t.pump(); // let the AnimatedContainer's color tween start
      await t.pump(const Duration(milliseconds: 250)); // and finish

      final color = _pillColor(t, 'Saved');
      expect(color, isNotNull);
      expect(color, isNot(Colors.transparent));
    });

    testWidgets('saving a bookmark pops the icon; removing one does not',
        (t) async {
      Future<void> pump(bool isBookmarked) =>
          t.pumpWidget(_host(_bar(isBookmarked: isBookmarked)));

      await pump(false);
      await pump(true);
      await t.pump(const Duration(milliseconds: 90)); // mid pop
      expect(_popScale(t, 'Saved'), greaterThan(1.0));
      await t.pumpAndSettle();

      await pump(false);
      await t.pump(const Duration(milliseconds: 90));
      // Un-bookmarking is not celebrated - a bounce on the way out would
      // read as an error shake rather than a plain undo.
      expect(_popScale(t, 'Bookmark'), 1.0);
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

    testWidgets('tapping Settings calls through', (t) async {
      var taps = 0;
      await t.pumpWidget(_host(_bar(onSettings: () => taps++)));

      await t.tap(find.text('Settings'));
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
