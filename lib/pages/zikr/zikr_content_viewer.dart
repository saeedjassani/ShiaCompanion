import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../constants.dart';
import '../../data/quran_ali_verses.dart';
import '../../utils/quran_index.dart';
import 'zikr_content_parser.dart';

/// Where a reader is in the Quran, and whether they got there by reading.
///
/// [fromUserScroll] is the whole point of this type. Landing on 23:56 from a
/// shared link is a lookup, not recitation, so it must not become the reader's
/// saved place; dragging the list is. The viewer is the only thing that can
/// tell the two apart, so it reports which happened rather than leaving the
/// page to guess from scroll offsets.
class QuranReadingPosition {
  const QuranReadingPosition({
    required this.verse,
    required this.text,
    required this.fromUserScroll,
  });

  /// The surah as well as the ayah: a juz runs across surahs, so an ayah
  /// number on its own does not say where the reader is.
  final VerseKey verse;

  /// The verse as shown, so saving it from the action bar can keep an excerpt
  /// without the reader having opened the per-verse menu first.
  final String text;

  final bool fromUserScroll;
}

/// A verse the reader tapped, and what the page needs to act on it.
class AyahActionRequest {
  const AyahActionRequest({
    required this.verse,
    required this.text,
    required this.lineIndex,
    this.aliNote,
  });

  /// Which verse was tapped, surah included - in a juz the surah is not the
  /// one the page as a whole is showing.
  final VerseKey verse;

  /// The verse as text worth copying or sharing.
  final String text;

  /// The content line the verse starts on, which is what a bookmark records.
  final int lineIndex;

  /// The occasion Shia tafsir cites this verse as being about Imam Ali (as)
  /// for - see [aliRelatedNoteFor] - or null for most verses. Carried here so
  /// the per-verse menu can say it: in paragraph mode there is no per-verse
  /// badge to long-press for it.
  final String? aliNote;
}

class ZikrContentScrollPosition {
  const ZikrContentScrollPosition({
    required this.tabIndex,
    required this.scrollOffset,
    this.maxScrollExtent = 0,
    this.lineIndex,
  });

  final int tabIndex;
  final double scrollOffset;
  final double maxScrollExtent;

  /// The content line sitting at the top of the view at this offset, measured
  /// from the laid-out list, or null when the list has not been laid out yet.
  /// This is what a bookmark taken here records, so the "you left off here"
  /// marker lands on the very line the offset was read off.
  final int? lineIndex;
}

/// How much of a line may sit above the top of the viewport before the line
/// below it counts as the one being read. Guards against a line whose bottom
/// edge lands exactly on the viewport top being picked over its successor.
const double _lineEdgeTolerance = 0.5;

/// Whether the Arabic-only reading layout applies: both English aids are
/// switched off, so translation/transliteration lines draw nothing anyway,
/// the reader has opted into paragraph flow via [showArabicAsParagraph], and
/// consecutive Arabic verses can flow together as one prose paragraph instead
/// of stacking as separate centered lines with a gap between each.
bool get isArabicOnlyReadingView =>
    !showTransliteration && !showTranslation && showArabicAsParagraph;

/// Whether line [index] draws anything at all under the current reading
/// settings. A transliteration or translation line the reader has switched
/// off renders as an empty, zero-height box, so the bookmark tint has to skip
/// it - tinting it would paint a stray sliver of border and padding for a line
/// that is not there.
bool isZikrLineVisible(ParsedZikrContent content, int index) {
  if (index < 0 || index >= content.lines.length) return false;
  // Mirrors the renderer's own order: Arabic wins over either English set.
  if (content.arabicCodes.contains(index)) return true;
  if (content.transliCodes.contains(index)) return showTransliteration;
  if (content.translaCodes.contains(index)) return showTranslation;
  return true;
}

/// The span of content lines the bookmark marker covers, given the line the
/// bookmark was actually taken on.
///
/// A bookmark taken anywhere in an Arabic triplet - on the Arabic itself, or
/// on its transliteration or translation - marks the whole triplet, starting
/// from its first line, so the marker never cuts a verse in half. A bookmark
/// on a line that stands on its own (a heading, an instruction) marks just
/// that line.
///
/// This deliberately takes no scroll measurements. The line index is fixed
/// when the bookmark is saved, so the marker cannot drift or vanish when
/// something later changes the layout - the audio player opening, the reading
/// chrome sliding away, or transliteration being switched off.
ZikrLineGroup? bookmarkedLineRange({
  required int? bookmarkLineIndex,
  required ParsedZikrContent content,
}) {
  final index = bookmarkLineIndex;
  if (index == null || index < 0 || index >= content.lines.length) return null;
  return content.groupContaining(index) ??
      ZikrLineGroup(start: index, end: index + 1);
}

/// The first line of [range] that actually draws something, which is where
/// the "Bookmarked" label goes. Null when every line in the range is switched
/// off, in which case there is nothing to mark at all.
int? firstVisibleLineInRange(ZikrLineGroup range, ParsedZikrContent content) {
  for (var index = range.start; index < range.end; index++) {
    if (isZikrLineVisible(content, index)) return index;
  }
  return null;
}

/// Renders [rawLine] as a [TextSpan], turning any `[label](href)`
/// markdown-style links embedded in it (cross-references to another zikr's
/// uid, mostly - a Quran surah cited from a merits note, say) into tappable
/// spans styled with [linkStyle]. Shared by the tab content viewer below and
/// by the merits sheet in zikr_page.dart, so a link reads and behaves the
/// same whether it sits in the dua text or in its merits.
TextSpan buildZikrTextSpanWithLinks({
  required String rawLine,
  required TextStyle baseStyle,
  required TextStyle linkStyle,
  required void Function(String href) onLinkTap,
}) {
  final segments = ZikrContentParser.parseLineSegments(rawLine);
  return TextSpan(
    style: baseStyle,
    children: segments.map((segment) {
      if (!segment.hasHref) {
        return TextSpan(text: segment.text);
      }
      return TextSpan(
        text: segment.text,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => onLinkTap(segment.href!),
      );
    }).toList(),
  );
}

/// One item the reading list actually renders. Ordinarily this is a single
/// content line, same as always. A run of consecutive standalone lines -
/// narration, commentary, a heading, a citation - collapses into one item
/// so they render as a single continuous block instead of one separately
/// bordered fragment per line. In [isArabicOnlyReadingView], a run of
/// consecutive Arabic verses - possibly with a switched-off transliteration
/// or translation line folded in between them - collapses the same way so
/// the verses can be laid out as a single flowing paragraph rather than
/// separate centered lines.
class _ReadingListItem {
  const _ReadingListItem(this.lineIndexes);

  /// The content-line indexes this item covers, in source order. A plain
  /// line has exactly one; a merged Arabic paragraph has one per verse - the
  /// folded-in hidden lines are not members, since they draw nothing and
  /// contribute no text.
  final List<int> lineIndexes;

  int get firstLineIndex => lineIndexes.first;
}

/// Splits [content] into the units the reading list renders. Outside
/// [isArabicOnlyReadingView] this is one item per line except for a run of
/// standalone lines, which always collapses into one item regardless of
/// view mode. See [_ReadingListItem].
List<_ReadingListItem> _buildReadingListItems(ParsedZikrContent content) {
  final total = content.lines.length;
  final items = <_ReadingListItem>[];

  bool isStandalone(int i) =>
      !content.arabicCodes.contains(i) &&
      !content.transliCodes.contains(i) &&
      !content.translaCodes.contains(i);

  var i = 0;
  while (i < total) {
    if (isStandalone(i)) {
      final lines = <int>[i];
      var j = i + 1;
      while (j < total && isStandalone(j)) {
        lines.add(j);
        j++;
      }
      items.add(_ReadingListItem(lines));
      i = j;
      continue;
    }

    if (isArabicOnlyReadingView && content.arabicCodes.contains(i)) {
      final verses = <int>[i];
      var j = i + 1;
      while (j < total) {
        if (content.arabicCodes.contains(j)) {
          verses.add(j);
          j++;
        } else if (content.transliCodes.contains(j) ||
            content.translaCodes.contains(j)) {
          // Switched off in this view - draws nothing, but does not break
          // the paragraph the Arabic verses around it are flowing into.
          j++;
        } else {
          break;
        }
      }
      items.add(_ReadingListItem(verses));
      i = j;
      continue;
    }

    items.add(_ReadingListItem([i]));
    i++;
  }
  return items;
}

/// Several lines or verses flowing together as one ruled paragraph, measured
/// so a point in it can be turned back into the member there and a member
/// into the height of the row it begins on. Kept across builds by whoever
/// owns it: [textKey] minted afresh each build would remount the text - and
/// lose the measurement - on every scroll.
class _FlowingText {
  /// Where each member's text begins inside the laid-out paragraph, in
  /// reading order. Recorded when the item is built - the offsets depend on
  /// the selected font, which rewrites the verse markers - and read back to
  /// turn a point in the paragraph into a member and a member into a height.
  List<int> textStarts = const [];

  /// Finds the paragraph's own [RenderParagraph], among the several text
  /// blocks the item may draw (a label, a surah heading), for measuring.
  final GlobalKey textKey = GlobalKey();

