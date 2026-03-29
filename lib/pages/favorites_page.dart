import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/favorites_manager.dart';

class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    trackScreen('Favorites Page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Favorites')),
      body: favsData == null || favsData!.isEmpty
          ? Center(child: Text('No favorites yet.'))
          : ListView.separated(
              itemCount: favsData!.length,
              separatorBuilder: (_, __) => Divider(),
              itemBuilder: (context, index) {
                UniversalData item = favsData![index];
                return ListTile(
                  title: isUserAdmin ? Text(item.uid + ' ' + item.title) : Text(item.title),
                  onTap: () {
                    handleUniversalDataClick(context, item);
                  },
                  onLongPress: () {
                    if (isUserAdmin) handleUniversalDataClick(context, item, itemPage: true);
                  },
                  trailing: InkWell(
                    onTap: () {
                      FavoritesManager.instance.toggleFavorite(item);
                      setState(() {});
                    },
                    child: getFavIcon(context, item),
                  ),
                );
              },
            ),
    );
  }
}
