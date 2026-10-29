import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/smart_actions_service.dart';

void main() {
  group('spokenZikrName', () {
    test('says a surah the way someone asks for it', () {
      expect(SmartActionsService.spokenZikrName('A40', '36: Ya-Sin يس'),
          'Surah Ya-Sin');
    });

    test('drops the Arabic script and keeps the English title', () {
      expect(SmartActionsService.spokenZikrName('E31', 'Dua Kumayl دعاء كميل'),
          'Dua Kumayl');
      expect(SmartActionsService.spokenZikrName('G4', 'Ziyarat Ashura'),
          'Ziyarat Ashura');
    });

    test('leaves nothing for a title that is Arabic only', () {
      expect(SmartActionsService.spokenZikrName('X1', 'دعاء'), '');
    });
  });

  group('buildCatalog', () {
    Map<String, List<Map<String, Object>>> build(Map<String, String> titles) {
      return SmartActionsService.buildCatalog(
        playlists: const [
          (
            id: 'default-thursday',
            name: 'Thursday Night',
            displayName: 'جمعرات کی رات'
          ),
          (id: 'abc', name: 'Mine', displayName: 'Mine'),
        ],
        titles: titles,
        displayTitle: (uid, title) => uid == 'E31' ? 'دعائے کمیل' : title,
        slugFor: (uid) => uid == 'E31' ? 'dua-kumayl' : null,
        slugAliasesFor: (uid) => uid == 'E31' ? const ['dua-kumail'] : const [],
        hasAudio: (uid) => uid == 'E31',
      );
    }

    test('lists playlists by stored name, with the shown name beside it', () {
      final playlists = build(const {})['playlists']!;
      expect(playlists, [
        {
          'id': 'default-thursday',
          'name': 'Thursday Night',
          'subtitle': 'جمعرات کی رات',
        },
        {'id': 'abc', 'name': 'Mine'},
      ]);
    });

    test('describes a zikr with its link, audio and old spellings', () {
      final zikrs = build(const {'E31': 'Dua Kumayl'})['zikrs']!;
      expect(zikrs.single, {
        'id': 'E31',
        'uid': 'E31',
        'name': 'Dua Kumayl',
        'subtitle': 'دعائے کمیل',
        'link': 'https://shiacompanion.app/zikr/dua-kumayl',
        'audio': true,
        'keywords': ['dua kumayl', 'dua kumail'],
      });
    });

    test('skips menus and aliases that only repeat their canonical', () {
      final zikrs = build(const {
        'E31': 'Dua Kumayl',
        'AA~Z8': 'Mahe Ramazan',
        'AC4|E31': 'Dua Kumayl',
        'AC5|E31': 'Dua Kumayl (Night of 15th Shaban)',
      })['zikrs']!;
      expect(zikrs.map((zikr) => zikr['id']), ['E31', 'AC5|E31']);
      expect(zikrs.last['uid'], 'E31');
      expect(zikrs.last['audio'], true);
    });
  });
}
