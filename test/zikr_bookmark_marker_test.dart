import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

void main() {
  group('resolveBookmarkMarkerTop', () {
    test('lands at the top of the viewport when scrolled exactly there', () {
      expect(
        resolveBookmarkMarkerTop(
          savedOffset: 500,
          currentOffset: 500,
          viewportHeight: 800,
          bandHeight: 70,
        ),
        0,
      );
    });

    test('tracks scroll position - offsets below the saved one push it down',
        () {
      expect(
        resolveBookmarkMarkerTop(
          savedOffset: 500,
          currentOffset: 300,
          viewportHeight: 800,
          bandHeight: 70,
        ),
        200,
      );
    });

    test('is null once scrolled past the band, not just past the exact pixel',
        () {
      // The saved position is 60px above the current top of the viewport;
      // a 70px band would still have 10px on screen, so it should still show.
      expect(
        resolveBookmarkMarkerTop(
          savedOffset: 240,
          currentOffset: 300,
          viewportHeight: 800,
          bandHeight: 70,
        ),
        -60,
      );
      // One more pixel up and the whole band has scrolled off the top.
      expect(
        resolveBookmarkMarkerTop(
          savedOffset: 229,
          currentOffset: 300,
          viewportHeight: 800,
          bandHeight: 70,
        ),
        isNull,
      );
    });

    test('is null exactly at, but not just inside, the bottom edge', () {
      // top (799) is one pixel inside the 800px viewport - still visible.
      expect(
        resolveBookmarkMarkerTop(
          savedOffset: 899,
          currentOffset: 100,
          viewportHeight: 800,
          bandHeight: 70,
        ),
        799,
      );
      // top == viewportHeight means the band would start exactly where the
      // viewport ends - nothing of it is actually visible.
      expect(
        resolveBookmarkMarkerTop(
          savedOffset: 900,
          currentOffset: 100,
          viewportHeight: 800,
          bandHeight: 70,
        ),
        isNull,
      );
    });
  });
}
