import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
import 'package:shia_companion/services/analytics_service.dart';

class DataSearch extends SearchDelegate<String> {
  final List<UidTitleData> listWords;
  final Set<String> libraryUids;

  DataSearch(
    this.listWords, {
    this.libraryUids = const {},
  }) : _sources = _loadSources();

  /// Remembers which sources the last search had switched on.
  static const String sourcesPrefKey = 'search_sources';

  /// Duas and the Quran by default: most searches are for a dua, ziyarat or
  /// surah, and a hundred book titles matching a common word like "prayer"
  /// bury them.
  static const Set<SearchSource> defaultSources = {
    SearchSource.duas,
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
    return SearchSource.duas;
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
      slugsFor: (uid) => [
        if (itemSlugs[uid] != null) itemSlugs[uid]!,
        ...?itemSlugAliases[uid],
      ],
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
                    builder: (context) =>
                        ItemList(entry.getUId().split("~")[1], entry.title)));
          } else {
            handleUniversalDataClick(context, itemData,
                source: ZikrOpenSource.search);
          }
        },
        onLongPress: _recordSearch,
        title: isUserAdmin
            ? Text('${entry.uid} ${entry.title}')
            : Text(entry.title),
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
      isUserAdmin ? 'Search title or UID' : super.searchFieldLabel;

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
      final hidden = [
        for (final source in SearchSource.values)
          if (!_sources.contains(source) && bySource[source]!.isNotEmpty)
            source,
      ];

      final rows = <Widget>[
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
                ? '1 match in ${source.label}'
                : '${bySource[source]!.length} matches in ${source.label}'),
            trailing: const Text('Show'),
            onTap: () => toggle(source, true),
          ),
        if (query.trim().isNotEmpty && results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No results')),
          ),
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
  duas('Duas', Icons.menu_book_outlined),
  quran('Quran', Icons.auto_stories_outlined),
  library('Library', Icons.local_library_outlined);

  const SearchSource(this.label, this.icon);

  final String label;
  final IconData icon;
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
