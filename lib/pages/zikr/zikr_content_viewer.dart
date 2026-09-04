import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../utils/quran_index.dart';
import 'zikr_content_parser.dart';

/// Where a reader is in a surah, and whether they got there by reading.
///
/// [fromUserScroll] is the whole point of this type. Landing on 23:56 from a
/// shared link is a lookup, not recitation, so it must not become the reader's
/// saved place; dragging the list is. The viewer is the only thing that can
/// tell the two apart, so it reports which happened rather than leaving the
/// page to guess from scroll offsets.
class QuranReadingPosition {
  const QuranReadingPosition({
    required this.ayah,
    required this.fromUserScroll,
  });

  final int ayah;
  final bool fromUserScroll;
}

/// A verse the reader tapped, and everything the page needs to act on it.
///
/// [scrollOffset] is carried because it is only knowable here: bookmarking is
/// stored as a scroll position, and the viewer is the only thing that can say
/// where a given verse sits in the list. Null when the verse's geometry cannot
/// be read, in which case the page falls back to bookmarking the view.
class AyahActionRequest {
  const AyahActionRequest({
    required this.ayah,
    required this.text,
    required this.scrollOffset,
  });

  final int ayah;

  /// The verse as text worth copying or sharing.
  final String text;

  final double? scrollOffset;
}

class ZikrContentScrollPosition {
  const ZikrContentScrollPosition({
    required this.tabIndex,
    required this.scrollOffset,
    this.maxScrollExtent = 0,
  });

  final int tabIndex;
  final double scrollOffset;
  final double maxScrollExtent;
}

/// Which line of a tab's content a bookmark saved at [scrollFraction] of the
/// way through it (0 = top, 1 = bottom) should be pinned to, snapped back to
/// the nearest line in [arabicLineIndexes] at or before that point - so the
/// marker always lands on the verse showing at the top of the view, never
/// mid-verse or straddling two.
///
/// A raw scroll pixel offset by itself doesn't correspond to any one line -
/// lines wrap to different heights depending on content and the reader's own
/// font settings, so there is no fixed pixels-per-line to invert. Treating
/// every line as equal weight and snapping to the nearest verse start is
/// precise enough to say "about here", without needing real layout
/// measurements to do it.
///
/// Backward, not forward: this was originally forward (the nearest verse at
/// or after the estimate), on the reasoning that reading continues past
/// whatever was on screen. In practice a verse then stayed "current" for
/// only the single instant the estimate sat exactly on its start index - any
/// small scroll drift pushed the estimate just past it and the marker jumped
/// to the next verse. Bookmarking twice in a row without deliberately
/// scrolling could visibly creep forward one verse at a time. Snapping
/// backward instead is stable across a verse's whole span: the marker holds
/// steady from that verse's start up to wherever the next one begins.
int? snapToArabicLineIndex({
  required double scrollFraction,
  required int lineCount,
  required Set<int> arabicLineIndexes,
}) {
  if (lineCount <= 0 || arabicLineIndexes.isEmpty) return null;

  final estimated = (scrollFraction.clamp(0.0, 1.0) * (lineCount - 1)).round();

  int? atOrBefore;
  for (final index in arabicLineIndexes) {
    if (index <= estimated && (atOrBefore == null || index > atOrBefore)) {
      atOrBefore = index;
    }
  }
  // No Arabic line at or before the estimate - the reader was somewhere
  // ahead of the first verse (an intro paragraph, say), so the first verse
  // is the closest thing to "the top of what's visible".
  return atOrBefore ?? arabicLineIndexes.reduce(math.min);
}

/// The span of content-line indexes, `[start, end)`, that make up one verse
/// starting at an Arabic line - everything up to (but not including) whatever
/// Arabic line comes next, or the end of the tab if this is the last verse.
class BookmarkedVerseRange {
  const BookmarkedVerseRange({required this.start, required this.end});

  final int start;
  final int end;

  bool contains(int lineIndex) => lineIndex >= start && lineIndex < end;

  static BookmarkedVerseRange? fromStart(
    int? startIndex, {
    required Set<int> arabicLineIndexes,
    required int lineCount,
  }) {
    if (startIndex == null) return null;
    final end = arabicLineIndexes
        .where((i) => i > startIndex)
        .fold(lineCount, math.min);
    return BookmarkedVerseRange(start: startIndex, end: end);
  }
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
  final ValueChanged<ZikrContentScrollPosition>? onScrollPositionChanged;

