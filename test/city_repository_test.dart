import 'package:flutter_test/flutter_test.dart';
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

  test('keeps the list small: big cities and capitals only', () {
    // The picker is the fallback for when GPS is unavailable, and the list
    // ships in every install.
    final all = repository.search('a', limit: 100000);
    expect(all.length, lessThan(8000));
  });
}
