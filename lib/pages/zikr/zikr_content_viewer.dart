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

/// Where to paint the "you left off here" band for a bookmark saved at
/// [savedOffset], in the ListView's own coordinate space - the distance from
/// the top of its viewport, which is where [Positioned.top] expects it.
///
/// Null means the saved position is currently scrolled out of view, in
/// either direction, so nothing should be painted at all.
///
/// A bookmark records a raw scroll pixel offset, not which line was there -
/// the reading content has no per-line index to save in the first place, and
/// wrapped Arabic/transliteration/translation lines all resize with the
/// reader's own font settings anyway. This paints a band roughly [bandHeight]
/// tall at that same pixel offset instead of trying to highlight one exact
/// line: close enough to say "around here", not exact enough to promise more.
double? resolveBookmarkMarkerTop({
  required double savedOffset,
  required double currentOffset,
  required double viewportHeight,
  required double bandHeight,
}) {
  final top = savedOffset - currentOffset;
  if (top <= -bandHeight || top >= viewportHeight) return null;
  return top;
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

    // Create text styles with current settings each time this is called
    final arabicStyle = TextStyle(
      fontFamily: arabicFont,
      fontSize: arabicFontSize,
      letterSpacing: 0,
    );
    final transliStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

    final scrollingContent = NotificationListener<ScrollMetricsNotification>(
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
            } else if (parsedContent.transliCodes.contains(contentIndex)) {
              return showTransliteration
                  ? Text.rich(
                      _buildTextSpanForLine(str.toUpperCase(), transliStyle),
                      textAlign: TextAlign.center,
                    )
                  : Container();
            } else if (parsedContent.translaCodes.contains(contentIndex)) {
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
            } else {
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
          },
        ),
      ),
    );

    final bookmarkOffset = widget.initialBookmarkTabIndex == tabIndex
        ? widget.initialBookmarkScrollOffset
        : null;
    if (bookmarkOffset == null || bookmarkOffset <= 0) {
      return scrollingContent;
    }

    return Stack(
      children: [
        scrollingContent,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (!controller.hasClients) return const SizedBox.shrink();
            final top = resolveBookmarkMarkerTop(
              savedOffset: bookmarkOffset,
              currentOffset: controller.offset,
              viewportHeight: controller.position.viewportDimension,
              bandHeight: _estimatedBookmarkBandHeight(),
            );
            if (top == null) return const SizedBox.shrink();
            return Positioned(
              left: 0,
              right: 0,
              top: top,
              height: _estimatedBookmarkBandHeight(),
              // Purely a landmark painted over the content, not part of it -
              // scrolling and text selection both need to keep reaching the
              // real lines underneath.
              child: const IgnorePointer(child: _BookmarkBand()),
            );
          },
        ),
      ],
    );
  }

  /// Rough height of one verse at the reader's current settings: the Arabic
  /// line plus whichever of transliteration/translation are switched on.
  /// Not exact - lines wrap differently per device width - but close enough
  /// that the band reads as "about one verse" rather than a fixed size that
  /// is visibly wrong at the font-size extremes.
  double _estimatedBookmarkBandHeight() {
    var height = arabicFontSize * 2.0 + 16;
    if (showTransliteration) height += englishFontSize * 1.3;
    if (showTranslation) height += englishFontSize * 1.3 + 4;
    return height;
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
class _BookmarkBand extends StatelessWidget {
  const _BookmarkBand();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 3),
        ),
      ),
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
    );
  }
}
