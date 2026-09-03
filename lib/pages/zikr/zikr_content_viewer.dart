import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import 'zikr_content_parser.dart';

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
/// way through it (0 = top, 1 = bottom) should be pinned to, snapped forward
/// to the nearest line in [arabicLineIndexes] - so the marker always lands on
/// the start of a verse, never mid-verse or straddling two.
///
/// A raw scroll pixel offset by itself doesn't correspond to any one line -
/// lines wrap to different heights depending on content and the reader's own
/// font settings, so there is no fixed pixels-per-line to invert. Treating
/// every line as equal weight and snapping to the nearest verse start is
/// precise enough to say "about here", without needing real layout
/// measurements to do it.
///
/// Forward rather than to the nearest verse in either direction: reading
/// continues past whatever was on screen, so the next verse's start is the
/// more natural "resume from here" than the one already read.
int? snapToArabicLineIndex({
  required double scrollFraction,
  required int lineCount,
  required Set<int> arabicLineIndexes,
}) {
  if (lineCount <= 0 || arabicLineIndexes.isEmpty) return null;

  final estimated = (scrollFraction.clamp(0.0, 1.0) * (lineCount - 1)).round();

  int? atOrAfter;
  for (final index in arabicLineIndexes) {
    if (index >= estimated && (atOrAfter == null || index < atOrAfter)) {
      atOrAfter = index;
    }
  }
  // No Arabic line at or after the estimate - the reader was somewhere in
  // the closing lines, so the last verse is the closest thing to "here".
  return atOrAfter ?? arabicLineIndexes.reduce(math.max);
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

    final parsedContent = ZikrContentParser.parseContent(
      rawContent,
      hideHeaderLine: hideHeaderLine,
      code: widget.code,
    );
    final bookmarkedVerse = _bookmarkedVerseRange(
      tabIndex,
      controller,
      parsedContent,
    );

    // Create text styles with current settings each time this is called
    final arabicStyle = TextStyle(
      fontFamily: arabicFont,
      fontSize: arabicFontSize,
      letterSpacing: 0,
    );
    final transliStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

    return NotificationListener<ScrollMetricsNotification>(
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
          itemCount: parsedContent.lines.length + (showMeritsButton ? 1 : 0),
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

            // Adjust content index for merits button
            final contentIndex = showMeritsButton ? index - 1 : index;
            final str = parsedContent.lines[contentIndex].trim();

            Widget line;
            if (parsedContent.arabicCodes.contains(contentIndex)) {
              line = Padding(
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
            } else if (parsedContent.transliCodes.contains(contentIndex)) {
              line = showTransliteration
                  ? Text.rich(
                      _buildTextSpanForLine(str.toUpperCase(), transliStyle),
                      textAlign: TextAlign.center,
                    )
                  : Container();
            } else if (parsedContent.translaCodes.contains(contentIndex)) {
              line = showTranslation
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
            } else {
              line = Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4.0),
                child: Text.rich(
                  _buildTextSpanForLine(
                    str,
                    const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              );
            }

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
    );
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
