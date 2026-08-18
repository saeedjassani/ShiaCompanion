import 'dart:io';

import 'dart:ui' as ui;


import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/chapter_page.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/reader_content.dart';

import 'firebase_test_doubles.dart';

/// Drives the reader itself — the real [ChapterPage], not a stand-in for it —
/// over real chapter markdown, turning pages and checking that every line on
/// every page is shown whole.
///
/// Where the pages fall is decided by `paginateColumn` and checked over the
/// same fixtures in `test/library_pagination_test.dart`. What only the reader
/// knows is the width and height it measures at, the style sheet it renders
/// with, and the window it shifts and clips each page into — this test covers
/// that seam, which is where "the last line is cut off" is actually visible.

/// How many pages of a fixture to turn through. Enough to cross several page
/// boundaries — where mis-measured blocks land — without paying to settle a
/// frame for every page of a long chapter.
const int _pagesToWalk = 12;

void main() {
  const bookSlug = 'a-book';

  late Directory documentsDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
    documentsDir = await Directory.systemTemp.createTemp('reader_test');
    PathProviderPlatform.instance = _TempDirPathProvider(documentsDir.path);
  });

  tearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  /// Puts [fixture] where the reader looks for a chapter it has saved for
  /// offline reading, which is the one path into the reader that needs no
  /// network.
  ///
  /// Synchronous on purpose: called from inside a `testWidgets` body, where
  /// async file I/O is handed to a fake-async zone that never completes it.
  void seedChapter(String chapterSlug, String fixture) {
    final file =
        File('${documentsDir.path}/offline_library/$bookSlug/$chapterSlug.md');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      File('test/fixtures/library_chapters/$fixture').readAsStringSync(),
    );
  }

  // Every fixture is paginated end to end by `library_real_chapter_fit_test`.
  // Turning pages through the live reader is far more expensive per page, so
  // this test takes the two fixtures whose constructs broke the page-height
  // model hardest — a numbered list (rows measured beside their marker column)
  // and setext headings (`Title` underlined with `===`) — and walks the first
  // [_pagesToWalk] pages of each.
  const fixtures = <String>['numbered_list.md', 'setext_headings.md'];

  for (final fixture in fixtures) {
    for (final fontSize in <double>[16, 24]) {
      testWidgets('$fixture holds every line at ${fontSize.toInt()}pt',
          (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // LibraryService caches markdown by slug for the life of the process,
        // so each test reads its fixture under a slug of its own.
        final chapterSlug = '${fixture.split('.').first}-${fontSize.toInt()}';
        final chapterPath = '$bookSlug/$chapterSlug';
        seedChapter(chapterSlug, fixture);

        // Warm the service's cache outside the test's fake-async zone: the
        // disk read never completes inside it, and the reader would sit on its
        // spinner for the whole test.
        await tester
            .runAsync(() => LibraryService.loadChapterMarkdown(chapterPath));

        await tester.pumpWidget(MaterialApp(
          home: ChapterPage(
            chapterPath,
            'A Chapter',
            bookSlug: bookSlug,
            chapters: [UidTitleData(chapterSlug, 'A Chapter')],
            chapterIndex: 0,
            initialFontSize: fontSize,
          ),
        ));

        // Resolve the chapter future, then let the post-frame pagination land.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageView), findsOneWidget,
            reason: 'the reader never finished paginating');

        final counter = find.textContaining(RegExp(r'^1 / \d+$'));
        expect(counter, findsOneWidget);
        final totalPages =
            int.parse(tester.widget<Text>(counter).data!.split('/').last.trim());
        expect(totalPages, greaterThan(1),
            reason: 'a fixture that fits on one page tests nothing');

        final pagesToWalk =
            totalPages < _pagesToWalk ? totalPages : _pagesToWalk;

        for (var page = 1; page <= pagesToWalk; page++) {
          // A page is a window onto the chapter's layout, so what it shows is
          // whatever falls inside its clip. Every line has to be wholly in or
          // wholly out of it: a line hanging over either edge is a line the
          // reader sees the top or the bottom half of.
          final windows = tester
              .renderObjectList<RenderBox>(find.descendant(
                of: find.byType(ReaderPageWindow),
                matching: find.byType(ClipRect),
              ))
              .where((box) => box.hasSize && box.size.height > 0)
              .toList();
          expect(windows, isNotEmpty, reason: 'no page is being shown');

          for (final window in windows) {
            var visibleLines = 0;
            var lowestVisible = 0.0;
            for (final line in linesIn(window)) {
              final inside = line.$1 >= -_tolerance &&
                  line.$2 <= window.size.height + _tolerance;
              final outside = line.$2 <= _tolerance ||
                  line.$1 >= window.size.height - _tolerance;
              expect(inside || outside, isTrue,
                  reason: '$fixture at ${fontSize.toInt()}pt: page $page of '
                      '$totalPages shows only part of a line, running '
                      '${line.$1.toStringAsFixed(1)}–'
                      '${line.$2.toStringAsFixed(1)} in a page '
                      '${window.size.height.toStringAsFixed(1)} tall');
              if (inside) {
                visibleLines++;
                if (line.$2 > lowestVisible) lowestVisible = line.$2;
              }
            }
            expect(visibleLines, greaterThan(0),
                reason: 'a page of a chapter should show some text');
            // And it should be a page of text, not a line or two of it with
            // the rest of the page left blank.
            expect(lowestVisible, greaterThan(window.size.height / 2),
                reason: '$fixture at ${fontSize.toInt()}pt: page $page of '
                    '$totalPages runs out of text '
                    '${lowestVisible.toStringAsFixed(1)}px into a page '
                    '${window.size.height.toStringAsFixed(1)} tall');
          }

          if (page < pagesToWalk) {
            // Turn the page by tapping its right-hand edge, as a reader does.
            // The taps carry a rising timestamp: the reader ignores a tap that
            // lands within the double-tap window of the last one, and every
            // synthesised tap otherwise arrives at time zero.
            await tapToTurn(tester, Duration(seconds: page));
            await tester.pumpAndSettle();
            expect(find.text('${page + 1} / $totalPages'), findsOneWidget,
                reason: 'tapping the edge of page $page did not turn it');
          }
        }

        expect(tester.takeException(), isNull);
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }

  testWidgets('changing the font size re-cuts the pages and stays put',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const chapterSlug = 'font-size';
    const chapterPath = '$bookSlug/$chapterSlug';
    seedChapter(chapterSlug, 'numbered_list.md');
    await tester.runAsync(() => LibraryService.loadChapterMarkdown(chapterPath));

    await tester.pumpWidget(MaterialApp(
      home: ChapterPage(
        chapterPath,
        'A Chapter',
        bookSlug: bookSlug,
        chapters: [UidTitleData(chapterSlug, 'A Chapter')],
        chapterIndex: 0,
        initialFontSize: 16,
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Read a few pages in.
    for (var page = 1; page <= 3; page++) {
      await tapToTurn(tester, Duration(seconds: page));
      await tester.pumpAndSettle();
    }
    final before = readCounter(tester);
    expect(before.page, 4);

    // A bigger font means a fresh layout of the whole chapter. It has to
    // settle — a reader that measured at one size and rendered at another
    // would measure again for ever — and it has to keep the reader's place,
    // which can only have moved further into a chapter that now runs longer.
    await tester.tap(find.byTooltip('Increase font size'));
    await tester.pumpAndSettle();

    final after = readCounter(tester);
    expect(after.total, greaterThan(before.total),
        reason: 'a bigger font should take more pages');
    expect(after.page, greaterThanOrEqualTo(before.page),
        reason: 'the reader was dropped back to the start of the chapter');

    // And the pages it produced are still whole pages of whole lines.
    for (final window in tester
        .renderObjectList<RenderBox>(find.descendant(
          of: find.byType(ReaderPageWindow),
          matching: find.byType(ClipRect),
        ))
        .where((box) => box.hasSize && box.size.height > 0)) {
      for (final line in linesIn(window)) {
        final inside =
            line.$1 >= -_tolerance && line.$2 <= window.size.height + _tolerance;
        final outside = line.$2 <= _tolerance ||
            line.$1 >= window.size.height - _tolerance;
        expect(inside || outside, isTrue,
            reason: 'a page shows only part of a line after a font change');
      }
    }

    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// The reader's page counter, as its two numbers.
({int page, int total}) readCounter(WidgetTester tester) {
  final counter = find.textContaining(RegExp(r'^\d+ / \d+$'));
  expect(counter, findsOneWidget);
  final parts = tester.widget<Text>(counter).data!.split('/');
  return (page: int.parse(parts.first.trim()), total: int.parse(parts.last.trim()));
}

/// Taps the right-hand edge of the reader — the tap-to-turn zone — at
/// [timeStamp].
Future<void> tapToTurn(WidgetTester tester, Duration timeStamp) async {
  const where = Offset(360, 400);
  final gesture = await tester.createGesture();
  await gesture.down(where, timeStamp: timeStamp);
  await gesture.up(timeStamp: timeStamp);
}

/// How far over an edge a line may hang before it counts as cut: lines of one
/// paragraph overlap each other by a fraction of a pixel, since every line box
/// is grown to the tallest ascent and descent on it.
const double _tolerance = 1.0;

/// The top and bottom of every line of text under [window], in its
/// coordinates.
List<(double, double)> linesIn(RenderBox window) {
  final lines = <(double, double)>[];
  void walk(RenderObject node) {
    if (node is RenderParagraph) {
      if (!node.hasSize) return;
      final top = node.localToGlobal(Offset.zero, ancestor: window).dy;
      final length = node.text.toPlainText(includeSemanticsLabels: false).length;
      if (length == 0) return;
      for (final box in node.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: length),
        boxHeightStyle: ui.BoxHeightStyle.max,
      )) {
        lines.add((top + box.top, top + box.bottom));
      }
      return;
    }
    node.visitChildren(walk);
  }

  walk(window);
  return lines;
}

/// Points `getApplicationDocumentsDirectory` at the test's temp directory, so
/// the reader finds the seeded chapter where it looks for offline copies.
class _TempDirPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempDirPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
