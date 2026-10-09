import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/quran_ali_verses.dart';
import '../../data/quran_duas.dart';
import '../../data/quran_mahdi_verses.dart';
import '../../data/quran_prophet_stories.dart';
import '../../data/universal_data.dart';
import '../../services/analytics_service.dart';
import '../../services/saved_verses_store.dart';
import '../../theme/shia_colors.dart';
import '../../utils/quran_index.dart';
import '../../utils/shared_preferences.dart';
import '../../widgets/favorite_icon.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../l10n/l10n.dart';

/// The groups the Collections view can show, in pill order.
enum QuranCollection {
  duas,
  imamAli,
  imamMahdi,
  prophets,
  saved;

  String get label => switch (this) {
        QuranCollection.duas => L10n.current.quranCollectionDuas,
        QuranCollection.imamAli => L10n.current.quranCollectionImamAli,
        QuranCollection.imamMahdi => L10n.current.quranCollectionImamMahdi,
        QuranCollection.prophets => L10n.current.quranCollectionProphets,
        QuranCollection.saved => L10n.current.quranCollectionSaved,
      };

  /// Remembers the collection last picked, so someone who comes for their
  /// saved verses is not sent back to Duas every visit.
  static const String selectedKey = 'quran_collections_selected';

  static QuranCollection readSelected() {
    if (!SP.isInitialized) return values.first;
    final stored = SP.prefs.getString(selectedKey);
    return values.firstWhere(
      (collection) => collection.name == stored,
      orElse: () => values.first,
    );
  }

  void remember() {
    if (SP.isInitialized) SP.prefs.setString(selectedKey, name);
  }
}

/// The Quran screen's Collections view: everything that is a *selection* of
/// the Quran rather than a way of walking through it, picked with a row of
/// pills.
///
/// This is also where the zikrs the old 'Surahs' list carried alongside the
/// 114 - Ayat al Kursi and the Quran duas - live, since the surah list only
/// shows surahs. New groups are one more [QuranCollection] value and one
/// more case in [_bodySlivers].
///
/// Built as slivers, so the list scrolls with the rest of the Quran screen
/// rather than in a box of its own under it.
class QuranCollectionsSliver extends StatelessWidget {
  const QuranCollectionsSliver({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.saved,
    required this.onOpenVerse,
    required this.onRemoveSaved,
  });

  final QuranCollection selected;
  final ValueChanged<QuranCollection> onSelect;
  final List<SavedVerse> saved;
  final void Function(VerseKey verse) onOpenVerse;
  final void Function(SavedVerse saved) onRemoveSaved;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          // Wrapped rather than scrolled sideways: with five collections a
          // single row runs off a phone screen and hides the last ones.
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final collection in QuranCollection.values)
                ChoicePill(
                  label: collection.label,
                  selected: collection == selected,
                  onTap: () => onSelect(collection),
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ..._bodySlivers(context),
      ],
    );
  }

  List<Widget> _bodySlivers(BuildContext context) {
    switch (selected) {
      case QuranCollection.duas:
        return _quranDuaSlivers(context, onOpenVerse);
      case QuranCollection.imamAli:
        return [_notedVerseSliver(quranAliVerses, onOpenVerse)];
      case QuranCollection.imamMahdi:
        return [_notedVerseSliver(quranMahdiVerses, onOpenVerse)];
      case QuranCollection.prophets:
        return _prophetStorySlivers(onOpenVerse);
      case QuranCollection.saved:
        return [
          saved.isEmpty
              ? const SliverToBoxAdapter(child: _NoSavedVerses())
              : _savedVerseSliver(context, saved, onOpenVerse, onRemoveSaved),
        ];
    }
  }
}

String _verseTitle(VerseKey verse) {
  final name = surahInfoFor(verse.surah)?.displayName ??
      L10n.current.quranSurahNumber(verse.surah);
  return L10n.current.quranSurahAyah(name, verse.ayah ?? 1);
}

