import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../navigation/home_menu.dart';
import '../services/home_shortcuts_store.dart';
import '../theme/shia_colors.dart';
import '../widgets/page_chrome.dart';
import 'home/home_section.dart';
import 'home/shortcuts_section.dart';

/// Every feature in one grid, in the order the old home grid had them (less
/// Quran and Favorites, which are tabs), each one already on Home marked
/// with a check.
class AllFeaturesPage extends StatefulWidget {
  const AllFeaturesPage({super.key});

  @override
  State<AllFeaturesPage> createState() => _AllFeaturesPageState();
}

class _AllFeaturesPageState extends State<AllFeaturesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('All Features Page'));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return ListenableBuilder(
      listenable: HomeShortcutsStore.instance,
      builder: (context, _) {
        final onHome = {
          for (final item in homeShortcutMenuItems(
              HomeShortcutsStore.instance.idsFor(wide: isHomeWide(context))))
            item.analyticsId,
        };
        final features = allFeaturesMenuItems;

        return LargeTitlePage(
          title: context.l10n.homeAllFeatures,
          maxWidth: 720,
          actions: [
            PageTextAction(
              label: context.l10n.homeEditShortcuts,
              onPressed: () => showShortcutsEditor(context),
            ),
          ],
          slivers: [
            SliverPadding(
              padding: pageGutter(context, maxWidth: 720),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    _FeatureGrid(
                      features: features,
                      onHome: onHome,
                      onOpen: (item) => item.open(context),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          const ExcludeSemantics(
                            child: OnHomeBadge(size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.homeAlreadyShortcut,
                              style: ShiaText.caption.copyWith(
                                fontSize: 14,
                                height: 20 / 14,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.features,
    required this.onHome,
    required this.onOpen,
  });

  final List<HomeMenuItem> features;
  final Set<String> onHome;
  final ValueChanged<HomeMenuItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        // Three across on a phone, more as the width allows.
        final columns = (constraints.maxWidth / 130).floor().clamp(3, 5);
        return Column(
          children: [
            for (var start = 0; start < features.length; start += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++)
                      Expanded(
                        child: i < features.length
                            ? Padding(
                                padding: const EdgeInsets.all(2),
                                child: ShortcutTile(
                                  label: features[i].displayLabel,
                                  tileSize: 54,
                                  onHome:
                                      onHome.contains(features[i].analyticsId),
                                  labelStyle: ShiaText.caption.copyWith(
                                    fontSize: 14,
                                    height: 18 / 14,
                                  ),
                                  icon: (color) => features[i]
                                      .buildIcon(size: 32, color: color),
                                  onTap: () => onOpen(features[i]),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}
