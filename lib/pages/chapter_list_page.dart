import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';
import 'chapter_page.dart';

class ChapterListPage extends StatefulWidget {
  final String slug;
  final String title;

  const ChapterListPage(this.slug, this.title);

  @override
  _ChapterListPageState createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  late Future<List<UidTitleData>> _chaptersFuture;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter List Page');
    _chaptersFuture = LibraryService.loadChapters(widget.slug);
    _checkSaved();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline copy removed')),
          );
        }
      } else {
        await LibraryService.saveBookForOffline(widget.slug, widget.title);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.title} saved for offline')),
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

  void _openChapter(List<UidTitleData> chapters, UidTitleData chapter) {
    final chapterIndex = chapters.indexOf(chapter);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterPage(
          '${widget.slug}/${chapter.uid}',
          chapter.title,
          bookTitle: widget.title,
          chapters: chapters,
          chapterIndex: chapterIndex,
          bookSlug: widget.slug,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
      ),
      body: FutureBuilder<List<UidTitleData>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          final chapters = snapshot.data ?? const <UidTitleData>[];

          return ResponsiveContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: switch (snapshot.connectionState) {
              ConnectionState.waiting => const Center(
                  child: CircularProgressIndicator(),
                ),
              _ when snapshot.hasError => _ChapterMessage(
                  icon: Icons.cloud_off,
                  title: 'Chapters unavailable',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: _retry,
                ),
              _ when chapters.isEmpty => const _ChapterMessage(
                  icon: Icons.menu_book,
                  title: 'No chapters found',
                  message: 'This book has no chapters right now.',
                ),
              _ => ListView.separated(
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      title: Text(chapter.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openChapter(chapters, chapter),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: chapters.length,
                ),
            },
          );
        },
      ),
    );
  }
}

class _ChapterMessage extends StatelessWidget {
  const _ChapterMessage({
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
