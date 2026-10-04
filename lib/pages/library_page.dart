import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';
import '../services/favorites_manager.dart';
import 'chapter_list_page.dart';
import 'chapter_page.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/content_request_service.dart';
import 'package:shia_companion/widgets/content_request_dialog.dart';
import '../l10n/l10n.dart';

class LibraryPage extends StatefulWidget {
  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<UidTitleData>> _booksFuture;
  List<LibraryProgress> _recentProgress = const [];

  @override
  void initState() {
    super.initState();
    trackScreen('Library Page');
    _booksFuture = LibraryService.loadBooks();
    _loadRecentProgress();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<UidTitleData>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <UidTitleData>[];

        return ResponsiveContent(
          maxWidth: listContentWidth,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: switch (snapshot.connectionState) {
            ConnectionState.waiting => const Center(
                child: CircularProgressIndicator(),
              ),
            _ when snapshot.hasError => _LibraryMessage(
                icon: Icons.cloud_off,
                title: context.l10n.libraryUnavailable,
                message: context.l10n.audioDownloadCheckConnection,
                actionLabel: context.l10n.commonRetry,
                onAction: _retry,
              ),
            _ when books.isEmpty => _LibraryMessage(
                icon: Icons.library_books,
                title: context.l10n.libraryNoBooks,
                message: context.l10n.libraryEmpty,
              ),
            _ => ListView.separated(
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final continueCount = _recentProgress.length;
                  final headerOffset = continueCount == 0 ? 0 : 1;

                  if (continueCount > 0 && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        context.l10n.libraryContinueReading,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  if (index < continueCount + headerOffset) {
                    final progress = _recentProgress[index - headerOffset];
                    return _ContinueReadingTile(
                      progress: progress,
                      onTap: () => _continueReading(progress),
                      onDismiss: () async {
                        await LibraryProgressStore.instance.remove(progress.bookSlug);
                        if (!mounted) return;
                        setState(_loadRecentProgress);
                      },
                    );
                  }

                  final bookIndex = index - continueCount - headerOffset;
                  if (bookIndex == books.length) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      leading: const Icon(Icons.playlist_add),
                      title: Text(context.l10n.libraryRequestBook),
                      subtitle: Text(
                          context.l10n.libraryRequestBookSubtitle),
                      onTap: () => showContentRequestDialog(
                        context,
                        initialType: ContentRequestType.book,
                        source: 'library',
                      ),
                    );
                  }
                  final book = books[bookIndex];
                  final itemData = UniversalData(book.uid, book.title, 1);
                  return _BookTile(
                    book: book,
                    itemData: itemData,
                    isSaved: false,
                    onSaveToggle: () async {
                      try {
                        await LibraryService.saveBookForOffline(
                          book.uid,
                          book.title,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.librarySavedOffline(book.title)),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.librarySaveFailed(
                                    e.toString().replaceFirst("Exception: ", "")),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
                separatorBuilder: (context, index) => Divider(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
                // +1 for the context.l10n.libraryRequestBook row after the last book.
                itemCount: books.length +
                    1 +
                    _recentProgress.length +
                    (_recentProgress.isEmpty ? 0 : 1),
              ),
          },
        );
      },
    );
  }
}

class _ContinueReadingTile extends StatelessWidget {
  const _ContinueReadingTile({
    required this.progress,
    required this.onTap,
    required this.onDismiss,
  });

  final LibraryProgress progress;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final pageCount = progress.pageCount <= 0 ? 1 : progress.pageCount;
    final pageIndex = progress.pageIndex.clamp(0, pageCount - 1) + 1;

    final title = progress.bookTitle.trim().isNotEmpty
        ? progress.bookTitle
        : progress.chapterTitle;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      leading: const Icon(Icons.play_circle_outline),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        context.l10n.libraryProgress(
            progress.chapterTitle, pageIndex, pageCount),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.commonRemove,
        onPressed: onDismiss,
      ),
      onTap: onTap,
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.itemData,
    required this.isSaved,
    required this.onSaveToggle,
  });

  final UidTitleData book;
  final UniversalData itemData;
  final bool isSaved;
  final Future<void> Function() onSaveToggle;

  @override
  Widget build(BuildContext context) {
    final author = book.author;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      title: Text(book.title),
      // The library holds several works under near-identical titles — separate
      // translations of the same book, most often — so the author is what tells
      // two rows apart. Not every book names one, and those rows simply have no
      // subtitle rather than a placeholder.
      subtitle: author == null
          ? null
          : Text(author, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => handleUniversalDataClick(context, itemData,
          source: ZikrOpenSource.library),
      trailing: Wrap(
        spacing: 12,
        children: [
          InkWell(
            onTap: () async {
              await FavoritesManager.instance.toggleFavorite(itemData);
            },
            child: FavoriteIcon(favorite: itemData),
          ),
        ],
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
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
              child: Text(actionLabel!),
            ),
          ],
        ],
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
      const SnackBar(content: Text('Saved chapter is no longer available')),
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
        initialFontSize: progress.fontSize,
      ),
    ),
  );
}
