import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
import 'package:shia_companion/services/analytics_service.dart';

class DataSearch extends SearchDelegate<String> {
  final List<UidTitleData> listWords;
  final Set<String> libraryUids;

  DataSearch(
    this.listWords, {
    this.libraryUids = const {},
  });

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

    return filterDataSearchResults(listWords, query);
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
        onLongPress: () {
          _recordSearch();
          if (isUserAdmin && !isLibraryBook) {
            handleUniversalDataClick(context, itemData,
                itemPage: true, source: ZikrOpenSource.search);
          }
        },
        title: isUserAdmin
            ? Text('${entry.uid} ${entry.title}')
            : Text(entry.title),
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
    final suggestionList = _filteredResults();

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) =>
            _buildSearchTile(context, suggestionList[index]),
        itemCount: suggestionList.length,
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Rebuilt on every keystroke, so the record is debounced rather than fired
    // here — this is the only hook that sees a search nobody acts on.
    _scheduleSearchRecord();
    final List<UidTitleData> suggestionList = _filteredResults();

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) =>
            _buildSearchTile(context, suggestionList[index]),
        itemCount: suggestionList.length,
      ),
    );
  }
}
