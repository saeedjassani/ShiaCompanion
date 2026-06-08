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
      updatedAt: updatedAt,
    );

    expect(bookmark.toJson(), {
      'version': 1,
      'uid': 'A36',
      'title': '32: As-Sajda',
      'tabIndex': 1,
      'tabTitle': 'Part 2',
      'scrollOffset': 128.5,
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });
  });

  test('zikr bookmark decodes numeric fields defensively', () {
    final bookmark = ZikrBookmark.fromJson({
      'version': '1',
      'uid': 'A36',
      'title': '32: As-Sajda',
      'tabIndex': '2',
      'scrollOffset': '2048.25',
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });

    expect(bookmark.version, 1);
    expect(bookmark.uid, 'A36');
    expect(bookmark.tabIndex, 2);
    expect(bookmark.scrollOffset, 2048.25);
    expect(bookmark.updatedAt, DateTime.utc(2026, 6, 7, 10, 30));
  });
}
