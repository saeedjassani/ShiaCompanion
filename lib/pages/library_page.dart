import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/chapter_list_page.dart';

class LibraryPage extends StatefulWidget {
  @override
  _LibraryPageState createState() => new _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<UidTitleData> books = [];

  @override
  void initState() {
    super.initState();
    _updateEventString();
  }

  _updateEventString() async {
    String jsonBooks = await rootBundle.loadString("assets/books.json");

    List temp = json.decode(jsonBooks);

    for (var t in temp) {
      books.add(UidTitleData(t['slug'], t['title']));
    }
    if (this.mounted)
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        shrinkWrap: true,
        itemBuilder: (context, index) => ListTile(
              title: Text(
                books[index].title,
                key: ValueKey("lib-key-$index"),
              ),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ChapterListPage(
                          books[index].uid, books[index].title))),
            ),
        separatorBuilder: (context, index) => Divider(),
        itemCount: books.length);
  }
}
