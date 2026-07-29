import 'dart:convert';

/// A single airport entry loaded from `assets/airports.tsv`.
class Airport {
  const Airport({
    required this.iata,
    required this.icao,
    required this.name,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timeZoneId,
  });

  /// Three letter IATA code, e.g. `SFO`. Unique within the bundled database.
  final String iata;

  /// Four letter ICAO code, e.g. `KSFO`. May be empty for a few entries.
  final String icao;
  final String name;
  final String city;
  final String country;
  final double latitude;
  final double longitude;

  /// IANA time zone identifier, e.g. `America/Los_Angeles`.
  ///
  /// Stored canonically: tzdb aliases such as `Africa/Dar_es_Salaam` are
  /// recorded as the zone they link to (`Africa/Nairobi`), because the bundled
  /// time zone database only carries canonical names. The two are exact
  /// equivalents, so the resulting times are unchanged.
  final String timeZoneId;

  /// "San Francisco, United States" — falls back to the airport name when the
  /// dataset has no city for the entry.
  String get locationLabel {
    final place = city.isNotEmpty ? city : name;
    return country.isEmpty ? place : '$place, $country';
  }

  /// Lowercased text used for free-text search, precomputed by the repository
  /// so matching does not re-allocate on every keystroke.
  String get searchHaystack => '$iata $icao $name $city $country'.toLowerCase();

  /// Parses one tab separated line:
  /// `IATA \t ICAO \t name \t city \t country \t lat \t lon \t tz`
  static Airport? tryParseLine(String line) {
    final parts = line.split('\t');
    if (parts.length < 8) return null;

    final latitude = double.tryParse(parts[5]);
    final longitude = double.tryParse(parts[6]);
    if (latitude == null || longitude == null) return null;
    if (parts[0].isEmpty || parts[7].isEmpty) return null;

    return Airport(
      iata: parts[0],
      icao: parts[1],
      name: parts[2],
      city: parts[3],
      country: parts[4],
      latitude: latitude,
      longitude: longitude,
      timeZoneId: parts[7],
    );
  }

  /// Serialized into each saved flight so the flight carries everything it
  /// needs. See [Flight] for why the coordinates are copied rather than looked
  /// up again on every read.
  Map<String, dynamic> toJson() => {
        'iata': iata,
        'icao': icao,
        'name': name,
        'city': city,
        'country': country,
        'lat': latitude,
        'lon': longitude,
        'tz': timeZoneId,
      };

  static Airport? fromJson(Map<String, dynamic> json) {
    final iata = json['iata'];
    final timeZoneId = json['tz'];
    final latitude = (json['lat'] as num?)?.toDouble();
    final longitude = (json['lon'] as num?)?.toDouble();

    if (iata is! String ||
        iata.isEmpty ||
        timeZoneId is! String ||
        timeZoneId.isEmpty ||
        latitude == null ||
        longitude == null) {
      return null;
    }

    String text(Object? value) => value is String ? value : '';

    return Airport(
      iata: iata,
      icao: text(json['icao']),
      name: text(json['name']),
      city: text(json['city']),
      country: text(json['country']),
      latitude: latitude,
      longitude: longitude,
      timeZoneId: timeZoneId,
    );
  }

  static List<Airport> parseDatabase(String contents) {
    final airports = <Airport>[];
    for (final line in const LineSplitter().convert(contents)) {
      if (line.trim().isEmpty) continue;
      final airport = tryParseLine(line);
      if (airport != null) airports.add(airport);
    }
    return airports;
  }

  @override
  String toString() => 'Airport($iata)';
}
