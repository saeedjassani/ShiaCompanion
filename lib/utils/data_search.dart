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
    unawaited(AnalyticsService.search(query));
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
