import 'quran_portion.dart';

class DeepLinkTarget {
  final int type;
  final List<String> segments;

  /// The `src` query parameter off the URL, when the link itself knows where
  /// it was tapped from — currently only the home-screen widgets set this
  /// (see [HomeScreenWidgetService]). Null for an ordinary shared link, in
  /// which case the caller falls back to its own default source.
  final String? source;

  /// The tab a zikr link opens at, as the link writes it: `?tab=3` is the
  /// third tab the reader shows. Null when the link names none, or for any
  /// other kind of link. See [zikrDeepLinkTab].
  final int? tab;

  const DeepLinkTarget({
    required this.type,
    required this.segments,
    this.source,
    this.tab,
  });

  String get key =>
      '$type/${segments.join('/')}${tab == null ? '' : '?tab=$tab'}';
}

const int zikrDeepLinkType = 0;

/// Library links. Segments are `[]` for the Library itself, `[book]` or
/// `[book, chapter]`.
const int libraryDeepLinkType = 1;

/// The Library, what the address bar shows while it is open on the web.
const String libraryDeepLinkPath = '/library';

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

/// The Quran screen, what the address bar shows while it is open on the web.
const String quranDeepLinkPath = '/quran';

/// The Calendar page. Takes no segments: `/calendar` is the whole link, and
/// is what the Islamic calendar widgets open.
const int calendarDeepLinkType = 3;

const String calendarDeepLinkPath = '/calendar';

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

/// The link to zikr [uid], opening at the reader's tab [tabIndex] (0 = the
/// first) when it is past the first: `/zikr/<slug>?tab=3` for the third.
String buildZikrDeepLinkPath({
  required String uid,
  String? slug,
  int? tabIndex,
}) {
  // A juz is not a corpus document: its uid (`JUZ3`) is only what the reader
  // keys its state by, has no slug, and as `/0/JUZ3` would resolve to nothing.
  final juz = juzOfQuranUid(uid);
  if (juz != null) return buildQuranJuzDeepLinkPath(juz);

  final tabQuery = tabIndex != null && tabIndex > 0
      ? '?$zikrTabQueryParameter=${tabIndex + 1}'
      : '';

  final normalizedSlug = slug?.trim();
  if (normalizedSlug != null && normalizedSlug.isNotEmpty) {
    return '/zikr/${Uri.encodeComponent(normalizedSlug)}$tabQuery';
  }

  return '${buildDeepLinkPath(type: zikrDeepLinkType, segments: [uid])}'
      '$tabQuery';
}

