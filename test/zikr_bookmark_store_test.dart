import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/zikr_bookmark_store.dart';

void main() {
  test('zikr bookmark encodes versioned scroll data', () {
    final updatedAt = DateTime.utc(2026, 6, 7, 10, 30);
    final bookmark = ZikrBookmark(
      uid: 'A36',
      title: '32: As-Sajda',
      tabIndex: 1,
      tabTitle: 'Part 2',
      scrollOffset: 128.5,
      lineIndex: 12,
      updatedAt: updatedAt,
    );

    expect(bookmark.toJson(), {
      'version': 2,
      'uid': 'A36',
      'title': '32: As-Sajda',
      'tabIndex': 1,
      'tabTitle': 'Part 2',
      'scrollOffset': 128.5,
      'lineIndex': 12,
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });
  });

  test('zikr bookmark decodes numeric fields defensively', () {
    final bookmark = ZikrBookmark.fromJson({
      'version': '2',
      'uid': 'A36',
      'title': '32: As-Sajda',
      'tabIndex': '2',
      'scrollOffset': '2048.25',
      'lineIndex': '7',
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });

    expect(bookmark.version, 2);
    expect(bookmark.uid, 'A36');
    expect(bookmark.tabIndex, 2);
    expect(bookmark.scrollOffset, 2048.25);
    expect(bookmark.lineIndex, 7);
    expect(bookmark.updatedAt, DateTime.utc(2026, 6, 7, 10, 30));
  });

  test('a bookmark saved before line indexes existed decodes without one', () {
    // Those bookmarks keep working off their scroll offset until the reader
    // opens the zikr again, at which point the line under the restored offset
    // is measured and adopted.
    final bookmark = ZikrBookmark.fromJson({
      'uid': 'A36',
      'title': '32: As-Sajda',
      'tabIndex': 0,
      'scrollOffset': 128.5,
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });

    expect(bookmark.lineIndex, isNull);
    expect(bookmark.toJson().containsKey('lineIndex'), isFalse);
    expect(bookmark.copyWith(lineIndex: 4).lineIndex, 4);
    expect(bookmark.copyWith(lineIndex: 4).scrollOffset, 128.5);
  });

}
