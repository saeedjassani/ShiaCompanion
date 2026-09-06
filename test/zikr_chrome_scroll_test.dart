import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';

void main() {
  group('resolveChromeVisibilityForScroll', () {
    test('scrolling down (reverse) hides the chrome', () {
      expect(
        resolveChromeVisibilityForScroll(
            Axis.vertical, ScrollDirection.reverse),
        isFalse,
      );
    });

    test('scrolling up (forward) shows the chrome', () {
      expect(
        resolveChromeVisibilityForScroll(
            Axis.vertical, ScrollDirection.forward),
        isTrue,
      );
    });

    test('an idle vertical notification leaves the chrome alone', () {
      expect(
        resolveChromeVisibilityForScroll(Axis.vertical, ScrollDirection.idle),
        isNull,
      );
    });

    test(
        'horizontal scrolling is ignored regardless of direction - it is a '
        'tab swipe, not scrolling the reading area', () {
      // The reading ListView is nested inside the tabs' horizontal PageView,
      // so this is the exact case that used to be discarded by checking
      // notification.depth == 0 instead: the PageView, itself a Scrollable,
      // bumps depth to 1 as the reading content's own scroll bubbles past
      // it, so every real read was silently filtered out.
      for (final direction in ScrollDirection.values) {
        expect(
          resolveChromeVisibilityForScroll(Axis.horizontal, direction),
          isNull,
          reason: 'horizontal $direction should not move the chrome',
        );
      }
    });
  });

  group('shouldClearSelectionForScroll', () {
    test('a scroll the reader drives drops the selection', () {
      // Either direction, and either axis: a vertical scroll recycles the
      // selected line out of the ListView, and a horizontal one swipes its
      // whole tab away. Both dispose the Selectable the selection sits in,
      // which is what leaves SelectableRegion's overlay pointing at text that
      // is no longer in the tree.
      expect(shouldClearSelectionForScroll(ScrollDirection.reverse), isTrue);
      expect(shouldClearSelectionForScroll(ScrollDirection.forward), isTrue);
    });

    test('an idle scroll leaves the selection alone', () {
      // SelectableRegion auto-scrolls the list with jumpTo while a selection
      // handle is dragged past its edge, and jumpTo reports idle. Acting on it
      // would cancel the selection being made.
      expect(shouldClearSelectionForScroll(ScrollDirection.idle), isFalse);
    });
  });
}
