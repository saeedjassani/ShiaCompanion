import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import 'package:shia_companion/pages/downloaded_audio_page.dart';
import 'package:shia_companion/services/audio_download_store.dart';
import 'package:shia_companion/services/zikr_audio_index.dart';
import 'package:shia_companion/widgets/audio_download_button.dart';

void main() {
  late Directory dir;
  final store = AudioDownloadStore.instance;

  ZikrAudioTrack track(String name) =>
      ZikrAudioTrack(url: '$zikrAudioBaseUrl$name');

  Future<void> useDir(WidgetTester tester, List<String> saved) async {
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('audio_download_button');
      for (final name in saved) {
        await File('${dir.path}/$name').writeAsBytes(List.filled(2048, 1));
      }
      await store.useDirectoryForTest(dir);
    });
    addTearDown(() => dir.deleteSync(recursive: true));
  }

  Widget host(Widget child) => MaterialApp(
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('offers to download what is not saved yet', (tester) async {
    await useDir(tester, const []);
    await tester.pumpWidget(host(AudioDownloadButton(
      tracks: [track('a.mp3'), track('b.mp3')],
      labelled: true,
    )));

    expect(find.text('Download all'), findsOneWidget);
  });

  testWidgets('offline, a tap explains instead of starting', (tester) async {
    await useDir(tester, const []);
    await tester
        .pumpWidget(host(AudioDownloadButton(tracks: [track('a.mp3')])));

    // There is no connectivity plugin under test, which reads as offline.
    await tester.runAsync(() async {
      await tester.tap(find.byType(IconButton));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(store.anyDownloading([track('a.mp3')]), isFalse);
  });

  testWidgets('says how much is left when part of a playlist is saved',
      (tester) async {
    await useDir(tester, const ['a.mp3']);
    await tester.pumpWidget(host(AudioDownloadButton(
      tracks: [track('a.mp3'), track('b.mp3'), track('c.mp3')],
      labelled: true,
    )));

    expect(find.text('Download 2 more'), findsOneWidget);
  });

  testWidgets('once saved, a tap offers to remove it and frees the space',
      (tester) async {
    await useDir(tester, const ['a.mp3']);
    await tester.pumpWidget(host(AudioDownloadButton(
      tracks: [track('a.mp3')],
      label: 'Dua Kumayl',
      labelled: true,
    )));
    expect(find.text('Downloaded'), findsOneWidget);

    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();
    expect(find.text('Remove download?'), findsOneWidget);
    expect(find.textContaining('Frees 2 KB'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The saved-state flips at once; the file itself goes with real I/O,
    // which the store tests cover.
    expect(store.isDownloaded(track('a.mp3')), isFalse);
    expect(find.text('Remove download?'), findsNothing);
  });

  group('the Downloads page', () {
    setUp(() {
      items = {'E31': 'Dua Kumayl', 'E18': 'Dua e Ahad'};
      ZikrAudioIndex.instance.setForTest(ZikrAudioIndex.parse({
        'E31': [
          {'file': 'kumayl.mp3'},
        ],
        'E18': [
          {'file': 'ahad.mp3'},
        ],
      }));
    });

    testWidgets('explains itself when nothing is saved', (tester) async {
      await useDir(tester, const []);
      await tester.pumpWidget(host(const DownloadedAudioPage()));
      // The store's load future was completed outside the test zone, so its
      // listeners need a real turn of the event loop.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.text('No downloads yet'), findsOneWidget);
    });

    testWidgets('lists what is saved, its size, and older leftovers',
        (tester) async {
      await useDir(tester, const ['kumayl.mp3', 'renamed_since.mp3']);
      await tester.pumpWidget(host(const DownloadedAudioPage()));
      // The store's load future was completed outside the test zone, so its
      // listeners need a real turn of the event loop.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.text('Dua Kumayl'), findsOneWidget);
      expect(find.text('Dua e Ahad'), findsNothing,
          reason: 'not downloaded, so not listed');
      expect(find.text('2 KB'), findsOneWidget);
      expect(find.text('Older recordings'), findsOneWidget);
      expect(find.text('4 KB used on this device'), findsOneWidget);
      expect(find.text('Remove all'), findsOneWidget);
    });
  });

  group('the finished-download message', () {
    Future<void> show(WidgetTester tester, AudioDownloadResult result) async {
      await tester.pumpWidget(host(const SizedBox()));
      showAudioDownloadResult(result);
      await tester.pump();
    }

    testWidgets('names what finished', (tester) async {
      await show(
          tester,
          AudioDownloadResult(
              label: 'Morning', tracks: [track('a.mp3')], saved: 1, failed: 0));
      expect(find.text('Morning downloaded - plays without a connection'),
          findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a dropped connection says how far it got, with Retry',
        (tester) async {
      await show(
          tester,
          AudioDownloadResult(
            label: 'Morning',
            tracks: [track('a.mp3'), track('b.mp3'), track('c.mp3')],
            saved: 2,
            failed: 1,
            failure: AudioDownloadFailure.network,
          ));
      expect(
          find.text('Downloaded 2 of 3. Check your connection and try again.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a full device says so', (tester) async {
      await show(
          tester,
          AudioDownloadResult(
            label: 'Dua Kumayl',
            tracks: [track('a.mp3')],
            saved: 0,
            failed: 1,
            failure: AudioDownloadFailure.storage,
          ));
      expect(
          find.textContaining("Couldn't download Dua Kumayl"), findsOneWidget);
      expect(find.textContaining('out of space'), findsOneWidget);
    });
  });
}
