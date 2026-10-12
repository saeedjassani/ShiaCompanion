import 'package:flutter/foundation.dart';

/// A place from the bundled city list (assets/cities.tsv, built from
/// GeoNames by scripts/build_city_list.py).
@immutable
class City {
  const City({
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.timeZone,
    this.asciiName = '',
    this.admin1Name = '',
    this.aliases = const [],
    this.englishName = '',
  });

  /// The name to show, in the app language: as GeoNames writes it in
  /// English, accents and all ("Sāmarrā’"), or the list's name for it in
  /// another language ("سامراء").
  final String name;

  /// The English name when [name] is in another language, else empty: the
  /// search finds a city by either.
  final String englishName;

  /// [name] without diacritics, or empty when it has none.
  final String asciiName;
  final String countryCode;
  final String countryName;

  /// State or province, for telling apart two cities of the same name in
  /// one country. Only given for such cities; empty otherwise.
  final String admin1Name;
  final double latitude;
  final double longitude;
  final int population;

  /// IANA id, e.g. "Asia/Baghdad".
  final String timeZone;

  /// Other spellings it is known by ("Kerbala", "Mecca").
  final List<String> aliases;

  /// Parses assets/cities.tsv, named in another language from [names], the
  /// matching assets/cities_<code>.tsv, when given. A names file that does
  /// not match the list line for line is ignored rather than misnaming
  /// every city, and a place it has no name for keeps its English one.
  static List<City> parseDatabase(String contents, {String? names}) {
    final countries = <String, String>{};
    final admin1 = <String, String>{};
    final zones = <String>[];
    final cities = <City>[];
    final local = names == null ? null : _LocalNames.parse(names);
    var placeIndex = 0;

    for (final line in contents.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final fields = line.split('\t');
      switch (fields[0]) {
        case 'C' when fields.length >= 3:
          countries[fields[1]] = fields[2];
        case 'A' when fields.length >= 3:
          admin1[fields[1]] = fields[2];
        case 'Z' when fields.length >= 2:
          zones.add(fields[1]);
        case 'P':
          // Counted before anything can skip it: the names file has a line
          // for every place line, usable or not.
          final localName = local?.place(placeIndex) ?? '';
          placeIndex++;
          if (fields.length < 9) continue;
          final latitude = double.tryParse(fields[5]);
          final longitude = double.tryParse(fields[6]);
          if (latitude == null || longitude == null) continue;
          final country = fields[3];
          final admin1Code = '$country.${fields[4]}';
          cities.add(City(
            name: localName.isNotEmpty ? localName : fields[1],
            englishName: localName.isNotEmpty ? fields[1] : '',
            asciiName: fields[2],
            countryCode: country,
            countryName: _nonEmpty(local?.countries[country]) ??
                countries[country] ??
                country,
            admin1Name: _nonEmpty(local?.admin1[admin1Code]) ??
                admin1[admin1Code] ??
                '',
            latitude: latitude,
            longitude: longitude,
            population: int.tryParse(fields[7]) ?? 0,
            timeZone: _zone(zones, fields[8]),
            aliases: fields.length > 9 && fields[9].isNotEmpty
                ? fields[9].split('|')
                : const [],
          ));
      }
    }
    if (local != null && local.placeCount != placeIndex) {
      debugPrint('City names file has ${local.placeCount} places, the list '
          '$placeIndex; showing English.');
      return parseDatabase(contents);
    }
    return cities;
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  /// Time zones are written once each in the Z lines and referred to by
  /// their number, in order.
  static String _zone(List<String> zones, String field) {
    final index = int.tryParse(field);
    if (index == null || index < 0 || index >= zones.length) return '';
    return zones[index];
  }
}

/// An assets/cities_<code>.tsv: the list's names in one language.
class _LocalNames {
  _LocalNames(this.placeCount, this.countries, this.admin1, this._places);

  static _LocalNames parse(String contents) {
    var placeCount = -1;
    final countries = <String, String>{};
    final admin1 = <String, String>{};
    final places = <String>[];
    final lines = contents.split('\n');
    // A file ends in a newline, which is not one more place.
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    for (final line in lines) {
      if (line.startsWith('#')) continue;
      final fields = line.split('\t');
      if (fields.length == 2 && fields[0] == 'N') {
        placeCount = int.tryParse(fields[1]) ?? -1;
      } else if (fields.length == 3 && fields[0] == 'C') {
        countries[fields[1]] = fields[2];
      } else if (fields.length == 3 && fields[0] == 'A') {
        admin1[fields[1]] = fields[2];
      } else {
        places.add(line.trim());
      }
    }
    // Declared and found must agree, or the lines are not the list's.
    return _LocalNames(
        placeCount == places.length ? placeCount : -1, countries, admin1,
        places);
  }

  /// How many places it names, -1 when it is not well formed.
  final int placeCount;
  final Map<String, String> countries;
  final Map<String, String> admin1;
  final List<String> _places;

  String place(int index) => index < _places.length ? _places[index] : '';
}
