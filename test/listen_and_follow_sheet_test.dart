import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/quran/listen_and_follow_sheet.dart';
import 'package:shia_companion/services/recitation_recognizer.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_text_index.dart';

class _DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

/// A recogniser with no microphone behind it, so the sheet can be driven
/// through every one of its states in a test.
class _FakeRecognizer implements RecitationRecognizer {
  _FakeRecognizer({
    this.availability = RecognizerAvailability.ready,
    this.transcripts = const [],
    this.error,
  });

  final RecognizerAvailability availability;
  final List<String> transcripts;
  final Object? error;

  var stopped = false;

  @override
  bool get ranOnDevice => true;

  @override
  Future<RecognizerAvailability> ensureAvailable() async => availability;

  @override
  Stream<RecitationTranscript> listen() async* {
    for (var i = 0; i < transcripts.length; i++) {
      yield RecitationTranscript(
        text: transcripts[i],
        isFinal: i == transcripts.length - 1,
      );
    }
    if (error != null) throw error!;
  }

  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  late QuranTextIndex index;

  setUpAll(() async {
    resetQuranTextIndexCache();
    // Warms the process-wide cache, so the sheet's own load resolves from it
    // and the test is not timing an isolate.
    index = await loadQuranTextIndex(_DiskAssetBundle());
  });

  setUp(() {
    items = {
      for (var surah = 1; surah <= surahCount; surah++)
        uidForSurah(surah)!: '$surah: Surah$surah اسم',
    };
  });

  tearDown(() => items = {});

  String arabicOf(VerseKey verse) => index.verses[index.indexOf(verse)!].arabic;

  /// Opens the sheet and reports what it popped with.
  Future<VerseKey?> openSheet(
    WidgetTester tester,
    _FakeRecognizer recognizer, {
    VerseKey? readingAt,
  }) async {
    VerseKey? result;
    var popped = false;

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DiskAssetBundle(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showListenAndFollowSheet(
                    context,
                    readingAt: readingAt,
                    recognizer: recognizer,
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(popped || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue);
    return result;
  }

  testWidgets('jumps straight there when the verse is unmistakable',
      (tester) async {
    final recognizer = _FakeRecognizer(
      transcripts: [arabicOf(const VerseKey(2, 255))],
    );

    final result = await openSheet(tester, recognizer);

    expect(result, isNotNull);
    expect(result!.surah, 2);
    expect(result.ayah, 255);
    // Nothing is left listening once the sheet is gone.
    expect(recognizer.stopped, isTrue);
  });

  testWidgets('asks which one when the verse repeats verbatim',
      (tester) async {
    final recognizer = _FakeRecognizer(
      transcripts: [arabicOf(const VerseKey(55, 13))],
    );

    final result = await openSheet(tester, recognizer);

    expect(result, isNull, reason: 'it must not guess between 31 twins');
    expect(find.text('Which verse was it?'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('a chosen candidate is what the sheet returns', (tester) async {
    final recognizer = _FakeRecognizer(
      transcripts: [arabicOf(const VerseKey(55, 13))],
    );
    VerseKey? result;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DiskAssetBundle(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => result =
                    await showListenAndFollowSheet(context, recognizer: recognizer),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.surah, 55);
  });

  testWidgets('says so when nothing recognisable came through', (tester) async {
    final recognizer = _FakeRecognizer(transcripts: const ['مرحبا']);

    final result = await openSheet(tester, recognizer);

    expect(result, isNull);
    expect(find.textContaining('Try again'), findsWidgets);
  });

  testWidgets('explains a refused microphone rather than failing silently',
      (tester) async {
    final recognizer = _FakeRecognizer(
      availability: RecognizerAvailability.permissionDenied,
    );

    await openSheet(tester, recognizer);

    expect(find.textContaining('microphone access'), findsOneWidget);
  });

  testWidgets('explains a device with no Arabic recognition', (tester) async {
    final recognizer = _FakeRecognizer(
      availability: RecognizerAvailability.noArabicLocale,
    );

    await openSheet(tester, recognizer);

    expect(find.textContaining('no Arabic speech recognition'), findsOneWidget);
  });

  testWidgets('recovers from the recogniser erroring out', (tester) async {
    final recognizer = _FakeRecognizer(
      transcripts: const ['قل'],
      error: const RecitationRecognizerException('engine died'),
    );

    await openSheet(tester, recognizer);

    expect(find.text('Try again'), findsOneWidget);
  });
}
