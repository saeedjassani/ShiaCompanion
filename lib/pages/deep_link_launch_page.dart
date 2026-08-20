import 'package:flutter/material.dart';

import '../data/uid_title_data.dart';
import '../services/deep_link_resolver.dart';
import '../services/library_service.dart';
import '../services/session_refresh_service.dart';
import '../utils/deep_links.dart';
import 'chapter_list_page.dart';
import 'chapter_page.dart';
import 'deep_link_not_found_page.dart';
import 'zikr/zikr_page.dart';

/// The route the web app boots into when someone opens a shared link.
///
/// Before this existed, `/zikr/<slug>` generated no route, so Navigator fell
/// back to `onUnknownRoute`, which mounts home and then removes itself.
/// Removing a route above home fires its `didPopNext`, which rewrites the
/// address bar to "/" — and the real page could only be pushed once the zikr
/// index had loaded. A shared link therefore showed the home screen, reset the
/// URL, and only then arrived at the zikr.
///
/// Generating this route for the launch URL keeps the address bar on the
/// shared link throughout and puts the destination on screen the moment the
/// index is in. The index load is still unavoidable — the slug-to-uid map
/// lives there — but it now happens behind a neutral screen rather than behind
/// the home page.
class DeepLinkLaunchPage extends StatefulWidget {
  const DeepLinkLaunchPage({super.key, required this.target});

  final DeepLinkTarget target;

  @override
  State<DeepLinkLaunchPage> createState() => _DeepLinkLaunchPageState();
}

class _DeepLinkLaunchPageState extends State<DeepLinkLaunchPage> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    Widget destination;
    try {
      await SessionRefreshService.refreshSessionState();
      destination = await _resolveDestination() ??
          DeepLinkNotFoundPage(target: widget.target.segments.join('/'));
    } catch (error) {
      // A shared link is often someone's first contact with the app. Failing
      // to a named page beats an error screen or an indefinite spinner.
      debugPrint('Unable to resolve launch deep link: $error');
      destination =
          DeepLinkNotFoundPage(target: widget.target.segments.join('/'));
    }

    if (!mounted) return;
    setState(() => _destination = destination);
  }

  Future<Widget?> _resolveDestination() async {
    if (widget.target.segments.isEmpty) return null;

    switch (widget.target.type) {
      case zikrDeepLinkType:
        final item = await DeepLinkResolver.resolveZikrItem(widget.target);
        return item == null ? null : ZikrPage(item);
      case libraryDeepLinkType:
        return _resolveLibraryDestination();
      default:
        return null;
    }
  }

  Future<Widget?> _resolveLibraryDestination() async {
    final bookSlug = widget.target.segments.first;
    final chapterSlug =
        widget.target.segments.length > 1 ? widget.target.segments[1] : null;

    final books = await LibraryService.loadBooks();
    UidTitleData? book;
    for (final candidate in books) {
      if (candidate.uid == bookSlug) {
        book = candidate;
        break;
      }
    }
    if (book == null) return null;
    final resolvedBook = book;

    if (chapterSlug == null) {
      return ChapterListPage(resolvedBook.uid, resolvedBook.title);
    }

    List<UidTitleData> chapters;
    try {
      chapters = await LibraryService.loadChapters(bookSlug);
    } on LibraryLoadException {
      chapters = const [];
    }

    final chapterIndex =
        chapters.indexWhere((chapter) => chapter.uid == chapterSlug);
    if (chapterIndex == -1) {
      // Same fallback the home page uses: an unknown chapter lands in the book
      // rather than on a not-found page.
      return ChapterListPage(resolvedBook.uid, resolvedBook.title);
    }

    final chapter = chapters[chapterIndex];
    return ChapterPage(
      '$bookSlug/${chapter.uid}',
      chapter.title,
      bookTitle: resolvedBook.title,
      chapters: chapters,
      chapterIndex: chapterIndex,
      bookSlug: bookSlug,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    if (destination != null) {
      return destination;
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
