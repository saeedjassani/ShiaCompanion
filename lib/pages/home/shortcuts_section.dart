import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/home_menu.dart';
import '../../services/analytics_service.dart';
import '../../services/home_shortcuts_store.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import 'home_section.dart';

/// "Shortcuts": up to seven features the reader picked, then All features,
/// four to a row.
class ShortcutsSection extends StatelessWidget {
  const ShortcutsSection({
    super.key,
    required this.onOpen,
    required this.onOpenAllFeatures,
  });

  final ValueChanged<HomeMenuItem> onOpen;
  final VoidCallback onOpenAllFeatures;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HomeShortcutsStore.instance,
      builder: (context, _) {
        final shortcuts =
            homeShortcutMenuItems(HomeShortcutsStore.instance.ids);
        final tiles = <Widget>[
          for (final item in shortcuts)
            ShortcutTile(
              label: item.shortLabel,
              icon: (color) => item.buildIcon(size: 30, color: color),
              onTap: () => onOpen(item),
            ),
          ShortcutTile(
            label: 'All features',
            filled: true,
            icon: (color) =>
                OutlineIcon(OutlineGlyph.grid, size: 26, color: color),
            onTap: onOpenAllFeatures,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeSectionHeader(
              title: 'Shortcuts',
              actionLabel: 'Edit',
              actionSemanticsLabel: 'Edit shortcuts',
              onAction: () => showShortcutsEditor(context),
            ),
            const SizedBox(height: 10),
            HomeCard(
              radius: 20,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                children: [
                  for (var start = 0; start < tiles.length; start += 4)
                    // Each row as tall as its tallest label, so a two-line
                    // label never leaves its neighbours' tap areas short.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = start; i < start + 4; i++)
                            Expanded(
                              child: i < tiles.length
                                  ? tiles[i]
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A feature on Home or on the All features page: its glyph on a well, and
/// its name underneath, wrapping to two lines rather than truncating.
class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.onHome = false,
    this.tileSize = 52,
    this.labelStyle,
  });

  final String label;
  final Widget Function(Color color) icon;
  final VoidCallback onTap;

  /// Draws the well in the accent (All features), not the well colour.
  final bool filled;

  /// Badges the tile with a check: already one of Home's shortcuts.
  final bool onHome;

  final double tileSize;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return Semantics(
      button: true,
      label: onHome ? '$label, on your Home' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: tileSize,
                    height: tileSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled ? colors.accent : colors.well,
                      borderRadius: BorderRadius.circular(tileSize * 16 / 52),
                    ),
                    child: icon(filled ? colors.onAccent : colors.accent),
                  ),
                  if (onHome)
                    PositionedDirectional(
                      end: -4,
                      top: -4,
                      child: OnHomeBadge(),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (labelStyle ?? ShiaText.caption).copyWith(
                  fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small accent check that marks a feature already on Home.
class OnHomeBadge extends StatelessWidget {
  const OnHomeBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 2),
      ),
      child: OutlineIcon(
        OutlineGlyph.check,
        size: size - 6,
        color: colors.onAccent,
        strokeWidth: 3,
      ),
    );
  }
}

/// Opens the shortcuts editor: remove, reorder and add, up to seven.
Future<void> showShortcutsEditor(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ShiaColors.of(context).ground,
    builder: (_) => const ShortcutsEditorSheet(),
  );
}

/// The editor sheet. Changes stay local to the sheet until Done; Cancel
/// leaves Home as it was.
class ShortcutsEditorSheet extends StatefulWidget {
  const ShortcutsEditorSheet({super.key});

  @override
  State<ShortcutsEditorSheet> createState() => _ShortcutsEditorSheetState();
}

class _ShortcutsEditorSheetState extends State<ShortcutsEditorSheet> {
  late List<HomeMenuItem> _onHome;

  bool get _isFull => _onHome.length >= HomeShortcutsStore.maxShortcuts;

  @override
  void initState() {
    super.initState();
    _onHome = homeShortcutMenuItems(HomeShortcutsStore.instance.ids).toList();
  }

  List<HomeMenuItem> get _more => [
        for (final item in shortcutCandidateMenuItems)
          if (!_onHome.contains(item)) item,
      ];

  void _remove(HomeMenuItem item) => setState(() => _onHome.remove(item));

  void _add(HomeMenuItem item) {
    if (_isFull) return;
    setState(() => _onHome.add(item));
  }

