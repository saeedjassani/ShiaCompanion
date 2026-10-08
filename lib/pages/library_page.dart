import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
import 'package:shia_companion/widgets/find_field.dart';
import 'package:shia_companion/widgets/home_glyph.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/widgets/zikr_list_row.dart';

import '../constants.dart';
import 'chapter_list_page.dart';
import 'chapter_page.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/content_request_service.dart';
import 'package:shia_companion/widgets/content_request_dialog.dart';
import '../l10n/l10n.dart';

/// The Library (docs/DESIGN_SPEC.md, "Library"; mockup `R3-Library`): the
/// title with how many books there are, where the reader left off, then
/// every book with its author and the heart, narrowed by the "Find a book
/// or author" field at the bottom.
class LibraryPage extends StatefulWidget {
  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<UidTitleData>> _booksFuture;
  List<LibraryProgress> _recentProgress = const [];
  final TextEditingController _find = TextEditingController();

  @override
  void initState() {
    super.initState();
    trackScreen('Library Page');
    _booksFuture = LibraryService.loadBooks();
    _loadRecentProgress();
    _find.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _booksFuture = LibraryService.loadBooks();
      _loadRecentProgress();
    });
  }

  void _loadRecentProgress() {
    _recentProgress = LibraryProgressStore.instance.readAll();
  }

  Future<void> _continueReading(LibraryProgress progress) async {
    await resumeLibraryReading(context, progress);
    if (!mounted) return;
    setState(_loadRecentProgress);
  }

  Future<void> _forget(LibraryProgress progress) async {
    await LibraryProgressStore.instance.remove(progress.bookSlug);
    if (!mounted) return;
    setState(_loadRecentProgress);
  }

  Future<void> _openBook(UidTitleData book) async {
    await handleUniversalDataClick(
        context, UniversalData(book.uid, book.title, 1),
        source: ZikrOpenSource.library);
    // Reading a chapter moves where the reader left off.
    if (mounted) setState(_loadRecentProgress);
  }

  void _requestBook({String title = ''}) => showContentRequestDialog(
        context,
        initialType: ContentRequestType.book,
        initialTitle: title,
        source: 'library',
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gutter = pageGutter(context, maxWidth: widePageWidth);

    return FutureBuilder<List<UidTitleData>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <UidTitleData>[];
        final loaded = snapshot.connectionState != ConnectionState.waiting;
        final query = _find.text.trim();
        final shown = query.isEmpty
            ? books
            : filterDataSearchResults(books, query, matchUid: isUserAdmin);

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
        } else if (snapshot.hasError) {
          content = [
            SliverPadding(
              padding: gutter,
              sliver: SliverToBoxAdapter(
                child: EmptyStateCard(
                  glyph: OutlineGlyph.search,
                  title: l10n.libraryUnavailable,
                  body: l10n.audioDownloadCheckConnection,
                  actionLabel: l10n.commonRetry,
                  onAction: _retry,
                ),
              ),
            ),
          ];
        } else if (books.isEmpty) {
          content = [
            SliverPadding(
              padding: gutter,
              sliver: SliverToBoxAdapter(
                child: EmptyStateCard(
                  glyph: OutlineGlyph.search,
                  title: l10n.libraryNoBooks,
                  body: l10n.libraryEmpty,
                ),
              ),
            ),
          ];
        } else {
          content = [
            // Where the reader left off belongs to the whole library, not
            // to a search through it.
            if (query.isEmpty)
              for (final progress in _recentProgress)
                SliverPadding(
                  padding: gutter.copyWith(bottom: 14),
                  sliver: SliverToBoxAdapter(
                    child: _ContinueReadingCard(
                      progress: progress,
                      onTap: () => _continueReading(progress),
                      onDismiss: () => _forget(progress),
                    ),
                  ),
                ),
            SliverPadding(
              padding: gutter.copyWith(bottom: 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: GroupLabel(l10n.libraryAllBooks)),
                    PageTextAction(
                      label: l10n.libraryRequestBook,
                      onPressed: _requestBook,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: gutter,
              sliver: shown.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyStateCard(
                        glyph: OutlineGlyph.search,
                        title: l10n.listFindNone(query),
                        body: l10n.libraryRequestBookSubtitle,
                        actionLabel: l10n.libraryRequestBook,
                        onAction: () => _requestBook(title: query),
                      ),
                    )
                  : SliverCardList(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final book = shown[i];
                        return ZikrListRow(
                          item: UniversalData(book.uid, book.title, 1),
                          // Several books share near-identical titles -
                          // translations of the same work, mostly - so the
                          // author is what tells them apart. Not every book
                          // names one.
                          subtitle: book.author,
                          highlight: query,
                          first: i == 0,
                          last: i == shown.length - 1,
                          onTap: () => _openBook(book),
                        );
                      },
                    ),
            ),
          ];
        }

        return LargeTitlePage(
          maxWidth: widePageWidth,
          title: l10n.libraryTitle,
          subtitle: books.isEmpty ? null : l10n.libraryCount(books.length),
          bottom: books.isEmpty
              ? null
              : FindField(controller: _find, hint: l10n.libraryFindHint),
          slivers: content,
        );
      },
    );
  }
}