  /// The [RenderParagraph] under [textKey], once it has been laid out.
  ///
  /// Not simply the key's own render object: inside the reading area's
  /// [SelectionArea], [Text] wraps its [RichText] in a [MouseRegion] and a
  /// selection container, so the paragraph sits a few render objects down.
  RenderParagraph? get laidOutText {
    RenderParagraph? find(RenderObject? node) {
      if (node == null || node is RenderParagraph) {
        return node as RenderParagraph?;
      }
      RenderParagraph? found;
      node.visitChildren((child) => found ??= find(child));
      return found;
    }

    final text = find(textKey.currentContext?.findRenderObject());
    return text != null && text.hasSize && text.attached ? text : null;
  }

  /// Which member's text contains character [offset].
  int memberAtTextOffset(int offset) {
    var k = 0;
    while (k + 1 < textStarts.length && textStarts[k + 1] <= offset) {
      k++;
    }
    return k;
  }
}

/// One item of a surah read in [isArabicOnlyReadingView] with paragraph flow:
/// a run of consecutive verses flowing together as one ruled paragraph, or a
/// lone unnumbered span (the Bismillah) drawn the way it always is. See
/// [quranParagraphSpanRuns] for where the runs break. Its members are its
/// verses.
class _QuranParagraph extends _FlowingText {
  _QuranParagraph(this.spanIndexes);

  /// Indexes into [AyahIndex.spans], consecutive and in reading order.
  final List<int> spanIndexes;

  int get firstSpanIndex => spanIndexes.first;

  /// The verse whose text contains character [offset].
  int spanIndexAtTextOffset(int offset) =>
      spanIndexes[memberAtTextOffset(offset)];
}

/// The paragraphs of a surah tab, with a lookup from span to paragraph.
class _QuranParagraphs {
  _QuranParagraphs(this.items) {
    for (var p = 0; p < items.length; p++) {
      for (final spanIndex in items[p].spanIndexes) {
        _paragraphBySpan[spanIndex] = p;
      }
    }
  }

  factory _QuranParagraphs.build(AyahIndex index) => _QuranParagraphs([
        for (final run in quranParagraphSpanRuns(index)) _QuranParagraph(run),
      ]);

  final List<_QuranParagraph> items;
  final Map<int, int> _paragraphBySpan = {};

  int? paragraphIndexForSpan(int spanIndex) => _paragraphBySpan[spanIndex];
}

/// Matches the verse-number marker closing a formatted Arabic line - the
/// Scheherazade medallion (U+06DD and Arabic-Indic digits) or the plain `(n)`
/// Qalam draws its own medallion from - with the direction mark and spacing
/// around it, so it can be styled apart from the verse text.
final RegExp _trailingVerseMarker =
    RegExp(r'\u200F?(?:\u06DD[\u0660-\u0669]+|\(\d+\))\s*$');

/// The small "Bookmarked" marker - a bookmark icon plus label - shared by
/// the bordered per-line marker ([_BookmarkedLine]) and the inline paragraph
/// marker that sits above a flowing Arabic paragraph in
/// [isArabicOnlyReadingView], where the highlight lives on the verse's own
/// text rather than on a container wrapping the whole line.
Widget _bookmarkLabelRow(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.bookmark, size: 13, color: colorScheme.primary),
      const SizedBox(width: 4),
      Text(
        'Bookmarked',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
      ),
    ],
  );
}

/// The bookmark icon drawn inline at the start of the bookmarked verse in a
/// flowing Arabic paragraph, in place of a "Bookmarked" label above it - a
/// label there sits far from the verse, and breaking the paragraph to put it
/// nearer would undo the flow.
///
/// The icon font's glyph as plain text rather than a [WidgetSpan], so the
/// paragraph stays one run of text: [_RuledArabicParagraph] measures its rows
/// with a bare [TextPainter], which cannot lay out a widget placeholder. The
/// right-to-left mark after it keeps the glyph - a left-to-right character to
/// the bidi algorithm - on the verse's leading side.
TextSpan _inlineBookmarkSpan(Color color, double? arabicFontSize) {
  const icon = Icons.bookmark;
  return TextSpan(
    text: '${String.fromCharCode(icon.codePoint)}\u200F ',
    style: TextStyle(
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      color: color,
      fontSize: (arabicFontSize ?? 24) * 0.75,
    ),
  );
}

class ZikrContentViewerWidget extends StatefulWidget {
  final List<String> tabContents;
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final bool hasMerits;
  final VoidCallback onShowMerits;
  final Future<void> Function(String href) onLinkTap;
  final int? initialBookmarkTabIndex;
  final double? initialBookmarkScrollOffset;

  /// The content line the saved bookmark sits on, when it has one. This is
  /// what the marker is drawn on; the offset above is only used to scroll
  /// back there.
  final int? initialBookmarkLineIndex;

  /// Verses the reader has kept, marked with a small icon as they read.
  ///
  /// Deliberately not the bookmark: a bookmark is one marker saying where you
  /// stopped, these are a collection meant to be kept, so they are drawn
  /// unobtrusively rather than washing the block.
  final Set<VerseKey> savedVerses;
  final ValueChanged<ZikrContentScrollPosition>? onScrollPositionChanged;

  /// Reports the line a bookmark saved without one turns out to sit on, once
  /// the list has been restored to its offset and measured, so the bookmark
  /// can be rewritten with it and stop depending on the offset.
  final ValueChanged<int>? onBookmarkLineResolved;

  /// Which surah this is, when the document being read is one of the 114.
  ///
  /// Null for every other zikr, and that is what selects the rendering path:
  /// null means one widget per line, exactly as this viewer has always worked.
  /// Non-null switches to one widget per ayah, so verses can be numbered,
  /// tapped, scrolled to and reported on.
  final int? surahNumber;

  /// The verse to open at, for a `/quran/23/56` link or a resumed recitation.
  ///
  /// A whole verse rather than an ayah number, because in a juz the number
  /// alone is ambiguous - ayah 12 exists in every surah the portion covers.
  final VerseKey? initialVerse;

  /// A prebuilt index, for content the viewer cannot index by itself.
  ///
  /// A juz portion is several surahs stitched together, so its verse numbers
  /// restart partway through and its surah headings are known only to whoever
  /// assembled it. When supplied it is used as-is; otherwise the viewer derives
  /// an index from [surahNumber].
  final AyahIndex? ayahIndex;

  /// Fires with the topmost verse on screen. Only meaningful in ayah mode.
  final ValueChanged<QuranReadingPosition>? onAyahPositionChanged;

  /// Opens the per-verse menu. Null leaves verses untappable.
  final ValueChanged<AyahActionRequest>? onAyahAction;

  const ZikrContentViewerWidget({
    Key? key,
    required this.tabContents,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.hasMerits,
    required this.onShowMerits,
    required this.onLinkTap,
    this.initialBookmarkTabIndex,
    this.initialBookmarkScrollOffset,
    this.initialBookmarkLineIndex,
    this.savedVerses = const {},
    this.onScrollPositionChanged,
    this.onBookmarkLineResolved,
    this.surahNumber,
    this.initialVerse,
    this.ayahIndex,
    this.onAyahPositionChanged,
    this.onAyahAction,
  }) : super(key: key);

  @override
  _ZikrContentViewerWidgetState createState() =>
      _ZikrContentViewerWidgetState();
}

class _ZikrContentViewerWidgetState extends State<ZikrContentViewerWidget> {
  late PageController _pageController;
  late List<ScrollController> _tabScrollControllers;
  late List<GlobalKey> _tabHeaderKeys;
  late List<GlobalKey> _tabListKeys;

  /// Parsing and indexing a tab is pure work over a string that rarely
  /// changes, but [_buildTabContent] runs on every build. Al-Baqarah is 858
  /// lines, so caching by content keeps a scroll from re-parsing it each frame.
  final Map<int, _TabContentCache> _contentCaches = {};

  /// Whether this reader has actually moved the list by hand - touch drag,
  /// mouse drag, or a wheel/trackpad scroll. Set only by real user input -
  /// never by a jump to a linked verse or a bookmark restore, both of which
  /// scroll via [ScrollPosition.jumpTo] and so never fire a pointer event -
  /// so a lookup can be told apart from recitation. See [QuranReadingPosition].
  bool _sawUserScrollInput = false;

  bool _didScrollToInitialVerse = false;
  bool _verseReportScheduled = false;
  VerseKey? _reportedVerse;
  late int _selectedTabIndex;
  late final int? _initialBookmarkTabIndex;
  late final double? _initialBookmarkScrollOffset;
  bool _didRestoreInitialBookmark = false;

  /// The reading-list items built for each tab on its last build, keyed by
  /// tab index. [topContentLineIndex] reads this to turn the list index a
  /// scroll position measures back into a content-line index - the two only
  /// coincide one-to-one when [isArabicOnlyReadingView] is off.
  final Map<int, List<_ReadingListItem>> _tabReadingListItems = {};

  /// The paragraphs a surah tab is drawn as, for each tab currently read in
  /// Quran paragraph mode. Absent for every tab drawn any other way, which is
  /// what tells the measuring code below that one list item is one verse (ayah
  /// mode) or one reading item (every zikr).
  final Map<int, _QuranParagraphs> _tabQuranParagraphs = {};

  /// Per tab, each flowing Arabic paragraph of a zikr that is not Quran, by
  /// its first line - kept across builds for the same reason as
  /// [_TabContentCache.quranParagraphs]. Only filled in
  /// [isArabicOnlyReadingView].
  final Map<int, Map<int, _FlowingText>> _tabArabicFlows = {};

