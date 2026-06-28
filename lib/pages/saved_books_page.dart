import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';

class SavedBooksPage extends StatefulWidget {
  const SavedBooksPage({Key? key}) : super(key: key);

  @override
  State<SavedBooksPage> createState() => _SavedBooksPageState();
}

class _SavedBooksPageState extends State<SavedBooksPage> {
  late Future<List<SavedBook>> _savedFuture;

  @override
  void initState() {
    super.initState();
    _savedFuture = LibraryService.loadSavedBooks();
  }

  void _refresh() => setState(() => _savedFuture = LibraryService.loadSavedBooks());

  Future<void> _openBook(SavedBook book) async {
    final chapters = await LibraryService.loadSavedChapters(book.bookSlug);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SavedChaptersPage(bookSlug: book.bookSlug, title: book.title, chapters: chapters),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Books')),
      body: FutureBuilder<List<SavedBook>>(
        future: _savedFuture,
        builder: (context, snapshot) {
          final books = snapshot.data ?? const <SavedBook>[];
          return ResponsiveContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: switch (snapshot.connectionState) {
              ConnectionState.waiting => const Center(child: CircularProgressIndicator()),
              _ when snapshot.hasError => _Message(
                  icon: Icons.cloud_off,
                  title: 'Unable to load saved books',
                  message: 'Please try again.',
                  onAction: _refresh,
                ),
              _ when books.isEmpty => const _Empty(
                  icon: Icons.download,
                  title: 'No saved books',
                  message: 'Save books from the Library to read them offline.',
                ),
              _ => ListView.separated(
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _BookTile(
                      book: book,
                      onOpen: () => _openBook(book),
                      onRemove: () async {
                        await LibraryService.removeSavedBook(book.bookSlug);
                        _refresh();
                      },
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: books.length,
                ),
            },
          );
        },
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onOpen, required this.onRemove});
  final SavedBook book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      title: Text(book.title),
      subtitle: Text('Saved ${book.savedAt.day}/${book.savedAt.month}/${book.savedAt.year}'),
      trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Remove', onPressed: onRemove),
      onTap: onOpen,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message, this.onAction});
  final IconData icon;
  final String title;
  final String message;
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
          if (onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SavedChaptersPage extends StatefulWidget {
  const _SavedChaptersPage({required this.bookSlug, required this.title, required this.chapters});
  final String bookSlug;
  final String title;
  final List<UidTitleData> chapters;

  @override
  State<_SavedChaptersPage> createState() => _SavedChaptersPageState();
}

class _SavedChaptersPageState extends State<_SavedChaptersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: widget.chapters.isEmpty
          ? const Center(child: Text('No chapters available.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final chapter = widget.chapters[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  title: Text(chapter.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _SavedChapterPage(
                          bookSlug: widget.bookSlug,
                          chapterSlug: chapter.uid,
                          title: chapter.title,
                        ),
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              itemCount: widget.chapters.length,
            ),
    );
  }
}

class _SavedChapterPage extends StatefulWidget {
  const _SavedChapterPage({required this.bookSlug, required this.chapterSlug, required this.title});
  final String bookSlug;
  final String chapterSlug;
  final String title;

  @override
  State<_SavedChapterPage> createState() => _SavedChapterPageState();
}

class _SavedChapterPageState extends State<_SavedChapterPage> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    trackScreen('Saved Chapter Page');
    _future = LibraryService.loadSavedChapterMarkdown(widget.bookSlug, widget.chapterSlug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Unable to load this saved chapter.'));
          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(snapshot.data ?? ''));
        },
      ),
    );
  }
}
