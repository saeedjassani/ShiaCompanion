import 'package:flutter/material.dart';

import '../data/universal_data.dart';
import '../services/favorites_manager.dart';

class FavoriteIcon extends StatelessWidget {
  const FavoriteIcon({
    super.key,
    required this.favorite,
  });

  final UniversalData favorite;

  @override
  Widget build(BuildContext context) {
    final manager = FavoritesManager.instance;
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) => Icon(
        manager.isFavorite(favorite) ? Icons.star : Icons.star_border,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
