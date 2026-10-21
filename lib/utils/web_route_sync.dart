import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart' show routeObserver;

Future<void> syncWebRoutePath(
  String path, {
  bool replace = false,
}) async {
  if (!kIsWeb) return;

  final normalizedPath = path.startsWith('/') ? path : '/$path';
  await syncWebRouteUri(Uri.parse(normalizedPath), replace: replace);
}

Future<void> syncWebRouteUri(
  Uri uri, {
  bool replace = false,
}) async {
  if (!kIsWeb) return;

  await SystemNavigator.routeInformationUpdated(
    uri: uri,
    replace: replace,
  );
}

/// Keeps the browser's address on [webRoutePath] while this page's route is on
/// top, and puts back the address it was opened from when it is popped.
///
/// Only for a page that is a route of its own. The same page shown as a tab
/// root sits on the app's first route, the tab shell, which keeps the address
/// itself (see `AppShellTab.webPath`), so there this does nothing.
mixin WebRoutePathSync<T extends StatefulWidget> on State<T>
    implements RouteAware {
  /// The address shown while this page is on top, e.g. `/quran`.
  String get webRoutePath;

  PageRoute<dynamic>? _webRoute;
  bool _isCurrentWebRoute = false;
  Uri? _previousBrowserUri;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && !route.isFirst && route != _webRoute) {
      if (_webRoute != null) routeObserver.unsubscribe(this);
      _webRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_webRoute != null) routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _scheduleWebRouteSync({bool replace = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentWebRoute) return;
      syncWebRoutePath(webRoutePath, replace: replace);
    });
  }

  @override
  void didPush() {
    _isCurrentWebRoute = true;
    _previousBrowserUri ??= Uri.base;
    _scheduleWebRouteSync();
  }

  @override
  void didPopNext() {
    _isCurrentWebRoute = true;
    _scheduleWebRouteSync(replace: true);
  }

  @override
  void didPushNext() {
    _isCurrentWebRoute = false;
  }

  @override
  void didPop() {
    _isCurrentWebRoute = false;
    final previousBrowserUri = _previousBrowserUri;
    if (previousBrowserUri != null) {
      syncWebRouteUri(previousBrowserUri, replace: true);
    }
  }
}
