import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/web_route_sync.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import 'chapter_page.dart';
import '../l10n/l10n.dart';

class ChapterListPage extends StatefulWidget {
  final String slug;
  final String title;

  const ChapterListPage(this.slug, this.title);

  @override
  _ChapterListPageState createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> with RouteAware {
  late Future<List<UidTitleData>> _chaptersFuture;
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isSharing = false;
  bool _isCurrentRoute = false;
  PageRoute? _pageRoute;
  Uri? _previousBrowserUri;

  /// Who wrote the book, from the library's list; null until that loads,
  /// and for a book that names nobody.
  String? _author;

  /// Where the reader left this book, if they have started it.
  LibraryProgress? _progress;

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter List Page');
    _chaptersFuture = LibraryService.loadChapters(widget.slug);
    _checkSaved();
    _loadProgress();
    unawaited(_loadAuthor());
  }

  void _loadProgress() {
    _progress = LibraryProgressStore.instance
        .readAll()
        .where((progress) => progress.bookSlug == widget.slug)
        .firstOrNull;
  }

  Future<void> _loadAuthor() async {
    try {
      final books = await LibraryService.loadBooks();
      final author =
          books.where((book) => book.uid == widget.slug).firstOrNull?.author;
      if (mounted && author != null) setState(() => _author = author);
    } catch (_) {
      // The author is a nicety; the chapters are what the page is for.
    }
  }

