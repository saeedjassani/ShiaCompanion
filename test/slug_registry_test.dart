import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/slug_registry.dart';

void main() {
  setUp(clearLocalSlugMaps);
  tearDown(clearLocalSlugMaps);

  test('normalizes title-like slugs', () {
    expect(normalizeSlug(' Ziyarat_e Ashura!! '), 'ziyarat-e-ashura');
    expect(slugifyUid('G17|L4'), 'g17-l4');
  });

  test('buildSlugSeed prefers raw slug, then title, then uid', () {
    expect(
      buildSlugSeed(
        uid: 'G4',
        title: 'Ziyarat e Ashura',
        rawSlug: 'Custom Slug',
      ),
      'custom-slug',
    );
    expect(
      buildSlugSeed(uid: 'G4', title: 'Ziyarat e Ashura'),
      'ziyarat-e-ashura',
    );
    expect(buildSlugSeed(uid: 'G4', title: '!!!'), 'g4');
  });

  test('makeUniqueSlug appends suffixes for collisions', () {
    setLocalSlugData('G4', slug: 'ziyarat-e-ashura');
    setLocalSlugData('G5', slug: 'ziyarat-e-ashura-2');

    expect(makeUniqueSlug('Ziyarat e Ashura'), 'ziyarat-e-ashura-3');
    expect(
      makeUniqueSlug('Ziyarat e Ashura', currentUid: 'G4'),
      'ziyarat-e-ashura',
    );
  });

  test('aliases are normalized, deduplicated, and removed with owner', () {
    setLocalSlugData(
      'G4',
      slug: 'ziyarat-e-ashura',
      aliases: ['Old Ashura', 'old_ashura', 'Ziyarat e Ashura', ' '],
    );

    expect(itemSlugs['G4'], 'ziyarat-e-ashura');
    expect(itemSlugAliases['G4'], ['old-ashura']);
    expect(slugToItemUid['ziyarat-e-ashura'], 'G4');
    expect(slugToItemUid['old-ashura'], 'G4');

    removeLocalSlugData('G4');

    expect(itemSlugs.containsKey('G4'), isFalse);
    expect(itemSlugAliases.containsKey('G4'), isFalse);
    expect(slugToItemUid.containsKey('ziyarat-e-ashura'), isFalse);
    expect(slugToItemUid.containsKey('old-ashura'), isFalse);
  });

  test('applySlugLookupMap ignores unknown uids and empty slugs', () {
    applySlugLookupMap(
      {
        'Ashura': 'G4',
        'Waritha': 'G6',
        'Unknown': 'X9',
        ' ': 'G4',
      },
      {'G4', 'G6'},
    );

    expect(slugToItemUid, {
      'ashura': 'G4',
      'waritha': 'G6',
    });
  });
}
