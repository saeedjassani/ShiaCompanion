import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../navigation/home_menu.dart';
import '../../services/analytics_service.dart';
import '../../services/home_shortcuts_store.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart' show buttonTextStyle;
import 'home_section.dart';

/// Home's shortcuts: up to eleven features the reader picked, then All
/// features, four to a row - two rows, or three once there are eight or more.
/// Untouched, a phone shows two rows and a tablet or desktop three.
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
        final shortcuts = homeShortcutMenuItems(
            HomeShortcutsStore.instance.idsFor(wide: isHomeWide(context)));
        final tiles = <Widget>[
          for (final item in shortcuts)
            ShortcutTile(
              label: item.displayShortLabel,
              icon: (color) => item.buildIcon(size: 30, color: color),
              onTap: () => onOpen(item),
            ),
          ShortcutTile(
            label: context.l10n.homeAllFeatures,
            filled: true,
            icon: (color) =>
                OutlineIcon(OutlineGlyph.grid, size: 26, color: color),
            onTap: onOpenAllFeatures,
          ),
        ];

        // No heading: the tiles say what they are. They are edited from
        // All features, the last tile.
        return HomeCard(
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
      label: onHome ? context.l10n.homeShortcutOnHomeSemantics(label) : label,
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

/// Opens the shortcuts editor: remove, reorder and add, up to eleven.
/// A bottom sheet on a phone, a centred dialog from tablet width up.
Future<void> showShortcutsEditor(BuildContext context) {
  return showAdaptiveSheet<void>(
    context,
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
  late final List<HomeMenuItem> _onHome;
  bool _started = false;

  bool get _isFull => _onHome.length >= HomeShortcutsStore.maxShortcuts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Starts from what Home shows on this screen, so a tablet's editor
    // opens on the tablet's defaults.
    if (_started) return;
    _started = true;
    _onHome = homeShortcutMenuItems(
            HomeShortcutsStore.instance.idsFor(wide: isHomeWide(context)))
        .toList();
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
          const SheetDragHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    minimumSize: const Size(44, 44),
                    textStyle: buttonTextStyle(context, ShiaText.body),
                  ),
                  child: Text(context.l10n.commonCancel),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      context.l10n.homeShortcutsTitle,
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
                    textStyle: buttonTextStyle(context,
                        ShiaText.body.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  child: Text(context.l10n.commonDone),
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
                    context.l10n.homeShortcutsOnHomeCount(
                        _onHome.length, HomeShortcutsStore.maxShortcuts),
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
                              label: item.displayShortLabel,
                              leading: _RoundAction(
                                glyph: OutlineGlyph.minus,
                                semanticsLabel: context.l10n
                                    .homeShortcutRemove(item.displayShortLabel),
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
                          label: context.l10n.homeAllFeatures,
                          subtitle: context.l10n.homeAllFeaturesAlwaysLast,
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
                        ? context.l10n.homeShortcutsMoreFull
                        : context.l10n.homeShortcutsMore),
                    const SizedBox(height: 8),
                    HomeCard(
                      radius: 16,
                      child: Column(
                        children: [
                          for (var i = 0; i < more.length; i++)
                            _EditorRow(
                              label: more[i].displayShortLabel,
                              muted: _isFull,
                              showDivider: i < more.length - 1,
                              leading: _RoundAction(
                                glyph: OutlineGlyph.plus,
                                semanticsLabel: context.l10n
                                    .homeShortcutAdd(more[i].displayShortLabel),
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
