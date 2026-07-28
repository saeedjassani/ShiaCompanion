import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/markdown_block_parser.dart';
import 'package:shia_companion/utils/page_layout_engine.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';

import '../constants.dart';

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

  // A brief open (e.g. looking something up) shouldn't register as "reading"
  // and surface a Continue Reading entry for it. Progress is only persisted
  // once the chapter has been actively open for at least this long.
  static const Duration _minReadingDuration = Duration(seconds: 20);

  late Future<String> _chapterFuture;
  double _readerFontSize = 18;
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isSharing = false;
  bool _paginationReady = false;
  bool _isCurrentRoute = false;
  PageRoute? _pageRoute;
  Uri? _previousBrowserUri;

  PaginationResult? _result;
  PageController? _pageController;
  int _currentPageIndex = 0;
  int _savedBlockIndex = 0;
  double _pageHeight = 0;
  double _contentWidth = 400;

  final Stopwatch _activeReadingTime = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    trackScreen('Chapter Page');
    _readerFontSize = (widget.initialFontSize ?? englishFontSize)
        .clamp(_minFontSize, _maxFontSize);
    _savedBlockIndex = widget.initialPageIndex;
    _chapterFuture = LibraryService.loadChapterMarkdown(widget.slug);
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
    final segments = widget.slug.split('/');
    return segments.isNotEmpty ? segments.last : null;
  }

  void _scheduleCurrentWebRouteSync({bool replace = false}) {
    final bookSlug = widget.bookSlug;
    final chapterSlug = _chapterSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty || chapterSlug == null) {
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
    final bookSlug = widget.bookSlug;
    final chapterSlug = _chapterSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty || chapterSlug == null) {
      return;
    }

    setState(() => _isSharing = true);
    try {
      final deepLink = buildLibraryDeepLinkUrl(
        bookSlug: bookSlug,
        chapterSlug: chapterSlug,
      );
      await SharePlus.instance.share(
        ShareParams(text: '${widget.title}\n$deepLink'),
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
        final title = widget.bookTitle ?? widget.title;
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
      _chapterFuture = LibraryService.loadChapterMarkdown(widget.slug);
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

  void _repaginate() {
    if (_result != null && _pageHeight > 0) {
      final styleSheet = _readerStyleSheet(context);
      final engine = PageLayoutEngine(
        markdown: _result!.blocks.map((b) => b.rawText).join('\n\n'),
        contentWidth: _contentWidth,
        contentHeight: _pageHeight,
        fontSize: _readerFontSize,
        lineHeight: _lineHeight,
        styleSheet: styleSheet,
      );
      final result = engine.compute();
      int targetPage = 0;
      for (var p = 0; p < result.pageBlocks.length; p++) {
        for (final paginatedBlock in result.pageBlocks[p]) {
          if (paginatedBlock.originalIndex == _savedBlockIndex) {
            targetPage = p;
            break;
          }
        }
        if (targetPage == p) break;
      }
      setState(() {
        _result = result;
        _paginationReady = true;
        _currentPageIndex = targetPage;
      });
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.jumpToPage(targetPage);
      }
    }
  }

  void _saveProgress() {
    if (_activeReadingTime.elapsed < _minReadingDuration) return;

    final bookSlug = widget.bookSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty) return;

    final fallbackChapterSlug = widget.slug.split('/').last;
    final chapterSlug =
        widget.chapterIndex >= 0 && widget.chapterIndex < widget.chapters.length
            ? widget.chapters[widget.chapterIndex].uid
            : fallbackChapterSlug;

    final pageCount = _result?.pageCount ?? 1;
    LibraryProgressStore.instance.save(
      LibraryProgress(
        bookSlug: bookSlug,
        bookTitle: widget.bookTitle ?? '',
        chapterSlug: chapterSlug,
        chapterTitle: widget.title,
        chapterIndex: widget.chapterIndex,
        pageIndex: _savedBlockIndex,
        pageCount: pageCount,
        fontSize: _readerFontSize,
        updatedAt: DateTime.now(),
      ),
    );
  }

  MarkdownStyleSheet _readerStyleSheet(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
    final blocks = MarkdownBlockParser.parse(chapterMarkdown);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        _pageHeight = constraints.maxHeight;
        // Measure at the actual available width (parent minus padding) so
        // pages fit exactly without needing scroll on each page.
        _contentWidth = constraints.maxWidth - 32;

        if (!_paginationReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageHeight > 0) {
              final styleSheet = _readerStyleSheet(context);
              final engine = PageLayoutEngine(
                markdown: blocks.map((b) => b.rawText).join('\n\n'),
                contentWidth: _contentWidth,
                contentHeight: _pageHeight,
                fontSize: _readerFontSize,
                lineHeight: _lineHeight,
                styleSheet: styleSheet,
              );

              final result = engine.compute();
              int targetPage = 0;
              for (var p = 0; p < result.pageBlocks.length; p++) {
                for (final paginatedBlock in result.pageBlocks[p]) {
                  if (paginatedBlock.originalIndex == _savedBlockIndex) {
                    targetPage = p;
                    break;
                  }
                }
                if (targetPage == p) break;
              }
              
              setState(() {
                _pageController = PageController(initialPage: targetPage);
                _result = result;
                _paginationReady = true;
                _currentPageIndex = targetPage;
              });
            }
          });
          
          return const Center(child: CircularProgressIndicator());
        }

        final pageCount = _result?.pageCount ?? 1;

        return PageView.builder(
          controller: _pageController,
          itemCount: pageCount,
          onPageChanged: (page) {
            setState(() {
              _currentPageIndex = page;
              if (_result!.pageBlocks.isNotEmpty &&
                  page < _result!.pageBlocks.length &&
                  _result!.pageBlocks[page].isNotEmpty) {
                _savedBlockIndex = _result!.pageBlocks[page].first.originalIndex;
              }
            });
            _saveProgress();
          },
          itemBuilder: (context, pageIndex) => _buildPage(pageIndex),
        );
      },
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

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      _pageController?.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_result != null && _currentPageIndex < _result!.pageCount - 1) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    final bookSlug = widget.bookSlug;
    final pageCount = _result?.pageCount ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          return _buildPagedReader(snapshot.data ?? '');
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: _paginationReady && _currentPageIndex > 0
                    ? _goToPreviousPage
                    : null,
              ),
              if (_paginationReady)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${_currentPageIndex + 1} / $pageCount',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                const SizedBox(width: 48),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: _paginationReady && _currentPageIndex < pageCount - 1
                    ? _goToNextPage
                    : null,
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
                style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }
}