import 'dart:async';
import 'package:shia_companion/services/zikr_translations.dart';

import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/pages/quran/quran_navigation.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/verse_query.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/content_request_service.dart';
import 'package:shia_companion/widgets/content_request_dialog.dart';
import '../l10n/l10n.dart';

class DataSearch extends SearchDelegate<String> {
  final List<UidTitleData> listWords;
  final Set<String> libraryUids;

  DataSearch(
    this.listWords, {
    this.libraryUids = const {},
  }) : _sources = _loadSources();

  /// Remembers which sources the last search had switched on.
  static const String sourcesPrefKey = 'search_sources';

  /// Zikr and the Quran by default: most searches are for a dua, ziyarat or
  /// surah, and a hundred book titles matching a common word like "prayer"
  /// bury them.
  static const Set<SearchSource> defaultSources = {
    SearchSource.zikr,
    SearchSource.quran,
  };

  /// Which kinds of result are listed. Chosen with the chips above the list.
  Set<SearchSource> _sources;

  static Set<SearchSource> _loadSources() {
    final saved =
        SP.isInitialized ? SP.prefs.getStringList(sourcesPrefKey) : null;
    if (saved == null) return {...defaultSources};
    return {
      for (final source in SearchSource.values)
        if (saved.contains(source.name)) source,
    };
  }

  void _setSourceEnabled(SearchSource source, bool enabled) {
    _sources = {..._sources};
    enabled ? _sources.add(source) : _sources.remove(source);
    if (SP.isInitialized) {
      unawaited(SP.prefs
          .setStringList(sourcesPrefKey, [for (final s in _sources) s.name]));
    }
  }

  SearchSource _sourceOf(UidTitleData entry) {
    if (libraryUids.contains(entry.uid)) return SearchSource.library;
    if (surahForUid(entry.uid) != null) return SearchSource.quran;
    return SearchSource.zikr;
  }

  /// How long the query has to stop changing before it counts as a search.
  /// Long enough that "kum" on the way to "kumayl" is not a search of its own,
  /// short enough that someone who types and then reads the list is counted.
  static const Duration _searchRecordDelay = Duration(milliseconds: 900);

  Timer? _recordTimer;
  String? _recordedTerm;

  /// Records the search once the query settles.
  ///
  /// This used to live in [buildResults] alone, which only runs when the query
  /// is *submitted* — and almost nobody submits, because the suggestion list is
  /// already tappable and opens the zikr. That is why the counter read a single
  /// search against a pile of zikrs opened with `source: search`.
  void _scheduleSearchRecord() {
    _recordTimer?.cancel();
    if (query.trim().isEmpty) return;
    _recordTimer = Timer(_searchRecordDelay, _recordSearch);
  }

  void _recordSearch() {
    _recordTimer?.cancel();
    final term = query.trim();
    if (term.isEmpty) return;
    if (!isNewSearchTerm(previous: _recordedTerm, term: term)) return;
    _recordedTerm = term;
    unawaited(AnalyticsService.search(term));
  }

  List<UidTitleData> _filteredResults() {
    if (query.isEmpty) {
      return [];
    }

    return filterDataSearchResults(
      listWords,
      query,
      matchUid: isUserAdmin,
      translatedTitleFor: (uid) => libraryUids.contains(uid)
          ? null
          : ZikrTranslations.instance.titleFor(uid),
      slugsFor: (uid) => [
        if (itemSlugs[uid] != null) itemSlugs[uid]!,
        ...?itemSlugAliases[uid],
      ],
    );
  }

  /// The verse the query names (`2:255`, `baqarah 255`, `yasin 1`), offered
  /// above every other result.
  ///
  /// Only where the reader can open at a verse: that is part of the Quran
  /// revamp dark-launched to admins (see ZikrPage._surahNumber), and for
  /// everyone else "Go to 2:255" would open al-Baqarah at its first verse.
  VerseKey? _verseQuery() {
    if (!isUserAdmin) return null;
    return parseVerseQuery(query);
  }

