import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/zikr_page.dart';

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
    tableName = tableName
        .replaceAll(RegExp("[0-9].*"), "")
        .replaceAll(RegExp("[A-Z].*~"), "");
    if (tableName.contains("|"))
      tableName = tableName.split("\\|")[0].replaceAll(RegExp("[0-9].*"), "");

    for (String s in items.keys) {
      if (tableName == s.split("~")[0] ||
          tableName == s.replaceAll(RegExp("[0-9].*"), "")) {
        debugPrint(s + " " + items[s]);
        workingItems.add(UidTitleData(s, items[s]));
      }
    }

    // Populate Today's Recitations
    if (widget.item == "TR") {
      workingItems.add(UidTitleData("E18", items["E18"])); // Dua e Ahad
      workingItems.add(UidTitleData("G6", items["G6"])); // Ziyarat e Waritha
      workingItems.add(UidTitleData("G4", items["G4"])); // Ziyarat e Ashura
      workingItems
          .add(UidTitleData("E37", items["E37"])); // Dua e Sanamay Quraish
      String? tmp;
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
        if (tmp == s.split("~")[0] ||
            tmp == s.replaceAll(RegExp("[0-9].*"), "")) {
          debugPrint(s + " " + items[s]);
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
        itemBuilder: (BuildContext c, int i) =>
            buildZikrRow(c, workingItems[i]),
      ),
    );
  }

  ListTile buildZikrRow(BuildContext context, UidTitleData uidTitleData) {
    UniversalData itemData =
        UniversalData(uidTitleData.uid, uidTitleData.title, 0);
    String title;
    if (kReleaseMode) {
      title = itemData.title;
    } else {
      title = itemData.uid + " " + itemData.title;
    }
    return ListTile(
      onTap: () {
        if (uidTitleData.getUId().contains("~")) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ItemList(uidTitleData.getUId().split("~")[1])));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => ZikrPage(uidTitleData)));
        }
      },
      title: Text(title),
      trailing: uidTitleData.getUId().contains("~")
          ? null
          : InkWell(
              onTap: () {
                favsData!.contains(itemData)
                    ? favsData!.remove(itemData)
                    : favsData!.add(itemData);
                setState(() {});
              },
              child: favsData!.contains(itemData)
                  ? Icon(
                      Icons.star,
                      color: Theme.of(context).primaryColor,
                    )
                  : Icon(
                      Icons.star_border,
                      color: Theme.of(context).primaryColor,
                    )),
    );
  }
}
