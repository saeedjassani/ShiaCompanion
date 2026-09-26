import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import 'package:shia_companion/services/audio_download_store.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  final store = AudioDownloadStore.instance;

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
      if (name.startsWith('missing')) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.add(List.filled(4096, name.length));
      }
      request.response.close();
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
    expect(await file.length(), 4096);
    expect(store.sourceUri(kumayl), Uri.file(file.path));
    expect(dir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
  });

  test('downloads a whole playlist and reports it all saved', () async {
    final tracks = [track('a.mp3'), track('b.mp3'), track('c.mp3')];
    await store.download(tracks);
    expect(store.anyDownloading(tracks), isTrue);
    await settle(tracks);

    expect(store.allDownloaded(tracks), isTrue);
    expect(store.overallProgress(tracks), 1);
  });

  test('a failed download leaves nothing behind and is marked for retry',
      () async {
    final gone = track('missing.mp3');
    await store.download([gone]);
    await settle([gone]);

    expect(store.isDownloaded(gone), isFalse);
    expect(store.anyFailed([gone]), isTrue);
    expect(dir.listSync(), isEmpty);
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

  test('picks up files saved in an earlier session, dropping partial ones',
      () async {
    await File('${dir.path}/old.mp3').writeAsString('x');
    await File('${dir.path}/half.mp3.part').writeAsString('x');
    await store.useDirectoryForTest(dir);

    expect(store.isDownloaded(track('old.mp3')), isTrue);
    expect(store.isDownloaded(track('half.mp3')), isFalse);
  });

  test('file names are made safe for the file system', () {
    expect(
      AudioDownloadStore.fileNameFor(
          ZikrAudioTrack(url: '${zikrAudioBaseUrl}dua%20(1)%3A.mp3')),
      'dua__1__.mp3',
    );
  });
}
