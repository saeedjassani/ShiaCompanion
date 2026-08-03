import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/page_layout_engine.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';

import '../constants.dart';
import '../widgets/responsive_content.dart';

class ChapterPage extends StatefulWidget {
  final String slug;
  final String title;
  final String? bookTitle;
  final String? bookSlug;
  final List<UidTitleData> chapters;
  final int chapterIndex;
  final int initialPageIndex;
  final double? initialFontSize;

  const ChapterPage(
    this.slug,
    this.title, {
    this.bookTitle,
    this.bookSlug,
    this.chapters = const [],
    this.chapterIndex = -1,
    this.initialPageIndex = 0,
    this.initialFontSize,
  });

  @override
  _ChapterPageState createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage>
    with WidgetsBindingObserver, RouteAware {
  static const double _minFontSize = 14;
  static const double _maxFontSize = 28;
  static const double _lineHeight = 1.55;

  // A glance at a chapter (e.g. following a link and backing straight out)
  // shouldn't register as "reading" and surface a Continue Reading entry for
  // it. Progress is only persisted once the chapter has been actively open for
  // at least this long — short enough that anyone who actually started reading
  // gets their place back.
  static const Duration _minReadingDuration = Duration(seconds: 5);

  late Future<String> _chapterFuture;
  late String _slug;
  late String _title;
  late int _chapterIndex;

  double _readerFontSize = 18;
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isSharing = false;
  bool _paginationReady = false;
  bool _isCurrentRoute = false;
  PageRoute? _pageRoute;
  Uri? _previousBrowserUri;

  PaginationResult? _result;
  String? _paginatedMarkdown;
  PageController? _pageController;
  int _currentPageIndex = 0;
  int _savedBlockIndex = 0;
  double _pageHeight = 0;
  double _contentWidth = 400;

  /// Set while a neighbouring chapter is being opened, so a second swipe (or a
  /// button press) can't kick off a competing chapter change.
  bool _isChangingChapter = false;

  /// When we arrive in a chapter by paging *backwards* out of the next one, the
  /// reader should land on its last page rather than its first.
  bool _landOnLastPage = false;

  final Stopwatch _activeReadingTime = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    trackScreen('Chapter Page');
    _readerFontSize = (widget.initialFontSize ?? englishFontSize)
        .clamp(_minFontSize, _maxFontSize);
    _slug = widget.slug;
    _title = widget.title;
    _chapterIndex = widget.chapterIndex;
    _savedBlockIndex = widget.initialPageIndex;
    _chapterFuture = LibraryService.loadChapterMarkdown(_slug);
    _checkSaved();
    _activeReadingTime.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_pageRoute != null) {
      routeObserver.unsubscribe(this);
    }
    _pageController?.dispose();
    _saveProgress();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _pageRoute) {
      if (_pageRoute != null) {
        routeObserver.unsubscribe(this);
      }
      _pageRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  String? get _chapterSlug {
    final segments = _slug.split('/');
    return segments.isNotEmpty ? segments.last : null;
  }

  String? get _bookSlug {
    final bookSlug = widget.bookSlug;
    if (bookSlug != null && bookSlug.trim().isNotEmpty) return bookSlug.trim();
    final separator = _slug.lastIndexOf('/');
    return separator > 0 ? _slug.substring(0, separator) : null;
  }

  /// Whether this chapter knows its siblings, i.e. whether reading can flow on
  /// past its edges.
  bool get _hasChapterList =>
      _chapterIndex >= 0 && _chapterIndex < widget.chapters.length;

  bool get _hasPreviousChapter => _hasChapterList && _chapterIndex > 0;

  bool get _hasNextChapter =>
      _hasChapterList && _chapterIndex < widget.chapters.length - 1;

  /// The PageView carries one extra leading page when a previous chapter
  /// exists, so swiping back off page one flows into it.
  int get _leadingSlotCount => _hasPreviousChapter ? 1 : 0;

  void _scheduleCurrentWebRouteSync({bool replace = false}) {
    final bookSlug = _bookSlug;
    final chapterSlug = _chapterSlug;
    if (bookSlug == null || chapterSlug == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentRoute) return;
      syncWebRoutePath(
        buildLibraryDeepLinkPath(bookSlug: bookSlug, chapterSlug: chapterSlug),
        replace: replace,
      );
    });
  }

  @override
  void didPush() {
    _isCurrentRoute = true;
    _previousBrowserUri ??= Uri.base;
    _scheduleCurrentWebRouteSync();
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    _scheduleCurrentWebRouteSync(replace: true);
  }

  @override
  void didPushNext() {
    _isCurrentRoute = false;
  }

  @override
  void didPop() {
    _isCurrentRoute = false;
    final previousBrowserUri = _previousBrowserUri;
    if (previousBrowserUri != null) {
      syncWebRouteUri(previousBrowserUri, replace: true);
    }
  }

  Future<void> _shareChapter() async {
    if (_isSharing) return;
    final bookSlug = _bookSlug;
    final chapterSlug = _chapterSlug;
    if (bookSlug == null || chapterSlug == null) {
      return;
    }

    setState(() => _isSharing = true);
    try {
      final deepLink = buildLibraryDeepLinkUrl(
        bookSlug: bookSlug,
        chapterSlug: chapterSlug,
      );
      await SharePlus.instance.share(
        ShareParams(text: '$_title\n$deepLink'),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_paginationReady && _result != null) {
      _repaginate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_activeReadingTime.isRunning) _activeReadingTime.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_activeReadingTime.isRunning) _activeReadingTime.stop();
        _saveProgress();
    }
  }

  Future<void> _checkSaved() async {
    final bookSlug = widget.bookSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty) return;
    final saved = await LibraryService.isBookSaved(bookSlug);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    final bookSlug = widget.bookSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isSaved) {
        await LibraryService.removeSavedBook(bookSlug);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline copy removed')),
          );
        }
      } else {
        final title = widget.bookTitle ?? _title;
        await LibraryService.saveBookForOffline(bookSlug, title);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title saved for offline')),
          );
        }
      }
      await _checkSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retry() {
    setState(() {
      _isChangingChapter = false;
      _chapterFuture = LibraryService.loadChapterMarkdown(_slug);
    });
  }

  void _changeFontSize(double delta) {
    final newSize =
        (_readerFontSize + delta).clamp(_minFontSize, _maxFontSize);
    if (newSize == _readerFontSize) return;

    setState(() {
      _readerFontSize = newSize;
      englishFontSize = _readerFontSize;
    });
    if (SP.isInitialized) {
      SP.prefs.setDouble('eng_font_size', _readerFontSize);
    }

    _repaginate();
    _saveProgress();
  }

  PaginationResult _computePagination(String markdown) {
    return PageLayoutEngine(
      markdown: markdown,
      contentWidth: _contentWidth,
      contentHeight: _pageHeight,
      fontSize: _readerFontSize,
      lineHeight: _lineHeight,
      styleSheet: _readerStyleSheet(context),
    ).compute();
  }

  /// The page that should be shown for the position we're restoring: the last
  /// page when paging backwards into a chapter, otherwise the page holding the
  /// block the reader last saw.
  int _resolveTargetPage(PaginationResult result) {
    if (result.pageCount == 0) return 0;
    if (_landOnLastPage) return result.pageCount - 1;

    for (var page = 0; page < result.pageBlocks.length; page++) {
      for (final paginatedBlock in result.pageBlocks[page]) {
        if (paginatedBlock.originalIndex == _savedBlockIndex) return page;
      }
    }
    return 0;
  }

  int _blockIndexForPage(PaginationResult result, int page) {
    if (page < 0 || page >= result.pageBlocks.length) return _savedBlockIndex;
    final blocks = result.pageBlocks[page];
    return blocks.isEmpty ? _savedBlockIndex : blocks.first.originalIndex;
  }

  void _repaginate() {
    final markdown = _paginatedMarkdown;
    if (markdown == null || _pageHeight <= 0) return;

    final result = _computePagination(markdown);
    final targetPage = _resolveTargetPage(result);
    setState(() {
      _result = result;
      _paginationReady = true;
      _currentPageIndex = targetPage;
    });
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.jumpToPage(_leadingSlotCount + targetPage);
    }
  }

  void _saveProgress() {
    if (_activeReadingTime.elapsed < _minReadingDuration) return;

    final bookSlug = widget.bookSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty) return;

    final chapterSlug = _chapterSlug;
    if (chapterSlug == null || chapterSlug.isEmpty) return;

    final pageCount = _result?.pageCount ?? 1;
    LibraryProgressStore.instance.save(
      LibraryProgress(
        bookSlug: bookSlug,
        bookTitle: widget.bookTitle ?? '',
        chapterSlug: chapterSlug,
        chapterTitle: _title,
        chapterIndex: _chapterIndex,
        pageIndex: _savedBlockIndex,
        pageCount: pageCount,
        fontSize: _readerFontSize,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Warms the cache for the chapters either side of this one so paging across
  /// a chapter boundary is instant instead of hitting the network mid-swipe.
  void _prefetchAdjacentChapters() {
    final bookSlug = _bookSlug;
    if (bookSlug == null) return;

    if (_hasNextChapter) {
      LibraryService.prefetchChapterMarkdown(
        '$bookSlug/${widget.chapters[_chapterIndex + 1].uid}',
      );
    }
    if (_hasPreviousChapter) {
      LibraryService.prefetchChapterMarkdown(
        '$bookSlug/${widget.chapters[_chapterIndex - 1].uid}',
      );
    }
  }

  /// Continues reading into the chapter before or after this one, in place, so
  /// the book reads as one continuous flow and Back still returns to whatever
  /// opened the reader.
  void _openAdjacentChapter({required bool forward}) {
    if (_isChangingChapter) return;

    final targetIndex = _chapterIndex + (forward ? 1 : -1);
    if (targetIndex < 0 || targetIndex >= widget.chapters.length) return;

    final bookSlug = _bookSlug;
    if (bookSlug == null) return;

    _saveProgress();

    final chapter = widget.chapters[targetIndex];
    final previousController = _pageController;

    setState(() {
      _isChangingChapter = true;
      _chapterIndex = targetIndex;
      _title = chapter.title;
      _slug = '$bookSlug/${chapter.uid}';
      _chapterFuture = LibraryService.loadChapterMarkdown(_slug);
      _result = null;
      _paginatedMarkdown = null;
      _paginationReady = false;
      _currentPageIndex = 0;
      _savedBlockIndex = 0;
      _landOnLastPage = !forward;
      _pageController = null;
    });

    // The PageView is still mounted for this frame; disposing its controller
    // before it detaches would throw.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousController?.dispose();
    });

    _scheduleCurrentWebRouteSync(replace: true);
  }

  MarkdownStyleSheet _readerStyleSheet(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      // Justified body text is what makes a page read like a printed book
      // rather than a web page. WrapAlignment.spaceBetween is how
      // flutter_markdown_plus spells TextAlign.justify. Headings and list items
      // stay ragged-right — justifying short lines just stretches them.
      textAlign: WrapAlignment.spaceBetween,
      blockquoteAlign: WrapAlignment.spaceBetween,
      p: textTheme.bodyLarge?.copyWith(
        fontSize: _readerFontSize,
        height: _lineHeight,
      ),
      h1: textTheme.headlineSmall?.copyWith(fontSize: _readerFontSize + 8),
      h2: textTheme.titleLarge?.copyWith(fontSize: _readerFontSize + 5),
      h3: textTheme.titleMedium?.copyWith(fontSize: _readerFontSize + 3),
      h4: textTheme.titleSmall?.copyWith(fontSize: _readerFontSize + 2),
      h5: textTheme.titleSmall?.copyWith(fontSize: _readerFontSize + 1),
      h6: textTheme.titleSmall?.copyWith(fontSize: _readerFontSize),
      blockquote: textTheme.bodyLarge?.copyWith(
        fontSize: _readerFontSize,
        height: _lineHeight,
        fontStyle: FontStyle.italic,
      ),
      code: textTheme.bodyMedium?.copyWith(
        fontSize: _readerFontSize - 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      a: textTheme.bodyLarge?.copyWith(
        fontSize: _readerFontSize,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildPagedReader(String chapterMarkdown) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _pageHeight = constraints.maxHeight;
        // Measure at the actual available width (parent minus padding) so
        // pages fit exactly without needing scroll on each page.
        _contentWidth = constraints.maxWidth - 32;

        if (!_paginationReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _paginationReady || _pageHeight <= 0) return;

            final result = _computePagination(chapterMarkdown);
            final targetPage = _resolveTargetPage(result);

            setState(() {
              _result = result;
              _paginatedMarkdown = chapterMarkdown;
              _paginationReady = true;
              _isChangingChapter = false;
              _landOnLastPage = false;
              _currentPageIndex = targetPage;
              _savedBlockIndex = _blockIndexForPage(result, targetPage);
              _pageController = PageController(
                initialPage: _leadingSlotCount + targetPage,
              );
            });
            _prefetchAdjacentChapters();
          });

          return const Center(child: CircularProgressIndicator());
        }

        final pageCount = _result?.pageCount ?? 1;
        final slotCount =
            _leadingSlotCount + pageCount + (_hasNextChapter ? 1 : 0);

        return PageView.builder(
          controller: _pageController,
          itemCount: slotCount,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final contentIndex = index - _leadingSlotCount;
            if (contentIndex < 0) {
              return _buildChapterHandoff(forward: false);
            }
            if (contentIndex >= pageCount) {
              return _buildChapterHandoff(forward: true);
            }
            return _buildPage(contentIndex);
          },
        );
      },
    );
  }

  void _onPageChanged(int index) {
    final result = _result;
    if (result == null) return;

    final contentIndex = index - _leadingSlotCount;
    if (contentIndex < 0) {
      _openAdjacentChapter(forward: false);
      return;
    }
    if (contentIndex >= result.pageCount) {
      _openAdjacentChapter(forward: true);
      return;
    }

    setState(() {
      _currentPageIndex = contentIndex;
      _savedBlockIndex = _blockIndexForPage(result, contentIndex);
    });
    _saveProgress();

    // Reading up to an edge is the cue to have the neighbour ready.
    if (contentIndex <= 1 || contentIndex >= result.pageCount - 2) {
      _prefetchAdjacentChapters();
    }
  }

  /// The page shown while a swipe carries the reader across a chapter
  /// boundary. It names the chapter being entered, so the handoff reads as
  /// part of the book rather than as a stall.
  Widget _buildChapterHandoff({required bool forward}) {
    final theme = Theme.of(context);
    final index = _chapterIndex + (forward ? 1 : -1);
    final title = index >= 0 && index < widget.chapters.length
        ? widget.chapters[index].title
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              forward ? 'Next chapter' : 'Previous chapter',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int pageIndex) {
    final result = _result!;
    if (pageIndex >= result.pageBlocks.length) return const SizedBox.shrink();

    final paginatedBlocks = result.pageBlocks[pageIndex];
    final pageChildren = <Widget>[];

    for (final paginatedBlock in paginatedBlocks) {
      final block = result.blocks[paginatedBlock.originalIndex];
      final renderText = paginatedBlock.text;

      pageChildren.add(
        Padding(
          padding: EdgeInsets.only(
            top: paginatedBlock.topMargin,
            bottom: paginatedBlock.bottomMargin,
          ),
          child: Directionality(
            textDirection: block.textDirection,
            child: MarkdownBody(
              data: renderText,
              selectable: true,
              styleSheet: _readerStyleSheet(context),
            ),
          ),
        ),
      );
    }

    // Clip overflow so blocks that render slightly taller than measured
    // don't cause layout issues. The page is constrained to viewport height.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRect(
        child: SizedBox(
          height: _pageHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pageChildren,
          ),
        ),
      ),
    );
  }

  bool get _canGoBack =>
      _paginationReady && (_currentPageIndex > 0 || _hasPreviousChapter);

  bool get _canGoForward =>
      _paginationReady &&
      (_currentPageIndex < (_result?.pageCount ?? 1) - 1 || _hasNextChapter);

  void _goToPreviousPage() {
    if (!_paginationReady) return;
    if (_currentPageIndex > 0) {
      _pageController?.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_hasPreviousChapter) {
      _openAdjacentChapter(forward: false);
    }
  }

  void _goToNextPage() {
    if (!_paginationReady) return;
    if (_currentPageIndex < (_result?.pageCount ?? 1) - 1) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_hasNextChapter) {
      _openAdjacentChapter(forward: true);
    }
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookSlug = widget.bookSlug;
    final pageCount = _result?.pageCount ?? 1;
    final progress =
        pageCount <= 1 ? 1.0 : (_currentPageIndex + 1) / pageCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (bookSlug != null && bookSlug.trim().isNotEmpty) ...[
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              tooltip: 'Share chapter',
              onPressed: _isSharing ? null : _shareChapter,
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isSaved ? Icons.download_done : Icons.download),
              tooltip: _isSaved ? 'Remove offline copy' : 'Save book offline',
              onPressed: _toggleSave,
            ),
          ],
        ],
      ),
      body: FutureBuilder<String>(
        future: _chapterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildMessage(
              icon: Icons.cloud_off,
              title: 'Chapter unavailable',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _retry,
            );
          }
          return ResponsiveContent(
            maxWidth: readingContentWidth,
            padding: EdgeInsets.zero,
            child: _buildPagedReader(snapshot.data ?? ''),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _paginationReady ? progress : null,
              minHeight: 2,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _paginationReady &&
                            _currentPageIndex == 0 &&
                            _hasPreviousChapter
                        ? 'Previous chapter'
                        : 'Previous page',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _canGoBack ? _goToPreviousPage : null,
                  ),
                  if (_paginationReady)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '${_currentPageIndex + 1} / $pageCount',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  IconButton(
                    tooltip: _paginationReady &&
                            _currentPageIndex == pageCount - 1 &&
                            _hasNextChapter
                        ? 'Next chapter'
                        : 'Next page',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _canGoForward ? _goToNextPage : null,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Decrease font size',
                    icon: const Icon(Icons.text_decrease),
                    onPressed: _readerFontSize <= _minFontSize
                        ? null
                        : () => _changeFontSize(-1),
                  ),
                  Text(
                    '${_readerFontSize.round()}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  IconButton(
                    tooltip: 'Increase font size',
                    icon: const Icon(Icons.text_increase),
                    onPressed: _readerFontSize >= _maxFontSize
                        ? null
                        : () => _changeFontSize(1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
