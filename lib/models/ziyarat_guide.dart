import '../utils/geo_utils.dart';

/// The Ziyarat Guide (docs/ZIYARAT_GUIDE.md): the places pilgrims visit,
/// region by region and city by city, read from `assets/ziyarat_guide.json`
/// with the app language's overlay (`assets/ziyarat_guide_i18n/<code>.json`)
/// laid over it.
///
/// Every text field here is already in the app language. Outside English no
/// English is shown, as in the zikr reader: a name nobody has translated
/// falls back to its Arabic name where the reader reads Arabic script, and
/// an untranslated about, tip or note is left out (null, or dropped from
/// its list).
class ZiyaratGuide {
  const ZiyaratGuide({required this.general, required this.regions});

  /// "Before you go": what to read before any ziyarat (its etiquettes,
  /// permission to enter, what to recite after).
  final List<ZiyaratRef> general;
  final List<GuideRegion> regions;

  static const empty = ZiyaratGuide(general: [], regions: []);

  Iterable<GuideCity> get cities => regions.expand((r) => r.cities);

  Iterable<GuideSite> get sites => cities.expand((c) => c.sites);

  GuideCity? city(String id) {
    for (final city in cities) {
      if (city.id == id) return city;
    }
    return null;
  }

  GuideSite? site(String id) {
    for (final site in sites) {
      if (site.id == id) return site;
    }
    return null;
  }

  /// [json] (the English asset) in the language [languageCode], with that
  /// language's [translations] (the overlay's flat key -> text map).
  factory ZiyaratGuide.fromJson(
    Map<String, dynamic> json, {
    String languageCode = 'en',
    Map<String, String> translations = const {},
  }) {
    final text = GuideLocalizer(languageCode, translations);
    return ZiyaratGuide(
      general: _refs(json['general'], 'general', text),
      regions: [
        for (final region in _maps(json['regions']))
          GuideRegion._fromJson(region, text),
      ],
    );
  }
}

class GuideRegion {
  GuideRegion({
    required this.id,
    required this.name,
    required this.englishName,
    this.arabicName,
    required this.cities,
  });

  final String id;
  final String name;

  /// [name] in English whatever the app language: for analytics.
  final String englishName;
  final String? arabicName;
  final List<GuideCity> cities;

  factory GuideRegion._fromJson(Map<String, dynamic> json, GuideLocalizer t) {
    final id = json['id'] as String;
    final english = json['name'] as String;
    final arabic = json['arabicName'] as String?;
    final region = GuideRegion(
      id: id,
      name: t.name('region.$id.name', english, arabic),
      englishName: english,
      arabicName: arabic,
      cities: [],
    );
    for (final city in _maps(json['cities'])) {
      region.cities.add(GuideCity._fromJson(city, region, t));
    }
    return region;
  }
}

class GuideCity {
  GuideCity({
    required this.id,
    required this.region,
    required this.name,
    required this.englishName,
    this.arabicName,
    this.about,
    required this.tips,
    required this.sites,
  });

  final String id;
  final GuideRegion region;
  final String name;
  final String englishName;
  final String? arabicName;
  final String? about;
  final List<String> tips;
  final List<GuideSite> sites;

  /// Every ziyarat linked from the city's places.
  int get ziyaratCount =>
      sites.fold(0, (count, site) => count + site.ziyarat.length);

  factory GuideCity._fromJson(
    Map<String, dynamic> json,
    GuideRegion region,
    GuideLocalizer t,
  ) {
    final id = json['id'] as String;
    final english = json['name'] as String;
    final arabic = json['arabicName'] as String?;
    final city = GuideCity(
      id: id,
      region: region,
      name: t.name('city.$id.name', english, arabic),
      englishName: english,
      arabicName: arabic,
      about: t.prose('city.$id.about', json['about'] as String?),
      tips: t.list('city.$id.tips', json['tips']),
      sites: [],
    );
    for (final site in _maps(json['sites'])) {
      city.sites.add(GuideSite._fromJson(site, city, t));
    }
    return city;
  }
}

/// What a site is, for the line under its name and its icon.
enum GuideSiteKind {
  shrine,
  mosque,
  cemetery,
  tomb,
  maqam,
  other;

  static GuideSiteKind parse(Object? raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return other;
  }
}

class GuideSite {
  GuideSite({
    required this.id,
    required this.city,
    required this.name,
    required this.englishName,
    this.arabicName,
    required this.kind,
    required this.location,
    this.holySiteId,
    this.about,
    required this.ziyarat,
    required this.buried,
    required this.tips,
  });

  final String id;
  final GuideCity city;
  final String name;
  final String englishName;
  final String? arabicName;
  final GuideSiteKind kind;
  final GeoPoint location;

  /// The [HolySite] the compass can point at, when the site is one.
  final String? holySiteId;
  final String? about;
  final List<ZiyaratRef> ziyarat;
  final List<GuideBurial> buried;
  final List<String> tips;

