import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/item_page.dart';
import 'package:shia_companion/pages/list_items.dart';

import '../constants.dart';

class TasbeehWidget extends StatefulWidget {
  @override
  _TasbeehWidgetState createState() => _TasbeehWidgetState();
}

class _TasbeehWidgetState extends State<TasbeehWidget> {
  int counter = 0;

  @override
  void initState() {
    counter = sharedPreferences.getInt("key");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
              itemCount: 0,
              itemBuilder: (BuildContext c, int i) => Text("Salam"),
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
