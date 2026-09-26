import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import 'package:shia_companion/services/audio_download_store.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  final store = AudioDownloadStore.instance;

  /// Bytes the test server sends for [name]: sizes differ per file so
  /// byte-weighted progress is actually exercised.
  int sizeFor(String name) => 1000 * name.length;

  ZikrAudioTrack track(String name) =>
      ZikrAudioTrack(url: 'http://127.0.0.1:${server.port}/$name');

  /// Waits for every queued download to finish, however it ends.
  Future<void> settle(List<ZikrAudioTrack> tracks) async {
    while (store.anyDownloading(tracks)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('audio_download_test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      final name = request.uri.pathSegments.last;
      final response = request.response;
      if (name.startsWith('missing')) {
        response.statusCode = HttpStatus.notFound;
      } else {
        response.contentLength = sizeFor(name);
        if (request.method != 'HEAD') {
          response.add(List.filled(sizeFor(name), 7));
        }
      }
      response.close();
    });
    await store.useDirectoryForTest(dir);
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  test('saves a track under its bucket file name and plays it from disk',
      () async {
    final kumayl = track('dua_kumayl_96k.mp3');
    expect(store.isDownloaded(kumayl), isFalse);
    expect(store.sourceUri(kumayl), Uri.parse(kumayl.url));

    await store.download([kumayl]);
    await settle([kumayl]);

    final file = File('${dir.path}/dua_kumayl_96k.mp3');
    expect(store.isDownloaded(kumayl), isTrue);
    expect(await file.length(), sizeFor('dua_kumayl_96k.mp3'));
    expect(store.sizeOf(kumayl), sizeFor('dua_kumayl_96k.mp3'));
    expect(store.sourceUri(kumayl), Uri.file(file.path));
    expect(dir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
  });

  test('downloads a whole playlist and reports it once, by name', () async {
    final tracks = [track('a.mp3'), track('bb.mp3'), track('ccc.mp3')];
    final result = store.results.first;
    await store.download(tracks, label: 'Morning');
    expect(store.anyDownloading(tracks), isTrue);
    await settle(tracks);

    expect(store.allDownloaded(tracks), isTrue);
    expect(store.overallProgress(tracks), 1);
    expect(store.savedBytesOf(tracks),
        sizeFor('a.mp3') + sizeFor('bb.mp3') + sizeFor('ccc.mp3'));

    final reported = await result;
    expect(reported.label, 'Morning');
    expect(reported.succeeded, isTrue);
    expect(reported.saved, 3);
  });

  test('asks the bucket for sizes up front, for the button to show',
      () async {
    final tracks = [track('a.mp3'), track('bb.mp3')];
    expect(store.bytesToDownload(tracks), isNull);

    await store.fetchSizes(tracks);

    expect(store.bytesToDownload(tracks), sizeFor('a.mp3') + sizeFor('bb.mp3'));
  });

  test('progress is weighted by size once sizes are known', () async {
    final small = track('a.mp3');
    final large = track('a_much_longer_name.mp3');
    await store.fetchSizes([small, large]);
    await store.download([small]);
    await settle([small]);

    final expected = sizeFor('a.mp3') /
        (sizeFor('a.mp3') + sizeFor('a_much_longer_name.mp3'));
    expect(store.overallProgress([small, large]), closeTo(expected, 0.001));
    expect(store.bytesToDownload([small, large]),
        sizeFor('a_much_longer_name.mp3'));
  });

  test('a missing file fails cleanly, is marked for retry, and is reported',
      () async {
    final gone = track('missing.mp3');
    final ok = track('ok.mp3');
    final result = store.results.first;
    await store.download([ok, gone], label: 'Friday');
    await settle([ok, gone]);

    expect(store.isDownloaded(gone), isFalse);
    expect(store.anyFailed([gone]), isTrue);
    expect(store.failureOf([gone]), AudioDownloadFailure.unavailable);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['ok.mp3']);

    final reported = await result;
    expect(reported.succeeded, isFalse);
    expect(reported.saved, 1);
    expect(reported.failed, 1);
    expect(reported.failure, AudioDownloadFailure.unavailable);
  });

  test('an unreachable server is a network failure', () async {
    final port = server.port;
    await server.close(force: true);
    final offline = ZikrAudioTrack(url: 'http://127.0.0.1:$port/a.mp3');

    await store.download([offline]);
    await settle([offline]);

    expect(store.failureOf([offline]), AudioDownloadFailure.network);
    // Rebind so tearDown has a server to close.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  test('cancelling a queued download drops it without a report', () async {
    final first = track('first.mp3');
    final second = track('second.mp3');
    var reports = 0;
    final sub = store.results.listen((_) => reports++);

    await store.download([first]);
    await store.download([second]);
    store.cancel([second]);
    expect(store.isDownloading(second), isFalse);
    await settle([first, second]);
    await Future<void>.delayed(Duration.zero);

    expect(store.isDownloaded(first), isTrue);
    expect(store.isDownloaded(second), isFalse);
    expect(store.anyFailed([second]), isFalse);
    expect(reports, 1, reason: 'only the first download finished');
    await sub.cancel();
  });

  test('remove deletes the file so the track streams again', () async {
    final ahad = track('dua_ahad.mp3');
    await store.download([ahad]);
    await settle([ahad]);
    await store.remove([ahad]);

    expect(store.isDownloaded(ahad), isFalse);
    expect(store.sourceUri(ahad), Uri.parse(ahad.url));
    expect(dir.listSync(), isEmpty);
  });

  test('removeAll clears every saved file, even ones no zikr names', () async {
    await File('${dir.path}/renamed_since.mp3').writeAsString('old');
    await store.useDirectoryForTest(dir);
    final ahad = track('dua_ahad.mp3');
    await store.download([ahad]);
    await settle([ahad]);
    expect(store.totalSavedBytes, greaterThan(0));

    await store.removeAll();

    expect(store.totalSavedBytes, 0);
    expect(store.savedFileNames, isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test('picks up files saved in an earlier session, dropping partial ones',
      () async {
    await File('${dir.path}/old.mp3').writeAsString('xyz');
    await File('${dir.path}/half.mp3.part').writeAsString('x');
    await store.useDirectoryForTest(dir);

    expect(store.isDownloaded(track('old.mp3')), isTrue);
    expect(store.sizeOf(track('old.mp3')), 3);
    expect(store.isDownloaded(track('half.mp3')), isFalse);
    expect(File('${dir.path}/half.mp3.part').existsSync(), isFalse);
  });

  test('file names are made safe for the file system', () {
    expect(
      AudioDownloadStore.fileNameFor(
          const ZikrAudioTrack(url: '${zikrAudioBaseUrl}dua%20(1)%3A.mp3')),
      'dua__1__.mp3',
    );
  });

  test('sizes read the way a storage screen shows them', () {
    expect(formatAudioBytes(900), '1 KB');
    expect(formatAudioBytes(5 * 1024 * 1024 + 300 * 1024), '5.3 MB');
    expect(formatAudioBytes(250 * 1024 * 1024), '250 MB');
    expect(formatAudioBytes(3 * 1024 * 1024 * 1024 ~/ 2), '1.5 GB');
  });
}
