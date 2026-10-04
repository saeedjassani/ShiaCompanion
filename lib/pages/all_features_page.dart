import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../navigation/home_menu.dart';
import '../services/home_shortcuts_store.dart';
import '../theme/shia_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => showShortcutsEditor(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.accent,
              textStyle: ShiaText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            child: const Text('Edit shortcuts'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: HomeShortcutsStore.instance,
        builder: (context, _) {
          final onHome = {
            for (final item
                in homeShortcutMenuItems(HomeShortcutsStore.instance.ids))
              item.analyticsId,
          };
          final features = allFeaturesMenuItems;

          return ListView(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'All features',
                          style: ShiaText.largeTitle.copyWith(
                            color: colors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FeatureGrid(
                        features: features,
                        onHome: onHome,
                        onOpen: (item) =>
                            pushPageRoute(context, item.buildPage()),
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
                                'Already one of your Home shortcuts',
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
      ),
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
