import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';
import 'chapter_page.dart';

class ChapterListPage extends StatefulWidget {
  final String slug;
  final String title;

  ChapterListPage(this.slug, this.title);

  @override
  _ChapterListPageState createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  late Future<List<UidTitleData>> _chaptersFuture;

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter List Page');
    _chaptersFuture = LibraryService.loadChapters(widget.slug);
  }

  void _retry() {
    setState(() {
      _chaptersFuture = LibraryService.loadChapters(widget.slug);
    });
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
