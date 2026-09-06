import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';

void main() {
  group('ZikrChromeScrollTracker', () {
    late ZikrChromeScrollTracker tracker;

    setUp(() => tracker = ZikrChromeScrollTracker());

    /// Feeds [delta] as a single scroll update on a normal, in-range vertical
    /// reading list.
    bool? scroll(double delta, {bool chromeVisible = true}) => tracker.update(
          axis: Axis.vertical,
          delta: delta,
          outOfRange: false,
          chromeVisible: chromeVisible,
        );

    test('a sustained scroll down hides the chrome', () {
      expect(scroll(kZikrChromeScrollThreshold), isFalse);
    });

    test('a sustained scroll up shows the chrome again', () {
      expect(scroll(-kZikrChromeScrollThreshold, chromeVisible: false), isTrue);
    });

    test('deltas accumulate - a slow scroll still crosses the threshold', () {
      final step = kZikrChromeScrollThreshold / 3;
      expect(scroll(step), isNull);
      expect(scroll(step), isNull);
      expect(scroll(step), isFalse);
    });

    test('movement short of the threshold never moves the chrome', () {
      // The whole point of the tracker: the finger wobble inside one real
      // gesture used to flip UserScrollNotification's direction and flash
      // both bars in and out mid-read.
      for (var i = 0; i < 20; i++) {
        expect(scroll(i.isEven ? 4 : -4), isNull);
      }
    });

    test('reversing direction restarts the count from zero', () {
      // Not "carries a debt": the reversal drops the downward count rather
      // than subtracting from it, so the upward scroll below is 35 pixels of
      // travel, not 70, and is still short of a reveal...
      expect(scroll(kZikrChromeScrollThreshold - 1), isNull);
      expect(scroll(-(kZikrChromeScrollThreshold - 1), chromeVisible: false),
          isNull);
      // ...until it completes that full threshold on its own.
      expect(scroll(-1, chromeVisible: false), isTrue);
    });

    test('a decision resets the count, so the next one starts fresh', () {
      expect(scroll(kZikrChromeScrollThreshold), isFalse);
      expect(scroll(1, chromeVisible: false), isNull);
    });

    test('reset() drops momentum carried over from the last gesture', () {
      expect(scroll(kZikrChromeScrollThreshold - 1), isNull);
      tracker.reset();
      expect(scroll(1), isNull);
    });

    test('a request matching the current state is dropped', () {
      // Nothing to do, and reporting it anyway would restart the idle timer
      // on a scroll that changed nothing.
      expect(scroll(kZikrChromeScrollThreshold, chromeVisible: false), isNull);
      expect(scroll(-kZikrChromeScrollThreshold), isNull);
    });

    test('an overscroll bounce is ignored', () {
      // The bounce back from the end of a zikr reverses under its own
      // momentum with no reader input, and used to read as a reveal.
      expect(
        tracker.update(
          axis: Axis.vertical,
          delta: -kZikrChromeScrollThreshold * 2,
          outOfRange: true,
          chromeVisible: false,
        ),
        isNull,
      );
    });

    test('horizontal scrolling is ignored - it is a tab swipe', () {
      // The reading ListView is nested inside the tabs' horizontal PageView,
      // so the PageView's own scrolling arrives at the same listener.
      for (final delta in [kZikrChromeScrollThreshold * 4, -100.0]) {
        expect(
          tracker.update(
            axis: Axis.horizontal,
            delta: delta,
            outOfRange: false,
            chromeVisible: true,
          ),
          isNull,
          reason: 'horizontal $delta should not move the chrome',
        );
      }
    });
  });
}
