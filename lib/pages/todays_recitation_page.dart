import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/utils/todays_recitation.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';

class TodaysRecitationPage extends StatelessWidget {
  const TodaysRecitationPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<UidTitleData> workingItems = buildTodaysRecitationItems();

    return Scaffold(
      appBar: AppBar(title: Text("Today's Recitations")),
      body: workingItems.isEmpty
          ? Center(child: Text('No recitations configured.'))
          : ResponsiveContent(
              maxWidth: listContentWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                separatorBuilder: (_, __) => Divider(),
                shrinkWrap: true,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: workingItems.length,
                itemBuilder: (BuildContext c, int i) {
                  var itemData = workingItems[i];
                  final favoriteData =
                      UniversalData(itemData.uid, itemData.title, 0);
                  return ListTile(
                    onTap: () async {
                      if (itemData.getUId().contains("~")) {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ItemList(
                                    itemData.getUId().split("~")[1],
                                    itemData.title)));
                      } else {
                        await handleUniversalDataClick(context,
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
                    trailing: itemData.getUId().contains("~")
                        ? null
                        : StatefulBuilder(
                            builder: (context, setTileState) => InkWell(
                              onTap: () async {
                                await FavoritesManager.instance
                                    .toggleFavorite(favoriteData);
                                setTileState(() {});
                              },
                              child: getFavIcon(context, favoriteData),
                            ),
                          ),
                  );
                },
              ),
            ),
    );
  }
}
