import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

/// A heading, three consecutive Arabic verses with nothing between them, and
/// a trailing instruction - no transliteration or translation lines at all,
/// which is the shape of most plain-Arabic duas in the corpus.
const _heading = 'DUA FOR SOMETHING';
const _verse0 = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
const _verse1 = 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ';
const _verse2 = 'الرَّحْمَٰنِ الرَّحِيمِ';
const _instruction = 'Recite three times';
const _mergedParagraph = '$_verse0 $_verse1 $_verse2';

String _content() => [_heading, _verse0, _verse1, _verse2, _instruction]
    .join('\n');

Future<void> _pumpViewer(
  WidgetTester tester, {
  int? bookmarkLineIndex,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: <String>[_content()],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          initialBookmarkTabIndex: bookmarkLineIndex == null ? null : 0,
          initialBookmarkScrollOffset: bookmarkLineIndex == null ? null : 1,
          initialBookmarkLineIndex: bookmarkLineIndex,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The direct child spans of the merged paragraph's [TextSpan], in order -
/// one per verse plus the ' ' separators the paragraph joins them with.
///
/// [Text]'s build wraps whatever span it is given in a fresh outer
/// [TextSpan] (so it can merge in the ambient default style), so the actual
/// paragraph span built by the viewer is one level below the [RichText]'s
/// own `text`.
List<InlineSpan> _paragraphChildren() {
  final richText = find
      .byWidgetPredicate((widget) =>
          widget is RichText && widget.text.toPlainText() == _mergedParagraph)
      .evaluate()
      .single
      .widget as RichText;
  final outer = richText.text as TextSpan;
  final paragraphSpan = outer.children!.single as TextSpan;
  return paragraphSpan.children!;
}

void main() {
  setUp(() {
    showTransliteration = true;
    showTranslation = true;
  });

  tearDown(() {
    showTransliteration = true;
    showTranslation = true;
  });

  testWidgets(
    'keeps each verse on its own line while either English aid is on',
    (tester) async {
      showTransliteration = false; // translation is still on
      await _pumpViewer(tester);

      expect(find.text(_verse0), findsOneWidget);
      expect(find.text(_verse1), findsOneWidget);
      expect(find.text(_verse2), findsOneWidget);
      expect(find.text(_mergedParagraph), findsNothing);
    },
  );

  testWidgets(
    'flows consecutive Arabic verses into one paragraph in Arabic-only view',
    (tester) async {
      showTransliteration = false;
      showTranslation = false;
      await _pumpViewer(tester);

      // The three verses now live in a single flowing block of text...
      expect(find.text(_mergedParagraph), findsOneWidget);
      // ...so none of them is findable as its own separate widget any more.
      expect(find.text(_verse0), findsNothing);
      expect(find.text(_verse1), findsNothing);
      expect(find.text(_verse2), findsNothing);

      // The heading and the instruction sit outside the run of Arabic
      // verses and still stand on their own.
      expect(find.text(_heading), findsOneWidget);
      expect(find.text(_instruction), findsOneWidget);

      final paragraph = tester.widget<Text>(find.text(_mergedParagraph));
      expect(paragraph.textAlign, TextAlign.justify);
      expect(paragraph.textDirection, TextDirection.rtl);
    },
  );

  testWidgets(
    'highlights only the bookmarked verse, not the whole paragraph',
    (tester) async {
      showTransliteration = false;
      showTranslation = false;
      // Content line 2 is verse1, the middle of the three merged verses.
      await _pumpViewer(tester, bookmarkLineIndex: 2);

      expect(find.text('Bookmarked'), findsOneWidget);
      expect(find.text(_mergedParagraph), findsOneWidget);

      final highlighted = _paragraphChildren().where((span) {
        final style = span.style;
        return style?.backgroundColor != null;
      }).toList();

      expect(highlighted, hasLength(1));
      expect(highlighted.single.toPlainText(), _verse1);
    },
  );

  testWidgets(
    'moves the highlight when the bookmark is on a different verse',
    (tester) async {
      showTransliteration = false;
      showTranslation = false;
      // Content line 3 is verse2, the last of the three merged verses.
      await _pumpViewer(tester, bookmarkLineIndex: 3);

      final highlighted = _paragraphChildren().where((span) {
        return span.style?.backgroundColor != null;
      }).toList();

      expect(highlighted, hasLength(1));
      expect(highlighted.single.toPlainText(), _verse2);
    },
  );
}
