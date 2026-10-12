import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../l10n/l10n.dart';
import '../models/city.dart';

/// One search result: the city, and the other spelling it was found by, if
/// it was not found by its own name ("Mecca" for Makkah).
@immutable
class CityMatch {
  const CityMatch(this.city, {this.alias, this.nameMatchLength = 0});

  final City city;
  final String? alias;

  /// How many leading characters of [City.name] the query matched, for
  /// drawing them bold; 0 when the match was not at the start of the name.
  final int nameMatchLength;
}

/// Loads and searches the bundled city list, offline.
///
/// ~6,000 places, parsed on first use (on a background isolate where there
/// is one) and held in memory, named in the app language: English from
/// assets/cities.tsv, any other language from assets/cities_<code>.tsv.
/// Search is a ranked scan over precomputed folded names, fast enough to
/// run on every keystroke, and finds a city by its name in either.
class CityRepository {
  CityRepository._();

  static final CityRepository instance = CityRepository._();

  static const String assetPath = 'assets/cities.tsv';

  /// The list's names in [language], for any language but English.
  static String namesAssetPath(String language) =>
      'assets/cities_$language.tsv';

  List<City>? _cities;
  List<_SearchKeys>? _keys;
  String? _language;
  Future<void>? _loadFuture;
  String? _loadingLanguage;

  /// Whether the list is loaded in the app language.
  bool get isLoaded => _cities != null && _language == _appLanguage;

  static String get _appLanguage => L10n.current.localeName;

  /// Loads the list named in the app language, if it is not already.
  Future<void> load() {
    if (isLoaded) return Future.value();
    final language = _appLanguage;
    if (_loadFuture != null && _loadingLanguage == language) {
      return _loadFuture!;
    }
    _loadingLanguage = language;
    return _loadFuture = _loadInternal(language).whenComplete(() {
      if (_loadingLanguage == language) {
        _loadFuture = null;
        _loadingLanguage = null;
      }
    });
  }

  Future<void> _loadInternal(String language) async {
    final contents = await rootBundle.loadString(assetPath);
    String? names;
    if (language != 'en') {
      try {
        names = await rootBundle.loadString(namesAssetPath(language));
      } catch (e) {
        debugPrint('No city names for $language: $e');
      }
    }
    final (cities, keys) =
        await compute(_parseAndIndex, (contents: contents, names: names));
    // The language changed again while this was parsing.
    if (language != _appLanguage) return;
    _cities = cities;
    _keys = keys;
    _language = language;
  }

  /// Seeds the repository directly, bypassing the asset bundle. For tests.
  @visibleForTesting
  void seedForTesting(List<City> cities) {
    final (indexed, keys) = _index(cities);
    _cities = indexed;
    _keys = keys;
    _language = _appLanguage;
  }

  static (List<City>, List<_SearchKeys>) _parseAndIndex(
          ({String contents, String? names}) files) =>
      _index(City.parseDatabase(files.contents, names: files.names));

  static (List<City>, List<_SearchKeys>) _index(List<City> cities) {
    // Biggest first: ties in search, and the time-zone guess, both rely on
    // index order being population order.
    final sorted = [...cities]
      ..sort((a, b) => b.population.compareTo(a.population));
    return (
      List.unmodifiable(sorted),
      List.unmodifiable([for (final city in sorted) _SearchKeys(city)]),
    );
  }

