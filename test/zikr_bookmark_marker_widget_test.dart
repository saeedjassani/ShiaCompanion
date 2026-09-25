import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

/// 20 Arabic / transliteration / translation triplets.
String _tripletContent() {
  final lines = <String>[];
  for (var verse = 0; verse < 20; verse++) {
    lines.add('اللهم صل على محمد وآل محمد $verse');
    lines.add('TRANSLITERATION OF VERSE $verse');
    lines.add('Translation of verse $verse');
  }
  return lines.join('\n');
}

Future<List<ZikrContentScrollPosition>> _pumpViewer(
  WidgetTester tester, {
  int? bookmarkLineIndex,
  double bottomInset = 0,
}) async {
  final positions = <ZikrContentScrollPosition>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ZikrContentViewerWidget(
            tabContents: <String>[_tripletContent()],
            selectedTabIndex: 0,
            onTabChanged: (_) {},
            hasMerits: false,
            onShowMerits: () {},
            onLinkTap: (_) async {},
            initialBookmarkTabIndex: bookmarkLineIndex == null ? null : 0,
            initialBookmarkScrollOffset: bookmarkLineIndex == null ? null : 1,
            initialBookmarkLineIndex: bookmarkLineIndex,
            onScrollPositionChanged: positions.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return positions;
}

/// The text of content line [index] as the triplet content lays it out.
Finder _lineFinder(int index) {
  final verse = index ~/ 3;
  return switch (index % 3) {
    0 => find.text('اللهم صل على محمد وآل محمد $verse'),
    1 => find.text('TRANSLITERATION OF VERSE $verse'),
    _ => find.text('Translation of verse $verse'),
  };
}

Finder _tintedLines() => find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      // Both the color and the border: a border alone also matches the
      // paragraph divider the reading list now draws between triplets,
      // which is not a tint.
      return decoration is BoxDecoration &&
          decoration.color != null &&
          decoration.border != null;
    });

