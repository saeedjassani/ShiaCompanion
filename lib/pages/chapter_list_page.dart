import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/web_route_sync.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import 'chapter_page.dart';

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

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter List Page');
    _chaptersFuture = LibraryService.loadChapters(widget.slug);
    _checkSaved();
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
            const SnackBar(content: Text('Offline copy removed')),
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
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            tooltip: 'Share book',
            onPressed: _isSharing ? null : _shareBook,
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
