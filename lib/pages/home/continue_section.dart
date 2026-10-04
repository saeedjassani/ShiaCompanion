import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../models/recitation_tracker_state.dart';
import '../../services/analytics_service.dart';
import '../../services/library_progress_store.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../services/zikr_bookmark_store.dart';
import '../../services/zikr_bookmarks_manager.dart';
import '../../theme/shia_colors.dart';
import '../../utils/quran_index.dart';
import '../../widgets/home_glyph.dart';
import '../library_page.dart';
import '../quran/quran_navigation.dart';
import '../zikr/zikr_page.dart';
import 'home_section.dart';

enum ContinueKind { quran, bookmark, library }

/// One Continue card: where the reader left off in one kind of reading.
@immutable
class ContinueEntry {
  const ContinueEntry({
    required this.kind,
    required this.caption,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    this.progress,
    this.recitationLabel,
    this.verse,
    this.bookmark,
    this.library,
  });

  final ContinueKind kind;

  /// "Quran", "Dua · bookmark", "Library".
  final String caption;
  final HomeGlyphType glyph;
  final String title;
  final String subtitle;
  final DateTime updatedAt;

  /// 0-1 along the surah, for a Quran track; null otherwise.
  final double? progress;

  final String? recitationLabel;
  final VerseKey? verse;
  final ZikrBookmark? bookmark;
  final LibraryProgress? library;
}

/// What each zikr category is called on a bookmark card, and its glyph, by
/// uid prefix.
const Map<String, (String, HomeGlyphType)> _bookmarkCategories = {
  'A': ('Quran', HomeGlyphType.surahs),
  'C': ('Aamaal', HomeGlyphType.aamaal),
  'D': ('Taqibaat', HomeGlyphType.taqeebat),
  'E': ('Dua', HomeGlyphType.duas),
  'F': ('Namaz', HomeGlyphType.namaz),
  'G': ('Ziyarat', HomeGlyphType.ziyaraat),
  'H': ('Munajat', HomeGlyphType.munajaat),
  'I': ('Zikr', HomeGlyphType.baqeyaat),
};

/// Up to three cards, newest first: the most recent Quran track, zikr
/// bookmark and library book - one of each, so a busy week in one never
/// pushes the other two off Home.
@visibleForTesting
List<ContinueEntry> continueEntries({
  required RecitationTrackerState recitations,
  required Iterable<ZikrBookmark> bookmarks,
  required List<LibraryProgress> library,
  required bool includeQuran,
  Map<dynamic, dynamic> titles = const {},
}) {
  final entries = <ContinueEntry>[];

  final latestRecitation =
      includeQuran ? recitations.mostRecentFirst.firstOrNull : null;
  if (latestRecitation != null) {
    final label = latestRecitation.label;
    final resume = recitations.resumePositionFor(label);
    final info = resume == null ? null : surahInfoFor(resume.surah);
    if (resume != null && info != null) {
      final ayah = resume.ayah ?? 1;
      entries.add(ContinueEntry(
        kind: ContinueKind.quran,
        caption: label == unlabeledRecitationLabel ? 'Quran' : 'Quran · $label',
        glyph: HomeGlyphType.surahs,
        title: info.englishName,
        subtitle: 'Verse $ayah of ${info.ayahCount}',
        progress: ayah / info.ayahCount,
        updatedAt: latestRecitation.recitedAt,
        recitationLabel: label,
        verse: resume,
      ));
    }
  }

  ZikrBookmark? latestBookmark;
  for (final bookmark in bookmarks) {
    if (latestBookmark == null ||
        bookmark.updatedAt.isAfter(latestBookmark.updatedAt)) {
      latestBookmark = bookmark;
    }
  }
  if (latestBookmark != null) {
    final prefix = RegExp(r'^[A-Za-z]+').stringMatch(latestBookmark.uid) ?? '';
    final (word, glyph) =
        _bookmarkCategories[prefix] ?? ('Zikr', HomeGlyphType.duas);
    final tab = latestBookmark.tabTitle?.trim() ?? '';
    final title = titles[latestBookmark.uid]?.toString();
    entries.add(ContinueEntry(
      kind: ContinueKind.bookmark,
      caption: '$word · bookmark',
      glyph: glyph,
      title: (title == null || title.isEmpty) ? latestBookmark.title : title,
      subtitle: tab.isEmpty ? 'Pick up at your bookmark' : 'Pick up in $tab',
      updatedAt: latestBookmark.updatedAt,
      bookmark: latestBookmark,
    ));
  }

  final latestBook = library.firstOrNull;
  if (latestBook != null) {
    final book = latestBook.bookTitle.trim();
    entries.add(ContinueEntry(
      kind: ContinueKind.library,
      caption: 'Library',
      glyph: HomeGlyphType.library,
      title: book.isEmpty ? latestBook.chapterTitle : book,
      subtitle:
          book.isEmpty ? 'Pick up where you stopped' : latestBook.chapterTitle,
      updatedAt: latestBook.updatedAt,
      library: latestBook,
    ));
  }

  entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return entries.take(3).toList(growable: false);
}

