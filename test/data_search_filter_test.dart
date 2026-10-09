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

  test('ignores uid by default, even when the query matches one', () {
    expect(filterDataSearchResults(entries, 'g4'), isEmpty);
  });

  test('matches uid case-insensitively when matchUid is set', () {
    final results = filterDataSearchResults(entries, 'g4', matchUid: true);

    expect(results.map((entry) => entry.uid), ['G4']);
  });

  test('matchUid still skips duplicate aliases', () {
    final results = filterDataSearchResults(entries, 'L4', matchUid: true);

    expect(results, isEmpty);
  });

  group('slugsFor', () {
    final respelled = [UidTitleData('G6', 'Ziyarat Warith')];
    Iterable<String> slugsFor(String uid) =>
        uid == 'G6' ? const ['ziyarat-e-waaresa'] : const [];

    test('finds a respelled title by the old spelling kept in its slug', () {
      expect(
        filterDataSearchResults(respelled, 'Waaresa', slugsFor: slugsFor),
        respelled,
      );
      expect(
        filterDataSearchResults(respelled, 'ziyarat e waaresa',
            slugsFor: slugsFor),
        respelled,
      );
    });

    test('is not consulted unless given', () {
      expect(filterDataSearchResults(respelled, 'waaresa'), isEmpty);
    });

    test('ignores a query that is only punctuation', () {
      expect(
        filterDataSearchResults(respelled, '--', slugsFor: slugsFor),
        isEmpty,
      );
    });
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

  test('matches a book on its author', () {
    final books = [
      UidTitleData('B1', 'The Islamic Modest Dress',
          author: 'Murtada Mutahhari'),
      UidTitleData('B2', 'Peak of Eloquence'),
    ];

    expect(
        filterDataSearchResults(books, 'mutahhari').map((e) => e.uid), ['B1']);
  });

  group('ranking', () {
    test('ranks title start, then word start, then mid-word', () {
      expect(searchMatchRank('1: Al-Fatihah الفاتحة', 'fa'), 0);
      expect(searchMatchRank('Dua Kumayl', 'du'), 0);
      expect(searchMatchRank('Commentary on Dua Kumayl', 'kum'), 1);
      expect(searchMatchRank('Taqibaat of Namaz-e-Fajr', 'fa'), 1);
      expect(searchMatchRank('8: Al-Anfal الأنفال', 'fa'), 2);
      expect(searchMatchRank('1: Al-Fatihah الفاتحة', 'faa'), 3);
    });

    test('puts better matches first and keeps ties in entry order', () {
      final entries = [
        UidTitleData('A12', '8: Al-Anfal الأنفال'),
        UidTitleData('D3', 'Taqibaat of Namaz-e-Fajr'),
        UidTitleData('A5', '1: Al-Fatihah الفاتحة'),
        UidTitleData('AA47', 'Farewell Prayer of Ramazan'),
      ];

      expect(filterDataSearchResults(entries, 'fa').map((e) => e.uid),
          ['A5', 'AA47', 'D3', 'A12']);
    });
  });

  group('Arabic, Urdu and Persian titles', () {
    test('foldSearchText drops harakat and folds letter variants', () {
      expect(foldSearchText('دُعَاءُ كُمَيْل'), foldSearchText('دعاء کمیل'));
      expect(foldSearchText('أبي حمزة'), foldSearchText('ابی حمزه'));
      expect(foldSearchText('سورۃ البقرہ'), foldSearchText('سورة البقرة'));
      expect(foldSearchText('موسیٰ'), foldSearchText('موسی'));
      expect(foldSearchText('۳۶: سوره یس'), '36: سوره یس');
      expect(foldSearchText('نماز\u200cها'), 'نماز ها');
    });

    test('a translated title matches however it is typed', () {
      const translated = {'E1': 'دعاء كميل', 'G4': 'زيارة عاشوراء'};
      final results = filterDataSearchResults(
        [
          UidTitleData('E1', 'Dua Kumayl'),
          UidTitleData('G4', 'Ziyarat Ashura')
        ],
        'دعای کمیل',
        translatedTitleFor: (uid) => translated[uid],
      );
      expect(results.map((e) => e.uid), isEmpty);
      expect(
        filterDataSearchResults(
          [UidTitleData('E1', 'Dua Kumayl')],
          'کمیل',
          translatedTitleFor: (uid) => translated[uid],
        ).map((e) => e.uid),
        ['E1'],
      );
    });

    test('ranks by the translated title too', () {
      const translated = {'A1': '1: سورة الفاتحة', 'A2': 'دعاء الافتتاح'};
      final results = filterDataSearchResults(
        [
          UidTitleData('A2', 'Dua Iftitah'),
          UidTitleData('A1', '1: Al-Fatihah')
        ],
        'سورة',
        translatedTitleFor: (uid) => translated[uid],
      );
      expect(results.map((e) => e.uid), ['A1']);
      // Starting the translated title beats appearing in the middle of it.
      final ranked = filterDataSearchResults(
        [
          UidTitleData('A2', 'Dua Iftitah'),
          UidTitleData('E1', 'Dua for the Opening'),
        ],
        'دعاء',
        translatedTitleFor: (uid) =>
            {'A2': 'من دعاء الافتتاح', 'E1': 'دعاء الافتتاح'}[uid],
      );
      expect(ranked.map((e) => e.uid), ['E1', 'A2']);
    });
  });
}