  @override
  void dispose() {
    if (_pageRoute != null) {
      routeObserver.unsubscribe(this);
    }
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

  void _scheduleCurrentWebRouteSync({bool replace = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentRoute) return;
      syncWebRoutePath(
        buildLibraryDeepLinkPath(bookSlug: widget.slug),
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

  Future<void> _shareBook() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final deepLink = buildLibraryDeepLinkUrl(bookSlug: widget.slug);
      await SharePlus.instance.share(
        ShareParams(text: '${widget.title}\n$deepLink'),
      );
      unawaited(AnalyticsService.feature(
        'library_shared',
        label: 'Library shared',
        parameters: {'book_uid': widget.slug, 'scope': 'book'},
      ));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _checkSaved() async {
    final saved = await LibraryService.isBookSaved(widget.slug);
    if (mounted) {
      setState(() => _isSaved = saved);
    }
  }

  void _retry() {
    setState(() {
      _chaptersFuture = LibraryService.loadChapters(widget.slug);
    });
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isSaved) {
        await LibraryService.removeSavedBook(widget.slug);
        unawaited(AnalyticsService.feature(
          'library_offline_removed',
          label: 'Offline copy removed',
          parameters: {'book_uid': widget.slug},
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.libraryOfflineRemoved)),
          );
        }
      } else {
        await LibraryService.saveBookForOffline(widget.slug, widget.title);
        unawaited(AnalyticsService.feature(
          'library_offline_saved',
          label: 'Saved for offline',
          parameters: {'book_uid': widget.slug},
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(context.l10n.librarySavedForOffline(widget.title))),
          );
        }
      }
      await _checkSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.librarySaveFailedShort('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openChapter(
    List<UidTitleData> chapters,
    int chapterIndex, {
    int pageIndex = 0,
  }) async {
    final chapter = chapters[chapterIndex];
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterPage(
          '${widget.slug}/${chapter.uid}',
          chapter.title,
          bookTitle: widget.title,
          chapters: chapters,
          chapterIndex: chapterIndex,
          bookSlug: widget.slug,
          initialPageIndex: pageIndex,
        ),
      ),
    );
    // Reading moves where the reader left off.
    if (mounted) setState(_loadProgress);
  }

  /// The chapter [_progress] is in, found by its slug in case chapters were
  /// added or reordered since; null when the reader has not started the
  /// book, or the chapter is gone.
  int? _currentChapter(List<UidTitleData> chapters) {
    final progress = _progress;
    if (progress == null) return null;
    final index = progress.chapterIndex;
    if (index >= 0 &&
        index < chapters.length &&
        chapters[index].uid == progress.chapterSlug) {
      return index;
    }
    final found =
        chapters.indexWhere((chapter) => chapter.uid == progress.chapterSlug);
    return found < 0 ? null : found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: widePageWidth);

    return FutureBuilder<List<UidTitleData>>(
      future: _chaptersFuture,
      builder: (context, snapshot) {
        final chapters = snapshot.data ?? const <UidTitleData>[];
        final loaded = snapshot.connectionState != ConnectionState.waiting;
        final current = _currentChapter(chapters);
        final chapterCount =
            chapters.isEmpty ? null : l10n.libraryChapterCount(chapters.length);
        final author = _author;

        final List<Widget> content;
        if (!loaded) {
          content = const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ];
        } else if (snapshot.hasError || chapters.isEmpty) {
          content = [
            SliverPadding(
              padding: gutter,
              sliver: SliverToBoxAdapter(
                child: snapshot.hasError
                    ? EmptyStateCard(
                        glyph: OutlineGlyph.search,
                        title: l10n.libraryChaptersUnavailable,
                        body: l10n.audioDownloadCheckConnection,
                        actionLabel: l10n.commonRetry,
                        onAction: _retry,
                      )
                    : EmptyStateCard(
                        glyph: OutlineGlyph.search,
                        title: l10n.libraryNoChapters,
                        body: l10n.libraryNoChaptersBody,
                      ),
              ),
            ),
          ];
        } else {
          final progress = _progress;
          content = [
            SliverPadding(
              padding: gutter.copyWith(bottom: 14),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageButton(
                      filled: true,
                      glyph: OutlineGlyph.play,
                      label: current != null && progress != null
                          ? l10n.libraryContinueAt(
                              current + 1, progress.pageIndex + 1)
                          : l10n.libraryStartReading,
                      onPressed: () => current != null && progress != null
                          ? _openChapter(chapters, current,
                              pageIndex: progress.pageIndex)
                          : _openChapter(chapters, 0),
                    ),
                    const SizedBox(height: 8),
                    PageButton(
                      glyph:
                          _isSaved ? OutlineGlyph.trash : OutlineGlyph.download,
                      label: _isSaved
                          ? l10n.libraryRemoveOffline
                          : l10n.librarySaveForOffline,
                      busy: _isSaving,
                      onPressed: _toggleSave,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: gutter.copyWith(bottom: 8),
              sliver:
                  SliverToBoxAdapter(child: GroupLabel(l10n.libraryChapters)),
            ),
            SliverPadding(
              padding: gutter,
              sliver: SliverCardList(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final reading = index == current && progress != null;
                  final pageCount = progress == null || progress.pageCount <= 0
                      ? 1
                      : progress.pageCount;
                  return CardListRow(
                    first: index == 0,
                    last: index == chapters.length - 1,
                    leading: NumberWell(index + 1, selected: reading, size: 32),
                    title: Text(chapters[index].title),
                    titleStyle: ShiaText.body.copyWith(
                        fontWeight:
                            reading ? FontWeight.w600 : FontWeight.w400),
                    subtitle: reading
                        ? Text(
                            l10n.libraryReadingAt(
                                progress.pageIndex.clamp(0, pageCount - 1) + 1,
                                pageCount),
                            style: ShiaText.caption.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w600),
                          )
                        : null,
                    trailing: Padding(
                      padding:
                          const EdgeInsetsDirectional.only(start: 8, end: 8),
                      child: OutlineIcon(OutlineGlyph.chevronRight,
                          size: 16, color: colors.chevron, strokeWidth: 2.4),
                    ),
                    onTap: reading
                        ? () => _openChapter(chapters, index,
                            pageIndex: progress.pageIndex)
                        : () => _openChapter(chapters, index),
                  );
                },
              ),
            ),
          ];
        }

        return LargeTitlePage(
          maxWidth: widePageWidth,
          title: widget.title,
          subtitle: author != null && chapterCount != null
              ? l10n.libraryAuthorAndChapters(author, chapterCount)
              : author ?? chapterCount,
          actions: [
            RoundIconButton(
              label: l10n.libraryShareBook,
              icon: OutlineIcon(OutlineGlyph.share,
                  size: 20, color: colors.accent),
              onPressed: _isSharing ? null : _shareBook,
            ),
          ],
          slivers: content,
        );
      },
    );
  }
}
