import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
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
  }) : _includeLibrary = SP.isInitialized &&
            (SP.prefs.getBool(includeLibraryPrefKey) ?? false);

  /// Remembers whether the last search had library books switched on.
  static const String includeLibraryPrefKey = 'search_include_library';

  /// Whether library books are listed alongside duas and the Quran.
  ///
  /// Off by default: most searches are for a dua, ziyarat or surah, and a
  /// hundred book titles matching a common word like "prayer" bury them.
  bool _includeLibrary;

  void _setIncludeLibrary(bool value) {
    _includeLibrary = value;
    if (SP.isInitialized) {
      unawaited(SP.prefs.setBool(includeLibraryPrefKey, value));
    }
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
      final zikrResults =
          results.where((e) => !libraryUids.contains(e.uid)).toList();
      final libraryResults =
          results.where((e) => libraryUids.contains(e.uid)).toList();

      void toggleLibrary(bool value) =>
          setBodyState(() => _setIncludeLibrary(value));

      final rows = <Widget>[
        for (final entry in zikrResults) _buildSearchTile(context, entry),
        if (libraryResults.isNotEmpty && _includeLibrary) ...[
          _LibraryHeader(count: libraryResults.length),
          for (final entry in libraryResults) _buildSearchTile(context, entry),
        ],
        // With books switched off, still say they are there — otherwise a
        // search that only a book matches looks like it found nothing.
        if (libraryResults.isNotEmpty && !_includeLibrary)
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(libraryResults.length == 1
                ? '1 match in Library'
                : '${libraryResults.length} matches in Library'),
            trailing: const Text('Show'),
            onTap: () => toggleLibrary(true),
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
                  FilterChip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Include Library'),
                    selected: _includeLibrary,
                    onSelected: toggleLibrary,
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

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        'Library ($count)',
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