  factory GuideSite._fromJson(
    Map<String, dynamic> json,
    GuideCity city,
    GuideLocalizer t,
  ) {
    final id = json['id'] as String;
    final english = json['name'] as String;
    final arabic = json['arabicName'] as String?;
    final location = (json['location'] as List).cast<num>();
    return GuideSite(
      id: id,
      city: city,
      name: t.name('site.$id.name', english, arabic),
      englishName: english,
      arabicName: arabic,
      kind: GuideSiteKind.parse(json['kind']),
      location: GeoPoint(location[0].toDouble(), location[1].toDouble()),
      holySiteId: json['holySiteId'] as String?,
      about: t.prose('site.$id.about', json['about'] as String?),
      ziyarat: _refs(json['ziyarat'], 'site.$id.ziyarat', t),
      buried: [
        for (final person in _maps(json['buried']))
          GuideBurial._fromJson(person, 'site.$id.buried', t),
      ],
      tips: t.list('site.$id.tips', json['tips']),
    );
  }
}

/// A zikr to recite at a place: the whole entry, or one of its tabs.
class ZiyaratRef {
  const ZiyaratRef({required this.uid, this.tab, this.label, this.note});

  /// A live zikr uid (a key of `assets/zikr.json`).
  final String uid;

  /// The tab to open, counted from 1 as the reader shows tabs (the number a
  /// `?tab=N` link carries); null for the entry's first.
  final int? tab;

  /// What the row says instead of the zikr's own title: the name of the
  /// form [tab] holds. Null shows the zikr's title.
  final String? label;

  /// One short line under it: an occasion, a condition.
  final String? note;

  /// [tab] as [ZikrPage.initialTab] takes it: from 0.
  int? get initialTabIndex => tab == null ? null : tab! - 1;
}

/// Someone else buried at a site: family of the Imams, a companion, a
/// martyr, a scholar.
class GuideBurial {
  const GuideBurial({
    required this.id,
    required this.name,
    this.arabicName,
    this.diedAh,
    this.note,
  });

  final String id;
  final String name;
  final String? arabicName;

  /// The Hijri year of death, when well established.
  final int? diedAh;
  final String? note;

  factory GuideBurial._fromJson(
    Map<String, dynamic> json,
    String prefix,
    GuideLocalizer t,
  ) {
    final id = json['id'] as String;
    final arabic = json['arabicName'] as String?;
    return GuideBurial(
      id: id,
      name: t.name('$prefix.$id.name', json['name'] as String, arabic),
      arabicName: arabic,
      diedAh: (json['diedAh'] as num?)?.toInt(),
      note: t.prose('$prefix.$id.note', json['note'] as String?),
    );
  }
}

/// Picks each field's text for the app language from the overlay.
class GuideLocalizer {
  GuideLocalizer(this.languageCode, this.translations);

  final String languageCode;
  final Map<String, String> translations;

  bool get isEnglish => languageCode == 'en';

  /// Languages whose readers read Arabic script, for whom an untranslated
  /// name is better shown in Arabic than in English.
  static const _arabicScript = {'ar', 'fa', 'ur'};

  String? _translated(String key) {
    final text = translations[key]?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// A name: translated, else its Arabic name for a reader of Arabic
  /// script, else the English. A name is never hidden - the row would have
  /// nothing to say.
  String name(String key, String english, String? arabic) {
    if (isEnglish) return english;
    final translated = _translated(key);
    if (translated != null) return translated;
    if (arabic != null &&
        arabic.trim().isNotEmpty &&
        _arabicScript.contains(languageCode)) {
      return arabic;
    }
    return english;
  }

  /// A paragraph or note: null outside English when not translated.
  String? prose(String key, String? english) {
    if (english == null || english.trim().isEmpty) return null;
    if (isEnglish) return english;
    return _translated(key);
  }

  /// A list of tips, `<key>.<n>` from 0; untranslated ones dropped.
  List<String> list(String key, Object? raw) {
    if (raw is! List) return const [];
    return [
      for (var i = 0; i < raw.length; i++)
        if (prose('$key.$i', raw[i] as String?) case final text?) text,
    ];
  }
}

List<ZiyaratRef> _refs(Object? raw, String prefix, GuideLocalizer t) {
  final maps = _maps(raw).toList();
  return [
    for (var i = 0; i < maps.length; i++)
      ZiyaratRef(
        uid: maps[i]['uid'] as String,
        tab: (maps[i]['tab'] as num?)?.toInt(),
        label: t.isEnglish
            ? maps[i]['label'] as String?
            : t.prose('$prefix.$i.label', maps[i]['label'] as String?),
        note: t.prose('$prefix.$i.note', maps[i]['note'] as String?),
      ),
  ];
}

Iterable<Map<String, dynamic>> _maps(Object? raw) sync* {
  if (raw is! List) return;
  for (final item in raw) {
    if (item is Map) yield item.cast<String, dynamic>();
  }
}