  /// Which surah this is, when the document being read is one of the 114.
  ///
  /// Null for every other zikr, and that is what selects the rendering path:
  /// null means one widget per line, exactly as this viewer has always worked.
  /// Non-null switches to one widget per ayah, so verses can be numbered,
  /// tapped, scrolled to and reported on.
  final int? surahNumber;

  /// The ayah to open at, for a `/quran/23/56` link or a resumed recitation.
  final int? initialAyah;

  /// Fires with the topmost ayah on screen. Only meaningful in ayah mode.
  final ValueChanged<QuranReadingPosition>? onAyahPositionChanged;

  /// Opens the per-ayah menu. Null leaves verses untappable.
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
    this.onScrollPositionChanged,
    this.surahNumber,
    this.initialAyah,
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
  late int _selectedTabIndex;
  late final int? _initialBookmarkTabIndex;
  late final double? _initialBookmarkScrollOffset;
  bool _didRestoreInitialBookmark = false;

  /// Parsing and indexing a tab is pure work over a string that rarely
  /// changes, but [_buildTabContent] runs on every build. Al-Baqarah is 858
  /// lines, so caching by content keeps a scroll from re-parsing it each frame.
  final Map<int, _TabContentCache> _contentCaches = {};

  /// One key per ayah block of the selected tab, so a verse can be scrolled to
  /// exactly once it is built, and so the topmost one can be identified from
  /// real geometry rather than an estimate.
  final Map<int, GlobalKey> _ayahKeys = {};

  /// Whether this reader has actually been dragged. Set only by real drag
  /// gestures - never by [_scrollToAyah] or a bookmark restore - so a lookup
  /// can be told apart from recitation. See [QuranReadingPosition].
  bool _sawUserDrag = false;

  bool _didScrollToInitialAyah = false;
  bool _ayahReportScheduled = false;
  int? _reportedAyah;

