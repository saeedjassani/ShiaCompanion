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

const Set<String> _reservedNonZikrPaths = {
  'CALLBACK',
  'callback',
  'calendar-prayer-times',
  'delete-account',
  'widget-preview',
};

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
