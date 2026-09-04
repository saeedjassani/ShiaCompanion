import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../constants.dart';
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
    required this.fromUserScroll,
  });

  /// The surah as well as the ayah: a juz runs across surahs, so an ayah
  /// number on its own does not say where the reader is.
  final VerseKey verse;

  final bool fromUserScroll;
}

/// A verse the reader tapped, and what the page needs to act on it.
class AyahActionRequest {
  const AyahActionRequest({
    required this.verse,
    required this.text,
    required this.lineIndex,
  });

  /// Which verse was tapped, surah included - in a juz the surah is not the
  /// one the page as a whole is showing.
  final VerseKey verse;

  /// The verse as text worth copying or sharing.
  final String text;

  /// The content line the verse starts on, which is what a bookmark records.
  final int lineIndex;
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

class ZikrContentViewerWidget extends StatefulWidget {
  final List<String> tabContents;
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final bool hasMerits;
  final VoidCallback onShowMerits;
  final String? code;
  final Future<void> Function(String href) onLinkTap;
  final int? initialBookmarkTabIndex;
  final double? initialBookmarkScrollOffset;

  /// The content line the saved bookmark sits on, when it has one. This is
  /// what the marker is drawn on; the offset above is only used to scroll
  /// back there.
  final int? initialBookmarkLineIndex;
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
    this.code,
    this.initialBookmarkTabIndex,
    this.initialBookmarkScrollOffset,
    this.initialBookmarkLineIndex,
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

  /// Whether this reader has actually been dragged. Set only by real drag
  /// gestures - never by a jump to a linked verse or a bookmark restore - so a
  /// lookup can be told apart from recitation. See [QuranReadingPosition].
  bool _sawUserDrag = false;

  bool _didScrollToInitialVerse = false;
  bool _verseReportScheduled = false;
  VerseKey? _reportedVerse;
  late int _selectedTabIndex;
  late final int? _initialBookmarkTabIndex;
  late final double? _initialBookmarkScrollOffset;
  bool _didRestoreInitialBookmark = false;

