import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart' show appNavigatorKey;
import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'page_chrome.dart';

/// How long a toast stays up unless told otherwise; a Material snack bar's
/// own default.
const Duration toastDuration = Duration(seconds: 4);

/// Shows [message] as a toast: a glass capsule floating just above where
/// the tab bar and the find fields sit, so it never covers them, and like
/// them 16 px from the sides and centred at most 640 px wide.
///
/// The revamp's replacement for a Material snack bar, whose full-width dark
/// slab belongs to the old design. One shows at a time: a new toast takes
/// the place of the one on screen. It slides down out of the way on a
/// swipe, and goes by itself after [duration] - except, as with a snack
/// bar, one with an action while a screen reader is navigating, which waits
/// for the action or a swipe.
///
/// It belongs to the page on screen when it is shown, and goes as soon as
/// that page does: covered by another page, popped, or swapped for another
/// tab ([toastRouteObserver], [hideToast]). A sheet or dialog opening over
/// the page does not count. A message about where the user is going
/// ("Signed out" as Account closes) is shown after the pop, not before.
///
/// Needs no [BuildContext]: it is shown on the root navigator's overlay, so
/// it is safe to call after an async gap and from outside the widget tree.
void showToast(
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = toastDuration,
}) =>
    showToastContent(
      Text(message),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );

/// [showToast] with a widget for the message, for text that needs more than
/// a plain string (an icon mid-sentence, Arabic set right to left).
void showToastContent(
  Widget content, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = toastDuration,
}) {
  final overlay = appNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _ToastHandle.current?.remove();
  final handle = _ToastHandle(toastRouteObserver.topPage);
  handle.entry = OverlayEntry(
    builder: (context) => _ToastView(
      key: handle.viewKey,
      handle: handle,
      content: content,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );
  _ToastHandle.current = handle;
  overlay.insert(handle.entry);
}

/// Takes down the toast on screen, if any.
void hideToast() => _ToastHandle.current?.dismiss();

/// Follows the root navigator's pages so a toast goes with the page it was
/// shown on. Registered in the app's `navigatorObservers`.
final ToastRouteObserver toastRouteObserver = ToastRouteObserver();

/// Keeps the root navigator's stack of pages - [PageRoute]s, leaving out
/// the sheets, dialogs and menus that open over them - and takes the toast
/// down whenever the top page changes.
class ToastRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _pages = [];

  /// The page on screen, under any sheet or dialog.
  Route<dynamic>? get topPage => _pages.isEmpty ? null : _pages.last;

  void _changed(void Function() change) {
    final before = topPage;
    change();
    if (topPage != before) {
      final toast = _ToastHandle.current;
      if (toast != null && toast.page != topPage) toast.dismiss();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _changed(() => _pages.add(route));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _changed(() => _pages.remove(route));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _changed(() => _pages.remove(route));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _changed(() {
      final at = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
      if (at >= 0) _pages.removeAt(at);
      if (newRoute is PageRoute) {
        _pages.insert(at >= 0 ? at : _pages.length, newRoute);
      }
    });
  }
}

class _ToastHandle {
  _ToastHandle(this.page);

  static _ToastHandle? current;

  /// The page the toast was shown on; it goes when that page does.
  final Route<dynamic>? page;

  late final OverlayEntry entry;
  final GlobalKey<_ToastViewState> viewKey = GlobalKey<_ToastViewState>();
  bool _removed = false;

  /// Animates the toast out, then removes it.
  void dismiss() {
    final view = viewKey.currentState;
    if (view == null) {
      remove();
    } else {
      view.dismiss();
    }
  }

  void orphan() {
    _removed = true;
    if (current == this) current = null;
  }

  /// Removes the toast at once.
  void remove() {
    if (_removed) return;
    _removed = true;
    if (current == this) current = null;
    entry.remove();
    entry.dispose();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.handle,
    required this.content,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
  });

  final _ToastHandle handle;
  final Widget content;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _timer;
  bool _timerStarted = false;

  bool get _hasAction => widget.actionLabel != null;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timerStarted) return;
    _timerStarted = true;
    if (_hasAction && MediaQuery.accessibleNavigationOf(context)) return;
    _timer = Timer(widget.duration, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    if (!mounted || _controller.status == AnimationStatus.reverse) return;
    _controller.reverse().whenComplete(widget.handle.remove);
  }

  @override
  void dispose() {
    // Gone with its overlay (the app torn down) rather than through
    // [_ToastHandle.remove]: there is no overlay left to remove it from.
    widget.handle.orphan();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Clear of the tab bar or a find field (62 px tall) wherever they float,
    // the keyboard included.
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        floatingBottomOffset(context) +
        62 +
        12;

    Widget toast = GlassSurface(
      borderRadius: BorderRadius.circular(26),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 20,
            end: _hasAction ? 6 : 20,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DefaultTextStyle.merge(
                    style: ShiaText.secondary.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                    ),
                    child: widget.content,
                  ),
                ),
              ),
              if (_hasAction) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    widget.onAction?.call();
                    dismiss();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    widget.actionLabel!,
                    style: ShiaText.secondary
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    toast = Dismissible(
      key: ObjectKey(widget.handle),
      direction: DismissDirection.down,
      onDismissed: (_) => widget.handle.remove(),
      child: toast,
    );

    toast = FadeTransition(
      opacity: _curve,
      child: reduceMotion
          ? toast
          : SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(_curve),
              child: toast,
            ),
    );

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Material(
                type: MaterialType.transparency,
                child: toast,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
