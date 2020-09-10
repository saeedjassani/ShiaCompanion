import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';

import '../constants.dart';
import 'item_page.dart';

class ItemList extends StatefulWidget {
  final String item;

  ItemList(this.item);

  @override
  _ItemListState createState() => new _ItemListState();
}

class _ItemListState extends State<ItemList> {
  List<UidTitleData> workingItems = [];
  _ItemListState();

  @override
  void initState() {
    super.initState();
    String tableName = widget.item;
    if (widget.item == "D1") tableName = "D";
    tableName = tableName.replaceAll("[0-9].*", "").replaceAll("[A-Z].*~", "");
    if (tableName.contains("|")) tableName = tableName.split("\\|")[0].replaceAll("[0-9].*", "");

    for (String s in items.keys) {
      if (tableName == s.split("~")[0] || tableName == s.replaceAll(RegExp("[0-9].*"), "")) {
        print(s + " " + items[s]);
        workingItems.add(UidTitleData(s, items[s]));
      }
    }
    if (widget.item == "TR") {
      workingItems.add(UidTitleData("E18", items["E18"]));
      workingItems.add(UidTitleData("G6", items["G6"]));
      // workingItems.add(UidTitleData("G4", items["G4"]));
      // workingItems.add(UidTitleData("G4", items["G4"]));
      String tmp;
      DateTime today = DateTime.now();
      if (today.weekday == DateTime.friday) {
        tmp = "J";
      } else if (today.weekday == DateTime.saturday) {
        tmp = "K";
      } else if (today.weekday == DateTime.sunday) {
        tmp = "L";
      } else if (today.weekday == DateTime.monday) {
        tmp = "M";
      } else if (today.weekday == DateTime.tuesday) {
        tmp = "N";
      } else if (today.weekday == DateTime.wednesday) {
        tmp = "O";
      } else if (today.weekday == DateTime.thursday) {
        tmp = "Q";
      }
      for (String s in items.keys) {
        if (tmp == s.split("~")[0] || tmp == s.replaceAll(RegExp("[0-9].*"), "")) {
          print(s + " " + items[s]);
          workingItems.add(UidTitleData(s, items[s]));
        }
      }
    }
    workingItems.sort((a, b) {
      return a.getId() > b.getId() ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
      ),
      body: ListView.separated(
        separatorBuilder: (BuildContext context, int index) => Divider(),
        itemCount: workingItems.length,
        itemBuilder: (BuildContext c, int i) => buildBody(c, i),
      ),
    );
  }

  buildBody(BuildContext c, int i) {
    return ListTile(
      onTap: () {
        if (workingItems[i].getUId().contains("~")) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => ItemList(workingItems[i].getUId().split("~")[1])));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ItemPage(workingItems[i])));
        }
      },
      title: Text(workingItems[i].title),
    );
  }
}
