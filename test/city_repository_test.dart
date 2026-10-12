import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/l10n/l10n.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/services/city_repository.dart';

/// Runs against the real assets/cities.tsv: what matters is that the people
/// this app is for find their city, and that the list is not quietly short.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repository = CityRepository.instance;

  setUpAll(() => repository.load());

  List<String> top(String query, [int count = 4]) => [
        for (final match in repository.search(query).take(count))
          '${match.city.name}, ${match.city.countryCode}',
      ];

  test('finds the cities the airports list missed', () {
    // Kuwait City is a capital GeoNames counts at 60,000: capitals are kept
    // whatever their size.
    expect(top('Karbala', 1), ['Karbala, IQ']);
    expect(top('Najaf', 2), contains('Najaf, IQ'));
    expect(top('Qom', 1), ['Qom, IR']);
    expect(top('Kuwait City', 1), ['Kuwait City, KW']);
    expect(top('Kufa', 1), ['Kufa, IQ']);
    expect(top('Samarra', 1), ['Sāmarrā’, IQ']);
  });

  test('a prefix lists the biggest matches first', () {
    final results = top('kar', 5);
    expect(results.first, 'Karachi, PK');
    expect(results, containsAll(['Karbala, IQ', 'Karaj, IR']));
  });

  test('names starting with the query come before other spellings that do', () {
    final matches = repository.search('kar').take(10).toList();
    // Caracas is also "Karakas" somewhere, but nobody typing "kar" means it.
    expect(matches.every((match) => match.alias == null), isTrue);
    expect(matches.every((match) => match.city.name.startsWith('Kar')), isTrue);
  });

  test('other spellings find the city, and say which', () {
    final mecca = repository.search('Mecca').first;
    expect(mecca.city.name, 'Makkah');
    expect(mecca.alias, 'Mecca');
    expect(top('Kerbala', 1), ['Karbala, IQ']);
    expect(top('Bombay', 1), ['Mumbai, IN']);
    expect(top('Mashad', 1), ['Mashhad, IR']);
  });

  test('a big city found by another spelling beats small exact namesakes', () {
    expect(top('Medina', 1), ['Madinah, SA']);
    expect(top('London', 1), ['London, GB']);
  });

  test('ignores case, accents and punctuation', () {
    expect(foldForSearch("Sāmarrā’"), 'samarra');
    expect(foldForSearch('  Al-Madinah  al Munawwarah '),
        'al madinah al munawwarah');
    expect(top('KARBALA', 1), ['Karbala, IQ']);
    expect(top('al madinah', 1), ['Madinah, SA']);
  });

  test('marks how much of the name was typed', () {
    expect(repository.search('Kar').first.nameMatchLength, 3);
    expect(repository.search('Mecca').first.nameMatchLength, 0);
  });

  test('guesses the city a time zone is named after', () {
    String? guess(String zone) {
      final city = repository.guessForTimeZone(zone);
      return city == null ? null : '${city.name}, ${city.countryCode}';
    }

    expect(guess('Europe/London'), 'London, GB');
    expect(guess('Asia/Baghdad'), 'Baghdad, IQ');
    expect(guess('Asia/Karachi'), 'Karachi, PK');
    expect(guess('Asia/Kolkata'), 'Kolkata, IN');
    expect(guess('America/New_York'), 'New York City, US');
    expect(guess('Asia/Kuwait'), 'Kuwait City, KW');
    expect(guess('UTC'), isNull);
    expect(guess('Etc/GMT+3'), isNull);
    expect(guess('Nowhere/Nothing'), isNull);
  });

  test('suggests the biggest cities in a zone', () {
    final suggestions = repository.biggestInTimeZone('Asia/Baghdad');
    expect(suggestions.first.name, 'Baghdad');
    expect(suggestions.length, lessThanOrEqualTo(6));
  });

  test('parses names, countries, provinces and time zones', () {
    final cities = City.parseDatabase([
      '# comment',
      'C\tIN\tIndia',
      'A\tIN.40\tTelangana',
      'Z\tAsia/Dubai',
      'Z\tAsia/Kolkata',
      'P\tHyderābād\tHyderabad\tIN\t40\t17.38\t78.46\t6993262\t1\t'
          'Bhagnagar',
      'P\tBroken\t\tIN\t\tnot-a-number\t78\t1\t1\t',
      'P\tNo zone\t\tIN\t\t17\t78\t1\t-4\t',
    ].join('\n'));
    expect(cities, hasLength(2));
    expect(cities.last.timeZone, isEmpty);
    cities.removeLast();
    final city = cities.single;
    expect(city.name, 'Hyderābād');
    expect(city.countryName, 'India');
    expect(city.admin1Name, 'Telangana');
    expect(city.latitude, 17.38);
    expect(city.timeZone, 'Asia/Kolkata');
    expect(city.aliases, ['Bhagnagar']);
  });

  test('names the list in another language, line for line', () {
    const list = 'C\tIQ\tIraq\n'
        'A\tIQ.05\tKarbala\n'
        'Z\tAsia/Baghdad\n'
        'P\tKarbala\t\tIQ\t05\t32.62\t44.02\t434450\t0\tKerbala\n'
        'P\tBroken\t\tIQ\t\tx\t44\t1\t0\t\n'
        'P\tSāmarrā’\tSamarra\tIQ\t\t34.20\t43.87\t158508\t0\t\n'
        'P\tNowhere\t\tIQ\t\t1\t1\t1\t0\t\n';
    const urdu = '# comment\n'
        'N\t4\n'
        'C\tIQ\tعراق\n'
        'A\tIQ.05\tمحافظہ کربلا\n'
        'کربلا\n'
        'بروکن\n'
        'سامرا\n'
        '\n';
    final cities = City.parseDatabase(list, names: urdu);
    expect([for (final city in cities) city.name],
        ['کربلا', 'سامرا', 'Nowhere']);
    expect(cities.first.englishName, 'Karbala');
    expect(cities.first.countryName, 'عراق');
    expect(cities.first.admin1Name, 'محافظہ کربلا');
    // No name in the file: the English one, and nothing to search twice.
    expect(cities.last.englishName, isEmpty);

    // A file that does not match the list is not trusted at all.
    final shifted = City.parseDatabase(list,
        names: urdu.replaceFirst('N\t4', 'N\t5'));
    expect(shifted.first.name, 'Karbala');
    expect(shifted.first.countryName, 'Iraq');
  });

  test('folds Arabic-script spellings of one name together', () {
    expect(foldForSearch('كربلاء'), foldForSearch('کربلا'));
    expect(foldForSearch('مَشْهَد'), foldForSearch('مشهد'));
    expect(foldForSearch('مکہ'), foldForSearch('مكة'));
    expect(foldForSearch('آمل'), foldForSearch('امل'));
    expect(foldForSearch('کرمانشاه'), foldForSearch('کرمان‌شاه'));
    expect(foldForSearch('૧૨ અમદાવાદ'), '12 અમદાવાદ');
  });

  group('in another language', () {
    setUp(() async {
      L10n.current = lookupAppLocalizations(const Locale('ur'));
      await repository.load();
    });
    tearDown(() async {
      L10n.current = lookupAppLocalizations(const Locale('en'));
      await repository.load();
    });

    test('names every city, country and province in it', () {
      final karbala = repository.search('Karbala').first.city;
      expect(karbala.name, 'کربلا');
      expect(karbala.englishName, 'Karbala');
      expect(karbala.countryName, 'عراق');
      // Every place has a name of its own: nothing English is left.
      final latin = RegExp('[A-Za-z]');
      final all = repository.search('a', limit: 100000);
      expect(all, isNotEmpty);
      for (final match in all) {
        expect(match.city.name, isNot(matches(latin)),
            reason: match.city.englishName);
        expect(match.city.countryName, isNot(matches(latin)));
        expect(match.city.admin1Name, isNot(matches(latin)));
      }
    });

    test('finds a city by its name in either script', () {
      List<String> codes(String query) => [
            for (final match in repository.search(query).take(1))
              '${match.city.name}, ${match.city.countryCode}',
          ];
      expect(codes('کربلا'), ['کربلا, IQ']);
      // Typed on an Arabic keyboard: ي ك ة and a hamza the Urdu lacks.
      expect(codes('كربلاء'), ['کربلا, IQ']);
      expect(codes('Karbala'), ['کربلا, IQ']);
      expect(codes('مشہد'), ['مشہد, IR']);
      expect(codes('Qom'), ['قم, IR']);
    });

    test('never shows a Latin other spelling', () {
      final mecca = repository.search('Mecca').first;
      expect(mecca.city.countryCode, 'SA');
      expect(mecca.alias, isNull);
    });

    test('a chosen city can be found again by where it is', () {
      final karbala = repository.search('Karbala').first.city;
      expect(repository.cityAt(karbala.latitude, karbala.longitude)?.name,
          'کربلا');
    });
  });

  test('keeps the list small: big cities and capitals only', () {
    // The picker is the fallback for when GPS is unavailable, and the list
    // ships in every install.
    final all = repository.search('a', limit: 100000);
    expect(all.length, lessThan(8000));
  });
}
