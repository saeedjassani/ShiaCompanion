import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/uid_title_data.dart';

void main() {
  test('getFirstUId returns duplicate target UID', () {
    expect(UidTitleData('G17|L4', 'Duplicate').getFirstUId(), 'L4');
    expect(UidTitleData('E18', 'Direct').getFirstUId(), 'E18');
  });

  test('getId extracts sortable numeric ID from common UID shapes', () {
    expect(UidTitleData('AA10', 'Multi-letter prefix').getId(), 10);
    expect(UidTitleData('F10~A', 'Parent group').getId(), 10);
    expect(UidTitleData('G17|L4', 'Duplicate').getId(), 17);
    expect(UidTitleData('I21.5', 'Decimal UID').getId(), 21);
  });

  test('getId falls back instead of throwing for non-numeric UIDs', () {
    expect(UidTitleData('slug-only', 'No numeric suffix').getId(), 999999);
  });
}