  /// [newIndex] is already adjusted for the removal (onReorderItem).
  void _reorder(int oldIndex, int newIndex) {
    setState(() => _onHome.insert(newIndex, _onHome.removeAt(oldIndex)));
  }

  Future<void> _done() async {
    final ids = [for (final item in _onHome) item.analyticsId];
    await HomeShortcutsStore.instance.save(ids);
    unawaited(AnalyticsService.feature(
      'home_shortcuts_changed',
      label: 'Home shortcuts changed',
      parameters: {'count': ids.length, 'shortcuts': ids.join(',')},
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final more = _more;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: colors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    minimumSize: const Size(44, 44),
                    textStyle: ShiaText.body,
                  ),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Shortcuts',
                      textAlign: TextAlign.center,
                      style: ShiaText.cardTitle.copyWith(color: colors.text),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _done,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    minimumSize: const Size(44, 44),
                    textStyle:
                        ShiaText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ListLabel(
                    'On your Home · ${_onHome.length} of '
                    '${HomeShortcutsStore.maxShortcuts}',
                  ),
                  const SizedBox(height: 8),
                  HomeCard(
                    radius: 16,
                    child: Column(
                      children: [
                        // Each row reads as one stop - "Remove Duas, Duas"
                        // - with the list's own Move up / Move down actions
                        // for anyone who cannot drag.
                        ReorderableList(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _onHome.length,
                          onReorderItem: _reorder,
                          proxyDecorator: (child, index, animation) => Material(
                            elevation: 4,
                            color: colors.surface,
                            child: child,
                          ),
                          itemBuilder: (context, index) {
                            final item = _onHome[index];
                            return _EditorRow(
                              key: ValueKey(item.analyticsId),
                              label: item.shortLabel,
                              leading: _RoundAction(
                                glyph: OutlineGlyph.minus,
                                semanticsLabel: 'Remove ${item.shortLabel}',
                                fill: Theme.of(context).colorScheme.error,
                                iconColor:
                                    Theme.of(context).colorScheme.onError,
                                onPressed: () => _remove(item),
                              ),
                              trailing: ExcludeSemantics(
                                child: ReorderableDragStartListener(
                                  index: index,
                                  child: SizedBox.square(
                                    dimension: 44,
                                    child: Center(
                                      child: OutlineIcon(
                                        OutlineGlyph.dragHandle,
                                        color: colors.chevron,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        _EditorRow(
                          label: 'All features',
                          subtitle: 'Always last, so nothing gets lost',
                          showDivider: false,
                          leading: SizedBox.square(
                            dimension: 44,
                            child: Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: OutlineIcon(
                                  OutlineGlyph.grid,
                                  size: 18,
                                  color: colors.onAccent,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (more.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _ListLabel(_isFull
                        ? 'More · remove one above to add one here'
                        : 'More'),
                    const SizedBox(height: 8),
                    HomeCard(
                      radius: 16,
                      child: Column(
                        children: [
                          for (var i = 0; i < more.length; i++)
                            _EditorRow(
                              label: more[i].shortLabel,
                              muted: _isFull,
                              showDivider: i < more.length - 1,
                              leading: _RoundAction(
                                glyph: OutlineGlyph.plus,
                                semanticsLabel: 'Add ${more[i].shortLabel}',
                                fill: _isFull
                                    ? Color.lerp(
                                        colors.line, colors.chevron, 0.4)!
                                    : colors.accent,
                                iconColor:
                                    _isFull ? colors.surface : colors.onAccent,
                                onPressed: _isFull ? null : () => _add(more[i]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        text.toUpperCase(),
        style: ShiaText.caption.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: ShiaColors.of(context).textMuted,
        ),
      ),
    );
  }
}

class _EditorRow extends StatelessWidget {
  const _EditorRow({
    super.key,
    required this.label,
    required this.leading,
    this.trailing,
    this.subtitle,
    this.muted = false,
    this.showDivider = true,
  });

  final String label;
  final String? subtitle;
  final Widget leading;
  final Widget? trailing;
  final bool muted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              )
            : null,
        padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ShiaText.body.copyWith(
                        color: muted ? colors.textMuted : colors.text,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style:
                            ShiaText.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// The 28 px round remove/add button, with a 44 px tap target around it.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.glyph,
    required this.semanticsLabel,
    required this.fill,
    required this.iconColor,
    required this.onPressed,
  });

  final OutlineGlyph glyph;
  final String semanticsLabel;
  final Color fill;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: OutlineIcon(
                glyph,
                size: 18,
                color: iconColor,
                strokeWidth: 2.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
