class DeepLinkTarget {
  final int type;
  final List<String> segments;

  const DeepLinkTarget({
    required this.type,
    required this.segments,
  });

  String get key => '$type/${segments.join('/')}';
}

DeepLinkTarget? parseDeepLinkUri(Uri uri) {
  final segments = _extractSegments(uri);
  if (segments.length < 2) return null;

  final type = int.tryParse(segments.first);
  if (type == null) return null;

  return DeepLinkTarget(type: type, segments: segments.sublist(1));
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
  final encodedSegments = segments.map(Uri.encodeComponent).join('/');
  return 'https://shia-companion.web.app/#/$type/$encodedSegments';
}
