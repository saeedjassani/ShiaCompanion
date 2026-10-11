import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../constants.dart';
import '../../data/quran_ali_verses.dart';
import '../../data/quran_duas.dart';
import '../../data/quran_mahdi_verses.dart';
import '../../data/quran_prophet_stories.dart';
import '../../services/saved_verses_store.dart';
import '../../theme/shia_colors.dart';
import '../../utils/quran_index.dart';
import '../../utils/shared_preferences.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/responsive_content.dart';
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
/// New groups are one more [QuranCollection] value and one more case in
/// [_bodySlivers].
///
/// Built as slivers, so the list scrolls with the rest of the Quran screen
/// rather than in a box of its own under it.
class QuranCollectionsSliver extends StatelessWidget {
  const QuranCollectionsSliver({
    super.key,
    required this.gutter,
    required this.selected,
    required this.onSelect,
    required this.saved,
    required this.onOpenVerse,
    required this.onRemoveSaved,
  });

  /// The page's side margins. Applied here rather than around the sliver so
  /// the pills can scroll out from under the screen's edge.
  final EdgeInsets gutter;
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
          child: _CollectionPills(
            gutter: gutter,
            selected: selected,
            onSelect: onSelect,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        SliverPadding(
          padding: gutter,
          sliver: SliverMainAxisGroup(slivers: _bodySlivers(context)),
        ),
      ],
    );
  }

  List<Widget> _bodySlivers(BuildContext context) {
    switch (selected) {
      case QuranCollection.duas:
        return _quranDuaSlivers(context, onOpenVerse);
      case QuranCollection.imamAli:
        return [
          _notedVerseSliver(quranAliVerses.keys, aliRelatedNoteFor, onOpenVerse)
        ];
      case QuranCollection.imamMahdi:
        return [
          _notedVerseSliver(
              quranMahdiVerses.keys, mahdiRelatedNoteFor, onOpenVerse)
        ];
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

/// The collections as one row of pills, scrolled sideways.
///
/// One row rather than wrapped: wrapped, the five took three lines of a phone
/// screen before any of the list. The row runs to the screen's edge, so a
/// pill cut off there shows there are more, and the remembered collection is
/// scrolled into view on arrival, so someone who left on Saved sees it picked.
class _CollectionPills extends StatefulWidget {
  const _CollectionPills({
    required this.gutter,
    required this.selected,
    required this.onSelect,
  });

  final EdgeInsets gutter;
  final QuranCollection selected;
  final ValueChanged<QuranCollection> onSelect;

  @override
  State<_CollectionPills> createState() => _CollectionPillsState();
}

class _CollectionPillsState extends State<_CollectionPills> {
  final GlobalKey _selectedKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.selected != QuranCollection.values.first) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the row, and only the row, so the selected pill ends inside
  /// the gutter. Left alone when it is already in view.
  void _revealSelected() {
    final pill = _selectedKey.currentContext?.findRenderObject();
    if (pill == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    final end =
        RenderAbstractViewport.of(pill).getOffsetToReveal(pill, 1.0).offset +
            widget.gutter.right;
    if (end <= position.pixels) return;
    _scroll.jumpTo(end.clamp(0.0, position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return MouseDragScroll(
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: widget.gutter,
        child: Row(
          children: [
            for (final collection in QuranCollection.values) ...[
              if (collection != QuranCollection.values.first)
                const SizedBox(width: 8),
              ChoicePill(
                key: collection == widget.selected ? _selectedKey : null,
                label: collection.label,
                selected: collection == widget.selected,
                onTap: () => widget.onSelect(collection),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _verseTitle(VerseKey verse) {
  final name = surahInfoFor(verse.surah)?.displayName ??
      L10n.current.quranSurahNumber(verse.surah);
  return L10n.current.quranSurahAyah(name, verse.ayah ?? 1);
}

/// The duas the Quran itself contains ([quranDuas]), each opened in the
/// reader at its ayah.
///
/// Ayat al-Kursi and the duas recited with the Quran (after reciting, on a
/// khatm) used to head this list, but they are zikrs rather than verses and
/// did not sit well beside them; they are in the Duas list now, by alias,
/// and Dua Khatm al-Quran is offered at the end of an-Nas and of Juz 30.
///
/// Outside English a dua goes by its Arabic opening words rather than their
/// transliteration, which the app shows no one but English readers.
List<Widget> _quranDuaSlivers(
    BuildContext context, void Function(VerseKey verse) onOpenVerse) {
  final arabicOpenings = context.l10n.localeName != 'en';
  final colors = ShiaColors.of(context);
  return [
    SliverCardList(
      itemCount: quranDuas.length,
      itemBuilder: (context, index) {
        final dua = quranDuas[index];
        final reference = dua.endAyah == null
            ? _verseTitle(dua.verse)
            : '${_verseTitle(dua.verse)}-${localizeDigits('${dua.endAyah}')}';
        return CardListRow(
          first: index == 0,
          last: index == quranDuas.length - 1,
          title: arabicOpenings
              ? Text(
                  dua.arabic,
                  style: TextStyle(
                    fontFamily: arabicFont,
                    fontFamilyFallback: const ['Qalam'],
                    fontSize: 20,
                    height: 1.7,
                    color: colors.text,
                  ),
                )
              : Text(dua.opening),
          subtitle: Text('$reference · ${dua.displayNote}'),
          onTap: () => onOpenVerse(dua.verse),
        );
      },
    ),
  ];
}

/// A curated verse collection - the verses about Imam Ali (a.s.)
/// ([quranAliVerses]) or Imam al-Mahdi (a.t.f.s.) ([quranMahdiVerses]) - in
/// mushaf order, each with the note it is known by, in the app language
/// ([noteFor]).
Widget _notedVerseSliver(
    Iterable<VerseKey> keys,
    String? Function(VerseKey verse) noteFor,
    void Function(VerseKey verse) onOpen) {
  final verses = keys.toList()
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
        subtitle: Text(noteFor(verse)!),
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
          child: GroupLabel(entry.value.first.displayProphet, upperCase: false),
        ),
      ),
      SliverCardList(
        itemCount: entry.value.length,
        itemBuilder: (context, index) {
          final story = entry.value[index];
          final start = _verseTitle(story.verse);
          final reference = story.endAyah == story.verse.ayah
              ? start
              : '$start-${localizeDigits('${story.endAyah}')}';
          return CardListRow(
            first: index == 0,
            last: index == entry.value.length - 1,
            title: Text(story.displayTitle),
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
        ? '${verse.surahName} ${localizeDigits('${verse.ayah}')}'
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
