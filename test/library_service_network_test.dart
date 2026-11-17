import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shia_companion/services/library_service.dart';

/// The library's chapters come from GitHub. A connection that stalls rather
/// than fails must end in the reader's error and Retry, not a spinner that
/// stays up for as long as the platform takes to give up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // An empty documents directory: no book is saved for offline reading.
    final documents = Directory.systemTemp.createTempSync('library_test');
    addTearDown(() => documents.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => documents.path,
        );
  });

  tearDown(() {
    LibraryService.requestTimeout = const Duration(seconds: 20);
  });

  test('a chapter that never arrives fails instead of loading forever', () {
    LibraryService.requestTimeout = const Duration(milliseconds: 50);
    final stalled = MockClient((_) => Completer<http.Response>().future);

    return http.runWithClient(() async {
      await expectLater(
        LibraryService.loadChapterMarkdown('a-book/stalled-chapter'),
        throwsA(isA<LibraryLoadException>()),
      );
    }, () => stalled);
  });

  test('a book whose chapter list never arrives fails too', () {
    LibraryService.requestTimeout = const Duration(milliseconds: 50);
    final stalled = MockClient((_) => Completer<http.Response>().future);

    return http.runWithClient(() async {
      await expectLater(
        LibraryService.loadChapters('a-stalled-book'),
        throwsA(isA<LibraryLoadException>()),
      );
    }, () => stalled);
  });

  test('opening a chapter being prefetched waits for that request', () {
    var requests = 0;
    final answer = Completer<http.Response>();
    final client = MockClient((_) {
      requests++;
      return answer.future;
    });

    return http.runWithClient(() async {
      final prefetch = LibraryService.prefetchChapterMarkdown('a-book/next');
      // Past the offline-copy lookup, so the prefetch's request is out.
      for (var i = 0; requests == 0 && i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(requests, 1);
      final open = LibraryService.loadChapterMarkdown('a-book/next');
      // And the second load past that lookup too, before the answer lands.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      answer.complete(http.Response('# Next', 200));

      expect(await open, '# Next');
      await prefetch;
      expect(requests, 1);
    }, () => client);
  });
}
