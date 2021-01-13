import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';

import '../constants.dart';

class ItemPage extends StatefulWidget {
  final UidTitleData item;

  ItemPage(this.item);

  @override
  _ItemPageState createState() => new _ItemPageState(item);
}

class _ItemPageState extends State<ItemPage> {
  final UidTitleData item;

  Set<int> codes = Set();

  _ItemPageState(this.item);

  String loadString;
  var itemData;
  List<Tab> tabs = [
    Tab(text: 'Arabic'),
  ];
  List<Widget> children = [];

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  void initializeData() async {
    loadString = await DefaultAssetBundle.of(context)
        .loadString('assets/items/' + item.getFirstUId());
    itemData = json.decode(loadString);
    if (itemData['english'] != null && itemData['english'] != '') {
      tabs.add(Tab(text: 'Translation'));
      children.add(SingleChildScrollView(child: Text(itemData['english'])));
    }
    if (itemData['transliteration'] != null &&
        itemData['transliteration'] != '') {
      tabs.add(Tab(text: 'Transliteration'));
      children
          .add(SingleChildScrollView(child: Text(itemData['transliteration'])));
    }
    setState(() {});
  }

  TextStyle arabicStyle = TextStyle(
    fontFamily: "Qalam",
    fontSize: arabicFontSize,
  );

  @override
  Widget build(BuildContext context) {
    List<String> content =
        itemData != null ? generateCodeAndStrings(itemData['content']) : null;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.getTitle()),
          bottom: tabs.length > 1
              ? TabBar(
                  tabs: tabs,
                )
              : null,
        ),
        body: itemData != null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: TabBarView(
                  children: [
                    ListView.builder(
                      itemCount: content.length,
                      itemBuilder: (BuildContext c, int i) {
                        String str = content[i].trim();
                        if (codes.contains(i)) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              str,
                              style: arabicStyle,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                            ),
                          );
                        } else {
                          return Text(str);
                        }
                      },
                    ),
                    ...children
                  ],
                ),
              )
            : Text(''),
      ),
    );
  }

  List<String> generateCodeAndStrings(String content) {
    List<String> split =
        content.split("--"); //.replaceAll("\u200c", "") - Do not replace this.
    for (int i = 0, n = split.length; i < n; i++) {
      if (split[i].trim().isEmpty) continue;
      if (isArabic(split[i])) codes.add(i);
    }
    return split;
  }

  bool isArabic(String s) {
    var runes = s.runes.toList();
    for (int i = 0, n = s.runes.length; i < n && i < 5;) {
      int c = runes[i];
      if (c >= 0x0600 && c <= 0x06E0) return true;
      i++;
    }
    return false;
  }
}
