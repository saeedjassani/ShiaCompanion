import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/data_search_filter.dart';

void main() {
  final entries = [
    UidTitleData('E18', 'Dua e Ahad'),
    UidTitleData('G4', 'Ziyarat e Ashura'),
    UidTitleData('G17|L4', 'Duplicate Ashura'),
    UidTitleData('A1', 'Surah al-Fatiha'),
  ];

  test('returns no results for blank queries', () {
    expect(filterDataSearchResults(entries, ''), isEmpty);
    expect(filterDataSearchResults(entries, '   '), isEmpty);
  });

  test('matches titles case-insensitively and skips duplicate aliases', () {
    final results = filterDataSearchResults(entries, 'ashura');

    expect(results.map((entry) => entry.uid), ['G4']);
  });

  test('treats regex metacharacters as plain search text', () {
    expect(() => filterDataSearchResults(entries, '['), returnsNormally);
    expect(filterDataSearchResults(entries, 'al-'), [entries[3]]);
  });
}