  /// Cities matching [query], best first:
  ///
  ///  0. its name, or another spelling of it, is exactly [query];
  ///  1. its name starts with [query];
  ///  2. a later word of its name does;
  ///  3. another spelling starts with [query], then 4, a later word of one;
  ///  5. its name merely contains [query].
  ///
  /// Within each, bigger cities first - so "Medina" puts Madinah (Saudi
  /// Arabia) above the small towns of that name, and "kar" starts with
  /// Karachi. Other spellings only compete with names when exact: many are
  /// other languages' forms ("Karakas" for Caracas), which would otherwise
  /// crowd out the cities whose names really start with what was typed.
  List<CityMatch> search(String query, {int limit = 40}) {
    final cities = _cities;
    final keys = _keys;
    final folded = foldForSearch(query);
    if (cities == null || keys == null || folded.isEmpty) return const [];

    final scored = <(int, int, CityMatch)>[];
    for (var i = 0; i < cities.length; i++) {
      final key = keys[i];
      final city = cities[i];
      var nameRank = _nameRank(key.name, folded);
      final englishRank =
          key.englishName.isEmpty ? null : _nameRank(key.englishName, folded);
      if (englishRank != null && (nameRank == null || englishRank < nameRank)) {
        nameRank = englishRank;
      }
      if (nameRank == 0) {
        scored.add((
          0,
          i,
          CityMatch(city, nameMatchLength: _boldLength(city.name, query)),
        ));
        continue;
      }
      int? aliasRank;
      String? alias;
      for (var a = 0; a < key.aliases.length; a++) {
        final rank = _aliasRank(key.aliases[a], folded);
        if (rank != null && (aliasRank == null || rank < aliasRank)) {
          aliasRank = rank;
          alias = city.aliases[a];
          if (rank == 0) break;
        }
      }
      if (aliasRank != null && (nameRank == null || aliasRank < nameRank)) {
        // The other spellings are all in Latin letters, which a reader in
        // another language is never shown.
        scored.add((
          aliasRank,
          i,
          CityMatch(city, alias: city.englishName.isEmpty ? alias : null),
        ));
      } else if (nameRank != null) {
        scored.add((
          nameRank,
          i,
          CityMatch(city, nameMatchLength: _boldLength(city.name, query)),
        ));
      }
    }

    scored.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      if (byRank != 0) return byRank;
      // Index order is population order.
      return a.$2.compareTo(b.$2);
    });
    return [for (final entry in scored.take(limit)) entry.$3];
  }

  static int? _nameRank(String key, String query) {
    if (key == query) return 0;
    if (key.startsWith(query)) return 1;
    if (key.contains(' $query')) return 2;
    if (query.length >= 3 && key.contains(query)) return 5;
    return null;
  }

  static int? _aliasRank(String key, String query) {
    if (key == query) return 0;
    if (key.startsWith(query)) return 3;
    if (key.contains(' $query')) return 4;
    return null;
  }

  static int _boldLength(String name, String query) {
    final typed = query.trim().toLowerCase();
    return typed.isNotEmpty && name.toLowerCase().startsWith(typed)
        ? typed.length
        : 0;
  }

  /// The most likely city for the phone's time zone: the one the zone is
  /// named after when it is in the list (Europe/London -> London), otherwise
  /// the biggest city in the zone. Null for zones that name no place ("UTC").
  City? guessForTimeZone(String? timeZone) {
    final cities = _cities;
    final keys = _keys;
    if (cities == null || keys == null) return null;
    if (timeZone == null || !timeZone.contains('/')) return null;
    if (timeZone.startsWith('Etc/')) return null;

    final named = foldForSearch(timeZone.split('/').last);
    City? biggest;
    City? namedCity;
    for (var i = 0; i < cities.length; i++) {
      final city = cities[i];
      if (city.timeZone != timeZone) continue;
      // Biggest first, so the first in the zone is its biggest.
      biggest ??= city;
      final key = keys[i];
      final english = key.englishName.isEmpty ? key.name : key.englishName;
      if (english == named || key.aliases.contains(named)) return city;
      // Asia/Kuwait -> Kuwait City, America/Panama -> Panama City.
      if (namedCity == null && english == '$named city') namedCity = city;
    }
    return namedCity ?? biggest;
  }

  /// The city of the list at exactly [latitude], [longitude], as a chosen
  /// city's location is stored: for naming it again in another language.
  City? cityAt(double latitude, double longitude) {
    final cities = _cities;
    if (cities == null) return null;
    for (final city in cities) {
      if (city.latitude == latitude && city.longitude == longitude) {
        return city;
      }
    }
    return null;
  }

  /// The biggest cities in [timeZone], for suggesting before anything is
  /// typed.
  List<City> biggestInTimeZone(String? timeZone, {int limit = 6}) {
    final cities = _cities;
    if (cities == null || timeZone == null) return const [];
    return [
      for (final city in cities)
        if (city.timeZone == timeZone) city,
    ].take(limit).toList(growable: false);
  }
}

class _SearchKeys {
  _SearchKeys(City city)
      : name = city.englishName.isEmpty
            ? _englishKey(city.asciiName, city.name)
            : foldForSearch(city.name),
        englishName = city.englishName.isEmpty
            ? ''
            : _englishKey(city.asciiName, city.englishName),
        aliases = [for (final alias in city.aliases) foldForSearch(alias)];

  static String _englishKey(String asciiName, String name) =>
      foldForSearch(asciiName.isNotEmpty ? asciiName : name);

  /// [City.name], folded.
  final String name;

  /// [City.englishName], folded; empty when the name is the English one.
  final String englishName;
  final List<String> aliases;
}

const Map<String, String> _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ḥ': 'h',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ı': 'i',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ṣ': 's',
  'ť': 't',
  'ṭ': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
  'ẓ': 'z',
  'ß': 'ss',
};

/// Arabic-script letters written more than one way, as one: Arabic and
/// Persian/Urdu yeh and kaf, the forms of heh, alef with hamza.
const Map<String, String> _arabicLetters = {
  'ي': 'ی',
  'ى': 'ی',
  'ئ': 'ی',
  'ك': 'ک',
  'ہ': 'ه',
  'ە': 'ه',
  'ۀ': 'ه',
  'ة': 'ه',
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ؤ': 'و',
};

/// Lower case, accents dropped, apostrophes gone and other punctuation as
/// spaces - so "Sāmarrā’", "samarra" and "Samarra'" all compare equal. In
/// Arabic script, vowel marks are dropped and letters written more than one
/// way are made one, so "كربلاء" typed on an Arabic keyboard finds the Urdu
/// "کربلا"'s city too; Gujarati is kept as typed.
@visibleForTesting
String foldForSearch(String value) {
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final rune in asciiDigits(value).toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (_dropped.contains(char) || _arabicMarks.hasMatch(char)) continue;
    final mapped = _accents[char] ?? _arabicLetters[char] ?? char;
    if (_kept.hasMatch(mapped)) {
      if (pendingSpace && buffer.isNotEmpty) buffer.write(' ');
      pendingSpace = false;
      buffer.write(mapped);
    } else {
      pendingSpace = true;
    }
  }
  return buffer.toString();
}

/// Apostrophes, and the zero-width non-joiner Persian writes inside words.
const String _dropped = "'’‘ʻʼ`\u200C";

/// Arabic vowel marks, hamza (as the press often leaves it off: كربلاء,
/// كربلا) and tatweel.
final RegExp _arabicMarks = RegExp('[\u064B-\u0652\u0670\u0640\u0621]');
final RegExp _kept =
    RegExp('^[a-z0-9\u0620-\u064A\u066E-\u06D3\u06D5\u0A80-\u0AFF]+\$');
