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
  });

  /// As GeoNames writes it, accents and all: "Sāmarrā’".
  final String name;

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

  /// Parses assets/cities.tsv.
  static List<City> parseDatabase(String contents) {
    final countries = <String, String>{};
    final admin1 = <String, String>{};
    final zones = <String>[];
    final cities = <City>[];

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
        case 'P' when fields.length >= 9:
          final latitude = double.tryParse(fields[5]);
          final longitude = double.tryParse(fields[6]);
          if (latitude == null || longitude == null) continue;
          final country = fields[3];
          cities.add(City(
            name: fields[1],
            asciiName: fields[2],
            countryCode: country,
            countryName: countries[country] ?? country,
            admin1Name: admin1['$country.${fields[4]}'] ?? '',
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
    return cities;
  }

  /// Time zones are written once each in the Z lines and referred to by
  /// their number, in order.
  static String _zone(List<String> zones, String field) {
    final index = int.tryParse(field);
    if (index == null || index < 0 || index >= zones.length) return '';
    return zones[index];
  }
}
