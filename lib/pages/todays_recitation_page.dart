import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';

import '../constants.dart';

class TodaysRecitationPage extends StatelessWidget {
  const TodaysRecitationPage({super.key});

  List<UidTitleData> _buildList() {
    List<UidTitleData> workingItems = [];

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
        workingItems.add(UidTitleData(s, items[s]));
      }
    }
    workingItems.sort((a, b) {
      return a.getId() > b.getId() ? 1 : -1;
    });
    if (items.isNotEmpty) {
      workingItems.insert(1, UidTitleData("E18", items["E18"]));
      workingItems.insert(2, UidTitleData("G6", items["G6"]));
      workingItems.insert(3, UidTitleData("G4", items["G4"]));
      workingItems.insert(4, UidTitleData("E37", items["E37"]));
    }
    return workingItems;
  }

  @override
  Widget build(BuildContext context) {
    List<UidTitleData> workingItems = _buildList();

    return Scaffold(
      appBar: AppBar(title: Text("Today's Recitations")),
      body: workingItems.isEmpty
          ? Center(child: Text('No recitations configured.'))
          : ListView.separated(
              separatorBuilder: (_, __) => Divider(),
              shrinkWrap: true,
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: workingItems.length,
              itemBuilder: (BuildContext c, int i) {
                var itemData = workingItems[i];
                return ListTile(
                  onTap: () {
                    if (itemData.getUId().contains("~")) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ItemList(
                                  itemData.getUId().split("~")[1],
                                  itemData.title)));
                    } else {
                      handleUniversalDataClick(context,
                          UniversalData(itemData.uid, itemData.title, 0));
                    }
                  },
                  onLongPress: () {
                    if (isUserAdmin)
                      handleUniversalDataClick(context,
                          UniversalData(itemData.uid, itemData.title, 0),
                          itemPage: true);
                  },
                  title: isUserAdmin
                      ? Text(itemData.uid + " " + itemData.title)
                      : Text(itemData.title),
                );
              },
            ),
    );
  }
}
