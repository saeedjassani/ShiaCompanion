import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';

class DataSearch extends SearchDelegate<String> {
  final List<UidTitleData> listWords;

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  DataSearch(this.listWords);

  List<UidTitleData> _filteredResults() {
    if (query.isEmpty) {
      return [];
    }

    return listWords
        .where((entry) =>
            entry.title.contains(RegExp(query, caseSensitive: false)) &&
            !entry.uid.contains("|"))
        .toList();
  }

  Widget _buildSearchTile(BuildContext context, UidTitleData entry) {
    final itemData = UniversalData(entry.uid, entry.title, 0);
    final isParentZikr = entry.getUId().contains("~");

    return StatefulBuilder(
      builder: (context, setTileState) => ListTile(
        onTap: () {
          if (entry.getUId().contains("~")) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ItemList(entry.getUId().split("~")[1], entry.title)));
          } else {
            handleUniversalDataClick(context, itemData);
          }
        },
        onLongPress: () {
          if (isUserAdmin) {
            handleUniversalDataClick(context, itemData, itemPage: true);
          }
        },
        title: isUserAdmin
            ? Text('${entry.uid} ${entry.title}')
            : Text(entry.title),
        trailing: !isParentZikr
            ? InkWell(
                onTap: () {
                  if (favsData!.contains(itemData)) {
                    favsData!.remove(itemData);
                  } else {
                    favsData!.add(itemData);
                  }
                  setTileState(() {});
                },
                child: getFavIcon(context, itemData),
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
    analytics.logSearch(searchTerm: query); // Log the search event
    final suggestionList = _filteredResults();

    return ListView.builder(
      itemBuilder: (context, index) =>
          _buildSearchTile(context, suggestionList[index]),
      itemCount: suggestionList.length,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<UidTitleData> suggestionList = _filteredResults();

    return ListView.builder(
      itemBuilder: (context, index) =>
          _buildSearchTile(context, suggestionList[index]),
      itemCount: suggestionList.length,
    );
  }
}
