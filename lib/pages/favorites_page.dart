import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/models/saved_verse.dart';
import 'package:shia_companion/pages/quran/quran_collections_tab.dart';
import 'package:shia_companion/pages/quran/quran_navigation.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/services/saved_verses_manager.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import '../l10n/l10n.dart';

/// The Favorites tab (docs/DESIGN_SPEC.md, "Favorites"; mockup
/// `R2-Favorites`): what the reader has kept, in their own order, with
/// **Edit** to remove or reorder rather than a drag handle on every row; and,
/// beside it, the Quran verses they have saved.
class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

/// Favorites' two lists.
enum _FavoritesView { zikr, verses }

class _FavoritesPageState extends State<FavoritesPage> {
  _FavoritesView _view = _FavoritesView.zikr;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Favorites Page');
    unawaited(FavoritesManager.instance.loadFavorites());
    unawaited(SavedVersesManager.instance.loadSavedVerses());
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    try {
      await FavoritesManager.instance.moveFavorite(oldIndex, newIndex);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.favoritesReorderFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [FavoritesManager.instance, SavedVersesManager.instance]),
      builder: (context, _) {
        final favorites = FavoritesManager.instance.favorites;
        final view = _view;
        // Nothing to edit once the last one is removed.
        final editing = _editing && favorites.isNotEmpty;
        final gutter = pageGutter(context, maxWidth: widePageWidth);

        return LargeTitlePage(
          maxWidth: widePageWidth,
          title: context.l10n.menuFavorites,
          actions: [
            if (view == _FavoritesView.zikr && favorites.isNotEmpty)
              PageTextAction(
                label:
                    editing ? context.l10n.commonDone : context.l10n.commonEdit,
                semanticsLabel: editing ? null : context.l10n.favoritesEdit,
                onPressed: () => setState(() => _editing = !editing),
              ),
          ],
          slivers: [
            SliverPadding(
              padding: gutter.copyWith(bottom: 14),
              sliver: SliverToBoxAdapter(
                child: SegmentedSwitcher<_FavoritesView>(
                  segments: [
                    Segment(_FavoritesView.zikr, context.l10n.favoritesTabZikr),
                    Segment(
                        _FavoritesView.verses, context.l10n.favoritesTabVerses),
                  ],
                  selected: view,
                  onChanged: (next) => setState(() {
                    _view = next;
                    _editing = false;
                  }),
                ),
              ),
            ),
            SliverPadding(
              padding: gutter,
              sliver: view == _FavoritesView.zikr
                  ? _buildZikrList(favorites, editing)
                  : _buildVerseList(
                      SavedVersesManager.instance.state.inMushafOrder),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZikrList(List<UniversalData> favorites, bool editing) {
    final manager = FavoritesManager.instance;
    if (manager.isLoading &&
        (!manager.hasLoadedFavorites || favorites.isEmpty)) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (favorites.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyStateCard(
          glyph: OutlineGlyph.heart,
          title: context.l10n.favoritesNoneTitle,
          body: context.l10n.favoritesNoneBody,
        ),
      );
    }

    final colors = ShiaColors.of(context);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(SliverCardList.radius),
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(1),
        sliver: SliverReorderableList(
          itemCount: favorites.length,
          onReorderItem: _onReorder,
          proxyDecorator: (child, index, animation) => Material(
            color: colors.surface,
            elevation: 6,
            shadowColor: colors.glassShadow,
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          itemBuilder: (context, index) {
            final item = favorites[index];
            return _FavoriteRow(
              key: ValueKey(item.favoriteKey),
              item: item,
              index: index,
              first: index == 0,
              last: index == favorites.length - 1,
              editing: editing,
            );
          },
        ),
      ),
    );
  }

  Widget _buildVerseList(List<SavedVerse> saved) {
    if (saved.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyStateCard(
          glyph: OutlineGlyph.heart,
          title: context.l10n.quranNoSavedVerses,
          body: context.l10n.quranNoSavedVersesBody,
        ),
      );
    }

    return SliverCardList(
      itemCount: saved.length,
      itemBuilder: (context, index) => SavedVerseRow(
        verse: saved[index],
        first: index == 0,
        last: index == saved.length - 1,
        onOpen: () => openQuranVerse(context, saved[index].verse,
            source: ZikrOpenSource.favorites),
        onRemove: () => SavedVersesManager.instance.unsave(saved[index].verse),
      ),
    );
  }
}

/// One favourite: a filled heart and its title, opening it on a tap. While
/// editing, a remove button replaces the heart and a drag handle ends the
/// row.
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    super.key,
    required this.item,
    required this.index,
    required this.first,
    required this.last,
    required this.editing,
  });

  final UniversalData item;
  final int index;
  final bool first;
  final bool last;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final title =
        isUserAdmin ? '${item.uid} ${item.displayTitle}' : item.displayTitle;

    return CardListRow(
      first: first,
      last: last,
      title: Text(title),
      leading: editing
          ? _RemoveButton(
              label: context.l10n.favoritesRemove(item.displayTitle),
              onPressed: () => FavoritesManager.instance.toggleFavorite(item),
            )
          : OutlineIcon(OutlineGlyph.heart,
              size: 20, color: colors.accent, filled: true),
      trailing: editing
          ? ReorderableDragStartListener(
              index: index,
              child: Semantics(
                container: true,
                label: context.l10n.favoritesReorder(item.displayTitle),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: OutlineIcon(OutlineGlyph.dragHandle,
                        color: colors.chevron),
                  ),
                ),
              ),
            )
          : null,
      onTap: editing
          ? null
          : () => handleUniversalDataClick(context, item,
              source: ZikrOpenSource.favorites),
    );
  }
}

/// The round red minus that removes a favourite while editing.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox(
          width: 28,
          height: 44,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: scheme.error, shape: BoxShape.circle),
              child: OutlineIcon(OutlineGlyph.minus,
                  size: 16, color: scheme.onError, strokeWidth: 2.6),
            ),
          ),
        ),
      ),
    );
  }
}
