import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/holy_sites.dart';
import 'package:shia_companion/models/shrine_plan.dart';
import 'package:shia_companion/models/ziyarat_guide.dart';
import 'package:shia_companion/utils/geo_utils.dart';

// The rules of docs/ZIYARAT_GUIDE.md that a script can check, over
// assets/ziyarat_guide.json and its overlays in assets/ziyarat_guide_i18n/.

const _guidePath = 'assets/ziyarat_guide.json';
const _overlayDir = 'assets/ziyarat_guide_i18n';
final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');
final _linkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

Map<String, dynamic> _readJson(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _maps(Object? raw) => [
      for (final item in (raw as List? ?? const []))
        item as Map<String, dynamic>
    ];

/// How many parts (data + tabs) the zikr [uid]'s reader shows.
int _partCount(String uid) {
  final file = File('assets/zikr/$uid');
  if (!file.existsSync()) return 0;
  final zikr = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  final tabs = zikr['tabs'];
  return 1 + (tabs is List ? tabs.length : 0);
}

void main() {
  late Map<String, dynamic> guide;
  late Set<String> zikrKeys;

  setUpAll(() {
    guide = _readJson(_guidePath);
    zikrKeys = _readJson('assets/zikr.json').keys.toSet();
  });

  /// Every key an overlay may translate, mapped to its English text.
  Map<String, String> sourceKeys() {
    final keys = <String, String>{};
    void refs(String prefix, Object? raw) {
      final list = _maps(raw);
      for (var i = 0; i < list.length; i++) {
        for (final field in ['label', 'note']) {
          if (list[i][field] case final String text) {
            keys['$prefix.$i.$field'] = text;
          }
        }
      }
    }

    void tips(String prefix, Object? raw) {
      final list = (raw as List?) ?? const [];
      for (var i = 0; i < list.length; i++) {
        keys['$prefix.tips.$i'] = list[i] as String;
      }
    }

    refs('general', guide['general']);
    for (final region in _maps(guide['regions'])) {
      keys['region.${region['id']}.name'] = region['name'] as String;
      for (final city in _maps(region['cities'])) {
        final c = 'city.${city['id']}';
        keys['$c.name'] = city['name'] as String;
        if (city['about'] case final String about) keys['$c.about'] = about;
        tips(c, city['tips']);
        for (final site in _maps(city['sites'])) {
          final s = 'site.${site['id']}';
          keys['$s.name'] = site['name'] as String;
          if (site['about'] case final String about) keys['$s.about'] = about;
          tips(s, site['tips']);
          refs('$s.ziyarat', site['ziyarat']);
          for (final person in _maps(site['buried'])) {
            final b = '$s.buried.${person['id']}';
            keys['$b.name'] = person['name'] as String;
            if (person['note'] case final String note) keys['$b.note'] = note;
          }
        }
        for (final plan in _maps(city['plans'])) {
          for (final feature in _maps(plan['features'])) {
            final f = 'plan.${plan['id']}.${feature['id']}';
            keys['$f.name'] = feature['name'] as String;
            if (feature['note'] case final String note) keys['$f.note'] = note;
            refs('$f.ziyarat', feature['ziyarat']);
          }
        }
      }
    }
    return keys;
  }

  test('ids are snake_case and unique per kind', () {
    final problems = <String>[];
    void check(String kind, String? id, Set<String> seen) {
      if (id == null || !_idPattern.hasMatch(id)) {
        problems.add('$kind id "$id" is not snake_case');
      } else if (!seen.add(id)) {
        problems.add('$kind id "$id" is used twice');
      }
    }

    final regions = <String>{}, cities = <String>{}, sites = <String>{};
    final plans = <String>{};
    for (final region in _maps(guide['regions'])) {
      check('region', region['id'] as String?, regions);
      for (final city in _maps(region['cities'])) {
        check('city', city['id'] as String?, cities);
        for (final site in _maps(city['sites'])) {
          check('site', site['id'] as String?, sites);
          final people = <String>{};
          for (final person in _maps(site['buried'])) {
            check('burial in ${site['id']}', person['id'] as String?, people);
          }
        }
        for (final plan in _maps(city['plans'])) {
          check('plan', plan['id'] as String?, plans);
          final features = <String>{};
          for (final feature in _maps(plan['features'])) {
            check(
                'feature in ${plan['id']}', feature['id'] as String?, features);
          }
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('every ziyarat links a live zikr, and a tab it has', () {
    final problems = <String>[];
    void check(String where, Map<String, dynamic> ref) {
      final uid = ref['uid'] as String?;
      if (uid == null || !zikrKeys.contains(uid)) {
        problems.add('$where: "$uid" is not a key of assets/zikr.json');
        return;
      }
      if (uid.contains('~')) problems.add('$where: "$uid" is a group row');
      final target = uid.split('|').last;
      final tab = ref['tab'];
      if (tab != null) {
        final parts = _partCount(target);
        if (tab is! int || tab < 1 || tab > parts) {
          problems.add('$where: $uid has no tab $tab (it has $parts)');
        }
        if (ref['label'] is! String) {
          problems.add('$where: $uid tab $tab needs a label');
        }
      }
    }

    for (final ref in _maps(guide['general'])) {
      check('general', ref);
    }
    for (final region in _maps(guide['regions'])) {
      for (final city in _maps(region['cities'])) {
        for (final site in _maps(city['sites'])) {
          for (final ref in _maps(site['ziyarat'])) {
            check(site['id'] as String, ref);
          }
        }
        for (final plan in _maps(city['plans'])) {
          for (final feature in _maps(plan['features'])) {
            for (final ref in _maps(feature['ziyarat'])) {
              check('${plan['id']}.${feature['id']}', ref);
            }
          }
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('plans: their sites, features and drawings agree', () {
    final kinds = {for (final kind in PlanFeatureKind.values) kind.name};
    final osmRef = RegExp(r'^[nwr][1-9][0-9]*$');
    final problems = <String>[];
    for (final region in _maps(guide['regions'])) {
      for (final city in _maps(region['cities'])) {
        final sites = {
          for (final site in _maps(city['sites'])) site['id'] as String: site
        };
        for (final plan in _maps(city['plans'])) {
          final id = plan['id'];
          final planSites = [
            for (final site in (plan['sites'] as List? ?? const [])) '$site'
          ];
          if (planSites.isEmpty) problems.add('$id: no sites');
          for (final site in planSites) {
            if (!sites.containsKey(site)) {
              problems.add('$id: site "$site" is not in ${city['id']}');
            }
          }
          final bbox = plan['bbox'];
          if (bbox is! List ||
              bbox.length != 4 ||
              bbox.any((v) => v is! num) ||
              (bbox[0] as num) >= (bbox[2] as num) ||
              (bbox[1] as num) >= (bbox[3] as num)) {
            problems.add('$id: bbox $bbox is not [south, west, north, east]');
            continue;
          }
          final features = _maps(plan['features']).toList();
          for (final feature in features) {
            final where = '$id.${feature['id']}';
            if (!kinds.contains(feature['kind'])) {
              problems.add('$where: kind "${feature['kind']}"');
            }
            final osm = feature['osm'];
            if (osm != null && (osm is! String || !osmRef.hasMatch(osm))) {
              problems.add('$where: osm "$osm" is not n123, w123 or r123');
            }
            final location = feature['location'];
            if (location is! List ||
                location.length != 2 ||
                location.any((v) => v is! num)) {
              problems.add('$where: location $location '
                  '(run scripts/ziyarat_maps/build_plans.py)');
            } else {
              final lat = location[0] as num, lng = location[1] as num;
              if (lat < (bbox[0] as num) ||
                  lat > (bbox[2] as num) ||
                  lng < (bbox[1] as num) ||
                  lng > (bbox[3] as num)) {
                problems.add('$where: $location is outside the bbox');
              }
            }
            final site = feature['site'];
            if (site != null && !sites.containsKey(site)) {
              problems.add('$where: site "$site" is not in ${city['id']}');
            }
            final person = feature['person'];
            if (person != null) {
              final buried = site == null
                  ? const <Map<String, dynamic>>[]
                  : _maps(sites[site]?['buried']);
              if (!buried.any((p) => p['id'] == person)) {
                problems.add('$where: person "$person" is not buried at '
                    '"$site"');
              }
            }
          }
          for (final site in planSites) {
            if (!features.any((f) => f['site'] == site)) {
              problems.add('$id: no feature belongs to "$site", so the plan '
                  'has nothing to open on for it');
            }
          }
          final file = File('assets/ziyarat_plans/$id.json');
          if (!file.existsSync()) {
            problems.add('$id: no ${file.path} '
                '(run scripts/ziyarat_maps/build_plans.py $id)');
            continue;
          }
          final drawing = ShrinePlan.fromJson(_readJson(file.path));
          if (drawing.shapes.isEmpty) problems.add('$id: an empty drawing');
          for (final feature in features) {
            final location = feature['location'];
            if (location is! List || location.length != 2) continue;
            final at = drawing.project(GeoPoint((location[0] as num).toDouble(),
                (location[1] as num).toDouble()));
            if (!drawing.bounds.inflate(1).contains(at)) {
              problems.add('$id.${feature['id']}: outside the drawing '
                  '(rebuild it)');
            }
          }
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('links in the text name live zikrs', () {
    final problems = <String>[];
    for (final MapEntry(:key, :value) in sourceKeys().entries) {
      for (final match in _linkPattern.allMatches(value)) {
        final uid = match.group(2)!.split('?').first;
        if (!zikrKeys.contains(uid)) problems.add('$key links "$uid"');
      }
    }
    expect(problems, isEmpty);
  });

  test('sites have a kind, coordinates in range, a known holySiteId, sources',
      () {
    final holySiteIds = {for (final site in allHolySites) site.id};
    final kinds = {for (final kind in GuideSiteKind.values) kind.name};
    final problems = <String>[];
    for (final region in _maps(guide['regions'])) {
      for (final city in _maps(region['cities'])) {
        for (final site in _maps(city['sites'])) {
          final id = site['id'];
          if (!kinds.contains(site['kind'])) {
            problems.add('$id: kind "${site['kind']}"');
          }
          final location = site['location'];
          if (location is! List ||
              location.length != 2 ||
              location.any((v) => v is! num) ||
              (location[0] as num).abs() > 90 ||
              (location[1] as num).abs() > 180) {
            problems.add('$id: location $location');
          }
          final holySiteId = site['holySiteId'];
          if (holySiteId != null && !holySiteIds.contains(holySiteId)) {
            problems.add('$id: unknown holySiteId "$holySiteId"');
          }
          final sources = site['sources'];
          if (sources is! List || sources.isEmpty) {
            problems.add('$id: no sources');
          }
          final died = _maps(site['buried']).map((p) => p['diedAh']);
          if (died.any((year) => year != null && (year is! int || year < 1))) {
            problems.add('$id: a diedAh that is not a Hijri year');
          }
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('overlays translate only keys the guide has', () {
    final keys = sourceKeys().keys.toSet();
    final problems = <String>[];
    for (final file in Directory(_overlayDir).listSync().whereType<File>()) {
      final overlay = _readJson(file.path);
      for (final entry in overlay.entries) {
        if (!keys.contains(entry.key)) {
          problems.add('${file.path}: "${entry.key}" is not in the guide');
        } else if (entry.value is! String ||
            (entry.value as String).trim().isEmpty) {
          problems.add('${file.path}: "${entry.key}" is empty');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('the asset parses, and every language falls back as documented', () {
    final english = ZiyaratGuide.fromJson(guide);
    expect(english.general, isNotEmpty);

    final fixture = {
      'general': [
        {'uid': 'B3', 'note': 'Read once before travelling.'},
      ],
      'regions': [
        {
          'id': 'iraq',
          'name': 'Iraq',
          'arabicName': 'العراق',
          'cities': [
            {
              'id': 'najaf',
              'name': 'Najaf',
              'arabicName': 'النجف',
              'about': 'City of Imam Ali.',
              'tips': ['One', 'Two'],
              'sites': [
                {
                  'id': 'imam_ali_shrine',
                  'name': 'Shrine of Imam Ali (a.s.)',
                  'kind': 'shrine',
                  'location': [31.9966, 44.3147],
                  'ziyarat': [
                    {'uid': 'AK5', 'tab': 2, 'label': 'Ziyarat Aminullah'},
                  ],
                  'buried': [
                    {'id': 'allamah_hilli', 'name': 'Allamah al-Hilli'},
                  ],
                },
              ],
              'plans': [
                {
                  'id': 'najaf_haram',
                  'sites': ['imam_ali_shrine'],
                  'features': [
                    {
                      'id': 'gate',
                      'kind': 'gate',
                      'name': 'Bab al-Qibla',
                      'arabicName': 'باب القبلة',
                      'site': 'imam_ali_shrine',
                      'location': [31.9960, 44.3147],
                    },
                    {
                      'id': 'zarih',
                      'kind': 'zarih',
                      'name': 'Zarih of Imam Ali (a.s.)',
                      'arabicName': 'ضريح الإمام علي',
                      'note': 'Under the dome.',
                      'site': 'imam_ali_shrine',
                      'person': 'allamah_hilli',
                      'location': [31.9966, 44.3147],
                      'ziyarat': [
                        {'uid': 'AK5', 'note': 'The first ziyarat.'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };

    final en = ZiyaratGuide.fromJson(fixture);
    final site = en.site('imam_ali_shrine')!;
    expect(site.city.region.id, 'iraq');
    expect(site.ziyarat.single.initialTabIndex, 1);
    expect(en.city('najaf')!.tips, ['One', 'Two']);
    final plan = site.plan!;
    expect(plan.focusFor('imam_ali_shrine')!.id, 'zarih',
        reason: 'a plan opens on the zarih, not the first feature');
    expect(plan.features.last.person!.id, 'allamah_hilli');
    expect(plan.features.last.ziyarat.single.note, 'The first ziyarat.');

    final ur = ZiyaratGuide.fromJson(fixture,
        languageCode: 'ur', translations: {'city.najaf.tips.1': 'دو'});
    final najaf = ur.city('najaf')!;
    expect(najaf.name, 'النجف', reason: 'Arabic name for an Urdu reader');
    expect(najaf.about, isNull, reason: 'no English prose outside English');
    expect(najaf.tips, ['دو']);
    expect(ur.general.single.note, isNull);
    expect(ur.site('imam_ali_shrine')!.ziyarat.single.label, isNull,
        reason: 'falls back to the zikr title, which is translated');
    final urPlan = ur.site('imam_ali_shrine')!.plan!;
    expect(urPlan.features.first.name, 'باب القبلة');
    expect(urPlan.features.last.note, isNull);
    final urTranslated = ZiyaratGuide.fromJson(fixture,
        languageCode: 'ur',
        translations: {'plan.najaf_haram.zarih.note': 'گنبد کے نیچے۔'});
    expect(urTranslated.site('imam_ali_shrine')!.plan!.features.last.note,
        'گنبد کے نیچے۔');

    final gu = ZiyaratGuide.fromJson(fixture, languageCode: 'gu');
    expect(gu.city('najaf')!.name, 'Najaf',
        reason: 'no Gujarati and no script to fall back on: the name stays');
  });
}