/// "Continue": pick up the latest Quran track, bookmark or book. Hidden when
/// there is nothing to continue.
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    super.key,
    this.horizontalPadding = 16,
    this.topSpacing = 0,
  });

  /// Space above the section, only when it shows - so a Home with nothing
  /// to continue has no gap where it would be.
  final double topSpacing;

  /// The page gutter. On phones the cards scroll sideways to the screen's
  /// edge, so the section draws its own gutter inside the scroller instead
  /// of being padded by the page.
  final double horizontalPadding;

  Future<void> _open(BuildContext context, ContinueEntry entry) async {
    switch (entry.kind) {
      case ContinueKind.quran:
        await openQuranVerse(
          context,
          entry.verse!,
          source: ZikrOpenSource.quranResume,
          recitationLabel: entry.recitationLabel,
        );
      case ContinueKind.bookmark:
        final bookmark = entry.bookmark!;
        // The reader resumes at the bookmark on its own (ZikrPage reads it).
        await pushPageRoute(
          context,
          ZikrPage(
            UidTitleData(bookmark.uid, entry.title),
            source: ZikrOpenSource.homeContinue,
          ),
        );
      case ContinueKind.library:
        await resumeLibraryReading(context, entry.library!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        RecitationTrackerManager.instance,
        ZikrBookmarksManager.instance,
      ]),
      builder: (context, _) {
        final entries = continueEntries(
          recitations: RecitationTrackerManager.instance.state,
          bookmarks: ZikrBookmarksManager.instance.state.bookmarks.values,
          library: LibraryProgressStore.instance.readAll(),
          // Resuming a surah at a verse is part of the dark-launched Quran
          // reading (see quranMenuItem), so only admins see a track here.
          includeQuran: isUserAdmin,
          titles: items,
        );
        if (entries.isEmpty) return const SizedBox.shrink();

        final wide = isHomeWide(context);
        final gutter = EdgeInsets.symmetric(horizontal: horizontalPadding);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topSpacing),
            Padding(
              padding: gutter,
              child: const HomeSectionHeader(title: 'Continue'),
            ),
            const SizedBox(height: 10),
            if (wide)
              Padding(
                padding: gutter,
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 10),
                      // Two to a row, each pair as tall as its taller card.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ContinueCard(
                                entry: entries[i],
                                onTap: () => _open(context, entries[i]),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: i + 1 < entries.length
                                  ? _ContinueCard(
                                      entry: entries[i + 1],
                                      onTap: () =>
                                          _open(context, entries[i + 1]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: gutter,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        SizedBox(
                          width: 228,
                          child: _ContinueCard(
                            entry: entries[i],
                            onTap: () => _open(context, entries[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap});

  final ContinueEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final progress = entry.progress;

    return HomeCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HomeGlyph(type: entry.glyph, size: 18, color: colors.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShiaText.caption.copyWith(
                        height: 16 / 13,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.cardTitle.copyWith(
                  height: 21 / 17,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.caption.copyWith(
                  fontSize: 14,
                  height: 18 / 14,
                  color: colors.textMuted,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 4,
                    color: colors.accent,
                    backgroundColor: colors.divider,
                    semanticsLabel: 'Progress through the surah',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
