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
const int libraryDeepLinkType = 1;

/// Quran links. Segments are one of:
///
/// - `[]`            the Quran screen
/// - `['23']`        surah 23
/// - `['23', '56']`  surah 23, ayah 56
/// - `['juz', '5']`  juz 5
///
/// The single-segment `23:56` form is normalised into the two-segment one at
/// parse time, so everything downstream only ever sees the shape above.
const int quranDeepLinkType = 2;

const String quranJuzSegment = 'juz';

/// Set when the web launch URL generated its own route, so the home page knows
/// not to open the same link a second time.
///
/// The home page reads `Uri.base` on start-up to catch links the app booted
/// into. On web that job now belongs to the launch route, but the flag is
/// checked rather than the web branch simply removed: if route generation ever
/// stops matching a path, the home page still opens it instead of the link
/// silently doing nothing.
bool webLaunchDeepLinkHandled = false;

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

String buildLibraryDeepLinkPath({
  required String bookSlug,
  String? chapterSlug,
}) {
  final normalizedChapterSlug = chapterSlug?.trim();
  final segments = [
    bookSlug,
    if (normalizedChapterSlug != null && normalizedChapterSlug.isNotEmpty)
      normalizedChapterSlug,
  ];
  final encodedSegments = segments.map(Uri.encodeComponent).join('/');
  return '/library/$encodedSegments';
}

/// The canonical path for a verse: `/quran/23/56`, or `/quran/23` for a whole
/// surah. The other separators are accepted on the way in, never written out.
String buildQuranDeepLinkPath({required int surah, int? ayah}) {
  return ayah == null ? '/quran/$surah' : '/quran/$surah/$ayah';
}

String buildQuranJuzDeepLinkPath(int juz) => '/quran/$quranJuzSegment/$juz';

bool isReservedNonZikrRouteName(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  final uri = Uri.tryParse(routeName);
  if (uri == null) return false;
  final segments = _extractSegments(uri);
  return segments.isNotEmpty && _isReservedNonZikrPath(segments.first);
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

  if (segments.first == 'quran') {
    return _parseQuranSegments(segments.sublist(1));
  }

  if (segments.first == 'library') {
    if (segments.length < 2 || segments.length > 3) return null;
    return DeepLinkTarget(
      type: libraryDeepLinkType,
      segments: segments.sublist(1),
    );
  }

  if (_isReservedNonZikrPath(segments.first)) {
    return null;
  }

  // Legacy root-level slug paths like /ziyarat-e-ashura still resolve to zikr.
  if (segments.length == 1) {
    return DeepLinkTarget(type: zikrDeepLinkType, segments: segments);
  }

  return null;
}

/// The target a web launch URL should open directly, or null when the route
/// name is not a link the app can land on.
///
/// Split out from the route factory so the decision — which names get a route
/// of their own, and which fall through to the home page — is testable without
/// standing up a Navigator.
DeepLinkTarget? parseLaunchRouteName(String? name) {
  if (name == null || name.isEmpty || name == '/') return null;

  final uri = Uri.tryParse(name);
  if (uri == null) return null;

  final target = parseDeepLinkUri(uri);
  if (target == null) return null;
  if (target.type != zikrDeepLinkType &&
      target.type != libraryDeepLinkType &&
      target.type != quranDeepLinkType) {
    return null;
  }
  return target;
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
    return pathSegments[1];
  }

  return null;
}

/// Reads the part of a Quran link after `/quran`.
///
/// Deliberately only checks shape, not range: this file stays free of any
/// dependency on the Quran's structure so it remains a pure, cheaply testable
/// parser. Whether surah 200 exists is decided when the link is resolved.
DeepLinkTarget? _parseQuranSegments(List<String> segments) {
  if (segments.isEmpty) {
    return const DeepLinkTarget(type: quranDeepLinkType, segments: []);
  }

  if (segments.first.toLowerCase() == quranJuzSegment) {
    if (segments.length != 2 || !_isNumber(segments[1])) return null;
    return DeepLinkTarget(
      type: quranDeepLinkType,
      segments: [quranJuzSegment, segments[1]],
    );
  }

  if (segments.length == 1) {
    // The single-segment forms: `23`, and `23:56` with any of the separators
    // people actually write. Normalised here so callers see one shape.
    final match = _verseSegmentPattern.firstMatch(segments.first);
    if (match == null) return null;
    final ayah = match.group(2);
    return DeepLinkTarget(
      type: quranDeepLinkType,
      segments: [match.group(1)!, if (ayah != null) ayah],
    );
  }

  if (segments.length == 2 &&
      _isNumber(segments[0]) &&
      _isNumber(segments[1])) {
    return DeepLinkTarget(type: quranDeepLinkType, segments: segments);
  }

  return null;
}

final RegExp _verseSegmentPattern = RegExp(r'^(\d{1,3})(?:[:.\-](\d{1,3}))?$');

final RegExp _numberPattern = RegExp(r'^\d{1,3}$');

bool _isNumber(String value) => _numberPattern.hasMatch(value);

const Set<String> _reservedNonZikrPaths = {
  'callback',
  'calendar-prayer-times',
  'delete-account',
  'quran',
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
  final pathUri = _fragmentPathUri(uri) ?? uri;
  return pathUri.pathSegments.where((segment) => segment.isNotEmpty).toList();
}

Uri? _fragmentPathUri(Uri uri) {
  if (uri.fragment.isEmpty) return null;

  final normalizedFragment =
      uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
  return Uri.tryParse(normalizedFragment);
}

bool _isReservedNonZikrPath(String segment) {
  return _reservedNonZikrPaths.contains(segment.toLowerCase());
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

String buildLibraryDeepLinkUrl({
  required String bookSlug,
  String? chapterSlug,
}) {
  return 'https://shia-companion.web.app${buildLibraryDeepLinkPath(
    bookSlug: bookSlug,
    chapterSlug: chapterSlug,
  )}';
}

String buildQuranDeepLinkUrl({required int surah, int? ayah}) {
  return 'https://shia-companion.web.app${buildQuranDeepLinkPath(
    surah: surah,
    ayah: ayah,
  )}';
}