/// Ayat al Kursi and the duas recited with the Quran - the non-surah zikrs of
/// the Quran category, opened like any other zikr - followed by the duas the
/// Quran itself contains ([quranDuas]), opened in the reader at their ayah.
List<Widget> _quranDuaSlivers(
    BuildContext context, void Function(VerseKey verse) onOpenVerse) {
  final uids = quranCompanionZikrUids();
  return [
    if (uids.isNotEmpty) ...[
      SliverCardList(
        itemCount: uids.length,
        itemBuilder: (context, index) {
          // The same UniversalData shape the category lists build, so the
          // favourite here is the same favourite as in the old Surahs list.
          final itemData =
              UniversalData(uids[index], items[uids[index]].toString(), 0);
          return CardListRow(
            first: index == 0,
            last: index == uids.length - 1,
            title: Text(itemData.displayTitle),
            trailing: FavoriteHeartButton(favorite: itemData),
            onTap: () => handleUniversalDataClick(
              context,
              itemData,
              source: ZikrOpenSource.quran,
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ],
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GroupLabel(context.l10n.quranFromTheQuran),
      ),
    ),
    SliverCardList(
      itemCount: quranDuas.length,
      itemBuilder: (context, index) {
        final dua = quranDuas[index];
        final reference = dua.endAyah == null
            ? _verseTitle(dua.verse)
            : '${_verseTitle(dua.verse)}-${dua.endAyah}';
        return CardListRow(
          first: index == 0,
          last: index == quranDuas.length - 1,
          title: Text(dua.opening),
          subtitle: Text('$reference · ${dua.note}'),
          onTap: () => onOpenVerse(dua.verse),
        );
      },
    ),
  ];
}

/// A curated verse collection - the verses about Imam Ali (a.s.)
/// ([quranAliVerses]) or Imam al-Mahdi (a.t.f.s.) ([quranMahdiVerses]) - in
/// mushaf order, each with the note it is known by.
Widget _notedVerseSliver(
    Map<VerseKey, String> notes, void Function(VerseKey verse) onOpen) {
  final verses = notes.keys.toList()
    ..sort((a, b) => a.surah != b.surah
        ? a.surah.compareTo(b.surah)
        : (a.ayah ?? 0).compareTo(b.ayah ?? 0));

  return SliverCardList(
    itemCount: verses.length,
    itemBuilder: (context, index) {
      final verse = verses[index];
      return CardListRow(
        first: index == 0,
        last: index == verses.length - 1,
        title: Text(_verseTitle(verse)),
        subtitle: Text(notes[verse]!),
        onTap: () => onOpen(verse),
      );
    },
  );
}

/// The stories of the prophets ([quranProphetStories]), one card per
/// prophet, each story opened in the reader at its first ayah.
List<Widget> _prophetStorySlivers(void Function(VerseKey verse) onOpen) {
  final groups = <String, List<QuranStory>>{};
  for (final story in quranProphetStories) {
    groups.putIfAbsent(story.prophet, () => []).add(story);
  }

  return [
    for (final entry in groups.entries) ...[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(
              top: entry.key == groups.keys.first ? 0 : 20, bottom: 8),
          child: GroupLabel(entry.key, upperCase: false),
        ),
      ),
      SliverCardList(
        itemCount: entry.value.length,
        itemBuilder: (context, index) {
          final story = entry.value[index];
          final start = _verseTitle(story.verse);
          final reference = story.endAyah == story.verse.ayah
              ? start
              : '$start-${story.endAyah}';
          return CardListRow(
            first: index == 0,
            last: index == entry.value.length - 1,
            title: Text(story.title),
            subtitle: Text(reference),
            onTap: () => onOpen(story.verse),
          );
        },
      ),
    ],
  ];
}

/// The verses the reader has kept.
///
/// In mushaf order rather than most-recent-first: this is a reference list
/// someone builds up and returns to, so it should read like an index of their
/// own Quran rather than a feed of recent activity.
Widget _savedVerseSliver(
  BuildContext context,
  List<SavedVerse> saved,
  void Function(VerseKey verse) onOpen,
  void Function(SavedVerse saved) onRemove,
) {
  return SliverCardList(
    itemCount: saved.length,
    itemBuilder: (context, index) => SavedVerseRow(
      verse: saved[index],
      first: index == 0,
      last: index == saved.length - 1,
      onOpen: () => onOpen(saved[index].verse),
      onRemove: () => onRemove(saved[index]),
    ),
  );
}

/// One kept verse: its reference, the opening of its Arabic, and a remove
/// button. Also the rows of Favorites' Quran verses.
class SavedVerseRow extends StatelessWidget {
  const SavedVerseRow({
    super.key,
    required this.verse,
    required this.onOpen,
    required this.onRemove,
    this.first = false,
    this.last = false,
  });

  final SavedVerse verse;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final title = verse.surahName.isNotEmpty
        ? '${verse.surahName} ${verse.ayah}'
        : _verseTitle(verse.verse);

    return CardListRow(
      first: first,
      last: last,
      title: Text(title),
      subtitle: verse.excerpt.isEmpty
          ? null
          : SizedBox(
              width: double.infinity,
              child: Text(
                verse.excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontFamilyFallback: const ['Qalam'],
                  fontSize: 18,
                  height: 1.8,
                  color: colors.text,
                ),
              ),
            ),
      trailing: Tooltip(
        message: context.l10n.commonRemove,
        child: InkResponse(
          onTap: onRemove,
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: OutlineIcon(OutlineGlyph.close,
                  size: 20, color: colors.chevron, strokeWidth: 2),
            ),
          ),
        ),
      ),
      onTap: onOpen,
    );
  }
}

/// What the saved list says before anything is kept, and how to keep one.
class _NoSavedVerses extends StatelessWidget {
  const _NoSavedVerses();

  @override
  Widget build(BuildContext context) {
    return EmptyStateCard(
      glyph: OutlineGlyph.heart,
      title: context.l10n.quranNoSavedVerses,
      body: context.l10n.quranNoSavedVersesBody,
    );
  }
}
