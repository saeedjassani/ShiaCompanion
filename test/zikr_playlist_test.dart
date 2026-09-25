import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/playlists_page.dart';
import 'package:shia_companion/services/exclusive_audio.dart';
import 'package:shia_companion/services/playlist_audio_service.dart';
import 'package:shia_companion/services/zikr_audio_index.dart';
import 'package:shia_companion/services/zikr_playlist_store.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// A store with [values] in storage and, unless a test says otherwise, the
/// starter playlists already handed out - so it starts empty.
Future<void> _freshStore([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(
      {ZikrPlaylistStore.seededKey: true, ...values});
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

  group('starter playlists', () {
    test('a first run gets Morning, Thursday and Friday', () async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      final store = ZikrPlaylistStore.instance..resetForTest();

      expect(store.playlists.map((playlist) => playlist.name),
          ['Morning', 'Thursday', 'Friday']);
      expect(
          store.byId('default-morning')!.zikrUids, ['E18', 'G4', 'G1', 'G13']);
    });

    test('are added alongside playlists the reader already made', () async {
      await _freshStore();
      await ZikrPlaylistStore.instance.create('Mine');
      final stored = SP.prefs.getString(ZikrPlaylistStore.storageKey)!;

      SharedPreferences.setMockInitialValues(
          {ZikrPlaylistStore.storageKey: stored});
      await SP.init();
      final store = ZikrPlaylistStore.instance..resetForTest();
      expect(store.playlists.map((playlist) => playlist.name),
          ['Mine', 'Morning', 'Thursday', 'Friday']);
    });

    test('a deleted starter playlist stays deleted', () async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      final store = ZikrPlaylistStore.instance..resetForTest();
      await store.delete('default-thursday');

      store.resetForTest();
      expect(store.playlists.map((playlist) => playlist.name),
          ['Morning', 'Friday']);
    });

    test('hold only zikrs that have a recording', () {
      final audio =
          jsonDecode(File(ZikrAudioIndex.assetPath).readAsStringSync()) as Map;
      for (final playlist in ZikrPlaylistStore.defaultPlaylists) {
        for (final uid in playlist.zikrUids) {
          expect(audio.containsKey(uid), isTrue,
              reason: '${playlist.name}: $uid has no audio');
        }
      }
    });
  });

  group('PlaylistAudioService.buildQueue', () {
    test('queues every track of every zikr in order, skipping silent ones', () {
      final audio = ZikrAudioIndex.parse({
        'E18': [
          {'file': 'ahad.mp3', 'reciter': 'Ali Fani'},
        ],
        'F11': [
          {'file': 'salat.mp3', 'label': 'Salat'},
          {'file': 'dua.mp3', 'label': 'Dua after'},
        ],
      });
      final queue = PlaylistAudioService.buildQueue(
        ['E18', 'I24', 'MISSING', 'F11'],
        tracksFor: (uid) => audio[uid] ?? const [],
        titleFor: (uid) => uid == 'E18' ? 'Dua e Ahad' : uid,
      );

      expect(queue.map((entry) => entry.zikrUid), ['E18', 'F11', 'F11']);
      expect(queue.map((entry) => entry.title),
          ['Dua e Ahad', 'Salat', 'Dua after']);
      expect(queue.map((entry) => entry.track.artist),
          ['Ali Fani', 'Shia Companion', 'Shia Companion']);
    });

    test('a playlist with nothing playable does not start', () async {
      final service = PlaylistAudioService.instance;
      ZikrAudioIndex.instance.setForTest(const {});
      await _freshStore();
      final playlist =
          await ZikrPlaylistStore.instance.create('Silent', zikrUids: ['I24']);
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

  group('pages', () {
    setUp(() async {
      await _freshStore();
      items = {'E18': 'Dua e Ahad', 'G4': 'Ziyarat Ashura', 'E31': 'Kumayl'};
      ZikrAudioIndex.instance.setForTest(ZikrAudioIndex.parse({
        for (final uid in ['E18', 'G4', 'E31'])
          uid: [
            {'file': '$uid.mp3'},
          ],
      }));
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
