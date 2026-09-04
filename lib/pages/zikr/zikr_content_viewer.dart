import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../constants.dart';
import 'zikr_content_parser.dart';

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
        lineIndex: topContentLineIndex(tabIndex, controller),
      ),
    );
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
        final resolvedLine = topContentLineIndex(tabIndex, controller);
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
          key: _tabListKeys[tabIndex],
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
