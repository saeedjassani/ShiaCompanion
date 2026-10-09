import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../pages/home_page.dart';
import '../theme/app_theme.dart';
import '../theme/shia_colors.dart';
import '../pages/search_page.dart';
import '../widgets/app_toast.dart';
import '../widgets/azan_playing_banner.dart';
import '../widgets/glass_surface.dart';
import '../widgets/home_glyph.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import 'home_menu.dart';
import 'keyboard_shortcuts.dart';

/// One tab of [AppShell].
class AppShellTab {
  const AppShellTab({
    required this.label,
    required this.icon,
    required this.builder,
    this.onSelected,
    this.contentKey,
  });

  final String label;

  /// Builds the tab's icon in [color].
  final Widget Function(Color color) icon;

  /// Builds the tab's root page. Not called until the tab is first opened;
  /// from then on the page's state lasts as long as [contentKey] stays the
  /// same.
  final WidgetBuilder builder;

  /// Runs every time the tab is chosen (not when it is already current).
  final VoidCallback? onSelected;

  /// Identifies what [builder] currently builds; a change replaces the tab's
  /// page rather than updating it.
  final Object? contentKey;
}

/// The app's root: Home, Quran and Favorites as tabs, with a floating glass
/// tab bar and a round search button beside it (docs/DESIGN_SPEC.md,
/// "Navigation").
///
/// The bar shows only here, on the tab roots. Everything opened from a tab is
/// pushed on the app's one navigator, above this whole route, so it gets the
/// full screen and deep links, [routeObserver] and the web URL sync keep
/// working as before.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.tabs, this.onSearch});

  /// Replaces the real tabs; for tests, which cannot build Home's plugins.
  final List<AppShellTab>? tabs;

  /// Replaces what the search button opens; for tests.
  final VoidCallback? onSearch;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Tabs built so far. A tab is built on first visit and then kept alive in
  /// the [IndexedStack], so it keeps its scroll position; building all three
  /// up front would load and count screens nobody opened.
  final Set<int> _visited = {0};

  List<AppShellTab> get _tabs => widget.tabs ?? _defaultTabs(context.l10n);

  @override
  void initState() {
    super.initState();
    // The admin claim lands after the shell is built; a tab whose content
    // depends on it is rebuilt then, under a new contentKey.
    adminState.addListener(_handleAdminChanged);
  }

  @override
  void dispose() {
    adminState.removeListener(_handleAdminChanged);
    super.dispose();
  }

  void _handleAdminChanged() {
    if (mounted) setState(() {});
  }

  static List<AppShellTab> _defaultTabs(AppLocalizations l10n) {
    final quranItem = quranTabMenuItem;
    return [
      AppShellTab(
        label: l10n.shellTabHome,
        icon: (color) =>
            OutlineIcon(OutlineGlyph.home, color: color, strokeWidth: 1.9),
        builder: (_) => const MyHomePage(),
      ),
      AppShellTab(
        label: l10n.shellTabQuran,
        icon: (color) =>
            HomeGlyph(type: HomeGlyphType.surahs, size: 24, color: color),
        builder: (_) => quranItem.pageBuilder(),
        onSelected: quranItem.recordOpen,
        contentKey: quranItem.analyticsId,
      ),
      AppShellTab(
        label: l10n.shellTabFavorites,
        icon: (color) => OutlineIcon(OutlineGlyph.heart, color: color),
        builder: (_) => favoritesMenuItem.pageBuilder(),
        onSelected: favoritesMenuItem.recordOpen,
      ),
    ];
  }

  void _select(int index) {
    if (index == _index) return;
    // A message belongs to the tab that raised it.
    hideToast();
    setState(() {
      _index = index;
      _visited.add(index);
    });
    _tabs[index].onSelected?.call();
  }

  Future<void> _openSearch() async {
    final onSearch = widget.onSearch;
    if (onSearch != null) {
      onSearch();
      return;
    }

    await openAppSearch(context);
  }

  /// Tab roots title themselves with the large title (34 / 41); pages
  /// pushed from them keep the regular bar. Dialogs and pushed routes are
  /// built by the navigator, outside this override.
  static ThemeData _tabRootTheme(ThemeData theme) {
    final colors = theme.extension<ShiaColors>() ??
        ShiaColors.forBrightness(theme.brightness);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: ShiaText.largeTitle.copyWith(color: colors.text),
        toolbarHeight: 64,
        centerTitle: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(brightness),
      // Back on Quran or Favorites goes to Home first, rather than out of
      // the app.
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select(0);
        },
        // Search from the keyboard, on the web or with a keyboard attached.
        child: CallbackShortcuts(
          bindings: searchShortcuts(_openSearch),
          child: Focus(
            autofocus: true,
            child: Scaffold(
              // The tabs scroll under the floating bar; extendBody hands them
              // its height as bottom padding so their ends can clear it.
              extendBody: true,
              bottomSheet: const AzanPlayingBanner(),
              body: Theme(
                data: _tabRootTheme(theme),
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      _visited.contains(i)
                          ? KeyedSubtree(
                              key: ValueKey(tabs[i].contentKey ?? i),
                              child: Builder(builder: tabs[i].builder),
                            )
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
              bottomNavigationBar: AppTabBar(
                tabs: tabs,
                currentIndex: _index,
                onSelect: _select,
                onSearch: _openSearch,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating glass capsule with the tabs, and the round search button to
/// its right. Full width less the page gutters on phones; a fixed width,
/// centred, from tablet width up.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onSearch,
  });

  static const double height = 62;
  static const double gutter = 16;
  static const double bottomGap = 26;
  static const double searchGap = 10;

  /// The capsule's width from [wideBreakpoint] up.
  static const double wideBarWidth = 290;
  static const double wideBreakpoint = 600;

  final List<AppShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;

  /// Distance from the bottom of the screen: 26, but never closer than 8 to
  /// the system's own bottom inset (home indicator, gesture or button bar).
  static double bottomOffset(BuildContext context) =>
      math.max(bottomGap, MediaQuery.viewPaddingOf(context).bottom + 8);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final bar = _TabCapsule(
      tabs: tabs,
      currentIndex: currentIndex,
      onSelect: onSelect,
    );

    return Stack(
      children: [
        // Fades whatever scrolls beneath into the ground, so rows do not
        // show through below and beside the floating bar.
        const Positioned.fill(child: BottomFade()),
        Padding(
          padding: EdgeInsets.fromLTRB(
              gutter, 0, gutter, AppTabBar.bottomOffset(context)),
          // A fixed-height bar can only take so much: past 1.5x, the labels
          // would no longer fit under their icons.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (wide)
                    SizedBox(width: wideBarWidth, child: bar)
                  else
                    Expanded(child: bar),
                  const SizedBox(width: searchGap),
                  _SearchButton(onPressed: onSearch),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabCapsule extends StatelessWidget {
  const _TabCapsule({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppTabBar.height / 2),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: _TabButton(
                    tab: tabs[i],
                    selected: i == currentIndex,
                    position: i,
                    count: tabs.length,
                    onTap: () => onSelect(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.position,
    required this.count,
    required this.onTap,
  });

  final AppShellTab tab;
  final bool selected;
  final int position;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final radius = BorderRadius.circular(AppTabBar.height / 2 - 4);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      // "Home, tab 1 of 3", as a platform tab bar reads.
      label: context.l10n.shellTabSemantics(tab.label, position + 1, count),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? colors.selectedTint : Colors.transparent,
              borderRadius: radius,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tab.icon(colors.accent),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (selected
                          ? ShiaText.tabLabelSelected
                          : ShiaText.tabLabel)
                      .copyWith(color: selected ? colors.accent : colors.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    const size = AppTabBar.height;

    return Semantics(
      button: true,
      label: context.l10n.commonSearch,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: context.l10n.commonSearch,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(size / 2),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: Center(
                  child: OutlineIcon(
                    OutlineGlyph.search,
                    color: colors.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
