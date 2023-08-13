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
    final suggestionList = listWords;

    return ListView.builder(
      itemBuilder: (context, index) => ListTile(
        title: Text(listWords[index].title),
      ),
      itemCount: suggestionList.length,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // show when someone searches for something

    final List<UidTitleData> suggestionList = query.isEmpty
        ? []
        : listWords
            .where((p) => p.title.contains(RegExp(query, caseSensitive: false)))
            .toList();

    return ListView.builder(
      itemBuilder: (context, index) => ListTile(
        onTap: () {
          if (suggestionList[index].getUId().contains("~")) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ItemList(
                        suggestionList[index].getUId().split("~")[1])));
          } else {
            handleUniversalDataClick(
                context,
                UniversalData(
                    suggestionList[index].uid, suggestionList[index].title, 0));
          }
        },
        title: Text(suggestionList[index].title),
      ),
      itemCount: suggestionList.length,
    );
  }
}
