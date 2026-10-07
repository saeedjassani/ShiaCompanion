import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Esc goes back a page, for anyone with a keyboard: the web, a desktop, a
/// tablet with one attached (docs/DESIGN_SPEC.md, "Responsive behaviour").
///
/// Dialogs, sheets and menus already close on Esc; this does the same for
/// the pushed page on top, the way a browser's Back would. Never the first
/// page, and never while a dialog that asks to stay open is up.
class BackOnEscape extends StatelessWidget {
  const BackOnEscape({super.key, required this.child});

  /// Holds the app's navigator.
  final Widget child;

  /// The page route that has the keyboard's focus, when it is on top and
  /// has a page under it.
  static ModalRoute<Object?>? _pageToLeave() {
    final focused = primaryFocus?.context;
    if (focused == null) return null;
    final route = ModalRoute.of(focused);
    if (route is! PageRoute || !route.isCurrent || route.isFirst) return null;
    return route;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    // A page's own DismissIntent action is there, disabled, to let its
    // dialogs close on Esc; it would stop the key in the app's Shortcuts,
    // so a page is left from here, on the way up. A dialog or menu on top
    // is not a page: the key goes on to it.
    final route = _pageToLeave();
    if (route == null) return KeyEventResult.ignored;
    Navigator.of(route.subtreeContext!).maybePop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }
}

/// The keys that open search from the tab roots: `/`, as on most sites,
/// and Ctrl+K (Cmd+K on Apple keyboards), as in most apps.
Map<ShortcutActivator, VoidCallback> searchShortcuts(VoidCallback openSearch) =>
    {
      const CharacterActivator('/'): openSearch,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): openSearch,
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): openSearch,
    };