  Widget _buildVerseTile(BuildContext context, VerseKey verse) {
    final name = surahInfoFor(verse.surah)?.englishName ??
        context.l10n.quranSurahNumber(verse.surah);
    return ListTile(
      leading: Icon(Icons.auto_stories_outlined,
          color: Theme.of(context).colorScheme.primary),
      title: Text(
        context.l10n.goToVerseJump(name, '$verse'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        _recordSearch();
        openQuranVerse(context, verse, source: ZikrOpenSource.search);
      },
    );
  }

  Widget _buildSearchTile(BuildContext context, UidTitleData entry) {
    final isLibraryBook = libraryUids.contains(entry.uid);
    final itemData =
        UniversalData(entry.uid, entry.title, isLibraryBook ? 1 : 0);
    final isParentZikr = entry.getUId().contains("~");

    return StatefulBuilder(
      builder: (context, setTileState) => ListTile(
        onTap: () {
          // Acting on a result is the clearest evidence a search happened, and
          // the query is still exactly what the user searched with.
          _recordSearch();
          if (!isLibraryBook && entry.getUId().contains("~")) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ItemList(
                        entry.getUId().split("~")[1], itemData.displayTitle)));
          } else {
            handleUniversalDataClick(context, itemData,
                source: ZikrOpenSource.search);
          }
        },
        onLongPress: _recordSearch,
        title: isUserAdmin
            ? Text('${entry.uid} ${itemData.displayTitle}')
            : Text(itemData.displayTitle),
        // Several books share near-identical titles (translations of the same
        // work, mostly), so the author is what tells them apart here too.
        subtitle: isLibraryBook && entry.author != null
            ? Text(entry.author!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: !isParentZikr
            ? InkWell(
                onTap: () async {
                  await FavoritesManager.instance.toggleFavorite(itemData);
                },
                child: FavoriteIcon(favorite: itemData),
              )
            : null,
      ),
    );
  }

  @override
  String? get searchFieldLabel =>
      isUserAdmin ? L10n.current.searchTitleOrUid : super.searchFieldLabel;

  @override
  List<Widget> buildActions(BuildContext context) {
    //Actions for app bar
    return [
      IconButton(
          icon: Icon(Icons.clear),
          onPressed: () {
            query = '';
          })
    ];
  }

  @override
  void close(BuildContext context, String result) {
    // A closed search is a finished search: flush whatever is pending instead
    // of leaving a timer to fire against a delegate nobody is looking at.
    _recordSearch();
    super.close(context, result);
  }

  @override
  Widget buildLeading(BuildContext context) {
    //leading icon on the left of the app bar
    return IconButton(
        icon: AnimatedIcon(
          icon: AnimatedIcons.menu_arrow,
          progress: transitionAnimation,
        ),
        onPressed: () {
          close(context, '');
        });
  }

  @override
  Widget buildResults(BuildContext context) {
    // show some result based on the selection
    _recordSearch();
    return _buildBody(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Rebuilt on every keystroke, so the record is debounced rather than fired
    // here — this is the only hook that sees a search nobody acts on.
    _scheduleSearchRecord();
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    return StatefulBuilder(builder: (context, setBodyState) {
      final results = _filteredResults();
      final bySource = {
        for (final source in SearchSource.values) source: <UidTitleData>[],
      };
      for (final entry in results) {
        bySource[_sourceOf(entry)]!.add(entry);
      }

      void toggle(SearchSource source, bool enabled) =>
          setBodyState(() => _setSourceEnabled(source, enabled));

      final shown = [
        for (final source in SearchSource.values)
          if (_sources.contains(source) && bySource[source]!.isNotEmpty) source,
      ];
      // The section with the better match goes first. Results arrive ranked,
      // so a section's first entry is its best. Ties keep the chip order;
      // someone after a surah can switch Zikr off.
      final bestRank = {
        for (final source in shown)
          source: searchMatchRank(
              bySource[source]!.first.title, query.trim().toLowerCase()),
      };
      shown.sort((a, b) => bestRank[a] != bestRank[b]
          ? bestRank[a]! - bestRank[b]!
          : a.index - b.index);
      final hidden = [
        for (final source in SearchSource.values)
          if (!_sources.contains(source) && bySource[source]!.isNotEmpty)
            source,
      ];

      final verse = _verseQuery();

      final rows = <Widget>[
        if (verse != null) _buildVerseTile(context, verse),
        for (final source in shown) ...[
          // A lone section needs no heading; the chips already say what it is.
          if (shown.length > 1)
            _SectionHeader(
                label: source.label, count: bySource[source]!.length),
          for (final entry in bySource[source]!)
            _buildSearchTile(context, entry),
        ],
        // A switched-off source still says it has matches — otherwise a search
        // that only, say, a book matches looks like it found nothing.
        for (final source in hidden)
          ListTile(
            leading: Icon(source.icon),
            title: Text(bySource[source]!.length == 1
                ? context.l10n.searchOneMatch(source.label)
                : context.l10n
                    .searchMatches(bySource[source]!.length, source.label)),
            trailing: Text(context.l10n.searchShow),
            onTap: () => toggle(source, true),
          ),
        if (query.trim().isNotEmpty && results.isEmpty && verse == null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Center(child: Text(context.l10n.searchNoResults)),
          ),
          // A search that finds nothing is the moment someone knows exactly
          // what's missing, so offer to request it with the query pre-filled.
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.playlist_add),
              label: Text(context.l10n.searchRequestIt),
              onPressed: () => showContentRequestDialog(
                context,
                initialType: _sources.length == 1 &&
                        _sources.contains(SearchSource.library)
                    ? ContentRequestType.book
                    : ContentRequestType.zikr,
                initialTitle: query.trim(),
                source: 'search',
              ),
            ),
          ),
        ],
      ];

      return ResponsiveContent(
        maxWidth: listContentWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final source in SearchSource.values)
                    FilterChip(
                      label: Text(source.label),
                      selected: _sources.contains(source),
                      onSelected: (enabled) => toggle(source, enabled),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: rows,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// The kinds of result search can list, each with its own filter chip.
enum SearchSource {
  zikr(Icons.menu_book_outlined),
  quran(Icons.auto_stories_outlined),
  library(Icons.local_library_outlined);

  const SearchSource(this.icon);

  final IconData icon;

  String get label => switch (this) {
        SearchSource.zikr => L10n.current.searchSourceZikr,
        SearchSource.quran => L10n.current.searchSourceQuran,
        SearchSource.library => L10n.current.searchSourceLibrary,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$label ($count)',
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
