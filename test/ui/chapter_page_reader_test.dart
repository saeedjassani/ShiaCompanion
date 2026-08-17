import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/chapter_page.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'firebase_test_doubles.dart';

/// Drives the reader itself — the real [ChapterPage], not a stand-in for it —
/// over real chapter markdown, turning pages and checking that none of them
/// hides text below its bottom edge.
///
/// The page-height model lives in `PageLayoutEngine` and is tested directly in
/// `test/library_real_chapter_fit_test.dart`. Only the page itself knows the
/// width and height it hands that engine, the style sheet it renders with, and
/// the box it renders into — this test covers that seam, which is where "the
/// last line is cut off" is actually visible.

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
          // Each page is a scroll view exactly one page tall. If its blocks
          // were measured correctly there is nothing to scroll; whatever can
          // be scrolled to is text the reader cannot otherwise see.
          final positions = tester
              .stateList<ScrollableState>(find.descendant(
                of: find.byType(PageView),
                matching: find.byType(Scrollable),
              ))
              .map((state) => state.position)
              .where((p) => p.axis == Axis.vertical && p.hasContentDimensions)
              .toList();

          // Without one of these there is nothing here to measure, and this
          // test would quietly pass on a reader that clips its overflow away.
          expect(positions, isNotEmpty,
              reason: 'a page should be able to scroll rather than clip');

          final hidden = positions
              .map((p) => p.maxScrollExtent)
              .reduce((a, b) => a > b ? a : b);

          expect(
            hidden,
            0.0,
            reason: '$fixture at ${fontSize.toInt()}pt: page $page of '
                '$totalPages hides ${hidden.toStringAsFixed(1)}px of text '
                'below its bottom edge',
          );

          if (page < pagesToWalk) {
            // Turn the page by tapping its right-hand edge, as a reader does.
            await tester.tapAt(const Offset(360, 400));
            await tester.pumpAndSettle();
          }
        }

        expect(tester.takeException(), isNull);
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }
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
