import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/markdown_block.dart';
import 'package:shia_companion/utils/markdown_block_parser.dart';
import 'package:shia_companion/utils/reader_layout.dart';
import 'package:shia_companion/utils/reader_style.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';

import '../constants.dart';
import '../widgets/reader_content.dart';
import '../widgets/responsive_content.dart';
import '../services/analytics_service.dart';

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

  /// The chapter's blocks, and the pages measured from the column they were
  /// laid out in. Both are replaced together whenever the chapter is measured
  /// again — at a new font size, or a new page size.
  List<MarkdownBlock> _blocks = const [];
  ReaderPagination? _pagination;

  /// The keys the measuring pass reads its geometry through. Non-null only
  /// while a measuring pass is in flight.
  GlobalKey? _measureColumnKey;
  List<GlobalKey> _measureBlockKeys = const [];

  /// The page size and system text size the current pages were measured at.
  /// Pages only hold for the layout they were cut from, so a change to either
  /// is a re-measure.
  ({Size size, TextScaler textScaler})? _measuredFor;
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

  // Tap-to-turn. The page text is selectable, and SelectableText registers its
  // own tap recognizer — a descendant recognizer wins the gesture arena over an
  // ancestor GestureDetector, so taps landing on text would never reach one.
  // Listener sees raw pointer events regardless of the arena, so we recognise
  // the tap ourselves and leave selection untouched.
  static const double _tapTurnZoneFraction = 0.3;
  static const double _tapMoveSlop = 12;

  Offset? _pointerDownPosition;
  Duration? _pointerDownTimestamp;
  Duration? _lastTapTurnTimestamp;
  bool _hasTextSelection = false;

  /// Whether text was selected when the current tap started. Such a tap is the
  /// one that dismisses the selection, so it shouldn't also turn the page.
  bool _tapStartedWithSelection = false;

  final Stopwatch _activeReadingTime = Stopwatch();

  /// Holds the keyboard for the reader, so the arrow keys turn pages on web and
  /// desktop instead of walking focus around the controls.
  final FocusNode _keyboardFocusNode =
      FocusNode(debugLabel: 'ChapterPage keyboard');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    trackScreen('Chapter Page');
    // Ranks books by chapters actually read, which is a truer signal than the
    // book list tap that ChapterListPage already records.
    unawaited(AnalyticsService.libraryView(
      bookUid: widget.bookSlug ?? widget.slug,
      bookTitle: widget.bookTitle ?? widget.title,
      chapterUid: widget.slug,
    ));
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
    _keyboardFocusNode.dispose();
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
      unawaited(AnalyticsService.feature(
        'library_shared',
        label: 'Library shared',
        parameters: {
          'book_uid': bookSlug,
          'chapter_uid': chapterSlug,
          'scope': 'chapter',
        },
      ));
    } finally {
      if (mounted) setState(() => _isSharing = false);
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

    _remeasure();
    _saveProgress();
  }

  /// The page that should be shown for the position we're restoring: the last
  /// page when paging backwards into a chapter, otherwise the page holding the
  /// block the reader last saw.
  int _resolveTargetPage(ReaderPagination pagination) {
    if (pagination.pageCount == 0) return 0;
    if (_landOnLastPage) return pagination.pageCount - 1;
    return pagination.pageForBlock(_savedBlockIndex);
  }

  int _blockIndexForPage(ReaderPagination pagination, int page) {
    if (page < 0 || page >= pagination.pageCount) return _savedBlockIndex;
    return pagination.pages[page].firstBlock;
  }

  /// Throws the current pages away and lays the chapter out again, keeping the
  /// reader on the block they were on. Everything about a page — where it
  /// starts, where it ends — comes from a real layout at one font size and one
  /// page size, so a change to either can only be answered by measuring again.
  void _remeasure() {
    if (!_paginationReady) return;
    // The pages, and every Selectable in them, are gone by the end of this
    // frame.
    _clearTextSelection();
    final controller = _pageController;
    setState(() {
      _paginationReady = false;
      _pagination = null;
      _pageController = null;
      _measureColumnKey = null;
      _measureBlockKeys = const [];
      _measuredFor = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => controller?.dispose());
  }

  void _saveProgress() {
    if (_activeReadingTime.elapsed < _minReadingDuration) return;

    final bookSlug = widget.bookSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty) return;

    final chapterSlug = _chapterSlug;
    if (chapterSlug == null || chapterSlug.isEmpty) return;

    final pageCount = _pagination?.pageCount ?? 1;
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
    _clearTextSelection();

    final chapter = widget.chapters[targetIndex];
    final previousController = _pageController;

    setState(() {
      _isChangingChapter = true;
      _chapterIndex = targetIndex;
      _title = chapter.title;
      _slug = '$bookSlug/${chapter.uid}';
      _chapterFuture = LibraryService.loadChapterMarkdown(_slug);
      _pagination = null;
      _blocks = const [];
      _measureColumnKey = null;
      _measureBlockKeys = const [];
      _measuredFor = null;
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

  Widget _buildPagedReader(String chapterMarkdown) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _pageHeight = constraints.maxHeight;
        // The width the chapter is measured in has to be the width it is
        // rendered in, so both go through the same horizontal padding.
        _contentWidth = constraints.maxWidth - 32;

        // Reading the text scaler here is also what subscribes the reader to
        // it: a chapter measured at one system text size is not the chapter
        // that renders at another.
        final measuredFor = (
          size: Size(_contentWidth, _pageHeight),
          textScaler: MediaQuery.textScalerOf(context),
        );
        if (_paginationReady && _measuredFor != measuredFor) {
          // The reader was rotated, resized, or had its text size changed
          // under it. The pages belong to the layout before that.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _remeasure();
          });
        }

        if (!_paginationReady) {
          return _buildMeasuringPass(chapterMarkdown, measuredFor);
        }

        final pageCount = _pagination?.pageCount ?? 1;
        final slotCount =
            _leadingSlotCount + pageCount + (_hasNextChapter ? 1 : 0);

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerCancel: _onPointerCancel,
          onPointerUp: (event) => _onPointerUp(event, constraints.maxWidth),
          child: PageView.builder(
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
          ),
        );
      },
    );
  }

  /// Lays the whole chapter out as one column, off-screen, and reads the
  /// pages out of it once the frame is done.
  ///
  /// The reader shows a page by windowing onto this column, so the column is
  /// built exactly as the pages are: same width, same style sheet, same widget
  /// per block. Nothing about a page is predicted — where it may start and
  /// where it may end are read back from the text the engine actually laid
  /// out, which is the only way a page can be guaranteed to hold whole lines
  /// and to hold as many of them as it has room for.
  Widget _buildMeasuringPass(
    String chapterMarkdown,
    ({Size size, TextScaler textScaler}) measuredFor,
  ) {
    if (_measureColumnKey == null) {
      _blocks = MarkdownBlockParser.parse(chapterMarkdown);
      _measureColumnKey = GlobalKey();
      _measureBlockKeys = [for (var i = 0; i < _blocks.length; i++) GlobalKey()];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final columnKey = _measureColumnKey;
        if (!mounted || _paginationReady || columnKey == null) return;
        if (_pageHeight <= 0) return;

        final pagination = paginateColumn(
          harvestColumnGeometry(
            columnKey: columnKey,
            blockKeys: _measureBlockKeys,
          ),
          pageHeight: _pageHeight,
        );
        final targetPage = _resolveTargetPage(pagination);

        setState(() {
          _pagination = pagination;
          _measuredFor = measuredFor;
          _paginationReady = true;
          _isChangingChapter = false;
          _landOnLastPage = false;
          _currentPageIndex = targetPage;
          _savedBlockIndex = _blockIndexForPage(pagination, targetPage);
          _pageController = PageController(
            initialPage: _leadingSlotCount + targetPage,
          );
          _measureColumnKey = null;
          _measureBlockKeys = const [];
        });
        _prefetchAdjacentChapters();
      });
    }

    return Stack(
      children: [
        const Center(child: CircularProgressIndicator()),
        // Laid out, never painted: an Opacity of zero skips its child's
        // painting entirely, and the reader only needs the layout.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ReaderMeasureColumn(
                  columnKey: _measureColumnKey!,
                  blocks: _blocks,
                  blockKeys: _measureBlockKeys,
                  styleSheet: readerStyleSheet(context, fontSize: _readerFontSize),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onPageChanged(int index) {
    final result = _pagination;
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

    // Any selection belonged to the page we just left, and its text may be
    // disposed without reporting the change.
    _clearTextSelection();

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

  /// Tracks whether any text on the page is currently selected. Read only by
  /// the tap handler, so there's nothing to rebuild.
  void _onSelectionChanged(SelectedContent? content) {
    _hasTextSelection = (content?.plainText.trim().isNotEmpty) ?? false;
  }

  /// Drops a live selection before the text it was made in is replaced.
  ///
  /// A page's [SelectionArea] keeps its handles and toolbar against the
  /// [Selectable]s the selection was made in; turning a page, re-measuring at
  /// a new font size, or flowing into the next chapter all take those out of
  /// the tree, and an overlay still pointing at them is what trips the
  /// framework's null checks (flutter/flutter#124078, #123378).
  ///
  /// Focus is handed back to the reader's own node rather than simply dropped:
  /// losing focus is how [SelectableRegion] clears itself, and the reader
  /// still needs the keyboard for the arrow keys afterwards.
  void _clearTextSelection() {
    if (!_hasTextSelection) return;
    _hasTextSelection = false;
    _keyboardFocusNode.requestFocus();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownTimestamp = event.timeStamp;
    _tapStartedWithSelection = _hasTextSelection;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDownPosition = null;
    _pointerDownTimestamp = null;
  }

  void _onPointerUp(PointerUpEvent event, double readerWidth) {
    final downPosition = _pointerDownPosition;
    final downTimestamp = _pointerDownTimestamp;
    _pointerDownPosition = null;
    _pointerDownTimestamp = null;

    if (downPosition == null || downTimestamp == null) return;
    if (!_paginationReady || _isChangingChapter) return;

    // A drag — a page swipe, or a selection drag on desktop.
    if ((event.localPosition - downPosition).distance > _tapMoveSlop) return;
    // Held long enough that the text is starting a selection instead.
    if (event.timeStamp - downTimestamp >= kLongPressTimeout) return;
    // The tap that clears an existing selection stops there.
    if (_tapStartedWithSelection) return;
    // The second half of a double tap selects a word; it shouldn't also turn a
    // second page.
    final lastTurn = _lastTapTurnTimestamp;
    if (lastTurn != null && event.timeStamp - lastTurn < kDoubleTapTimeout) {
      return;
    }

    final zoneWidth = readerWidth * _tapTurnZoneFraction;
    final x = event.localPosition.dx;
    if (x <= zoneWidth) {
      _lastTapTurnTimestamp = event.timeStamp;
      _goToPreviousPage();
    } else if (x >= readerWidth - zoneWidth) {
      _lastTapTurnTimestamp = event.timeStamp;
      _goToNextPage();
    }
    // The middle of the page is deliberately inert, so tapping to dismiss a
    // selection or to reach for a word never moves the reader by accident.
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
    final pagination = _pagination!;
    if (pageIndex >= pagination.pageCount) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SelectionArea(
        onSelectionChanged: _onSelectionChanged,
        child: ReaderPageWindow(
          blocks: _blocks,
          page: pagination.pages[pageIndex],
          pageHeight: _pageHeight,
          styleSheet: readerStyleSheet(context, fontSize: _readerFontSize),
        ),
      ),
    );
  }

  bool get _canGoBack =>
      _paginationReady && (_currentPageIndex > 0 || _hasPreviousChapter);

  bool get _canGoForward =>
      _paginationReady &&
      (_currentPageIndex < (_pagination?.pageCount ?? 1) - 1 || _hasNextChapter);

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
    if (_currentPageIndex < (_pagination?.pageCount ?? 1) - 1) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_hasNextChapter) {
      _openAdjacentChapter(forward: true);
    }
  }

  /// Turns pages from the keyboard. Arrow keys are what a reader on the web
  /// reaches for, and they carry across a chapter boundary exactly as the
  /// on-screen controls do.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      if (!_canGoBack) return KeyEventResult.ignored;
      _goToPreviousPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      if (!_canGoForward) return KeyEventResult.ignored;
      _goToNextPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The title of the chapter reading flows into, in [forward]'s direction, or
  /// null when this is the first or last chapter of the book.
  String? _adjacentChapterTitle({required bool forward}) {
    if (forward ? !_hasNextChapter : !_hasPreviousChapter) return null;
    return widget.chapters[_chapterIndex + (forward ? 1 : -1)].title;
  }

  /// The control at either end of the reader's toolbar.
  ///
  /// In the middle of a chapter it is an arrow, because there is nothing to say
  /// beyond "one page further". On the edge pages the same press leaves the
  /// chapter altogether, so the arrow becomes a labelled button naming the
  /// chapter it lands in — nobody should have to guess that a chevron is about
  /// to take them somewhere else.
  Widget _buildPageNavControl({
    required bool forward,
    required int pageCount,
  }) {
    final atEdge = _paginationReady &&
        (forward
            ? _currentPageIndex >= pageCount - 1
            : _currentPageIndex == 0);
    final chapterTitle =
        atEdge ? _adjacentChapterTitle(forward: forward) : null;
    final onPressed = forward
        ? (_canGoForward ? _goToNextPage : null)
        : (_canGoBack ? _goToPreviousPage : null);

    if (chapterTitle == null) {
      return IconButton(
        tooltip: forward ? 'Next page' : 'Previous page',
        icon: Icon(forward ? Icons.chevron_right : Icons.chevron_left),
        onPressed: onPressed,
      );
    }

    // One line, so the bar keeps its height as the reader crosses the edge,
    // and short-prefixed, so the room goes to the part that identifies the
    // chapter. The tooltip carries the untruncated title.
    return Flexible(
      child: Tooltip(
        message: forward
            ? 'Next chapter: $chapterTitle'
            : 'Previous chapter: $chapterTitle',
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(
            forward ? Icons.chevron_right : Icons.chevron_left,
            size: 20,
          ),
          iconAlignment: forward ? IconAlignment.end : IconAlignment.start,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          label: Text(
            forward ? 'Next: $chapterTitle' : 'Previous: $chapterTitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: forward ? TextAlign.end : TextAlign.start,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
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
    final pageCount = _pagination?.pageCount ?? 1;
    final progress =
        pageCount <= 1 ? 1.0 : (_currentPageIndex + 1) / pageCount;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
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
                    // The navigation controls take whatever room is left over
                    // once the font controls have theirs: on an edge page they
                    // grow into a labelled button, and the label is the part
                    // that needs the space.
                    Expanded(
                      child: Row(
                        children: [
                          _buildPageNavControl(
                            forward: false,
                            pageCount: pageCount,
                          ),
                          if (_paginationReady)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${_currentPageIndex + 1} / $pageCount',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          else
                            const SizedBox(width: 48),
                          _buildPageNavControl(
                            forward: true,
                            pageCount: pageCount,
                          ),
                        ],
                      ),
                    ),
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
      ),
    );
  }
}
