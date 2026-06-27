import 'dart:math' as math;

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

  ChapterPage(
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
  late final PageController _pageController;
  double _readerFontSize = 18;
  int _pageIndex = 0;
  int _pageCount = 1;
  bool _didRestoreInitialPage = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter Page');
    _pageController = PageController();
    _readerFontSize = (widget.initialFontSize ?? englishFontSize)
        .clamp(_minFontSize, _maxFontSize);
    _pageIndex = math.max(0, widget.initialPageIndex);
    _chapterFuture = LibraryService.loadChapterMarkdown(widget.slug);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _pageIndex = 0;
      _didRestoreInitialPage = false;
      _chapterFuture = LibraryService.loadChapterMarkdown(widget.slug);
    });
  }

  void _changeFontSize(double delta) {
    final pageRatio = _pageCount <= 1 ? 0.0 : _pageIndex / (_pageCount - 1);
    setState(() {
      _readerFontSize =
          (_readerFontSize + delta).clamp(_minFontSize, _maxFontSize);
      englishFontSize = _readerFontSize;
      _pageIndex = math.max(0, (pageRatio * (_pageCount - 1)).round());
    });
    if (SP.isInitialized) {
      SP.prefs.setDouble('eng_font_size', _readerFontSize);
    }
    _saveProgress();
  }

  List<String> _paginateMarkdown(
    String markdown,
    BoxConstraints constraints,
  ) {
    final normalized = markdown.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [''];

    final horizontalPadding = constraints.maxWidth >= 720 ? 56.0 : 32.0;
    final verticalPadding = constraints.maxHeight >= 720 ? 96.0 : 72.0;
    final contentWidth = math.min(
      readingContentWidth,
      math.max(240.0, constraints.maxWidth - horizontalPadding),
    );
    final contentHeight =
        math.max(240.0, constraints.maxHeight - verticalPadding);
    final charsPerLine =
        math.max(24, (contentWidth / (_readerFontSize * 0.52)).floor());
    final linesPerPage =
        math.max(7, (contentHeight / (_readerFontSize * _lineHeight)).floor());
    final budget = math.max(320, (charsPerLine * linesPerPage * 0.58).floor());

    final pages = <String>[];
    final blocks = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty);
    final current = StringBuffer();

    void flush() {
      final text = current.toString().trim();
      if (text.isNotEmpty) pages.add(text);
      current.clear();
    }

    for (final block in blocks) {
      if (block.length > budget) {
        flush();
        pages.addAll(_splitLongBlock(block, budget));
        continue;
      }

      final separatorLength = current.isEmpty ? 0 : 2;
      if (current.length + separatorLength + block.length > budget) {
        flush();
      }
      if (current.isNotEmpty) current.write('\n\n');
      current.write(block);
    }

    flush();
    return pages.isEmpty ? const [''] : pages;
  }

  List<String> _splitLongBlock(String block, int budget) {
    final pages = <String>[];
    final words = block.split(RegExp(r'\s+'));
    final current = StringBuffer();

    for (final word in words) {
      final separatorLength = current.isEmpty ? 0 : 1;
      if (current.length + separatorLength + word.length > budget) {
        final page = current.toString().trim();
        if (page.isNotEmpty) pages.add(page);
        current.clear();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(word);
    }

    final page = current.toString().trim();
    if (page.isNotEmpty) pages.add(page);
    return pages;
  }

  void _syncPageCount(int pageCount) {
    if (_didRestoreInitialPage &&
        _pageCount == pageCount &&
        _pageIndex < pageCount) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requestedIndex =
          _didRestoreInitialPage ? _pageIndex : widget.initialPageIndex;
      final nextIndex = math.max(0, math.min(requestedIndex, pageCount - 1));
      setState(() {
        _pageCount = pageCount;
        _pageIndex = nextIndex;
        _didRestoreInitialPage = true;
      });
      if (_pageController.hasClients &&
          nextIndex != _pageController.page?.round()) {
        _pageController.jumpToPage(nextIndex);
      }
      _saveProgress();
    });
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
        pageIndex: math.max(0, _pageIndex),
        pageCount: math.max(1, _pageCount),
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

  Widget _buildPagedReader(String chapterMarkdown) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _paginateMarkdown(chapterMarkdown, constraints);
        _syncPageCount(pages.length);

        return PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _pageIndex = index);
            _saveProgress();
          },
          itemCount: pages.length,
          itemBuilder: (context, index) {
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: readingContentWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth >= 720 ? 28 : 16,
                      constraints.maxHeight >= 720 ? 28 : 18,
                      constraints.maxWidth >= 720 ? 28 : 16,
                      28,
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: MarkdownBody(
                        data: pages[index],
                        selectable: true,
                        styleSheet: _readerStyleSheet(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              Text(
                'Page ${_pageIndex + 1} of $_pageCount',
                style: Theme.of(context).textTheme.bodyMedium,
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