  TextSpan _buildTextSpanForLine(String rawLine, TextStyle baseStyle) {
    final linkStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );

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
            ..onTap = () {
              widget.onLinkTap(segment.href!);
            },
        );
      }).toList(),
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
  /// [topContentLineIndex] measures the topmost *item*, and in ayah mode an
  /// item is a whole verse rather than a line - so its answer is a span index
  /// there and has to be turned back into a line before anything that speaks
  /// in lines, the bookmark above all, is handed it.
  int? _topLineIndex(int tabIndex, ScrollController controller) {
    final topIndex = topContentLineIndex(tabIndex, controller);
    if (topIndex == null) return null;

    final ayahIndex = _ayahIndexFor(tabIndex);
    if (ayahIndex == null) return topIndex;
    if (topIndex < 0 || topIndex >= ayahIndex.spans.length) return null;
    return ayahIndex.spans[topIndex].start;
  }

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

    final spanIndex = topContentLineIndex(tabIndex, controller);
    if (spanIndex == null) return;

    final verse = ayahIndex.verseAtSpanIndex(spanIndex);
    if (verse == null || verse == _reportedVerse) return;

    _reportedVerse = verse;
    callback(
      QuranReadingPosition(verse: verse, fromUserScroll: _sawUserDrag),
    );
  }

  /// Brings [verse] to the top of the view.
  ///
  /// A `ListView.builder` cannot seek to an index, and lines wrap to different
  /// heights so there is no fixed extent to invert. This estimates an offset,
  /// lets the frame build, and then - now that the target is on screen - reads
  /// back which item actually ended up on top and corrects. In ayah mode the
  /// items are whole verses rather than single lines, so the estimate is close
  /// enough that this settles in a pass or two.
  Future<void> _scrollToVerse(
    int tabIndex,
    AyahIndex ayahIndex,
    VerseKey verse,
    int leadingItems,
  ) async {
    final spanIndex = ayahIndex.nearestSpanIndexForVerse(verse);
    if (spanIndex == null || tabIndex >= _tabScrollControllers.length) return;

    final controller = _tabScrollControllers[tabIndex];
    final itemCount = ayahIndex.spans.length + leadingItems;

    for (var attempt = 0; attempt < 5; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !controller.hasClients) return;

      final position = controller.position;
      if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
        return;
      }

      final landed = topContentLineIndex(tabIndex, controller);
      if (landed == spanIndex) return;

      // Aim by proportion, then let the next pass correct off the real
      // position rather than trusting the estimate.
      final target = landed == null
          ? position.maxScrollExtent *
              ((spanIndex + leadingItems) / itemCount)
          : position.pixels +
              (spanIndex - landed) *
                  (position.maxScrollExtent / itemCount);

      controller.jumpTo(
        target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
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

  /// The content line currently at the top of tab [tabIndex]'s view, read off
  /// the laid-out list, or null if it has not been laid out yet.
  ///
  /// This is the line a bookmark taken now records. It is measured rather
  /// than estimated from the scroll fraction: line heights vary with the
  /// content, the font settings and the width, so there is no pixels-per-line
  /// to invert, and an estimate drifts to a different line whenever anything
  /// changes the layout underneath it.
  int? topContentLineIndex(int tabIndex, ScrollController controller) {
    if (!controller.hasClients || tabIndex >= _tabListKeys.length) return null;

    final renderObject =
        _tabListKeys[tabIndex].currentContext?.findRenderObject();
    if (renderObject == null) return null;
    final sliver = _findSliverList(renderObject);
    if (sliver == null) return null;

    final scrollOffset = controller.position.pixels;
    // Children are held in index order, so the first one whose bottom edge is
    // still below the top of the viewport is the line being read. Lines the
    // reader has switched off lay out at zero height and are skipped by the
    // same test.
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
          // The Merits button is not content; a reader still up at it is at
          // the top of the content just below it.
          final contentIndex = index - _leadingItemCount(tabIndex);
          return contentIndex < 0 ? 0 : contentIndex;
        }
      }
      child = sliver.childAfter(child);
    }
    return null;
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
    final bookmarkOffset = _initialBookmarkScrollOffset;
    if (_didRestoreInitialBookmark ||
        bookmarkTabIndex == null ||
        bookmarkOffset == null ||
        bookmarkOffset <= 0 ||
        tabIndex != bookmarkTabIndex) {
      return;
    }

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
      // restored offset can only be measured a frame later. That measurement
      // is what a bookmark saved before line indexes existed adopts as its
      // line, which is exactly the line it was taken on.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.hasClients) return;
        _reportScrollPosition(tabIndex, controller);
        if (widget.initialBookmarkLineIndex != null) return;
        // _topLineIndex, not topContentLineIndex: in ayah mode an item is a
        // whole verse, so the raw measurement is a span index and storing it
        // as a line would point the marker at the wrong text.
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
        cached.hideHeaderLine == hideHeaderLine &&
        cached.code == widget.code) {
      return cached;
    }

    final parsed = ZikrContentParser.parseContent(
      rawContent,
      hideHeaderLine: hideHeaderLine,
      code: widget.code,
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
      code: widget.code,
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
        (ayahIndex != null
            ? ayahIndex.spans.length
            : parsedContent.lines.length);

    if (ayahIndex != null && tabIndex == _selectedTabIndex) {
      _scheduleInitialVerseScroll(tabIndex, ayahIndex, leadingItems);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Only a real drag counts as reading. A jump to a linked verse and a
        // bookmark restore both scroll this list too, and neither should move
        // the reader's saved place.
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _sawUserDrag = true;
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

              final contentIndex = index - leadingItems;

              if (ayahIndex != null) {
                return _buildAyahBlock(
                  ayahIndex: ayahIndex,
                  spanIndex: contentIndex,
                  parsedContent: parsedContent,
                  arabicStyle: arabicStyle,
                  transliStyle: transliStyle,
                  bookmarkedRange: bookmarkedRange,
                );
              }

              final line = _buildLine(
                parsedContent,
                contentIndex,
                arabicStyle,
                transliStyle,
              );

              if (bookmarkedRange == null ||
                  bookmarkLabelLine == null ||
                  !bookmarkedRange.contains(contentIndex) ||
                  !isZikrLineVisible(parsedContent, contentIndex)) {
                return line;
              }
              return _BookmarkedLine(
                // The label only belongs on the first line of the marked
                // triplet that is actually showing - repeating it on the
                // transliteration/translation lines under the same tint would
                // just be noise, and a switched-off line draws nothing to
                // carry it.
                showLabel: contentIndex == bookmarkLabelLine,
                child: line,
              );
            },
          ),
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4.0),
      child: Text.rich(
        _buildTextSpanForLine(
          str,
          const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
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
      isBookmarked: bookmarkedRange != null && span.contains(bookmarkedRange.start),
      onAction: verse == null || widget.onAyahAction == null
          ? null
          : () => widget.onAyahAction!(
                AyahActionRequest(
                  verse: verse,
                  text: _ayahPlainText(parsedContent, span),
                  lineIndex: span.start,
                ),
              ),
      children: lines,
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
  const _TabContentCache({
    required this.rawContent,
    required this.hideHeaderLine,
    required this.code,
    required this.parsed,
    required this.ayahIndex,
  });

  final String rawContent;
  final bool hideHeaderLine;
  final String? code;
  final ParsedZikrContent parsed;

  /// Null for everything that is not Quran, which is what keeps every other
  /// zikr on the line-by-line rendering path.
  final AyahIndex? ayahIndex;
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

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        children: [
          Divider(color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${surah.number}. ${surah.englishName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
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
    required this.isBookmarked,
    required this.onAction,
    required this.children,
  });

  /// Null for the Bismillah heading a surah, which is drawn without a badge
  /// because it is not a numbered verse.
  final int? ayah;

  /// Set on the first verse of each surah in a juz, where the reader crosses
  /// from one surah into the next and the page title cannot say which.
  final SurahInfo? startsSurah;

  final bool isBookmarked;
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
              child: Row(
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
              ),
            ),
          child,
        ],
      ),
    );
  }
}
