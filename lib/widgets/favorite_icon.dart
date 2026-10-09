import 'package:flutter/material.dart';

import '../data/universal_data.dart';
import '../l10n/l10n.dart';
import '../services/favorites_manager.dart';
import '../theme/shia_colors.dart';
import 'outline_icon.dart';

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

/// The revamp's favourite toggle: a heart, filled once [favorite] is kept,
/// with a 44 px tap target.
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.favorite,
    this.round = false,
  });

  final UniversalData favorite;

  /// Drawn as a round button on the surface with a 1 px line, like the
  /// page's Back button beside it (the reader's top bar).
  final bool round;

  @override
  Widget build(BuildContext context) {
    final manager = FavoritesManager.instance;
    final colors = ShiaColors.of(context);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final kept = manager.isFavorite(favorite);
        void toggle() => manager.toggleFavorite(favorite);
        final heart = SizedBox.square(
          dimension: 44,
          child: Center(
            child: OutlineIcon(
              OutlineGlyph.heart,
              size: round ? 20 : 22,
              color: colors.accent,
              filled: kept,
            ),
          ),
        );
        // Its own node, apart from the row it sits in.
        return Semantics(
          container: true,
          button: true,
          toggled: kept,
          label: context.l10n.favoriteToggleLabel(favorite.displayTitle),
          excludeSemantics: true,
          onTap: toggle,
          child: round
              ? Material(
                  color: colors.surface,
                  shape: CircleBorder(side: BorderSide(color: colors.line)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: toggle, child: heart),
                )
              : InkResponse(onTap: toggle, radius: 22, child: heart),
        );
      },
    );
  }
}
