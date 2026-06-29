import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

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

class _ChapterPageState extends State<ChapterPage> {
  static const double _minFontSize = 14;
  static const double _maxFontSize = 28;
  static const double _lineHeight = 1.55;

  late Future<String> _chapterFuture;
  double _readerFontSize = 18;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter Page');
    _readerFontSize = (widget.initialFontSize ?? englishFontSize)
        .clamp(_minFontSize, _maxFontSize);
    _chapterFuture = LibraryService.loadChapterMarkdown(widget.slug);
    _checkSaved();
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
    setState(() {
      _readerFontSize =
          (_readerFontSize + delta).clamp(_minFontSize, _maxFontSize);
      englishFontSize = _readerFontSize;
    });
    if (SP.isInitialized) {
      SP.prefs.setDouble('eng_font_size', _readerFontSize);
    }
    _saveProgress();
  }

  void _saveProgress() {
    final bookSlug = widget.bookSlug;
    if (bookSlug == null || bookSlug.trim().isEmpty) return;

    final fallbackChapterSlug = widget.slug.split('/').last;
    final chapterSlug =
        widget.chapterIndex >= 0 && widget.chapterIndex < widget.chapters.length
            ? widget.chapters[widget.chapterIndex].uid
            : fallbackChapterSlug;

    LibraryProgressStore.instance.save(
      LibraryProgress(
        bookSlug: bookSlug,
        bookTitle: widget.bookTitle ?? '',
        chapterSlug: chapterSlug,
        chapterTitle: widget.title,
        chapterIndex: widget.chapterIndex,
        pageIndex: 0,
        pageCount: 1,
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
      blockquote: textTheme.bodyLarge?.copyWith(
        fontSize: _readerFontSize,
        height: _lineHeight,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildScrollableReader(String chapterMarkdown) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readingContentWidth),
        child: MarkdownBody(
          data: chapterMarkdown,
          selectable: true,
          styleSheet: _readerStyleSheet(context),
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
    final bookSlug = widget.bookSlug;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (bookSlug != null && bookSlug.trim().isNotEmpty)
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
          return _buildScrollableReader(snapshot.data ?? '');
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
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