  TextSpan _buildTextSpanForLine(String rawLine, TextStyle baseStyle) {
    return buildZikrTextSpanWithLinks(
      rawLine: rawLine,
      baseStyle: baseStyle,
      linkStyle: baseStyle.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      onLinkTap: (href) => widget.onLinkTap(href),
    );
  }

  /// Renders one [isArabicOnlyReadingView] list item: [item]'s verses joined
  /// with plain spaces into a single right-aligned, justified paragraph
  /// block, so a run of Arabic verses reads as one continuous, wrapping
  /// passage - several short verses sharing a rendered line where they fit -
  /// instead of stacking as separate blocks with a gap and a divider between
  /// each. That flow is the entire point of paragraph mode, so verses are
  /// *not* forced onto their own line the way [_buildLine] lays them out one
  /// at a time. [_RuledArabicParagraph] is what gives a reciter something to
  /// find their place by instead - a rule under each *rendered* row, not a
  /// mark between verses, which would read as stray punctuation wherever two
  /// or three short ones share a row.
  ///
  /// A verse this item covers that is also the reader's bookmark gets its
  /// own text tinted in place - the paragraph itself is never tinted, since
  /// that would mark every verse sharing it, not the one actually bookmarked
  /// - with a bookmark icon inline at the start of that verse, so the mark
  /// sits on the verse without breaking the paragraph around it.
  Widget _buildArabicParagraphItem(
    int tabIndex,
    _ReadingListItem item,
    ParsedZikrContent parsedContent,
    int? bookmarkLabelLine,
    TextStyle arabicStyle,
  ) {
    final flow = (_tabArabicFlows[tabIndex] ??= {})
        .putIfAbsent(item.firstLineIndex, _FlowingText.new);
    final textStarts = <int>[];
    var length = 0;

    final highlightedIndex = bookmarkLabelLine != null &&
            item.lineIndexes.contains(bookmarkLabelLine)
        ? bookmarkLabelLine
        : null;

    final colorScheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    for (var k = 0; k < item.lineIndexes.length; k++) {
      final lineIndex = item.lineIndexes[k];
      final lineSpan = _buildTextSpanForLine(
        ZikrContentParser.formatArabicText(parsedContent.lines[lineIndex]),
        arabicStyle,
      );
      final verseSpan = lineIndex == highlightedIndex
          ? TextSpan(
              style: TextStyle(
                backgroundColor:
                    colorScheme.primaryContainer.withValues(alpha: 0.55),
              ),
              children: [
                _inlineBookmarkSpan(colorScheme.primary, arabicStyle.fontSize),
                lineSpan,
              ],
            )
          : lineSpan;
      textStarts.add(length);
      length += verseSpan.toPlainText(includeSemanticsLabels: false).length;
      spans.add(verseSpan);
      if (k != item.lineIndexes.length - 1) {
        // Just a plain space: _RuledArabicParagraph's rule under each row is
        // what a reciter tracks by, so nothing extra is needed between
        // sentences that happen to share one - a visible mark there read as
        // stray punctuation, not a boundary.
        spans.add(const TextSpan(text: ' '));
        length += 1;
      }
    }
    flow.textStarts = textStarts;

    // A bit taller than the font's own metrics, so the rule under each row
    // sits in a clear gap rather than crowding the descenders/diacritics of
    // the row above it.
    final paragraphStyle = arabicStyle.copyWith(height: 2.0);

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
      child: _RuledArabicParagraph(
        textKey: flow.textKey,
        span: TextSpan(style: paragraphStyle, children: spans),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.selectedTabIndex;
    _initialBookmarkTabIndex = widget.initialBookmarkTabIndex;
    _initialBookmarkScrollOffset = widget.initialBookmarkScrollOffset;
    _pageController = PageController(initialPage: _selectedTabIndex);
    _tabScrollControllers = [];
    _tabHeaderKeys = [];
    _tabListKeys = [];
    _syncTabState(widget.tabContents.length);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncTabState(int count) {
    if (count <= 0) {
      _selectedTabIndex = 0;
      _syncTabHeaderKeys(0);
      _syncTabListKeys(0);
      _syncTabScrollControllers(0);
      return;
    }

    final clampedIndex = _selectedTabIndex.clamp(0, count - 1);
    final didClampIndex = clampedIndex != _selectedTabIndex;
    if (didClampIndex) {
      _selectedTabIndex = clampedIndex;
    }

    if (didClampIndex && _pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_selectedTabIndex);
        }
      });
    }

    _syncTabHeaderKeys(count);
    _syncTabListKeys(count);
    _syncTabScrollControllers(count);
  }

  void _syncTabHeaderKeys(int count) {
    while (_tabHeaderKeys.length < count) {
      _tabHeaderKeys.add(GlobalKey());
    }
    while (_tabHeaderKeys.length > count) {
      _tabHeaderKeys.removeLast();
    }
  }

  void _syncTabListKeys(int count) {
    while (_tabListKeys.length < count) {
      _tabListKeys.add(GlobalKey());
    }
    while (_tabListKeys.length > count) {
      _tabListKeys.removeLast();
    }
  }

  void _syncTabScrollControllers(int count) {
    while (_tabScrollControllers.length < count) {
      final tabIndex = _tabScrollControllers.length;
      final controller = ScrollController();
      controller.addListener(() => _reportScrollPosition(tabIndex, controller));
      _tabScrollControllers.add(controller);
    }
    while (_tabScrollControllers.length > count) {
      _tabScrollControllers.removeLast().dispose();
    }
  }

  void _reportScrollPosition(int tabIndex, ScrollController controller) {
    if (widget.onScrollPositionChanged == null || !controller.hasClients) {
      return;
    }

    final position = controller.position;
    widget.onScrollPositionChanged!.call(
      ZikrContentScrollPosition(
        tabIndex: tabIndex,
        scrollOffset: position.pixels,
        maxScrollExtent: position.maxScrollExtent,
        lineIndex: _topLineIndex(tabIndex, controller),
      ),
    );
  }

  /// The content line at the top of the view, in every mode.
  ///
  /// [topContentLineIndex] already answers in content lines whatever one list
  /// item happens to hold - a line, a verse, or a paragraph of verses - so
  /// this is it; kept as the name everything that records a bookmark calls.
  int? _topLineIndex(int tabIndex, ScrollController controller) =>
      topContentLineIndex(tabIndex, controller);

  /// Queues a verse report for the end of the current frame.
  ///
  /// The measurement has to happen after layout, not during the scroll
  /// notification that prompts it: a scroll notification is dispatched when the
  /// offset changes, which is before the children have been laid out at their
  /// new positions. Reading geometry there returns the previous frame's, and a
  /// gesture producing many updates before a single layout - a fling, or a
  /// synthesised drag - would read the same stale position every time and never
  /// notice the reader had moved.
  void _scheduleVerseReport(int tabIndex, ScrollController controller) {
    if (_verseReportScheduled) return;

    _verseReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verseReportScheduled = false;
      if (!mounted) return;
      _reportTopmostVerse(tabIndex, controller);
    });
  }

  /// Publishes the verse at the top of the view, when reading Quran.
  void _reportTopmostVerse(int tabIndex, ScrollController controller) {
    final callback = widget.onAyahPositionChanged;
    final ayahIndex = _ayahIndexFor(tabIndex);
    if (callback == null || ayahIndex == null || !controller.hasClients) return;

    final spanIndex = _topSpanIndex(tabIndex, controller);
    if (spanIndex == null) return;

    final verse = ayahIndex.verseAtSpanIndex(spanIndex);
    if (verse == null || verse == _reportedVerse) return;

    final parsed = _contentCaches[tabIndex]?.parsed;
    _reportedVerse = verse;
    callback(
      QuranReadingPosition(
        verse: verse,
        text: parsed == null
            ? ''
            : _ayahPlainText(parsed, ayahIndex.spans[spanIndex]),
        fromUserScroll: _sawUserScrollInput,
      ),
    );
  }

  /// A little air above a verse scrolled to, so it does not sit flush against
  /// the reading chrome.
  static const double _scrollToVerseMargin = 8;

  /// List item [itemIndex] as currently laid out - its box and where it
  /// begins in scroll coordinates - or null when it is not built and so has
  /// no measured position.
  ({RenderBox box, double offset})? _builtItem(int tabIndex, int itemIndex) {
    if (tabIndex >= _tabListKeys.length) return null;

    final renderObject =
        _tabListKeys[tabIndex].currentContext?.findRenderObject();
    if (renderObject == null) return null;
    final sliver = _findSliverList(renderObject);
    if (sliver == null) return null;

    RenderBox? child = sliver.firstChild;
    while (child != null) {
      final parentData = child.parentData;
      if (parentData is SliverMultiBoxAdaptorParentData &&
          parentData.index == itemIndex) {
        final offset = parentData.layoutOffset;
        return offset == null ? null : (box: child, offset: offset);
      }
      child = sliver.childAfter(child);
    }
    return null;
  }

  /// Brings [verse] to the top of the view.
  Future<void> _scrollToVerse(
    int tabIndex,
    AyahIndex ayahIndex,
    VerseKey verse,
    int leadingItems,
  ) async {
    final spanIndex = ayahIndex.nearestSpanIndexForVerse(verse);
    if (spanIndex == null) return;
    await _scrollToSpan(tabIndex, ayahIndex, spanIndex, leadingItems);
  }

  /// Brings ayah span [spanIndex] - a verse, or a Bismillah - to the top of
  /// the view, in ayah mode or paragraph mode alike.
  Future<void> _scrollToSpan(
    int tabIndex,
    AyahIndex ayahIndex,
    int spanIndex,
    int leadingItems,
  ) {
    // In paragraph mode the verse is somewhere inside a paragraph item, so
    // the item is found first and the verse's own row within it second.
    final paragraphs = _tabQuranParagraphs[tabIndex];
    final paragraphIndex = paragraphs?.paragraphIndexForSpan(spanIndex);
    final contentIndex = paragraphIndex ?? spanIndex;

    return _scrollToItem(
      tabIndex,
      itemIndex: contentIndex + leadingItems,
      itemCount:
          (paragraphs?.items.length ?? ayahIndex.spans.length) + leadingItems,
      insetWithin: paragraphIndex == null
          ? null
          : (box) {
              final paragraph = paragraphs!.items[paragraphIndex];
              return _memberTopInFlow(
                box,
                paragraph,
                paragraph.spanIndexes.indexOf(spanIndex),
              );
            },
    );
  }

  /// Brings content line [lineIndex] to the top of the view - the line a
  /// bookmark was taken on - whatever the list is currently made of.
  ///
  /// This is how a bookmark is restored whenever it knows its line, rather
  /// than by jumping to the pixel offset it was saved at: that offset only
  /// means the same place under the exact layout it was measured in, and
  /// switching paragraph mode, the font, its size or the screen width all
  /// move every line under it. The line never moves.
  Future<void> _scrollToLine(int tabIndex, int lineIndex) async {
    final leadingItems = _leadingItemCount(tabIndex);

    final ayahIndex = _ayahIndexFor(tabIndex);
    if (ayahIndex != null) {
      final spanIndex =
          ayahIndex.spans.indexWhere((span) => span.contains(lineIndex));
      // Before the first verse there is nothing above it to scroll past.
      if (spanIndex < 0) return;
      await _scrollToSpan(tabIndex, ayahIndex, spanIndex, leadingItems);
      return;
    }

    final items = _tabReadingListItems[tabIndex];
    if (items == null || items.isEmpty) return;
    // The last item starting at or before the line: an item can cover
    // several lines, and in paragraph flow a switched-off transliteration or
    // translation line is folded into the paragraph around it without being
    // one of its members, so matching on membership alone would miss it.
    var itemIndex = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].firstLineIndex > lineIndex) break;
      itemIndex = i;
    }

    // Inside a flowing paragraph, the row the line begins on - the same way:
    // the last member at or before it.
    final item = items[itemIndex];
    final flow = _tabArabicFlows[tabIndex]?[item.firstLineIndex];
    var member = 0;
    if (flow != null) {
      for (var k = 0; k < item.lineIndexes.length; k++) {
        if (item.lineIndexes[k] > lineIndex) break;
        member = k;
      }
    }
    if (itemIndex == 0 && member == 0 && leadingItems == 0) return;

    await _scrollToItem(
      tabIndex,
      itemIndex: itemIndex + leadingItems,
      itemCount: items.length + leadingItems,
      insetWithin:
          member == 0 ? null : (box) => _memberTopInFlow(box, flow!, member),
    );
  }

  /// Brings list item [itemIndex] - plus [insetWithin] of it, for a target
  /// partway down one item - to the top of the view.
  ///
  /// A `ListView.builder` cannot seek to an index, and lines wrap to different
  /// heights so there is no fixed extent to invert. So: estimate an offset, let
  /// the frame build, and then - now that the target is built - read its real
  /// layout offset and land on it exactly.
  ///
  /// Aligning the item's *start* is the point. An earlier version stopped as
  /// soon as [topContentLineIndex] named the target, but that reports the item
  /// whose bottom edge is still below the fold - true of a verse scrolled 95%
  /// past - so it settled with the verse mostly above the view and only its
  /// last line showing.
  Future<void> _scrollToItem(
    int tabIndex, {
    required int itemIndex,
    required int itemCount,
    double? Function(RenderBox itemBox)? insetWithin,
  }) async {
    if (tabIndex >= _tabScrollControllers.length || itemCount <= 0) return;
    final controller = _tabScrollControllers[tabIndex];

    // The reading chrome's inset animates in, which moves every item under it,
    // so a landing is only trusted once it has held still for a frame.
    var settledFrames = 0;
    for (var attempt = 0; attempt < 12; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !controller.hasClients) return;

      final position = controller.position;
      if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
        return;
      }

      final item = _builtItem(tabIndex, itemIndex);
      final inset = item == null ? 0.0 : insetWithin?.call(item.box) ?? 0.0;
      final itemOffset = item == null ? null : item.offset + inset;
      final target = itemOffset == null
          // Not built yet: aim by proportion to bring it into range, then
          // measure properly on the next pass.
          ? position.maxScrollExtent * (itemIndex / itemCount)
          : itemOffset - _scrollToVerseMargin;

      final clamped = target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if (itemOffset != null && (position.pixels - clamped).abs() <= 1) {
        if (++settledFrames >= 2) return;
        continue;
      }

      settledFrames = 0;
      controller.jumpTo(clamped);
    }
  }

  /// Runs the one-off jump to [ZikrContentViewerWidget.initialVerse].
  ///
  /// Guarded rather than driven from `initState` because the list has no
  /// scroll position until it has laid out, and the ayah index does not exist
  /// until the tab's content has been parsed.
  void _scheduleInitialVerseScroll(
    int tabIndex,
    AyahIndex ayahIndex,
    int leadingItems,
  ) {
    final verse = widget.initialVerse;
    if (_didScrollToInitialVerse || verse == null || verse.ayah == null) return;

    _didScrollToInitialVerse = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToVerse(tabIndex, ayahIndex, verse, leadingItems);
    });
  }

  /// How many list items sit ahead of the content itself - just the Merits
  /// button, on the tab that has one - so a list item index can be turned
  /// into a content line index.
  int _leadingItemCount(int tabIndex) =>
      widget.hasMerits && tabIndex == 0 ? 1 : 0;

  /// The content item at the top of tab [tabIndex]'s view - its index among
  /// the tab's content items, the Merits button not counted - with its box
  /// and how far down that box the top of the view falls. Null if the list
  /// has not been laid out yet.
  ///
  /// Measured rather than estimated from the scroll fraction: line heights
  /// vary with the content, the font settings and the width, so there is no
  /// pixels-per-line to invert, and an estimate drifts to a different line
  /// whenever anything changes the layout underneath it.
  ({int itemIndex, RenderBox box, double depth})? _topItem(
    int tabIndex,
    ScrollController controller,
  ) {
    if (!controller.hasClients || tabIndex >= _tabListKeys.length) return null;

    final renderObject =
        _tabListKeys[tabIndex].currentContext?.findRenderObject();
    if (renderObject == null) return null;
    final sliver = _findSliverList(renderObject);
    if (sliver == null) return null;

    // Read from where a scrolled-to item lands - [_scrollToVerseMargin] below
    // the top edge - not the edge itself: otherwise the last few pixels of the
    // item above, left showing in that margin, would count as what is being
    // read, and opening at a verse and bookmarking it would save the one
    // before.
    final scrollOffset = controller.position.pixels + _scrollToVerseMargin;
    // Children are held in index order, so the first one whose bottom edge is
    // still below that line is the one being read. Lines the reader has
    // switched off lay out at zero height and are skipped by the same test.
    RenderBox? child = sliver.firstChild;
    while (child != null) {
      final parentData = child.parentData;
      if (parentData is SliverMultiBoxAdaptorParentData && child.hasSize) {
        final layoutOffset = parentData.layoutOffset;
        final index = parentData.index;
        if (layoutOffset != null &&
            index != null &&
            scrollOffset <
                layoutOffset + child.size.height - _lineEdgeTolerance) {
          final itemIndex = index - _leadingItemCount(tabIndex);
          // The Merits button is not content; a reader still up at it is at
          // the top of the content just below it.
          if (itemIndex < 0) return (itemIndex: 0, box: child, depth: 0.0);
          return (
            itemIndex: itemIndex,
            box: child,
            depth: scrollOffset - layoutOffset,
          );
        }
      }
      child = sliver.childAfter(child);
    }
    return null;
  }

  /// The ayah span at the top of tab [tabIndex]'s view, or null when the tab
  /// is not Quran or has not been laid out.
  ///
  /// In ayah mode one item is one span. In paragraph mode one item is a run
  /// of them, so the verse is read off the paragraph's own text layout at the
  /// height the view's top edge crosses it - otherwise a reader working down
  /// a long passage would sit on its first verse the whole way.
  int? _topSpanIndex(int tabIndex, ScrollController controller) {
    final ayahIndex = _ayahIndexFor(tabIndex);
    if (ayahIndex == null) return null;
    final top = _topItem(tabIndex, controller);
    if (top == null) return null;

    final paragraphs = _tabQuranParagraphs[tabIndex];
    if (paragraphs == null) {
      return top.itemIndex < ayahIndex.spans.length ? top.itemIndex : null;
    }
    if (top.itemIndex >= paragraphs.items.length) return null;
    final paragraph = paragraphs.items[top.itemIndex];
    final k = _memberInFlowAt(top.box, paragraph, top.depth);
    return k == null ? paragraph.firstSpanIndex : paragraph.spanIndexes[k];
  }

  /// The content line currently at the top of tab [tabIndex]'s view, read off
  /// the laid-out list, or null if it has not been laid out yet.
  ///
  /// This is the line a bookmark taken now records, so it is always a content
  /// line, whatever one list item holds in the current mode: for Quran it is
  /// the first line of the verse at the top, and for every other zikr the
  /// first line of the reading item there.
  int? topContentLineIndex(int tabIndex, ScrollController controller) {
    final ayahIndex = _ayahIndexFor(tabIndex);
    if (ayahIndex != null) {
      final spanIndex = _topSpanIndex(tabIndex, controller);
      return spanIndex == null ? null : ayahIndex.spans[spanIndex].start;
    }

    final top = _topItem(tabIndex, controller);
    if (top == null) return null;
    // A reading item can cover several merged lines - a run of standalone
    // lines, or verses flowing as one paragraph - so the item index has to be
    // translated back to the content line its first line actually sits at.
    final items = _tabReadingListItems[tabIndex];
    if (items == null || top.itemIndex >= items.length) return top.itemIndex;
    final item = items[top.itemIndex];
    // A flowing paragraph can be a whole dua long; the line is the one being
    // read inside it, not the paragraph's first.
    final flow = _tabArabicFlows[tabIndex]?[item.firstLineIndex];
    final member =
        flow == null ? null : _memberInFlowAt(top.box, flow, top.depth);
    if (member != null && member < item.lineIndexes.length) {
      return item.lineIndexes[member];
    }
    return item.firstLineIndex;
  }

  /// [flow]'s own laid-out text inside [itemBox], with how far down the item
  /// it starts, or null when it has not been laid out.
  ({RenderParagraph text, double top})? _flowText(
    RenderBox itemBox,
    _FlowingText flow,
  ) {
    final text = flow.laidOutText;
    if (text == null) return null;
    final top = text.getTransformTo(itemBox).getTranslation().y;
    return (text: text, top: top);
  }

  /// The member of [flow] whose row sits [depth] pixels down [itemBox].
  ///
  /// The first member to begin on that row, if any does - a verse scrolled to
  /// lands on the row it begins on, usually behind the tail of the one before
  /// it, and must read back as itself. Otherwise the member the row continues.
  int? _memberInFlowAt(RenderBox itemBox, _FlowingText flow, double depth) {
    if (flow.textStarts.length <= 1) return 0;
    final laidOut = _flowText(itemBox, flow);
    if (laidOut == null) return null;

    final text = laidOut.text;
    final y = (depth - laidOut.top)
        .clamp(0.0, text.size.height > 1 ? text.size.height - 1 : 0.0)
        .toDouble();
    final position = text.getPositionForOffset(
      Offset(text.size.width > 1 ? text.size.width - 1 : 0, y),
    );
    final continued = flow.memberAtTextOffset(position.offset);
    for (var k = continued; k < flow.textStarts.length; k++) {
      final firstRow = _memberFirstRow(text, flow, k);
      if (firstRow == null || firstRow.top > y) break;
      if (firstRow.bottom > y) return k;
    }
    return continued;
  }

  /// The box of the row member [k] of [flow] begins on, within [text].
  static TextBox? _memberFirstRow(
    RenderParagraph text,
    _FlowingText flow,
    int k,
  ) {
    if (k >= flow.textStarts.length) return null;
    // The whole member, not just its first character: a one-character
    // selection splits the opening letter from its harakat - a single
    // grapheme - and comes back with no boxes at all. The member's highest
    // box is the row it starts on.
    final start = flow.textStarts[k];
    final end = k + 1 < flow.textStarts.length
        ? flow.textStarts[k + 1]
        : text.text.toPlainText(includeSemanticsLabels: false).length;
    final boxes = text.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isEmpty) return null;
    return boxes.reduce((a, b) => a.top <= b.top ? a : b);
  }

  /// How far down [itemBox] the row holding the start of member [k] of [flow]
  /// sits, or null when the paragraph has not been laid out.
  double? _memberTopInFlow(RenderBox itemBox, _FlowingText flow, int k) {
    if (k <= 0 || k >= flow.textStarts.length) return 0;
    final laidOut = _flowText(itemBox, flow);
    if (laidOut == null) return null;

    final firstRow = _memberFirstRow(laidOut.text, flow, k);
    return laidOut.top + (firstRow?.top ?? 0);
  }

  RenderSliverMultiBoxAdaptor? _findSliverList(RenderObject node) {
    if (node is RenderSliverMultiBoxAdaptor) return node;
    RenderSliverMultiBoxAdaptor? found;
    node.visitChildren((child) {
      found ??= _findSliverList(child);
    });
    return found;
  }

  /// Publishes the position of a tab that has not been scrolled yet, so
  /// progress is known as soon as a tab is laid out or swiped to.
  void _scheduleScrollPositionReport(int tabIndex) {
    if (widget.onScrollPositionChanged == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tabIndex >= _tabScrollControllers.length) return;
      _reportScrollPosition(tabIndex, _tabScrollControllers[tabIndex]);
    });
  }

  void _restoreInitialBookmarkIfNeeded(
    int tabIndex,
    ScrollController controller,
  ) {
    final bookmarkTabIndex = _initialBookmarkTabIndex;
    if (_didRestoreInitialBookmark ||
        bookmarkTabIndex == null ||
        tabIndex != bookmarkTabIndex) {
      return;
    }

    // An explicit destination wins: someone opening 23:56 asked for that
    // verse, not for wherever they last bookmarked this surah. The bookmark
    // is still drawn; the view just does not go there.
    if (widget.initialVerse?.ayah != null && _ayahIndexFor(tabIndex) != null) {
      _didRestoreInitialBookmark = true;
      return;
    }

    // A bookmark that knows its line goes back to that line, measured in the
    // list as it is laid out now - see [_scrollToLine].
    final bookmarkLine = widget.initialBookmarkLineIndex;
    if (bookmarkLine != null) {
      _didRestoreInitialBookmark = true;
      // Land on the start of what the marker covers - the whole triplet, when
      // the bookmark sits on its transliteration or translation - so the
      // tinted verse is on screen from its first line, not cut in half.
      final parsed = _contentCaches[tabIndex]?.parsed;
      final range = parsed == null
          ? null
          : bookmarkedLineRange(
              bookmarkLineIndex: bookmarkLine,
              content: parsed,
            );
      final targetLine = range?.start ?? bookmarkLine;
      if (targetLine <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _scrollToLine(tabIndex, targetLine);
        if (mounted && controller.hasClients) {
          _reportScrollPosition(tabIndex, controller);
        }
      });
      return;
    }

    // Only a bookmark saved before line indexes existed still has nothing
    // but a pixel offset to go on. It is restored by offset once, and the
    // line found there is handed back so the bookmark can be rewritten with
    // it - after which it restores by line like every other.
    final bookmarkOffset = _initialBookmarkScrollOffset;
    if (bookmarkOffset == null || bookmarkOffset <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRestoreInitialBookmark || !controller.hasClients) {
        return;
      }

      final position = controller.position;
      final targetOffset = bookmarkOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      controller.jumpTo(targetOffset);
      _didRestoreInitialBookmark = true;

      // The jump only takes effect at the next layout, so the line under the
      // restored offset can only be measured a frame later.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.hasClients) return;
        _reportScrollPosition(tabIndex, controller);
        // A content line in every mode - never a raw list index, which in
        // ayah or paragraph mode would point the marker at the wrong text.
        final resolvedLine = _topLineIndex(tabIndex, controller);
        if (resolvedLine != null) {
          widget.onBookmarkLineResolved?.call(resolvedLine);
        }
      });
    });
  }

  void _centerSelectedTab(
      {Duration duration = const Duration(milliseconds: 360)}) {
    if (!mounted ||
        _selectedTabIndex < 0 ||
        _selectedTabIndex >= _tabHeaderKeys.length) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selectedTabIndex < 0 ||
          _selectedTabIndex >= _tabHeaderKeys.length) {
        return;
      }

      final currentContext = _tabHeaderKeys[_selectedTabIndex].currentContext;
      if (currentContext == null) return;

      Scrollable.ensureVisible(
        currentContext,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _animateToTab(int index) async {
    if (!_pageController.hasClients) {
      setState(() {
        _selectedTabIndex = index;
      });
      _centerSelectedTab(duration: Duration.zero);
      return;
    }

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  String _getTabHeader(String content, int index) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    if (lines.isNotEmpty) {
      return lines.first;
    }
    return 'Tab ${index + 1}';
  }

  /// The parsed content and ayah index for a tab, reparsed only when the tab's
  /// raw text or the settings that shape parsing actually change.
  _TabContentCache _cacheFor(
    int tabIndex,
    String rawContent, {
    required bool hideHeaderLine,
  }) {
    final cached = _contentCaches[tabIndex];
    if (cached != null &&
        cached.rawContent == rawContent &&
        cached.hideHeaderLine == hideHeaderLine) {
      return cached;
    }

    final parsed = ZikrContentParser.parseContent(
      rawContent,
      hideHeaderLine: hideHeaderLine,
    );

    // Only the first tab is Quran text. Surah documents are single-tab today,
    // but guarding on the index means a tabbed one would degrade to line
    // rendering on its extra tabs rather than mis-number them.
    final surah = widget.surahNumber;
    final ayahIndex = tabIndex != 0
        ? null
        : widget.ayahIndex ??
            (surah == null
                ? null
                : AyahIndex.fromParsedContent(parsed, surah: surah));

    final cache = _TabContentCache(
      rawContent: rawContent,
      hideHeaderLine: hideHeaderLine,
      parsed: parsed,
      ayahIndex: ayahIndex != null && !ayahIndex.isEmpty ? ayahIndex : null,
    );
    _contentCaches[tabIndex] = cache;
    return cache;
  }

  /// The ayah index in force for a tab, or null when it renders line by line.
  AyahIndex? _ayahIndexFor(int tabIndex) => _contentCaches[tabIndex]?.ayahIndex;

  Widget _buildTabContent(
    String rawContent,
    ScrollController controller, {
    required int tabIndex,
    required bool hideHeaderLine,
    required bool showMeritsButton,
  }) {
    final cache = _cacheFor(
      tabIndex,
      rawContent,
      hideHeaderLine: hideHeaderLine,
    );
    final parsedContent = cache.parsed;
    final ayahIndex = cache.ayahIndex;

    _restoreInitialBookmarkIfNeeded(tabIndex, controller);
    if (tabIndex == _selectedTabIndex) {
      _scheduleScrollPositionReport(tabIndex);
    }
    final bookmarkedRange = tabIndex == widget.initialBookmarkTabIndex
        ? bookmarkedLineRange(
            bookmarkLineIndex: widget.initialBookmarkLineIndex,
            content: parsedContent,
          )
        : null;
    final bookmarkLabelLine = bookmarkedRange == null
        ? null
        : firstVisibleLineInRange(bookmarkedRange, parsedContent);
    // A surah read Arabic-only with paragraph flow on is drawn as one
    // paragraph rather than one block per verse - the same flow every other
    // zikr gets in that view, but still numbered, tappable and tracked verse
    // by verse. See [_buildQuranParagraphItem].
    final quranParagraphs = ayahIndex != null && isArabicOnlyReadingView
        ? cache.quranParagraphs
        : null;
    final readingItems = ayahIndex == null
        ? _buildReadingListItems(parsedContent)
        : const <_ReadingListItem>[];
    if (ayahIndex == null) {
      _tabReadingListItems[tabIndex] = readingItems;
    } else {
      _tabReadingListItems.remove(tabIndex);
    }
    if (ayahIndex != null || !isArabicOnlyReadingView) {
      _tabArabicFlows.remove(tabIndex);
    }
    if (quranParagraphs != null) {
      _tabQuranParagraphs[tabIndex] = quranParagraphs;
    } else {
      _tabQuranParagraphs.remove(tabIndex);
    }

    // Create text styles with current settings each time this is called
    final arabicStyle = TextStyle(
      fontFamily: arabicFont,
      // Six Indo-Pak pause signs — ص, ق, قف, وقفة, ك and the rukūʿ ع — have
      // no Unicode codepoint at all, so Al Qalam encodes them privately and
      // no other font can carry them. They are 1,361 marks, 0.1% of the
      // corpus. Falling back to Qalam draws the correct sign for each one;
      // substituting a plain letter per mark would risk printing the wrong
      // pause, which is a worse failure than a face change on a lone glyph.
      // A no-op when Qalam is the selected font.
      fontFamilyFallback: const ['Qalam'],
      fontSize: arabicFontSize,
      letterSpacing: 0,
    );
    final transliStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

    final leadingItems = showMeritsButton ? 1 : 0;
    final itemCount = leadingItems +
        (quranParagraphs != null
            ? quranParagraphs.items.length
            : ayahIndex != null
                ? ayahIndex.spans.length
                : readingItems.length);

    if (ayahIndex != null && tabIndex == _selectedTabIndex) {
      _scheduleInitialVerseScroll(tabIndex, ayahIndex, leadingItems);
    }

    return Listener(
      // Only real input counts as reading. A jump to a linked verse and a
      // bookmark restore both scroll this list too, but do it via jumpTo,
      // which never raises a pointer event - so catching input here, rather
      // than trusting ScrollStartNotification.dragDetails alone, is what
      // makes a mouse-wheel or trackpad scroll (desktop, web) count the same
      // way a touch drag does.
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _sawUserScrollInput = true;
      },
      onPointerPanZoomStart: (event) => _sawUserScrollInput = true,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _sawUserScrollInput = true;
          }
          if (tabIndex == _selectedTabIndex && ayahIndex != null) {
            _scheduleVerseReport(tabIndex, controller);
          }
          return false;
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (tabIndex == _selectedTabIndex) {
              _reportScrollPosition(tabIndex, controller);
            }
            return false;
          },
          child: Scrollbar(
            controller: controller,
            child: ListView.builder(
              key: _tabListKeys[tabIndex],
              controller: controller,
              itemCount: itemCount,
              itemBuilder: (BuildContext context, int index) {
                // Show merits button at the top of first tab
                if (showMeritsButton && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      top: 12.0,
                      right: 16.0,
                      bottom: 12.0,
                    ),
                    child: InkWell(
                      onTap: widget.onShowMerits,
                      child: Text(
                        'Merits',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                // A surah in paragraph mode has one item per surah (a juz one
                // per surah it spans, each Bismillah apart), and in
                // ayah mode one per verse; every other zikr is one item per
                // reading-list entry, which is one item per content line
                // except when Arabic-only paragraph flow folds a run of
                // verses into one.
                if (quranParagraphs != null) {
                  final paragraph = quranParagraphs.items[index - leadingItems];
                  final first = ayahIndex!.spans[paragraph.firstSpanIndex];
                  // The Bismillah stands alone and is drawn exactly as it is
                  // in ayah mode - centred, unnumbered, untappable.
                  if (first.ayah == null) {
                    return _buildAyahBlock(
                      ayahIndex: ayahIndex,
                      spanIndex: paragraph.firstSpanIndex,
                      parsedContent: parsedContent,
                      arabicStyle: arabicStyle,
                      transliStyle: transliStyle,
                      bookmarkedRange: bookmarkedRange,
                    );
                  }
                  return _buildQuranParagraphItem(
                    paragraph: paragraph,
                    ayahIndex: ayahIndex,
                    parsedContent: parsedContent,
                    arabicStyle: arabicStyle,
                    bookmarkedRange: bookmarkedRange,
                  );
                }

                if (ayahIndex != null) {
                  final contentIndex = index - leadingItems;
                  return _buildAyahBlock(
                    ayahIndex: ayahIndex,
                    spanIndex: contentIndex,
                    parsedContent: parsedContent,
                    arabicStyle: arabicStyle,
                    transliStyle: transliStyle,
                    bookmarkedRange: bookmarkedRange,
                  );
                }

                final itemIndex = index - leadingItems;
                final item = readingItems[itemIndex];

                final isLastItem = itemIndex == readingItems.length - 1;

                if (isArabicOnlyReadingView &&
                    parsedContent.arabicCodes.contains(item.firstLineIndex)) {
                  return _withParagraphDivider(
                    _buildArabicParagraphItem(
                      tabIndex,
                      item,
                      parsedContent,
                      bookmarkLabelLine,
                      arabicStyle,
                    ),
                    showDivider: !isLastItem,
                  );
                }

                // No trailing divider here: a standalone line never closed a
                // group before either (groupForLine only covers Arabic
                // triplets), so this preserves that - the block's own border
                // already sets it apart from what follows.
                if (item.lineIndexes.length > 1) {
                  return _buildFootnoteBlock(
                    item,
                    parsedContent,
                    bookmarkLabelLine,
                  );
                }

                // Every non-paragraph item covers exactly one content line.
                final contentIndex = item.firstLineIndex;
                final line = _buildLine(
                  parsedContent,
                  contentIndex,
                  arabicStyle,
                  transliStyle,
                );

                final Widget content;
                if (bookmarkedRange == null ||
                    bookmarkLabelLine == null ||
                    !bookmarkedRange.contains(contentIndex) ||
                    !isZikrLineVisible(parsedContent, contentIndex)) {
                  content = line;
                } else {
                  content = _BookmarkedLine(
                    // The label only belongs on the first line of the marked
                    // triplet that is actually showing - repeating it on the
                    // transliteration/translation lines under the same tint
                    // would just be noise, and a switched-off line draws
                    // nothing to carry it.
                    showLabel: contentIndex == bookmarkLabelLine,
                    child: line,
                  );
                }

                // Only the last line of an Arabic/transliteration/translation
                // triplet closes it off - a standalone heading or instruction
                // line (absent from groupForLine) never gets a trailing
                // divider of its own.
                final group = parsedContent.groupForLine[contentIndex];
                final closesGroup =
                    group != null && contentIndex == group.end - 1;
                return _withParagraphDivider(
                  content,
                  showDivider: closesGroup && !isLastItem,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Appends the same thin divider [_AyahBlock] draws between verses, below
  /// [content], so a zikr's paragraphs read as separated steps the way a
  /// surah's verses already do. Omitted for the last paragraph of a tab,
  /// where there is nothing left to separate it from.
  Widget _withParagraphDivider(Widget content, {required bool showDivider}) {
    if (!showDivider) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        Divider(
          height: 20,
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ],
    );
  }

  /// One content line, styled by its role.
  ///
  /// Shared by both rendering paths so an ayah block and a plain line list draw
  /// identical text - the ayah path only changes how lines are grouped, never
  /// how any one of them looks.
  Widget _buildLine(
    ParsedZikrContent parsedContent,
    int contentIndex,
    TextStyle arabicStyle,
    TextStyle transliStyle,
  ) {
    final str = parsedContent.lines[contentIndex].trim();

    if (parsedContent.arabicCodes.contains(contentIndex)) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
        child: Text.rich(
          _buildTextSpanForLine(
            ZikrContentParser.formatArabicText(str),
            arabicStyle,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
      );
    }

    if (parsedContent.transliCodes.contains(contentIndex)) {
      return showTransliteration
          ? Text.rich(
              _buildTextSpanForLine(str.toUpperCase(), transliStyle),
              textAlign: TextAlign.center,
            )
          : Container();
    }

    if (parsedContent.translaCodes.contains(contentIndex)) {
      return showTranslation
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text.rich(
                _buildTextSpanForLine(
                  str,
                  TextStyle(fontSize: englishFontSize),
                ),
                textAlign: TextAlign.center,
              ),
            )
          : Container();
    }

    // A standalone line that isn't part of an Arabic/transliteration/
    // translation triplet is narration, personal commentary, a heading, or a
    // source citation.
    return _footnoteBox(
      Text.rich(_buildTextSpanForLine(str, const TextStyle())),
    );
  }

  /// Renders a run of consecutive standalone lines - narration, commentary,
  /// a heading, a citation - as one continuous block, so the accent reads as
  /// a single unbroken rule instead of a separately margined, separately
  /// bordered box per line. [_buildReadingListItems] is what folds such a
  /// run into one [_ReadingListItem] in the first place.
  ///
  /// A bookmark can in principle land on one of these lines - it is just
  /// whatever line was topmost when the reader last left the tab - so
  /// [bookmarkLabelLine], when it names one of this block's own lines, gets
  /// the same "Bookmarked" label and tint a single bookmarked line would
  /// otherwise carry via [_BookmarkedLine].
  Widget _buildFootnoteBlock(
    _ReadingListItem item,
    ParsedZikrContent parsedContent,
    int? bookmarkLabelLine,
  ) {
    final paragraphs = <Widget>[];
    for (final lineIndex in item.lineIndexes) {
      if (paragraphs.isNotEmpty) paragraphs.add(const SizedBox(height: 10));
      final isBookmarked = lineIndex == bookmarkLabelLine;
      if (isBookmarked) {
        paragraphs.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _bookmarkLabelRow(context),
          ),
        );
      }
      final str = parsedContent.lines[lineIndex].trim();
      final textSpan = _buildTextSpanForLine(str, const TextStyle());
      paragraphs.add(
        Text.rich(
          isBookmarked
              ? TextSpan(
                  style: TextStyle(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4),
                  ),
                  children: [textSpan],
                )
              : textSpan,
        ),
      );
    }
    return _footnoteBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: paragraphs,
      ),
    );
  }

  /// The start-edge accent that marks a standalone line's text as
  /// quoted/reference material - never Arabic script that could wrap
  /// right-to-left, so a directional border reads correctly - without an
  /// italic slant, matching the reader's own blockquote treatment (see
  /// readerStyleSheet in reader_style.dart).
  Widget _footnoteBox(Widget child) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4.0),
      padding: const EdgeInsetsDirectional.only(start: 14.0),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
            width: 3,
          ),
        ),
      ),
      child: child,
    );
  }

  /// One whole verse - its Arabic, transliteration and translation together -
  /// as a single tappable item.
  Widget _buildAyahBlock({
    required AyahIndex ayahIndex,
    required int spanIndex,
    required ParsedZikrContent parsedContent,
    required TextStyle arabicStyle,
    required TextStyle transliStyle,
    required ZikrLineGroup? bookmarkedRange,
  }) {
    final span = ayahIndex.spans[spanIndex];
    final lines = <Widget>[
      for (var i = span.start; i < span.end; i++)
        _buildLine(parsedContent, i, arabicStyle, transliStyle),
    ];

    final verse = span.verse;
    return _AyahBlock(
      ayah: span.ayah,
      startsSurah: span.startsSurah,
      isSaved: verse != null && widget.savedVerses.contains(verse),
      isBookmarked:
          bookmarkedRange != null && span.contains(bookmarkedRange.start),
      aliNote: verse == null ? null : aliRelatedNoteFor(verse),
      onAction: verse == null || widget.onAyahAction == null
          ? null
          : () => _requestAyahAction(parsedContent, span),
      children: lines,
    );
  }

  /// Opens the per-verse menu for [span], when the page offers one.
  void _requestAyahAction(ParsedZikrContent parsedContent, AyahSpan span) {
    final verse = span.verse;
    final onAction = widget.onAyahAction;
    if (verse == null || onAction == null) return;
    onAction(
      AyahActionRequest(
        verse: verse,
        text: _ayahPlainText(parsedContent, span),
        lineIndex: span.start,
        aliNote: aliRelatedNoteFor(verse),
      ),
    );
  }

  /// A surah in paragraph mode - or the part of it a juz holds: its verses
  /// flowing together
  /// as one right-aligned, justified, ruled paragraph - the layout every other
  /// zikr gets from [_buildArabicParagraphItem] - while keeping what makes a
  /// surah more than text:
  ///
  /// * each verse still its own tap target, found from where the tap lands in
  ///   the laid-out text, opening the same per-verse menu;
  /// * a saved verse's number drawn in the primary colour, a mark on the
  ///   verse itself rather than a tint over running text it shares;
  /// * the bookmarked verse tinted in place with a bookmark icon at its
  ///   start, as in any flowing paragraph;
  /// * the surah heading, where a juz crosses into a new surah - which
  ///   [quranParagraphSpanRuns] guarantees only ever happens at the top of one.
  ///
  /// The verses' text offsets are recorded on [paragraph] as the span is
  /// built, so the reading position and scroll-to-verse can work inside it.
  Widget _buildQuranParagraphItem({
    required _QuranParagraph paragraph,
    required AyahIndex ayahIndex,
    required ParsedZikrContent parsedContent,
    required TextStyle arabicStyle,
    required ZikrLineGroup? bookmarkedRange,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final spans = [for (final i in paragraph.spanIndexes) ayahIndex.spans[i]];

    final bookmarkedSpan = bookmarkedRange == null
        ? null
        : spans
            .where((span) => span.contains(bookmarkedRange.start))
            .firstOrNull;

    final children = <InlineSpan>[];
    final textStarts = <int>[];
    var length = 0;
    for (var k = 0; k < spans.length; k++) {
      final span = spans[k];
      final verse = span.verse;
      if (k > 0) {
        // Just a plain space, as in any flowing paragraph: the rule under
        // each row is what a reciter tracks by, and the verse's own medallion
        // already marks where it ends.
        children.add(const TextSpan(text: ' '));
        length += 1;
      }
      textStarts.add(length);

      final formatted = ZikrContentParser.formatArabicText(
        parsedContent.lines[span.start].trim(),
      );
      final marker = _trailingVerseMarker.firstMatch(formatted);
      final body =
          marker == null ? formatted : formatted.substring(0, marker.start);
      final isSaved = verse != null && widget.savedVerses.contains(verse);

      final isBookmarked = span == bookmarkedSpan;
      final verseSpan = TextSpan(
        style: isBookmarked
            ? TextStyle(
                backgroundColor:
                    colorScheme.primaryContainer.withValues(alpha: 0.55),
              )
            : null,
        children: [
          if (isBookmarked)
            _inlineBookmarkSpan(colorScheme.primary, arabicStyle.fontSize),
          _buildTextSpanForLine(body, arabicStyle),
          if (marker != null)
            TextSpan(
              text: marker.group(0),
              style: isSaved
                  ? arabicStyle.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    )
                  : arabicStyle,
            ),
        ],
      );
      children.add(verseSpan);
      length += verseSpan.toPlainText(includeSemanticsLabels: false).length;
    }
    paragraph.textStarts = textStarts;

    final paragraphStyle = arabicStyle.copyWith(height: 2.0);
    final first = spans.first;

    final canAct = widget.onAyahAction != null;
    void actAt(RenderParagraph text, Offset globalPosition) {
      final position =
          text.getPositionForOffset(text.globalToLocal(globalPosition));
      final spanIndex = paragraph.spanIndexAtTextOffset(position.offset);
      _requestAyahAction(parsedContent, ayahIndex.spans[spanIndex]);
    }

    Widget ruled = Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: _RuledArabicParagraph(
        textKey: paragraph.textKey,
        span: TextSpan(style: paragraphStyle, children: children),
      ),
    );
    if (canAct) {
      ruled = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final laidOut = paragraph.laidOutText;
          if (laidOut != null) actAt(laidOut, details.globalPosition);
        },
        onLongPressStart: (details) {
          final laidOut = paragraph.laidOutText;
          if (laidOut != null) actAt(laidOut, details.globalPosition);
        },
        child: ruled,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (first.startsSurah != null)
            _SurahHeading(surah: first.startsSurah!),
          ruled,
          Divider(
            height: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  /// The verse as text worth copying or sharing: its Arabic and, when the
  /// reader has them switched on, the transliteration and translation they are
  /// reading alongside it.
  String _ayahPlainText(ParsedZikrContent parsedContent, AyahSpan span) {
    final parts = <String>[];
    for (var i = span.start; i < span.end; i++) {
      final line = parsedContent.lines[i].trim();
      if (line.isEmpty || !isZikrLineVisible(parsedContent, i)) continue;
      parts.add(line);
    }
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final showTabHeaders = widget.tabContents.length > 1;
    _syncTabState(widget.tabContents.length);

    return Column(
      children: [
        if (showTabHeaders)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.tabContents.length,
                          (index) {
                            final isSelected = index == _selectedTabIndex;
                            return Padding(
                              key: _tabHeaderKeys[index],
                              padding: EdgeInsets.only(
                                right: index == widget.tabContents.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: Material(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(18),
                                elevation: isSelected ? 2 : 0,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _animateToTab(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      _getTabHeader(
                                        widget.tabContents[index],
                                        index,
                                      ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.78),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.tabContents.length,
            onPageChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
              widget.onTabChanged(index);
              _centerSelectedTab();
              _scheduleScrollPositionReport(index);
            },
            itemBuilder: (context, index) => _buildTabContent(
              widget.tabContents[index],
              _tabScrollControllers[index],
              tabIndex: index,
              hideHeaderLine: showTabHeaders,
              showMeritsButton: widget.hasMerits && index == 0,
            ),
            pageSnapping: true,
            physics: const PageScrollPhysics(),
          ),
        ),
      ],
    );
  }
}

/// A parsed tab, kept so a scroll does not reparse the text every frame.
class _TabContentCache {
  _TabContentCache({
    required this.rawContent,
    required this.hideHeaderLine,
    required this.parsed,
    required this.ayahIndex,
  });

  final String rawContent;
  final bool hideHeaderLine;
  final ParsedZikrContent parsed;

  /// Null for everything that is not Quran, which is what keeps every other
  /// zikr on the line-by-line rendering path.
  final AyahIndex? ayahIndex;

  /// How this surah flows in paragraph mode, built the first time it is read
  /// that way and then kept: each paragraph holds the key its text is
  /// measured by, and a key minted afresh every build would remount the text
  /// - and lose the measurement - on every scroll.
  _QuranParagraphs? get quranParagraphs {
    final index = ayahIndex;
    if (index == null) return null;
    return _quranParagraphs ??= _QuranParagraphs.build(index);
  }

  _QuranParagraphs? _quranParagraphs;
}

/// Names the surah a juz has just moved into.
///
/// Only ever drawn inside a portion that spans surahs. Reading a single surah
/// needs no such marker - the page title is already its name - so this is
/// absent from that path entirely rather than duplicating it.
class _SurahHeading extends StatelessWidget {
  const _SurahHeading({required this.surah});

  final SurahInfo surah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // No rule of its own. At a surah boundary the preceding verse's separator
    // already draws one, and adding a second stacked a few pixels under it;
    // at the top of a portion there is nothing above, so it drew a line
    // floating in space. Room and type mark the transition instead.
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 8),
      child: Column(
        children: [
          Text(
            '${surah.number}. ${surah.englishName}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (surah.arabicName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                surah.arabicName,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontFamilyFallback: const ['Qalam'],
                  fontSize: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One verse of the Quran, drawn as a single item.
///
/// The verse number is already inside the Arabic, as the medallion the corpus
/// is authored with - but at the end of the line and in Arabic-Indic digits,
/// which is no help when you are looking for ayah 156. The badge here is for
/// scanning: small, muted, and at the start where the eye lands.
class _AyahBlock extends StatelessWidget {
  const _AyahBlock({
    required this.ayah,
    required this.startsSurah,
    required this.isSaved,
    required this.isBookmarked,
    required this.aliNote,
    required this.onAction,
    required this.children,
  });

  /// Null for the Bismillah heading a surah, which is drawn without a badge
  /// because it is not a numbered verse.
  final int? ayah;

  /// Set on the first verse of each surah in a juz, where the reader crosses
  /// from one surah into the next and the page title cannot say which.
  final SurahInfo? startsSurah;

  /// Whether the reader has kept this verse. Drawn as a small mark beside the
  /// number rather than a tint, so a page of saved verses still reads calmly.
  final bool isSaved;

  final bool isBookmarked;

  /// Set when this verse is one Shia tafsir cites as being about Imam Ali
  /// (as); its text is the occasion or title the verse is known by, shown as
  /// a tooltip on the badge. Null for every other verse, which is most of
  /// them, so the badge stays rare enough to mean something when it appears.
  final String? aliNote;

  final VoidCallback? onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final block = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (startsSurah != null) _SurahHeading(surah: startsSurah!),
          if (ayah != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (isBookmarked) ...[
                    Icon(Icons.bookmark, size: 13, color: colorScheme.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    '$ayah',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isBookmarked
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                  ),
                  if (isSaved) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.bookmark,
                      size: 13,
                      color: colorScheme.primary.withValues(alpha: 0.85),
                    ),
                  ],
                  if (aliNote != null) ...[
                    const SizedBox(width: 6),
                    _AliBadge(note: aliNote!),
                  ],
                ],
              ),
            ),
          ...children,
          Divider(
            height: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );

    final decorated = isBookmarked
        ? Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 3),
              ),
            ),
            child: block,
          )
        : block;

    if (onAction == null) return decorated;

    return InkWell(
      onTap: onAction,
      onLongPress: onAction,
      child: decorated,
    );
  }
}

