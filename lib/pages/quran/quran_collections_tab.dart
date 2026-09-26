import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/quran_ali_verses.dart';
import '../../data/universal_data.dart';
import '../../services/analytics_service.dart';
import '../../services/favorites_manager.dart';
import '../../services/saved_verses_store.dart';
import '../../utils/quran_index.dart';
import '../../utils/shared_preferences.dart';
import '../../widgets/favorite_icon.dart';
import '../../widgets/responsive_content.dart';

/// The groups the Collections tab can show, in chip order.
enum QuranCollection {
  duas('Duas'),
  imamAli('Imam Ali (as)'),
  saved('Saved');

  const QuranCollection(this.label);

  final String label;
}

/// The Quran screen's third tab: everything that is a *selection* of the
/// Quran rather than a way of walking through it, picked with a row of chips.
///
/// This is also where the zikrs the old 'Surahs' list carried alongside the
/// 114 - Ayat al Kursi and the Quran duas - live now, since the surah list
/// only shows surahs. New groups are one more [QuranCollection] value and one
/// more case in [_buildBody].
class QuranCollectionsTab extends StatefulWidget {
  const QuranCollectionsTab({
    super.key,
    required this.saved,
    required this.onOpenVerse,
    required this.onRemoveSaved,
  });

  final List<SavedVerse> saved;
  final void Function(VerseKey verse) onOpenVerse;
  final void Function(SavedVerse saved) onRemoveSaved;

  /// Remembers the chip last picked, so someone who comes here for their
  /// saved verses is not sent back to Duas every visit.
  static const String selectedCollectionKey = 'quran_collections_selected';

  @override
  State<QuranCollectionsTab> createState() => _QuranCollectionsTabState();
}

class _QuranCollectionsTabState extends State<QuranCollectionsTab> {
  late QuranCollection _selected;

  @override
  void initState() {
    super.initState();
    _selected = _readSelected();
  }

  QuranCollection _readSelected() {
    if (!SP.isInitialized) return QuranCollection.values.first;
    final stored =
        SP.prefs.getString(QuranCollectionsTab.selectedCollectionKey);
    return QuranCollection.values.firstWhere(
      (collection) => collection.name == stored,
      orElse: () => QuranCollection.values.first,
    );
  }

  void _select(QuranCollection collection) {
    setState(() => _selected = collection);
    if (SP.isInitialized) {
      SP.prefs.setString(
          QuranCollectionsTab.selectedCollectionKey, collection.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ResponsiveContent(
          maxWidth: listContentWidth,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final collection in QuranCollection.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(collection.label),
                      selected: collection == _selected,
                      onSelected: (_) => _select(collection),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    switch (_selected) {
      case QuranCollection.duas:
        return const _QuranDuaList();
      case QuranCollection.imamAli:
        return _AliVerseList(onOpen: widget.onOpenVerse);
      case QuranCollection.saved:
        return _SavedVerseList(
          saved: widget.saved,
          onOpen: widget.onOpenVerse,
          onRemove: widget.onRemoveSaved,
        );
    }
  }
}

String _verseTitle(VerseKey verse) {
  final name = surahInfoFor(verse.surah)?.englishName ?? 'Surah ${verse.surah}';
  return '$name ${verse.ayah}';
}

/// Ayat al Kursi and the duas recited with the Quran - the non-surah zikrs of
/// the Quran category, opened like any other zikr.
class _QuranDuaList extends StatelessWidget {
  const _QuranDuaList();

  @override
  Widget build(BuildContext context) {
    final uids = quranCompanionZikrUids();

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: uids.length,
        itemBuilder: (context, index) {
          // The same UniversalData shape the category lists build, so the
          // favourite here is the same favourite as in the old Surahs list.
          final itemData =
              UniversalData(uids[index], items[uids[index]].toString(), 0);

          return ListTile(
            title: Text(itemData.title),
            trailing: InkWell(
              onTap: () => FavoritesManager.instance.toggleFavorite(itemData),
              child: FavoriteIcon(favorite: itemData),
            ),
            onTap: () => handleUniversalDataClick(
              context,
              itemData,
              source: ZikrOpenSource.quran,
            ),
          );
        },
      ),
    );
  }
}

/// The curated verses about Imam Ali (as), in mushaf order, each with the
/// occasion it is known by.
class _AliVerseList extends StatelessWidget {
  const _AliVerseList({required this.onOpen});

  final void Function(VerseKey verse) onOpen;

  @override
  Widget build(BuildContext context) {
    final verses = quranAliVerses.keys.toList()
      ..sort((a, b) => a.surah != b.surah
          ? a.surah.compareTo(b.surah)
          : (a.ayah ?? 0).compareTo(b.ayah ?? 0));

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: verses.length,
        itemBuilder: (context, index) {
          final verse = verses[index];
          return ListTile(
            title: Text(_verseTitle(verse)),
            subtitle: Text(quranAliVerses[verse]!),
            onTap: () => onOpen(verse),
          );
        },
      ),
    );
  }
}

/// The verses the reader has kept.
///
/// In mushaf order rather than most-recent-first: this is a reference list
/// someone builds up and returns to, so it should read like an index of their
/// own Quran rather than a feed of recent activity.
class _SavedVerseList extends StatelessWidget {
  const _SavedVerseList({
    required this.saved,
    required this.onOpen,
    required this.onRemove,
  });

  final List<SavedVerse> saved;
  final void Function(VerseKey verse) onOpen;
  final void Function(SavedVerse saved) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (saved.isEmpty) {
      return ResponsiveContent(
        maxWidth: listContentWidth,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_outline,
                size: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'No saved verses yet',
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a verse while reading to keep it here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: saved.length,
        itemBuilder: (context, index) {
          final verse = saved[index];
          final title = verse.surahName.isNotEmpty
              ? '${verse.surahName} ${verse.ayah}'
              : _verseTitle(verse.verse);

          return ListTile(
            title: Text(title),
            subtitle: verse.excerpt.isEmpty
                ? null
                : Text(
                    verse.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: arabicFont,
                      fontFamilyFallback: const ['Qalam'],
                      fontSize: 16,
                    ),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: () => onRemove(verse),
            ),
            onTap: () => onOpen(verse.verse),
          );
        },
      ),
    );
  }
}
