import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    try {
      await FavoritesManager.instance.moveFavorite(oldIndex, newIndex);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the new order. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesManager = FavoritesManager.instance;

    return Scaffold(
      appBar: AppBar(title: Text('Favorites')),
      body: ListenableBuilder(
        listenable: favoritesManager,
        builder: (context, _) {
          final favorites = favoritesManager.favorites;
          final shouldShowLoading = favoritesManager.isLoading &&
              (!favoritesManager.hasLoadedFavorites || favorites.isEmpty);

          if (shouldShowLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (favorites.isEmpty) {
            return Center(child: Text('No favorites yet.'));
          }

          return ResponsiveContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: favorites.length,
              buildDefaultDragHandles: false,
              onReorderItem: _onReorder,
              itemBuilder: (context, index) {
                UniversalData item = favorites[index];
                return Column(
                  key: ValueKey(item.favoriteKey),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: isUserAdmin
                          ? Text(item.uid + ' ' + item.title)
                          : Text(item.title),
                      onTap: () {
                        handleUniversalDataClick(context, item);
                      },
                      onLongPress: () {
                        if (isUserAdmin)
                          handleUniversalDataClick(context, item,
                              itemPage: true);
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () async {
                              await FavoritesManager.instance
                                  .toggleFavorite(item);
                            },
                            child: FavoriteIcon(favorite: item),
                          ),
                          const SizedBox(width: 8),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.drag_handle,
                                semanticLabel: 'Reorder ${item.title}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < favorites.length - 1) Divider(),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
