class DeepLinkTarget {
  final int type;
  final List<String> segments;

  const DeepLinkTarget({
    required this.type,
    required this.segments,
  });

  String get key => '$type/${segments.join('/')}';
}

const int zikrDeepLinkType = 0;

String buildDeepLinkPath({
  required int type,
  required List<String> segments,
}) {
  final encodedSegments = segments.map(Uri.encodeComponent).join('/');
  return '/$type/$encodedSegments';
}

String buildZikrDeepLinkPath({
  required String uid,
  String? slug,
}) {
  final normalizedSlug = slug?.trim();
  if (normalizedSlug != null && normalizedSlug.isNotEmpty) {
    return '/zikr/${Uri.encodeComponent(normalizedSlug)}';
  }

  return buildDeepLinkPath(type: zikrDeepLinkType, segments: [uid]);
}

bool isReservedNonZikrRouteName(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  final uri = Uri.tryParse(routeName);
  if (uri == null) return false;
  final segments = _extractSegments(uri);
  return segments.isNotEmpty && _reservedNonZikrPaths.contains(segments.first);
}

DeepLinkTarget? parseDeepLinkUri(Uri uri) {
  final segments = _extractSegments(uri);
  if (segments.isEmpty) return null;

  final type = int.tryParse(segments.first);
  if (type != null) {
    if (segments.length < 2) return null;
    return DeepLinkTarget(type: type, segments: segments.sublist(1));
  }

  if (segments.first == 'zikr') {
    if (segments.length != 2) return null;
    return DeepLinkTarget(type: zikrDeepLinkType, segments: [segments[1]]);
  }

  if (_reservedNonZikrPaths.contains(segments.first)) {
    return null;
  }

  // Legacy root-level slug paths like /ziyarat-e-ashura still resolve to zikr.
  if (segments.length == 1) {
    return DeepLinkTarget(type: zikrDeepLinkType, segments: segments);
  }

  return null;
}

String? extractZikrLinkSegment(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (!uri.hasScheme) {
    return _firstZikrSegment(parseDeepLinkUri(uri));
  }

  final appTarget = _isAppDeepLinkHost(uri.host) ? parseDeepLinkUri(uri) : null;
  final appSegment = _firstZikrSegment(appTarget);
  if (appSegment != null) {
    return appSegment;
  }

  final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (pathSegments.length == 2 && pathSegments.first == 'zikr') {
    return Uri.decodeComponent(pathSegments[1]);
  }

  return null;
}

const Set<String> _reservedNonZikrPaths = {
  'CALLBACK',
  'callback',
  'calendar-prayer-times',
  'delete-account',
  'widget-preview',
};

const Set<String> _appDeepLinkHosts = {
  'shia-companion.web.app',
  'www.shia-companion.web.app',
};

String? _firstZikrSegment(DeepLinkTarget? target) {
  if (target == null ||
      target.type != zikrDeepLinkType ||
      target.segments.isEmpty) {
    return null;
  }
  return target.segments.first;
}

bool _isAppDeepLinkHost(String host) {
  return _appDeepLinkHosts.contains(host.toLowerCase());
}

List<String> _extractSegments(Uri uri) {
  if (uri.fragment.isNotEmpty) {
    final fragmentPath =
        uri.fragment.startsWith('/') ? uri.fragment.substring(1) : uri.fragment;
    return fragmentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
  }

  return uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .map(Uri.decodeComponent)
      .toList();
}

String buildDeepLinkUrl({
  required int type,
  required List<String> segments,
}) {
  return 'https://shia-companion.web.app${buildDeepLinkPath(
    type: type,
    segments: segments,
  )}';
}

String buildZikrDeepLinkUrl({
  required String uid,
  String? slug,
}) {
  return 'https://shia-companion.web.app${buildZikrDeepLinkPath(
    uid: uid,
    slug: slug,
  )}';
}
