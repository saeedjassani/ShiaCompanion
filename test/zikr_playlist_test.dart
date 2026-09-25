import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/playlists_page.dart';
import 'package:shia_companion/services/exclusive_audio.dart';
import 'package:shia_companion/services/playlist_audio_service.dart';
import 'package:shia_companion/services/zikr_playlist_store.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

Future<void> _freshStore([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  await SP.init();
  ZikrPlaylistStore.instance.resetForTest();
}

void main() {
  group('ZikrPlaylistStore', () {
    setUp(_freshStore);

    test('creates, renames and deletes, persisting each change', () async {
      final store = ZikrPlaylistStore.instance;
      final morning = await store.create('  Morning ', zikrUids: ['E18', 'G4']);
      expect(morning.name, 'Morning');
      expect(morning.zikrUids, ['E18', 'G4']);

      await store.rename(morning.id, 'Fajr');
      store.resetForTest();
      expect(store.playlists.single.name, 'Fajr',
          reason: 'survives a reload from storage');

      await store.delete(morning.id);
      store.resetForTest();
      expect(store.playlists, isEmpty);
    });

    test('adds each zikr once, removes and reorders', () async {
      final store = ZikrPlaylistStore.instance;
      final playlist = await store.create('Morning');
      await store.addZikr(playlist.id, 'E18');
      await store.addZikr(playlist.id, 'G4');
      await store.addZikr(playlist.id, 'E18');
      await store.addZikr(playlist.id, 'E31');
      expect(store.byId(playlist.id)!.zikrUids, ['E18', 'G4', 'E31']);

      await store.move(playlist.id, 2, 0);
      expect(store.byId(playlist.id)!.zikrUids, ['E31', 'E18', 'G4']);
      await store.move(playlist.id, 0, 2);
      expect(store.byId(playlist.id)!.zikrUids, ['E18', 'G4', 'E31']);

      await store.removeAt(playlist.id, 1);
      expect(store.byId(playlist.id)!.zikrUids, ['E18', 'E31']);
    });

    test('ignores unreadable storage rather than throwing', () async {
      await _freshStore({ZikrPlaylistStore.storageKey: 'not json'});
      expect(ZikrPlaylistStore.instance.playlists, isEmpty);
    });
  });

  group('PlaylistAudioService.buildQueue', () {
    test('queues every track of every zikr in order, skipping silent ones', () {
      final queue = PlaylistAudioService.buildQueue(
        ['E18', 'I24', 'MISSING', 'F11'],
        {
          'E18': {
            'title': 'Dua e Ahad',
            'audio': [
              {'url': 'https://example.com/ahad.mp3'},
            ],
          },
          'I24': {'title': 'Etiquettes of Bedtime'},
          'MISSING': null,
          'F11': {
            'title': 'Namaz of Jafar-e-Tayyaar',
            'audio': [
              {'url': 'https://example.com/salat.mp3', 'label': 'Salat'},
              {'url': 'https://example.com/dua.mp3', 'label': 'Dua after'},
            ],
          },
        },
      );

      expect(queue.map((entry) => entry.zikrUid), ['E18', 'F11', 'F11']);
      expect(queue.map((entry) => entry.title),
          ['Dua e Ahad', 'Salat', 'Dua after']);
    });

    test('a playlist with nothing playable does not start', () async {
      final service = PlaylistAudioService.instance;
      service.loadDocument = (uid) async => {'title': uid};
      await _freshStore();
      final playlist = await ZikrPlaylistStore.instance
          .create('Silent', zikrUids: ['I24']);
      expect(await service.play(playlist), isFalse);
      expect(service.isActive, isFalse);
    });
  });

  group('ExclusiveAudio', () {
    test('releases the previous owner before the new one proceeds', () async {
      final a = Object();
      final b = Object();
      final events = <String>[];

      await ExclusiveAudio.claim(a, () async => events.add('a released'));
      await ExclusiveAudio.claim(b, () async => events.add('b released'));
      events.add('b loads');
      expect(events, ['a released', 'b loads']);
      expect(ExclusiveAudio.isOwnedBy(b), isTrue);

      // A stale relinquish from the old owner must not clear the new claim.
      ExclusiveAudio.relinquish(a);
      expect(ExclusiveAudio.isOwnedBy(b), isTrue);
      ExclusiveAudio.relinquish(b);
      expect(ExclusiveAudio.isOwnedBy(b), isFalse);
    });
  });

  test('the index flags exactly the zikrs whose content has audio', () {
    final index =
        jsonDecode(File('assets/zikr.json').readAsStringSync()) as Map;
    final flagged = <String>{
      for (final entry in index.entries)
        if (entry.value is Map && (entry.value as Map)['audio'] == true)
          entry.key as String,
    };
    final withAudio = <String>{
      for (final file in Directory('assets/zikr').listSync().whereType<File>())
        if (((jsonDecode(file.readAsStringSync()) as Map)['audio'] as List?)
                ?.isNotEmpty ??
            false)
          file.uri.pathSegments.last,
    };
    expect(flagged, withAudio,
        reason: 'run scripts/apply_duas_audio.js to resync the flags');
  });

  group('pages', () {
    setUp(() async {
      await _freshStore();
      items = {'E18': 'Dua e Ahad', 'G4': 'Ziyarat Ashura', 'E31': 'Kumayl'};
      audioZikrUids = {'E18', 'G4', 'E31'};
    });

    testWidgets('the playlists page invites a first playlist', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      expect(find.textContaining('Make a playlist'), findsOneWidget);
      expect(find.text('New playlist'), findsOneWidget);
    });

    testWidgets('lists playlists with a play button each', (tester) async {
      await ZikrPlaylistStore.instance
          .create('Morning', zikrUids: ['E18', 'G4']);
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('2 recitations'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('the picker ticks recitations into the playlist',
        (tester) async {
      final playlist =
          await ZikrPlaylistStore.instance.create('Morning', zikrUids: ['G4']);
      await tester.pumpWidget(
          MaterialApp(home: AddRecitationsPage(playlistId: playlist.id)));

      await tester.tap(find.text('Dua e Ahad'));
      await tester.pump();
      expect(ZikrPlaylistStore.instance.byId(playlist.id)!.zikrUids,
          ['G4', 'E18']);

      await tester.tap(find.text('Ziyarat Ashura'));
      await tester.pump();
      expect(ZikrPlaylistStore.instance.byId(playlist.id)!.zikrUids, ['E18']);
    });

    testWidgets('the detail page shows the queue in order', (tester) async {
      final playlist = await ZikrPlaylistStore.instance
          .create('Morning', zikrUids: ['E18', 'G4']);
      await tester.pumpWidget(
          MaterialApp(home: PlaylistDetailPage(playlistId: playlist.id)));
      expect(find.text('Play all'), findsOneWidget);
      final ahad = tester.getTopLeft(find.text('Dua e Ahad'));
      final ashura = tester.getTopLeft(find.text('Ziyarat Ashura'));
      expect(ahad.dy, lessThan(ashura.dy));
    });
  });
}