/// Where the reader left a book: the book, the chapter and page, how far
/// through the chapter, and × to forget it.
class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.progress,
    required this.onTap,
    required this.onDismiss,
  });

  final LibraryProgress progress;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final pageCount = progress.pageCount <= 0 ? 1 : progress.pageCount;
    final page = progress.pageIndex.clamp(0, pageCount - 1) + 1;
    final title = progress.bookTitle.trim().isNotEmpty
        ? progress.bookTitle
        : progress.chapterTitle;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HomeGlyph(
                            type: HomeGlyphType.library,
                            size: 16,
                            color: colors.accent),
                        const SizedBox(width: 6),
                        Text(
                          l10n.libraryContinueReading,
                          style: ShiaText.caption
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShiaText.cardTitle.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.libraryChapterPage(
                          progress.chapterTitle, page, pageCount),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShiaText.caption.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: page / pageCount,
                        minHeight: 4,
                        color: colors.accent,
                        backgroundColor: colors.divider,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.commonRemove,
                excludeFromSemantics: true,
                child: Semantics(
                  button: true,
                  label: l10n.libraryRemoveContinue(title),
                  excludeSemantics: true,
                  onTap: onDismiss,
                  child: InkResponse(
                    onTap: onDismiss,
                    radius: 22,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: OutlineIcon(OutlineGlyph.close,
                            size: 18, color: colors.textMuted, strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the chapter [progress] was saved in, at its page and font size, with
/// the book's chapter list underneath - backing out of the chapter lands in
/// the book, the same place a reader who navigated in by hand would be.
///
/// Used by Library's "Continue Reading" and Home's Continue cards. A chapter
/// that no longer exists says so and forgets the progress.
Future<void> resumeLibraryReading(
  BuildContext context,
  LibraryProgress progress,
) async {
  final chapters = await LibraryService.loadChapters(progress.bookSlug);
  if (!context.mounted) return;

  var chapterIndex = progress.chapterIndex;
  if (chapterIndex < 0 ||
      chapterIndex >= chapters.length ||
      chapters[chapterIndex].uid != progress.chapterSlug) {
    chapterIndex = chapters.indexWhere(
      (chapter) => chapter.uid == progress.chapterSlug,
    );
  }
  if (chapterIndex < 0 || chapterIndex >= chapters.length) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.librarySavedChapterGone)),
    );
    await LibraryProgressStore.instance.remove(progress.bookSlug);
    return;
  }

  final chapter = chapters[chapterIndex];
  final bookTitle = progress.bookTitle.trim().isNotEmpty
      ? progress.bookTitle
      : progress.chapterTitle;
  final navigator = Navigator.of(context);

  navigator.push(
    MaterialPageRoute(
      builder: (context) => ChapterListPage(progress.bookSlug, bookTitle),
    ),
  );
  await navigator.push(
    MaterialPageRoute(
      builder: (context) => ChapterPage(
        '${progress.bookSlug}/${chapter.uid}',
        chapter.title,
        bookTitle: progress.bookTitle,
        chapters: chapters,
        chapterIndex: chapterIndex,
        bookSlug: progress.bookSlug,
        initialPageIndex: progress.pageIndex,
      ),
    ),
  );
}
