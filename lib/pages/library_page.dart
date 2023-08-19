import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';

import '../constants.dart';

class LibraryPage extends StatefulWidget {
  @override
  _LibraryPageState createState() => new _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<UidTitleData> books = [];

  @override
  void initState() {
    super.initState();
    trackScreen('Library Page');
    _loadLibraryData();
  }

  _loadLibraryData() async {
    String jsonBooks = await rootBundle.loadString("assets/books.json");

    List temp = json.decode(jsonBooks);

    for (var t in temp) {
      books.add(UidTitleData(t['slug'], t['title']));
    }
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        shrinkWrap: true,
        itemBuilder: (context, index) {
          UniversalData itemData =
              UniversalData(books[index].uid, books[index].title, 1);
          return ListTile(
              title: Text(
                books[index].title,
                key: ValueKey("lib-key-$index"),
              ),
              onTap: () => handleUniversalDataClick(context, itemData),
              trailing: InkWell(
                onTap: () {
                  favsData!.contains(itemData)
                      ? favsData!.remove(itemData)
                      : favsData!.add(itemData);
                  setState(() {});
                },
                child: getFavIcon(context, itemData),
              ));
        },
        separatorBuilder: (context, index) => Divider(),
        itemCount: books.length);
  }
}
