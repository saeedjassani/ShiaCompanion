import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
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
  bool showBookmark = true,
  bool canBookmark = true,
  bool isBookmarked = false,
  bool canShare = true,
  bool isCounterVisible = false,
  VoidCallback? onBookmark,
  VoidCallback? onListen,
  VoidCallback? onText,
}) {
  return ZikrActionBar(
    player: player,
    hasAudio: hasAudio,
    showBookmark: showBookmark,
    canBookmark: canBookmark,
    isBookmarked: isBookmarked,
    canShare: canShare,
    isCounterVisible: isCounterVisible,
    onBookmark: onBookmark ?? () {},
    onShare: () {},
    onListen: onListen ?? () {},
    onText: onText ?? () {},
    onCounter: () {},
  );
}

/// The tool's tint; [Colors.transparent] when it is off.
AnimatedContainer _tool(WidgetTester t, String label) =>
    t.widget<AnimatedContainer>(find
        .ancestor(of: find.text(label), matching: find.byType(AnimatedContainer))
        .first);

Color? _pillColor(WidgetTester t, String label) =>
    (_tool(t, label).decoration as BoxDecoration?)?.color;

/// The pop animation's current scale for the tool labelled [label]. Scoped
/// to that tool: every tool has its own ScaleTransition.
double _popScale(WidgetTester t, String label) {
  return t
      .widget<ScaleTransition>(
        find.descendant(
          of: find
              .ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedContainer))
              .first,
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;
}

Finder _bookmarkIcon({required bool filled}) => find.byWidgetPredicate((w) =>
    w is OutlineIcon && w.glyph == OutlineGlyph.bookmark && w.filled == filled);

void main() {
  group('ZikrActionBar', () {
    testWidgets('shows every action labelled, on a narrow phone', (t) async {
      await t.binding.setSurfaceSize(_smallPhone);
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(_bar()));

      expect(find.text('Bookmark'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
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

    testWidgets('drops Bookmark when there is no place to mark', (t) async {
      // Quran: a recitation track keeps the place, so the bar has no
      // bookmark to offer at all.
      await t.pumpWidget(_host(_bar(showBookmark: false)));

      expect(find.text('Bookmark'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(_bookmarkIcon(filled: false), findsNothing);
      expect(find.text('Share'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('bookmark reads Saved once the zikr is bookmarked', (t) async {
      await t.pumpWidget(_host(_bar(isBookmarked: true)));

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Bookmark'), findsNothing);
      expect(_bookmarkIcon(filled: true), findsOneWidget);
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

    testWidgets('tapping Text calls through', (t) async {
      var taps = 0;
      await t.pumpWidget(_host(_bar(onText: () => taps++)));

      await t.tap(find.text('Text'));
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

      // The capsule floats over the reading area, and the text is padded to
      // clear exactly this height — if the two modes differed, opening the
      // player would either hide a line or leave a gap.
      expect(playerHeight, actionsHeight);
      expect(actionsHeight, ZikrActionBar.barHeight);
    });

    testWidgets('keeps the tools to a capsule width on a wide screen',
        (t) async {
      const tablet = Size(1024, 768);
      await t.binding.setSurfaceSize(tablet);
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(_bar(), size: tablet));

      final capsule = find.descendant(
        of: find.byType(ZikrActionBar),
        matching: find.byType(SizedBox),
      );
      expect(t.getSize(capsule.first).width, ZikrActionBar.maxToolsWidth);
    });

    testWidgets('lists the tools in the agreed order', (t) async {
      await t.pumpWidget(_host(_bar()));

      final xs = [
        for (final label in ['Bookmark', 'Listen', 'Text', 'Counter', 'Share'])
          t.getCenter(find.text(label)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });
  });
}
