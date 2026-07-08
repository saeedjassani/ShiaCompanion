import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';
import '../services/favorites_manager.dart';
import 'chapter_page.dart';

class LibraryPage extends StatefulWidget {
  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<UidTitleData>> _booksFuture;
  LibraryProgress? _lastProgress;

  @override
  void initState() {
    super.initState();
    trackScreen('Library Page');
    _booksFuture = LibraryService.loadBooks();
    _loadLastProgress();
  }

  void _retry() {
    setState(() {
      _booksFuture = LibraryService.loadBooks();
      _loadLastProgress();
    });
  }

  void _loadLastProgress() {
    _lastProgress = LibraryProgressStore.instance.readLast();
  }

  Future<void> _continueReading(LibraryProgress progress) async {
    final chapters = await LibraryService.loadChapters(progress.bookSlug);
    if (!mounted) return;

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
      await LibraryProgressStore.instance.removeLast();
      setState(_loadLastProgress);
      return;
    }

    final chapter = chapters[chapterIndex];
    await Navigator.push(
      context,
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
    if (!mounted) return;
    setState(_loadLastProgress);
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
                title: 'Library unavailable',
                message: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: _retry,
              ),
            _ when books.isEmpty => const _LibraryMessage(
                icon: Icons.library_books,
                title: 'No books found',
                message: 'The library is empty right now.',
              ),
            _ => ListView.separated(
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  if (_lastProgress != null && index == 0) {
                    return _ContinueReadingTile(
                      progress: _lastProgress!,
                      onTap: () => _continueReading(_lastProgress!),
                    );
                  }

                  final bookIndex = _lastProgress == null ? index : index - 1;
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
                            content: Text('${book.title} saved for offline.'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Unable to save book: ${e.toString().replaceFirst("Exception: ", "")}',
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
                itemCount: books.length + (_lastProgress == null ? 0 : 1),
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
  });

  final LibraryProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pageCount = progress.pageCount <= 0 ? 1 : progress.pageCount;
    final pageIndex = progress.pageIndex.clamp(0, pageCount - 1) + 1;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      leading: const Icon(Icons.play_circle_outline),
      title: const Text('Continue reading'),
      subtitle: Text(
        '${progress.chapterTitle} - Page $pageIndex of $pageCount',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      title: Text(book.title),
      onTap: () => handleUniversalDataClick(context, itemData),
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