void main() {
  setUp(() {
    showTransliteration = true;
    showTranslation = true;
  });

  tearDown(() {
    showTransliteration = true;
    showTranslation = true;
  });

  testWidgets('reports the line actually at the top of the view', (
    tester,
  ) async {
    final positions = await _pumpViewer(tester);
    expect(positions.last.lineIndex, 0);

    // Scroll down and the reported line must be a real line boundary further
    // in - measured off the laid-out list, not guessed from the fraction.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final scrolledLine = positions.last.lineIndex;
    expect(scrolledLine, isNotNull);
    expect(scrolledLine, greaterThan(0));

    // The real invariant: the reported line is the one straddling the top of
    // the viewport - it starts at or above the top edge, and has not gone by.
    final viewportTop = tester.getRect(find.byType(ListView)).top;
    final reportedLine = tester.getRect(_lineFinder(scrolledLine!));
    expect(reportedLine.top, lessThanOrEqualTo(viewportTop + 0.5));
    expect(reportedLine.bottom, greaterThan(viewportTop));

    // The reported line is stable: reading the position again without
    // scrolling reports the same line, so bookmarking twice cannot drift.
    await tester.drag(find.byType(ListView), const Offset(0, -0.0));
    await tester.pumpAndSettle();
    expect(positions.last.lineIndex, scrolledLine);
  });

  testWidgets('tints the whole triplet when bookmarked on the Arabic', (
    tester,
  ) async {
    // Line 0 is the Arabic of the first verse; its triplet is lines 0..2.
    await _pumpViewer(tester, bookmarkLineIndex: 0);

    expect(_tintedLines(), findsNWidgets(3));
    expect(find.text('Bookmarked'), findsOneWidget);
    expect(find.text('TRANSLITERATION OF VERSE 0'), findsOneWidget);
  });

  testWidgets('tints the same triplet when bookmarked on its translation', (
    tester,
  ) async {
    await _pumpViewer(tester, bookmarkLineIndex: 2);
    expect(_tintedLines(), findsNWidgets(3));
  });

  testWidgets('tints only the line when it is not part of a triplet', (
    tester,
  ) async {
    // A tab of back-to-back Arabic lines has no transliteration or
    // translation to group with, so each line stands alone.
    final arabicOnly = List.generate(
      60,
      (line) => 'اللهم صل على محمد وآل محمد $line',
    ).join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZikrContentViewerWidget(
            tabContents: <String>[arabicOnly],
            selectedTabIndex: 0,
            onTabChanged: (_) {},
            hasMerits: false,
            onShowMerits: () {},
            onLinkTap: (_) async {},
            initialBookmarkTabIndex: 0,
            initialBookmarkScrollOffset: 1,
            initialBookmarkLineIndex: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_tintedLines(), findsOneWidget);
  });

  testWidgets('drops the tint from a line the reader has switched off', (
    tester,
  ) async {
    showTransliteration = false;
    await _pumpViewer(tester, bookmarkLineIndex: 1);

    // The hidden transliteration draws nothing, so only the Arabic and the
    // translation carry the tint, and the label stays on the Arabic.
    expect(_tintedLines(), findsNWidgets(2));
    expect(find.text('Bookmarked'), findsOneWidget);
    expect(find.text('TRANSLITERATION OF VERSE 0'), findsNothing);
  });

  testWidgets('keeps the marker in place when the layout changes underneath', (
    tester,
  ) async {
    // Standing in for the audio player opening or the reading chrome sliding
    // away: the viewport changes size and the list relayouts. The marker used
    // to be derived from the scroll fraction, so this moved it or lost it.
    await _pumpViewer(tester, bookmarkLineIndex: 0);
    expect(_tintedLines(), findsNWidgets(3));
    expect(find.text('Bookmarked'), findsOneWidget);

    await _pumpViewer(tester, bookmarkLineIndex: 0, bottomInset: 180);
    await tester.pumpAndSettle();

    expect(_tintedLines(), findsNWidgets(3));
    expect(find.text('Bookmarked'), findsOneWidget);
    expect(find.text('TRANSLITERATION OF VERSE 0'), findsOneWidget);
  });

  testWidgets('adopts a line for a bookmark saved with only an offset', (
    tester,
  ) async {
    // Bookmarks from before line indexes existed: the offset is restored,
    // then the line under it is measured and handed back so the bookmark can
    // be rewritten with it.
    int? resolvedLine;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZikrContentViewerWidget(
            tabContents: <String>[_tripletContent()],
            selectedTabIndex: 0,
            onTabChanged: (_) {},
            hasMerits: false,
            onShowMerits: () {},
            onLinkTap: (_) async {},
            initialBookmarkTabIndex: 0,
            initialBookmarkScrollOffset: 400,
            onScrollPositionChanged: (_) {},
            onBookmarkLineResolved: (line) => resolvedLine = line,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resolvedLine, isNotNull);
    expect(resolvedLine, greaterThan(0));

    // The adopted line is the one the restored offset actually lands on.
    final viewportTop = tester.getRect(find.byType(ListView)).top;
    final adopted = tester.getRect(_lineFinder(resolvedLine!));
    expect(adopted.top, lessThanOrEqualTo(viewportTop + 0.5));
    expect(adopted.bottom, greaterThan(viewportTop));

    // Nothing is tinted until the page hands the adopted line back down.
    expect(_tintedLines(), findsNothing);
  });

  testWidgets('goes back to the bookmarked line, not the saved offset', (
    tester,
  ) async {
    // The offset is deliberately wrong - as it is once paragraph mode, the
    // font or its size has changed since the bookmark was taken. The line is
    // what the view has to come back to.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZikrContentViewerWidget(
            tabContents: <String>[_tripletContent()],
            selectedTabIndex: 0,
            onTabChanged: (_) {},
            hasMerits: false,
            onShowMerits: () {},
            onLinkTap: (_) async {},
            code: '102',
            initialBookmarkTabIndex: 0,
            initialBookmarkScrollOffset: 5,
            // The translation of verse 12: the triplet starts two lines up.
            initialBookmarkLineIndex: 38,
            onScrollPositionChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewportTop = tester.getRect(find.byType(ListView)).top;
    final tripletTop = tester.getRect(_lineFinder(36)).top;
    expect(tripletTop, greaterThanOrEqualTo(viewportTop - 0.5));
    expect(tripletTop, lessThan(viewportTop + 40),
        reason: 'the bookmarked triplet starts at the top of the view');
    expect(find.text('Bookmarked'), findsOneWidget);
  });

  testWidgets('comes back to the same line in paragraph mode', (
    tester,
  ) async {
    showTransliteration = false;
    showTranslation = false;
    showArabicAsParagraph = true;
    addTearDown(() => showArabicAsParagraph = false);

    final positions = <ZikrContentScrollPosition>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZikrContentViewerWidget(
            tabContents: <String>[_tripletContent()],
            selectedTabIndex: 0,
            onTabChanged: (_) {},
            hasMerits: false,
            onShowMerits: () {},
            onLinkTap: (_) async {},
            code: '102',
            initialBookmarkTabIndex: 0,
            // Measured in the old, taller one-verse-per-line layout.
            initialBookmarkScrollOffset: 2400,
            initialBookmarkLineIndex: 37,
            onScrollPositionChanged: positions.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Every verse flows into one paragraph here, so the right place is the
    // row inside it where the bookmarked verse begins - it reads back as a
    // verse on that row: several short ones share each, and the first to
    // begin on it is the one recorded. The mark is an icon inline at the
    // verse's start, not a label breaking the paragraph.
    expect(find.text('Bookmarked'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is RichText &&
          widget.text
              .toPlainText()
              .contains(String.fromCharCode(Icons.bookmark.codePoint))),
      findsOneWidget,
    );
    expect(positions, isNotEmpty);
    expect(positions.last.lineIndex, inInclusiveRange(37 - 9, 37));
  });

  testWidgets('lands on the bookmarked verse deep inside a long paragraph', (
    tester,
  ) async {
    showTransliteration = false;
    showTranslation = false;
    showArabicAsParagraph = true;
    addTearDown(() => showArabicAsParagraph = false);

    // One paragraph many screens long, as a whole dua is in this view.
    final lines = <String>[];
    for (var verse = 0; verse < 150; verse++) {
      lines.add('TRANSLITERATION OF VERSE $verse');
      lines.add('اللهم صل على محمد وآل محمد $verse');
      lines.add('Translation of verse $verse');
    }
    final positions = <ZikrContentScrollPosition>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: ZikrContentViewerWidget(
              tabContents: <String>[lines.join('\n')],
              selectedTabIndex: 0,
              onTabChanged: (_) {},
              hasMerits: false,
              onShowMerits: () {},
              onLinkTap: (_) async {},
              code: '102',
              initialBookmarkTabIndex: 0,
              initialBookmarkScrollOffset: 1,
              // Verse 100's Arabic.
              initialBookmarkLineIndex: 301,
              onScrollPositionChanged: positions.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Not the paragraph's start, which is where a bookmark taken anywhere in
    // it used to both record and land, but the row verse 100 begins on - it
    // reads back as the first verse to begin on that row, which several
    // short ones share.
    expect(positions, isNotEmpty);
    expect(positions.last.lineIndex, inInclusiveRange(301 - 9, 301));
    expect(positions.last.scrollOffset, greaterThan(0));
  });
}
