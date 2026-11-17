import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
import 'package:shia_companion/utils/fuzzy_search.dart';

void main() {
  final entries = [
    UidTitleData('A6', '2: Al-Baqarah البقرة'),
    UidTitleData('A40', '36: Ya-Sin يس'),
    UidTitleData('A59', '55: Ar-Rahman الرحمن'),
    UidTitleData('A110', '106: Quraysh قريش'),
    UidTitleData('E14', 'Hadith al-Kisa'),
    UidTitleData('E24', 'Dua Tawassul'),
    UidTitleData('E31', 'Dua Kumayl'),
    UidTitleData('E37', 'Dua Sanamay Quraish'),
    UidTitleData('E95', 'Dua Muqatil ibn Sulayman'),
    UidTitleData('G6', 'Ziyarat Warith'),
    UidTitleData('B1', 'Forty Hadith on Prayer'),
    UidTitleData('B2', 'Did Abu Bakr Lead the Prayer?'),
    UidTitleData('B3', 'The Human Being'),
    UidTitleData('B4', 'Kamil al-Ziyarat'),
    UidTitleData('B5', 'Philosophy of Muslim Thinkers'),
    UidTitleData('B6', 'Making the Case'),
  ];

  List<String> search(String query, {Map<String, String>? translated}) =>
      filterDataSearchResults(
        entries,
        query,
        translatedTitleFor: translated == null
            ? null
            : (uid) => translated[uid],
      ).map((e) => e.uid).toList();

  group('finds what readers asked for because search missed it', () {
    // Each of these reached the "Request a Zikr" queue in Oct-Nov 2026.
    for (final (query, uid) in [
      ('sanamaiqoraish', 'E37'),
      ('duae sunmaikuresh', 'E37'),
      ('duasanme qoraish', 'E37'),
      ('Sura bakra', 'A6'),
      ('surah e bakra', 'A6'),
      ('Surah e baqarah', 'A6'),
      ('hàdis e kissa', 'E14'),
      ('Hadis kissa', 'E14'),
      ('thawassul', 'E24'),
      ('Dua e tawasul', 'E24'),
      ('दुआ-ए-मुक़ातिल बिन सुलेमान⁠', 'E95'),
      ('soreh yaesn', 'A40'),
      ('surah yaseen', 'A40'),
      ('surah rehman', 'A59'),
    ]) {
      test(query, () => expect(search(query).first, uid));
    }
  });

  test('a Persian spelling of a translated title finds it', () {
    expect(search('دعاي صنعي قريش', translated: {'E37': 'دعای صنمی قریش'}), [
      'E37',
    ]);
  });

  test('ranks the closest spelling first', () {
    expect(search('kumail'), ['E31', 'B4']);
    expect(search('waaresa'), ['G6']);
  });

  test('an unmatched short word still ranks, so the right hadith leads', () {
    expect(search('hadis kissa'), ['E14']);
    expect(search('hadis'), ['E14', 'B1']);
  });

  test('matches the word being typed as a prefix', () {
    expect(search('sanam'), ['E37']);
    expect(search('qorais'), unorderedEquals(['A110', 'E37']));
  });

  test('words joined across "the" match only exactly', () {
    // "the human" is "shmn", one letter from "rehman"'s "rhmn".
    expect(search('rehman'), ['A59']);
  });

  test('drops matches far from the closest one', () {
    // "thinkers" is one consonant from "sanamaiqoraish" run together.
    expect(search('sanamaiqoraish'), ['E37']);
  });

  test(
    'a two-letter skeleton matches by sound only when nothing else does',
    () {
      expect(search('kisa'), ['E14']); // not "Making the Case"
      expect(search('kissa'), ['E14']);
    },
  );

  test(
    'a near miss keeps its first sound, so a keyboard mash finds nothing',
    () {
      expect(search('zzqqxx'), isEmpty);
      expect(search('xkcdqwerty'), isEmpty);
    },
  );

  group('keeps the noise out (review of PR #433)', () {
    final noisy = [
      UidTitleData('AA1', 'Nafilah of Asr'),
      UidTitleData('B7', 'Hajj the Pilgrimage'),
      UidTitleData('AJ1', 'Ziyarat of Lady Sakina (s.a.)'),
      UidTitleData('B8', 'Seeking and Asking'),
      UidTitleData('A118', '114: An-Nas الناس'),
      UidTitleData('A18', '14: Ibrahim إبراهيم'),
      UidTitleData('E29', 'Dua Jawshan Kabir'),
      UidTitleData('E30', 'Dua Jawshan Saghir'),
      UidTitleData('E9', 'Imam al-Mahdi (a.t.f.s.) - Short'),
      UidTitleData('B9', 'The Centre of the Account'),
      UidTitleData('D7', 'Qunut'),
    ];
    List<String> find(String query) =>
        filterDataSearchResults(noisy, query).map((e) => e.uid).toList();

    test(
      'words joined across a generic word match only after a leading one',
      () {
        expect(find('father'), isEmpty); // "of" + "asr", "a.t.f.s." + short
        expect(find('hajat'), isEmpty); // "hajj the"
      },
    );

    test('beside an exact match, only near spellings and no prefixes', () {
      expect(find('sakina'), ['AJ1']); // not "seeking", "asking"
    });

    test('numbers match only as they are', () {
      expect(find('surah 144'), isEmpty);
      expect(find('surah 114'), ['A118']);
    });

    test('a diphthong before a consonant is a vowel', () {
      expect(find('joshan'), ['E29', 'E30']);
    });

    test('a short skeleton is not a prefix of a longer word', () {
      expect(find('qunoot'), ['D7']); // not "Centre", "Account"
    });

    test('the Urdu دعائے is a generic word', () {
      expect(FuzzyQuery.parse('دعائے'), isNull);
    });
  });

  test('generic words alone match nothing by sound', () {
    expect(FuzzyQuery.parse('dua e surah'), isNull);
    expect(search('ziyarat namaz'), isEmpty);
  });

  test('phoneticKey merges what romanizations disagree on', () {
    expect(phoneticKey('baqarah'), phoneticKey('bakra'));
    expect(phoneticKey('hadith'), phoneticKey('hadis'));
    expect(phoneticKey('dhikr'), phoneticKey('zikr'));
    expect(phoneticKey('kumail'), phoneticKey('kumayl'));
    expect(phoneticKey('tawassul'), phoneticKey('tawasul'));
    expect(phoneticKey('thawassul'), phoneticKey('tawassul'));
    expect(phoneticKey('मुक़ातिल'), phoneticKey('muqatil'));
    expect(phoneticKey('सुलेमान'), phoneticKey('sulayman'));
  });
}
