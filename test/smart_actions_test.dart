import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/zikr_playlist.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/services/smart_actions_service.dart';
import 'package:shia_companion/utils/spoken_match.dart';

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

  group('spokenMatchScore', () {
    int score(String query, List<String> names) =>
        spokenMatchScore(query, names).score;

    test('ranks the same words over a prefix over a run-together match', () {
      expect(score('Dua Kumayl', ['Dua Kumayl']), 3);
      expect(score('kumayl', ['Dua Kumayl']), 2);
      expect(score('yasin', ['Surah Ya-Sin']), 1);
      expect(score('kumayl', ['Ziyarat Ashura']), 0);
    });

    test('ignores case, accents, apostrophes and filler words', () {
      expect(score("the Amir al-Mu'minin", ['Munajat Amir al-Muminin']), 2);
      expect(score('ṣalāt', ['Salat']), 3);
      expect(score('my Thursday Night', ['Thursday Night']), 3);
      // Filler is all there was: it is what was asked for.
      expect(score('the', ['The']), 3);
    });

    test('prefers the name with fewest words left unsaid', () {
      final best = bestSpokenMatch(
        'kumayl',
        ['Dua Kumayl (Night of 15th Shaban)', 'Dua Kumayl'],
        (name) => [name],
      );
      expect(best!.entry, 'Dua Kumayl');
    });
  });

  group('matching what Assistant heard', () {
    final catalog = SmartActionsService.buildCatalog(
      playlists: const [
        (
          id: 'default-thursday',
          name: 'Thursday Night',
          displayName: 'Thursday Night'
        ),
        (id: 'p2', name: 'Kumayl Nights', displayName: 'Kumayl Nights'),
      ],
      titles: const {
        'E31': 'Dua Kumayl دعاء كميل',
        'AC5|E31': 'Dua Kumayl (Night of 15th Shaban)',
        'A40': '36: Ya-Sin يس',
        'G4': 'Ziyarat Ashura',
      },
      displayTitle: (uid, title) => title,
      slugFor: (uid) => uid == 'E31' ? 'dua-kumayl' : null,
      slugAliasesFor: (uid) => uid == 'E31' ? const ['dua-kumail'] : const [],
      hasAudio: (uid) => uid != 'G4',
    );

    test('finds a dua by an old spelling, and a surah run together', () {
      expect(
          SmartActionsService.matchZikr('kumail', catalog['zikrs']!)!
              .entry['id'],
          'E31');
      expect(
          SmartActionsService.matchZikr('yasin', catalog['zikrs']!)!
              .entry['id'],
          'A40');
    });

    test('plays only a dua with a recitation', () {
      expect(
          SmartActionsService.matchZikr('ziyarat ashura', catalog['zikrs']!,
              recitedOnly: true),
          isNull);
      expect(
          SmartActionsService.matchZikr('ziyarat ashura', catalog['zikrs']!)!
              .entry['id'],
          'G4');
    });

    test('finds a playlist without the word playlist', () {
      expect(
          SmartActionsService.matchPlaylist(
                  'Thursday Night playlist', catalog['playlists']!)!
              .entry['id'],
          'default-thursday');
    });
  });

  group('matchFeature', () {
    String? feature(String name) =>
        SmartActionsService.matchFeature(name, visibleHomeMenuItems)
            ?.entry
            .analyticsId;

    test('takes the id a static shortcut sends', () {
      expect(feature('calendar_prayer_times'), 'calendar_prayer_times');
    });

    test('knows what people call a feature', () {
      expect(feature('prayer times'), 'calendar_prayer_times');
      expect(feature('qibla'), 'qibla_finder');
      expect(feature('tasbih'), 'tasbeeh_counter');
      expect(feature('Quran'), 'quran');
    });

    test('every keyword names a feature that exists', () {
      final ids = {
        for (final item in [...homeMenuItems, quranMenuItem]) item.analyticsId
      };
      expect(SmartActionsService.featureKeywords.keys.toSet().difference(ids),
          isEmpty);
    });
  });

  group('Android shortcuts', () {
    test('a playlist shortcut plays the playlist', () {
      final shortcut = SmartActionsService.playlistShortcut(ZikrPlaylist(
        id: 'p1',
        name: 'Mine',
        zikrUids: const [],
        updatedAt: DateTime(2026),
      ));
      expect(shortcut, {
        'id': 'playlist:p1',
        'kind': 'playlist',
        'label': 'Mine',
        'link': 'https://shiacompanion.app/playlist/p1',
      });
    });

    test('a zikr shortcut is labelled and keyed as the catalog has it', () {
      const titles = {
        'E31': 'Dua Kumayl دعاء كميل',
        'AC4|E31': 'Dua Kumayl دعاء كميل',
        'AC5|E31': 'Dua Kumayl (Night of 15th Shaban)',
        'AA~Z8': 'Mahe Ramazan',
      };
      Map<String, String>? shortcut(String uid) =>
          SmartActionsService.zikrShortcut(
            uid,
            titles: titles,
            displayTitle: (uid, title) => title,
            slugFor: (uid) => uid == 'E31' ? 'dua-kumayl' : null,
          );

      expect(shortcut('E31'), {
        'id': 'zikr:E31',
        'kind': 'zikr',
        'label': 'Dua Kumayl',
        'link': 'https://shiacompanion.app/zikr/dua-kumayl',
      });
      // An alias repeating its canonical's title is the canonical.
      expect(shortcut('AC4|E31')!['id'], 'zikr:E31');
      expect(shortcut('AC5|E31')!['id'], 'zikr:AC5|E31');
      expect(shortcut('AA~Z8'), isNull);
    });
  });
}
