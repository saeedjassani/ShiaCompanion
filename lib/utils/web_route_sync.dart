import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