  GlobalKey _ayahKey(int spanIndex) =>
      _ayahKeys.putIfAbsent(spanIndex, () => GlobalKey());

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
      ),
    );
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

    // Only the first tab of a surah is Quran text. Surah documents are
    // single-tab today, but guarding on the index means a tabbed one would
    // degrade to line rendering on its extra tabs rather than mis-number them.
    final ayahIndex = widget.surahNumber != null && tabIndex == 0
        ? AyahIndex.fromParsedContent(parsed)
        : null;

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

  /// Brings [ayah] to the top of the view.
  ///
  /// A `ListView.builder` cannot seek to an index, and lines wrap to different
  /// heights so there is no fixed extent to invert. This estimates an offset,
  /// lets the frame build, and then - now that the target widget exists - hands
  /// off to [Scrollable.ensureVisible], which is exact. In ayah mode the items
  /// are whole verses rather than single lines, so the estimate is close enough
  /// that this usually settles on the first pass; the loop is the safety net
  /// for a surah whose verses vary a lot in length.
  Future<void> _scrollToAyah(
    int tabIndex,
    AyahIndex ayahIndex,
    int ayah,
    int itemCount,
  ) async {
    final spanIndex = ayahIndex.nearestSpanIndexForAyah(ayah);
    if (spanIndex == null || tabIndex >= _tabScrollControllers.length) return;

    final controller = _tabScrollControllers[tabIndex];
    final itemIndex = spanIndex + (itemCount - ayahIndex.spans.length);

    for (var attempt = 0; attempt < 4; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !controller.hasClients) return;

      final targetContext = _ayahKey(spanIndex).currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0,
          duration: Duration.zero,
        );
        return;
      }

      final position = controller.position;
      if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
        continue;
      }
      final estimate = position.maxScrollExtent * (itemIndex / itemCount);
      controller.jumpTo(
        estimate
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    }
  }

  /// Queues a position report for the end of the current frame.
  ///
  /// The read has to happen after layout, not during the scroll notification
  /// that prompts it: a scroll notification is dispatched when the offset
  /// changes, which is before the children have been laid out at their new
  /// positions. Reading geometry there returns the previous frame's, and a
  /// gesture that produces many updates before a single layout - a fling, or a
  /// synthesised drag - would read the same stale positions every time and
  /// never notice the reader had moved at all. Coalescing to one read per
  /// frame is also simply cheaper than one per notification.
  void _scheduleAyahReport(AyahIndex ayahIndex, ScrollController controller) {
    if (_ayahReportScheduled) return;

    _ayahReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ayahReportScheduled = false;
      if (!mounted) return;
      _reportTopmostAyah(ayahIndex, controller);
    });
  }

  /// Publishes the ayah sitting at the top of the view.
  ///
  /// Reads the real position of the blocks currently built rather than
  /// estimating from a scroll fraction, so the answer is the verse the reader
  /// is actually looking at.
  void _reportTopmostAyah(AyahIndex ayahIndex, ScrollController controller) {
    final callback = widget.onAyahPositionChanged;
    if (callback == null || !controller.hasClients) return;

    final viewportTop = _viewportTopGlobalY(controller);
    if (viewportTop == null) return;

    int? topmost;
    var bestY = double.negativeInfinity;
    _ayahKeys.forEach((spanIndex, key) {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;

      final y = renderObject.localToGlobal(Offset.zero).dy;
      // The topmost block whose start is at or above the fold - the one the
      // reader has reached - rather than the first one merely visible.
      if (y <= viewportTop + _ayahTopSlack && y > bestY) {
        bestY = y;
        topmost = spanIndex;
      }
    });

    final spanIndex = topmost;
    if (spanIndex == null) return;

    final ayah = ayahIndex.ayahAtSpanIndex(spanIndex);
    if (ayah == null || ayah == _reportedAyah) return;

    _reportedAyah = ayah;
    callback(
      QuranReadingPosition(ayah: ayah, fromUserScroll: _sawUserDrag),
    );
  }

  /// Where a verse sits in the list, as a scroll offset.
  ///
  /// This is what makes "bookmark this verse" possible: the bookmark store
  /// records a scroll position, and only the laid-out block knows what position
  /// it is at. Null when the block is not currently built or measured.
  double? _scrollOffsetOfSpan(int tabIndex, int spanIndex) {
    if (tabIndex >= _tabScrollControllers.length) return null;

    final controller = _tabScrollControllers[tabIndex];
    if (!controller.hasClients) return null;

    final viewportTop = _viewportTopGlobalY(controller);
    final renderObject = _ayahKeys[spanIndex]?.currentContext?.findRenderObject();
    if (viewportTop == null ||
        renderObject is! RenderBox ||
        !renderObject.attached) {
      return null;
    }

    final offset =
        controller.offset + (renderObject.localToGlobal(Offset.zero).dy - viewportTop);
    return offset.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
  }

  /// The screen-space y of the top of the scrolling list itself - not of this
  /// widget, which on a tabbed zikr also contains the tab header strip.
  double? _viewportTopGlobalY(ScrollController controller) {
    final renderObject =
        controller.position.context.storageContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  /// How far past the fold a verse can start and still count as the one being
  /// read. Without it, scrolling a verse's first pixel off the top would jump
  /// the reported position forward a verse early.
  static const double _ayahTopSlack = 48;

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
      widget.onScrollPositionChanged?.call(
        ZikrContentScrollPosition(
          tabIndex: tabIndex,
          scrollOffset: targetOffset,
        ),
      );
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

  Widget _buildTabContent(
    String rawContent,
    ScrollController controller, {
    required int tabIndex,
    required bool hideHeaderLine,
    required bool showMeritsButton,
  }) {
    _restoreInitialBookmarkIfNeeded(tabIndex, controller);
    if (tabIndex == _selectedTabIndex) {
      _scheduleScrollPositionReport(tabIndex);
    }

    final cache = _cacheFor(
      tabIndex,
      rawContent,
      hideHeaderLine: hideHeaderLine,
    );
    final parsedContent = cache.parsed;
    final ayahIndex = cache.ayahIndex;
    final bookmarkedVerse = _bookmarkedVerseRange(
      tabIndex,
      controller,
      parsedContent,
    );

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

    final meritsOffset = showMeritsButton ? 1 : 0;
    final itemCount = meritsOffset +
        (ayahIndex != null ? ayahIndex.spans.length : parsedContent.lines.length);

    if (ayahIndex != null && tabIndex == _selectedTabIndex) {
      _scheduleInitialAyahScroll(tabIndex, ayahIndex, itemCount);
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
          _scheduleAyahReport(ayahIndex, controller);
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

              final contentIndex = index - meritsOffset;

              if (ayahIndex != null) {
                return _buildAyahBlock(
                  tabIndex: tabIndex,
                  ayahIndex: ayahIndex,
                  spanIndex: contentIndex,
                  parsedContent: parsedContent,
                  arabicStyle: arabicStyle,
                  transliStyle: transliStyle,
                  bookmarkedVerse: bookmarkedVerse,
                );
              }

              final line = _buildLine(
                parsedContent,
                contentIndex,
                arabicStyle,
                transliStyle,
              );

              if (bookmarkedVerse == null ||
                  !bookmarkedVerse.contains(contentIndex)) {
                return line;
              }
              return _BookmarkedLine(
                // The label only belongs on the verse's first line - repeating
                // it on the transliteration/translation lines under the same
                // tint would just be noise.
                showLabel: contentIndex == bookmarkedVerse.start,
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
    required int tabIndex,
    required AyahIndex ayahIndex,
    required int spanIndex,
    required ParsedZikrContent parsedContent,
    required TextStyle arabicStyle,
    required TextStyle transliStyle,
    required BookmarkedVerseRange? bookmarkedVerse,
  }) {
    final span = ayahIndex.spans[spanIndex];
    final lines = <Widget>[
      for (var i = span.start; i < span.end; i++)
        _buildLine(parsedContent, i, arabicStyle, transliStyle),
    ];

    return _AyahBlock(
      key: _ayahKey(spanIndex),
      ayah: span.ayah,
      isBookmarked: bookmarkedVerse != null && bookmarkedVerse.start == span.start,
      onAction: span.ayah == null || widget.onAyahAction == null
          ? null
          : () => widget.onAyahAction!(
                AyahActionRequest(
                  ayah: span.ayah!,
                  text: _ayahPlainText(parsedContent, span),
                  scrollOffset: _scrollOffsetOfSpan(tabIndex, spanIndex),
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
      if (line.isEmpty) continue;
      if (parsedContent.arabicCodes.contains(i)) {
        parts.add(line);
      } else if (parsedContent.transliCodes.contains(i)) {
        if (showTransliteration) parts.add(line);
      } else if (parsedContent.translaCodes.contains(i)) {
        if (showTranslation) parts.add(line);
      } else {
        parts.add(line);
      }
    }
    return parts.join('\n');
  }

  /// Runs the one-off jump to [ZikrContentViewerWidget.initialAyah].
  ///
  /// Guarded rather than driven from `initState` because the list has no
  /// scroll position until it has laid out, and the ayah index does not exist
  /// until the tab's content has been parsed.
  void _scheduleInitialAyahScroll(
    int tabIndex,
    AyahIndex ayahIndex,
    int itemCount,
  ) {
    final ayah = widget.initialAyah;
    if (_didScrollToInitialAyah || ayah == null) return;

    _didScrollToInitialAyah = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToAyah(tabIndex, ayahIndex, ayah, itemCount);
    });
  }

  /// The verse - a run of content-line indexes starting at an Arabic line -
  /// that a saved bookmark should highlight, or null if this tab has no
  /// bookmark, no Arabic to anchor one to, or has not laid out yet.
  ///
  /// [ScrollController.position] is only valid once the list has attached,
  /// which has not happened yet on a tab's very first build; when that is
  /// the case this schedules one follow-up rebuild for right after layout,
  /// so the highlight appears on its own rather than needing a scroll or
  /// other interaction to trigger it.
  BookmarkedVerseRange? _bookmarkedVerseRange(
    int tabIndex,
    ScrollController controller,
    ParsedZikrContent parsedContent,
  ) {
    if (widget.initialBookmarkTabIndex != tabIndex) return null;
    final bookmarkOffset = widget.initialBookmarkScrollOffset;
    if (bookmarkOffset == null || bookmarkOffset <= 0) return null;

    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return null;
    }

    final maxExtent = controller.position.maxScrollExtent;
    final fraction = maxExtent > 0 ? bookmarkOffset / maxExtent : 0.0;
    final startIndex = snapToArabicLineIndex(
      scrollFraction: fraction,
      lineCount: parsedContent.lines.length,
      arabicLineIndexes: parsedContent.arabicCodes,
    );
    return BookmarkedVerseRange.fromStart(
      startIndex,
      arabicLineIndexes: parsedContent.arabicCodes,
      lineCount: parsedContent.lines.length,
    );
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

  /// Null for everything that is not a surah, which is what keeps every other
  /// zikr on the line-by-line rendering path.
  final AyahIndex? ayahIndex;
}

/// One verse of the Quran, drawn as a single item.
///
/// The verse number is already inside the Arabic, as the medallion the corpus
/// is authored with - but at the end of the line and in Arabic-Indic digits,
/// which is no help when you are looking for ayah 156. The badge here is for
/// scanning: small, muted, and at the start where the eye lands.
class _AyahBlock extends StatelessWidget {
  const _AyahBlock({
    super.key,
    required this.ayah,
    required this.isBookmarked,
    required this.onAction,
    required this.children,
  });

  /// Null for the Bismillah heading a surah, which is drawn without a badge
  /// because it is not a numbered verse.
  final int? ayah;
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