/// The mark beside a verse's number when Shia tafsir cites it as being about
/// Imam Ali (as) - see [quranAliVerses]. A small gold seal with "علي" set
/// inside it, rather than a plain icon: the name itself is the point, not a
/// generic "this is special" glyph. A `Tooltip` rather than a tappable chip -
/// the whole ayah block is already a tap target for [AyahActionRequest], so
/// the seal only needs to answer "why is this marked" on long-press/hover,
/// not compete for the tap itself.
///
/// The gold is a fixed pair of colors rather than anything drawn from the
/// theme: a seal reads as gold in both light and dark reading modes, the way
/// actual wax or foil would, not as "whatever the app's primary color is."
class _AliBadge extends StatelessWidget {
  const _AliBadge({required this.note});

  final String note;

  static const _sealHighlight = Color(0xFFE7C878);
  static const _sealShadow = Color(0xFF8F6B1E);
  static const _sealInk = Color(0xFF2C2109);

  @override
  Widget build(BuildContext context) {
    // The ring the seal sits in is cut from the page behind it, so the gold
    // never collides with a bookmark tint or the primary-container wash a
    // saved verse already gets.
    final ringColor = Theme.of(context).colorScheme.surface;

    return Tooltip(
      message: note,
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.35),
            colors: [_sealHighlight, _sealShadow],
          ),
          border: Border.all(color: ringColor, width: 1.4),
          boxShadow: [
            BoxShadow(
                color: _sealShadow.withValues(alpha: 0.65), spreadRadius: 0.6),
          ],
        ),
        child: Text(
          'علي',
          style: TextStyle(
            fontFamily: arabicFont,
            fontFamilyFallback: const ['Qalam'],
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
            color: _sealInk,
          ),
        ),
      ),
    );
  }
}

