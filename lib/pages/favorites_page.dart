import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    trackScreen('Favorites Page');
    _ensureFavoritesLoaded();
  }

  Future<void> _ensureFavoritesLoaded() async {
    await FavoritesManager.instance.loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesManager = FavoritesManager.instance;

    return Scaffold(
      appBar: AppBar(title: Text('Favorites')),
      body: ListenableBuilder(
        listenable: favoritesManager,
        builder: (context, _) {
          final favorites = favsData;
          final shouldShowLoading = favoritesManager.isLoading &&
              (!favoritesManager.hasLoadedFavorites ||
                  favorites == null ||
                  favorites.isEmpty);

          if (shouldShowLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (favorites == null || favorites.isEmpty) {
            return Center(child: Text('No favorites yet.'));
          }

          return ResponsiveContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => Divider(),
              itemBuilder: (context, index) {
                UniversalData item = favorites[index];
                return ListTile(
                  title: isUserAdmin
                      ? Text(item.uid + ' ' + item.title)
                      : Text(item.title),
                  onTap: () {
                    handleUniversalDataClick(context, item);
                  },
                  onLongPress: () {
                    if (isUserAdmin)
                      handleUniversalDataClick(context, item, itemPage: true);
                  },
                  trailing: InkWell(
                    onTap: () {
                      FavoritesManager.instance.toggleFavorite(item);
                    },
                    child: getFavIcon(context, item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
