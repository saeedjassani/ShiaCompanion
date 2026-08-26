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

  group('isNewSearchTerm', () {
    test('counts the first term of a session', () {
      expect(isNewSearchTerm(previous: null, term: 'kum'), isTrue);
    });

    test('does not count a term that is still being typed', () {
      expect(isNewSearchTerm(previous: 'kum', term: 'kumayl'), isFalse);
      expect(isNewSearchTerm(previous: 'Kum', term: 'kumayl '), isFalse);
    });

    test('does not count the same term twice', () {
      expect(isNewSearchTerm(previous: 'kumayl', term: 'kumayl'), isFalse);
    });

    test('does not count a term being narrowed with backspace', () {
      expect(isNewSearchTerm(previous: 'kumayl', term: 'kum'), isFalse);
    });

    test('counts a genuinely different term', () {
      expect(isNewSearchTerm(previous: 'kumayl', term: 'ashura'), isTrue);
    });

    test('never counts an empty term', () {
      expect(isNewSearchTerm(previous: 'kumayl', term: '   '), isFalse);
    });
  });
}