/// The query parameter a zikr link names its tab with.
const String zikrTabQueryParameter = 'tab';

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

  final source = _extractSource(uri);

  final type = int.tryParse(segments.first);
  if (type != null) {
    if (segments.length < 2) return null;
    return DeepLinkTarget(
      type: type,
      segments: segments.sublist(1),
      source: source,
      tab: type == zikrDeepLinkType ? _extractTab(uri) : null,
    );
  }

  if (segments.first == 'zikr') {
    if (segments.length < 2 || segments.length > 3) return null;
    return _zikrTarget(
      segments[1],
      segments.length == 3 ? segments[2] : null,
      source,
      _extractTab(uri),
    );
  }

  if (segments.first == 'quran') {
    return _parseQuranSegments(segments.sublist(1), source);
  }

  if (segments.first == 'calendar' && segments.length == 1) {
    return DeepLinkTarget(
      type: calendarDeepLinkType,
      segments: const [],
      source: source,
    );
  }

  if (segments.first == 'library') {
    if (segments.length > 3) return null;
    return DeepLinkTarget(
      type: libraryDeepLinkType,
      segments: segments.sublist(1),
      source: source,
    );
  }

  if (_isReservedNonZikrPath(segments.first)) {
    return null;
  }

  // Legacy root-level slug paths like /ziyarat-e-ashura still resolve to zikr.
  if (segments.length == 1) {
    return DeepLinkTarget(
      type: zikrDeepLinkType,
      segments: segments,
      source: source,
      tab: _extractTab(uri),
    );
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

String? extractZikrLinkSegment(String href) =>
    _firstZikrSegment(extractZikrLinkTarget(href));

/// The zikr a link inside zikr text points at - with the tab it names, if
/// any - or null when it points anywhere else.
DeepLinkTarget? extractZikrLinkTarget(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (!uri.hasScheme) {
    return _zikrOnly(parseDeepLinkUri(uri));
  }

  final appTarget =
      _zikrOnly(_isAppDeepLinkHost(uri.host) ? parseDeepLinkUri(uri) : null);
  if (appTarget != null) {
    return appTarget;
  }

  final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (pathSegments.length == 2 && pathSegments.first == 'zikr') {
    return DeepLinkTarget(
      type: zikrDeepLinkType,
      segments: [pathSegments[1]],
      tab: _extractTab(uri),
    );
  }

  return null;
}

DeepLinkTarget? _zikrOnly(DeepLinkTarget? target) =>
    _firstZikrSegment(target) == null ? null : target;

/// A zikr link, with the ayah it names when it names one.
///
/// `/zikr/<slug>` is what the app itself writes, but someone reading a surah
/// will reasonably tack a verse onto it by hand. Both shapes people actually
/// type are taken - `/zikr/3-aal-e-imraan/91` and `/zikr/3-aal-e-imraan:91` -
/// and normalised to the same two segments, so callers see one form.
///
/// An ayah on a zikr that is not a surah is not an error: the zikr still
/// opens, the number simply has nothing to point at.
DeepLinkTarget? _zikrTarget(
  String slugSegment,
  String? ayahSegment,
  String? source,
  int? tab,
) {
  var slug = slugSegment;
  var ayah = ayahSegment;

  if (ayah == null) {
    final colon = slug.lastIndexOf(':');
    if (colon >= 0) {
      ayah = slug.substring(colon + 1);
      slug = slug.substring(0, colon);
    }
  }

  if (slug.isEmpty) return null;
  if (ayah != null && !_isNumber(ayah)) return null;

  return DeepLinkTarget(
    type: zikrDeepLinkType,
    segments: [slug, if (ayah != null) ayah],
    source: source,
    tab: tab,
  );
}

/// The ayah a zikr link named, or null when it named none or is not a zikr
/// link at all.
int? zikrDeepLinkAyah(DeepLinkTarget target) {
  if (target.type != zikrDeepLinkType || target.segments.length < 2) {
    return null;
  }
  final ayah = int.tryParse(target.segments[1]);
  return ayah != null && ayah > 0 ? ayah : null;
}

/// The tab a zikr link opens at, as a position among the tabs the reader
/// shows (0 = the first), or null when it names none or is not a zikr link.
///
/// Out of range is not decided here - a link naming a tab past the last opens
/// at the last, the way an ayah past a surah's end clamps.
int? zikrDeepLinkTab(DeepLinkTarget target) {
  if (target.type != zikrDeepLinkType) return null;
  final tab = target.tab;
  return tab == null ? null : tab - 1;
}

/// Reads the part of a Quran link after `/quran`.
///
/// Deliberately only checks shape, not range: this file stays free of any
/// dependency on the Quran's structure so it remains a pure, cheaply testable
/// parser. Whether surah 200 exists is decided when the link is resolved.
DeepLinkTarget? _parseQuranSegments(List<String> segments, String? source) {
  if (segments.isEmpty) {
    return DeepLinkTarget(
      type: quranDeepLinkType,
      segments: const [],
      source: source,
    );
  }

  if (segments.first.toLowerCase() == quranJuzSegment) {
    if (segments.length != 2 || !_isNumber(segments[1])) return null;
    return DeepLinkTarget(
      type: quranDeepLinkType,
      segments: [quranJuzSegment, segments[1]],
      source: source,
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
      source: source,
    );
  }

  if (segments.length == 2 &&
      _isNumber(segments[0]) &&
      _isNumber(segments[1])) {
    return DeepLinkTarget(
      type: quranDeepLinkType,
      segments: segments,
      source: source,
    );
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

/// Origin of every link the app builds and shares.
const String appWebOrigin = 'https://shiacompanion.app';

/// Hosts whose links open in the app. The `web.app` ones are the Firebase
/// Hosting default domain, which links shared before the custom domain still
/// point at, so they have to keep resolving.
const Set<String> _appDeepLinkHosts = {
  'shiacompanion.app',
  'www.shiacompanion.app',
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

/// The `src` query parameter, read off whichever URI actually carries the
/// query — the fragment's own URI for a hash-based link (`#/zikr/G1?src=x`),
/// the outer one otherwise. Blank is treated the same as absent.
String? _extractSource(Uri uri) {
  final pathUri = _fragmentPathUri(uri) ?? uri;
  final source = pathUri.queryParameters['src']?.trim();
  return (source == null || source.isEmpty) ? null : source;
}

/// The `tab` query parameter, read the way [_extractSource] reads `src`.
/// Anything but a tab number from 1 up is ignored rather than breaking the
/// link: the zikr still opens, at its first tab.
int? _extractTab(Uri uri) {
  final pathUri = _fragmentPathUri(uri) ?? uri;
  final raw = pathUri.queryParameters[zikrTabQueryParameter]?.trim() ?? '';
  if (!_isNumber(raw)) return null;
  final tab = int.parse(raw);
  return tab > 0 ? tab : null;
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
  return '$appWebOrigin${buildDeepLinkPath(
    type: type,
    segments: segments,
  )}';
}

String buildZikrDeepLinkUrl({
  required String uid,
  String? slug,
  int? tabIndex,
}) {
  return '$appWebOrigin${buildZikrDeepLinkPath(
    uid: uid,
    slug: slug,
    tabIndex: tabIndex,
  )}';
}

String buildLibraryDeepLinkUrl({
  required String bookSlug,
  String? chapterSlug,
}) {
  return '$appWebOrigin${buildLibraryDeepLinkPath(
    bookSlug: bookSlug,
    chapterSlug: chapterSlug,
  )}';
}

String buildCalendarDeepLinkUrl() {
  return '$appWebOrigin$calendarDeepLinkPath';
}

String buildQuranDeepLinkUrl({required int surah, int? ayah}) {
  return '$appWebOrigin${buildQuranDeepLinkPath(
    surah: surah,
    ayah: ayah,
  )}';
}
