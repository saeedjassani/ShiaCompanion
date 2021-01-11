import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/item_page.dart';
import 'package:shia_companion/pages/list_items.dart';

import '../constants.dart';

class TodaysRecitation extends StatelessWidget {
  // TODO Fix this widget rebuild everytime
  @override
  Widget build(BuildContext context) {
    List<UidTitleData> workingItems = [];

    workingItems.add(UidTitleData("~D1", items["~D1"])); // Taqeebaate Namaz
    workingItems.add(UidTitleData("E18", items["E18"])); // Dua e Ahad
    workingItems.add(UidTitleData("G6", items["G6"])); // Ziyarat e Waritha
    workingItems.add(UidTitleData("G4", items["G4"])); // Ziyarat e Ashura
    workingItems
        .add(UidTitleData("E37", items["E37"])); // Dua e Sanamay Quraish
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
      if (tmp == s.split("~")[0] ||
          tmp == s.replaceAll(RegExp("[0-9].*"), "")) {
        debugPrint(s + " " + items[s]);
        workingItems.add(UidTitleData(s, items[s]));
      }
    }
    workingItems.sort((a, b) {
      return a.getId() > b.getId() ? 1 : -1;
    });
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        child: ExpansionTile(
          title: Text("Today's Recitations"),
          children: <Widget>[
            ListView.separated(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              separatorBuilder: (BuildContext context, int index) => Divider(),
              itemCount: workingItems.length,
              itemBuilder: (BuildContext c, int i) =>
                  buildZikrRow(c, workingItems[i]),
            )
          ],
        ),
      ),
    );
  }

  Widget buildZikrRow(BuildContext context, UidTitleData itemData) {
    return InkWell(
      onTap: () {
        if (itemData.getUId().contains("~")) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ItemList(itemData.getUId().split("~")[1])));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => ItemPage(itemData)));
        }
      },
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(itemData.title),
          ),
        ],
      ),
    );
  }
}