/// The "you left off here" landmark itself - a tinted, left-bordered wash
/// with a small label, filling whatever height [Positioned] gives it. Reuses
/// the same primary/primaryContainer pairing as the bookmark action's own
/// filled-pill state, so the two read as the one feature.
/// Wraps a single line of a bookmarked verse in a tint and a left border.
/// Every line in the verse gets one of these, not one container around the
/// whole group - the ListView builds one item at a time, so this is what
/// keeps the tint a property of the actual lines rather than a separate
/// element that has to be positioned over them. Consecutive lines' tints and
/// borders sit flush against each other, reading as one continuous block.
class _BookmarkedLine extends StatelessWidget {
  const _BookmarkedLine({required this.showLabel, required this.child});

  /// Only the verse's first line carries the "Bookmarked" label - repeating
  /// it on every line under the same tint would just be noise.
  final bool showLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: showLabel ? 6 : 0,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _bookmarkLabelRow(context),
            ),
          child,
        ],
      ),
    );
  }
}

/// A right-aligned, justified block of Arabic text with a thin rule under
/// every rendered row - not just between merged sentences - so a reciter can
/// track which row they are on the way ruled paper would, even where several
/// short sentences share one of those rows.
///
/// [Text.rich] has no per-line decoration hook: a wrapped line only exists
/// once the paragraph has actually been laid out, and that layout depends on
/// the width it is given, which is only known at build time. So this lays
/// [span] out a second time itself, with a throwaway [TextPainter] built with
/// the exact width, style, alignment and text scale the real [Text.rich]
/// below it will use, purely to read back where each line actually broke via
/// [TextPainter.computeLineMetrics] - then paints a rule at each line's
/// bottom edge, under the text rather than instead of it.
class _RuledArabicParagraph extends StatelessWidget {
  const _RuledArabicParagraph({required this.span, this.textKey});

  final TextSpan span;

  /// Put on the [Text.rich] itself, for a caller that needs to measure the
  /// laid-out text - where each verse fell - rather than the whole block.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    // Same color and weight _withParagraphDivider already draws between
    // whole paragraphs, so a row rule and a paragraph divider read as the
    // one kind of mark instead of two different-looking ones.
    final ruleColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: span,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);
        final lines = painter.computeLineMetrics();
        painter.dispose();

        // Only between rows, not after the last one - the block's own
        // bottom padding, and the divider _withParagraphDivider draws below
        // it, already close the block off.
        var top = 0.0;
        final rules = <Widget>[];
        for (var i = 0; i < lines.length - 1; i++) {
          top += lines[i].height;
          rules.add(Positioned(
            left: 0,
            right: 0,
            top: top,
            child: Container(height: 1.0, color: ruleColor),
          ));
        }

        return Stack(
          children: [
            ...rules,
            Text.rich(
              span,
              key: textKey,
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
            ),
          ],
        );
      },
    );
  }
}
