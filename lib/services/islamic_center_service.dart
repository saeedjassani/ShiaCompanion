import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants.dart' as app;
import '../models/islamic_center.dart';
import '../utils/geo_utils.dart';
import '../utils/ics_calendar.dart';
import '../utils/shared_preferences.dart';

/// Whether the Islamic centre feature is on for this reader. Admin-only
/// while it is checked on devices (docs/ISLAMIC_CENTERS.md, "Shipping it").
bool get centerProgramsEnabled => app.isUserAdmin;

/// Why a centre's programmes could not be refreshed.
enum CenterFeedError {
  /// No connection, or the server did not answer.
  network,

  /// The address answered with something that is not a calendar: most
  /// often a Google calendar that is not public yet.
  notPublic,

  /// The calendar given is not a link or ID this understands.
  badLink,
}

/// The reader's Islamic centres (docs/ISLAMIC_CENTERS.md): the directory
/// to choose from, the ones they follow, and those centres' upcoming
/// programmes, read from each one's public calendar.
///
/// Everything is kept on the device. The directory is one Firestore doc
/// (`islamic_centers/directory`), read at most once a day; each centre's
/// calendar is fetched straight from its host and its next
/// [eventWindow] of programmes cached, so the page opens instantly and
/// works offline.
class IslamicCenterService extends ChangeNotifier {
  IslamicCenterService({
    Future<List<IslamicCenter>> Function()? directoryLoader,
    Future<String> Function(Uri url)? feedLoader,
    DateTime Function()? clock,
  }) : _directoryLoader = directoryLoader,
       _feedLoader = feedLoader,
       _clock = clock ?? DateTime.now;

  static final IslamicCenterService instance = IslamicCenterService();

  final Future<List<IslamicCenter>> Function()? _directoryLoader;
  final Future<String> Function(Uri url)? _feedLoader;
  final DateTime Function() _clock;

  static const String collection = 'islamic_centers';
  static const String directoryDoc = 'directory';

  static const String followedKey = 'islamic_centers_followed';
  static const String directoryCacheKey = 'islamic_centers_directory';
  static const String eventsCacheKey = 'islamic_centers_events';
  static const String suggestionDismissedKey =
      'islamic_centers_suggestion_dismissed';

  /// How far ahead programmes are kept.
  static const Duration eventWindow = Duration(days: 60);

  /// How old a centre's cached programmes get before opening the page
  /// fetches them again.
  static const Duration eventsMaxAge = Duration(hours: 3);

  static const Duration directoryMaxAge = Duration(days: 1);

  /// How close a centre has to be for Home to suggest it.
  static const double suggestionRadiusKm = 50;

  bool _restored = false;
  List<IslamicCenter> _directory = const [];
  DateTime? _directoryFetchedAt;
  List<IslamicCenter> _followed = const [];
  final Map<String, List<IcsOccurrence>> _events = {};
  final Map<String, DateTime> _eventsFetchedAt = {};
  final Map<String, CenterFeedError> _errors = {};
  final Set<String> _refreshing = {};
  bool _suggestionDismissed = false;
  Future<void>? _directoryInFlight;

  List<IslamicCenter> get directory => _directory;
  List<IslamicCenter> get followed => _followed;
  bool get hasFollowed => _followed.isNotEmpty;
  bool isFollowing(String id) => _followed.any((c) => c.id == id);
  bool get isRefreshing => _refreshing.isNotEmpty;
  CenterFeedError? errorFor(String id) => _errors[id];
  DateTime? fetchedAt(String id) => _eventsFetchedAt[id];

  /// When the programmes on show were last fetched: the oldest of the
  /// followed centres', so "Updated 3 hours ago" never overstates.
  DateTime? get eventsFetchedAt {
    DateTime? oldest;
    for (final center in _followed) {
      final at = _eventsFetchedAt[center.id];
      if (at == null) return null;
      if (oldest == null || at.isBefore(oldest)) oldest = at;
    }
    return oldest;
  }

  /// Loads what is stored on the device. Cheap and idempotent.
  void restore() {
    if (_restored || !SP.isInitialized) return;
    _restored = true;
    final prefs = SP.prefs;
    _followed = _decodeCenters(prefs.getString(followedKey));
    _suggestionDismissed = prefs.getBool(suggestionDismissedKey) ?? false;
    final directory = _decodeMap(prefs.getString(directoryCacheKey));
    if (directory != null) {
      _directory = _decodeCenters(jsonEncode(directory['centers'] ?? []));
      _directoryFetchedAt = DateTime.tryParse(
        directory['fetchedAt']?.toString() ?? '',
      );
    }
    final events = _decodeMap(prefs.getString(eventsCacheKey));
    events?.forEach((id, value) {
      if (value is! Map) return;
      final at = DateTime.tryParse(value['fetchedAt']?.toString() ?? '');
      if (at != null) _eventsFetchedAt[id] = at;
      _events[id] = [
        for (final e in (value['events'] as List? ?? const []))
          if (e is Map)
            if (IcsOccurrence.fromJson(Map<String, dynamic>.from(e))
                case final o?)
              o,
      ];
    });
  }

  // --- Directory -----------------------------------------------------------

  /// Fetches the directory when the stored copy is over a day old (or
  /// [force]). A failure keeps the stored copy.
  Future<void> loadDirectory({bool force = false}) {
    restore();
    final fetchedAt = _directoryFetchedAt;
    if (!force &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < directoryMaxAge) {
      return Future.value();
    }
    return _directoryInFlight ??= _loadDirectory().whenComplete(
      () => _directoryInFlight = null,
    );
  }

  Future<void> _loadDirectory() async {
    try {
      final centers = await (_directoryLoader ?? fetchDirectory)();
      _directory = centers;
      _directoryFetchedAt = _clock();
      // A directory centre someone follows picks up its edits (a new
      // calendar, a corrected address).
      final byId = {for (final c in centers) c.id: c};
      final updated = [for (final c in _followed) byId[c.id] ?? c];
      if (!listEquals(updated, _followed)) {
        _followed = updated;
        await _saveFollowed();
      }
      if (SP.isInitialized) {
        await SP.prefs.setString(
          directoryCacheKey,
          jsonEncode({
            'fetchedAt': _directoryFetchedAt!.toIso8601String(),
            'centers': [for (final c in centers) c.toJson()],
          }),
        );
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Islamic centre directory failed to load: $error');
    }
  }

  /// The directory doc. Throws when it cannot be read.
  static Future<List<IslamicCenter>> fetchDirectory() async {
    if (Firebase.apps.isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .doc(directoryDoc)
        .get();
    return centersFromDirectoryDoc(snapshot.data());
  }

  @visibleForTesting
  static List<IslamicCenter> centersFromDirectoryDoc(
    Map<String, dynamic>? data,
  ) {
    final list = data?['centers'];
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map)
          if (IslamicCenter.fromJson(Map<String, dynamic>.from(entry))
              case final c?)
            c,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Applies [change] to the directory as Firestore has it now (not the
  /// copy on this device, so two admins' edits don't undo each other) and
  /// saves it: the admin editor's save. Only an admin may write it
  /// (firestore.rules).
  Future<void> updateDirectory(
    List<IslamicCenter> Function(List<IslamicCenter> current) change,
  ) async {
    final doc = FirebaseFirestore.instance
        .collection(collection)
        .doc(directoryDoc);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final updated = [...change(centersFromDirectoryDoc(snapshot.data()))]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      transaction.set(doc, {
        'centers': [for (final c in updated) c.toJson()],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await loadDirectory(force: true);
  }

  /// An id for a new directory centre named [name]: its name in lower case
  /// and hyphens, numbered if [taken] already has it.
  static String newDirectoryId(String name, Iterable<String> taken) {
    var base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) base = 'center';
    if (base.length > 40) base = base.substring(0, 40);
    final used = taken.toSet();
    var id = base;
    for (var n = 2; used.contains(id); n++) {
      id = '$base-$n';
    }
    return id;
  }

  /// Directory centres nearest [from] first, each with its distance in km
  /// (null for one without coordinates, listed last by name). With no
  /// [from], by name.
  List<(IslamicCenter, double?)> centersByDistance(GeoPoint? from) {
    final rows = [
      for (final c in _directory)
        (
          c,
          from == null || c.point == null
              ? null
              : greatCircleDistanceKm(from, c.point!),
        ),
    ];
    rows.sort((a, b) {
      final da = a.$2, db = b.$2;
      if (da != null && db != null) return da.compareTo(db);
      if (da != null) return -1;
      if (db != null) return 1;
      return a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    });
    return rows;
  }

  // --- Following -----------------------------------------------------------

  Future<void> follow(IslamicCenter center) async {
    restore();
    if (isFollowing(center.id)) return;
    _followed = [..._followed, center];
    await _saveFollowed();
    notifyListeners();
    await refreshCenter(center, force: true);
  }

  Future<void> unfollow(String id) async {
    restore();
    _followed = [
      for (final c in _followed)
        if (c.id != id) c,
    ];
    _events.remove(id);
    _eventsFetchedAt.remove(id);
    _errors.remove(id);
    await _saveFollowed();
    await _saveEvents();
    notifyListeners();
  }

  /// A centre made from a link the reader pasted.
  static IslamicCenter customCenter({
    required String name,
    required String calendar,
    DateTime? now,
  }) => IslamicCenter(
    id:
        '${IslamicCenter.customPrefix}'
        '${(now ?? DateTime.now()).microsecondsSinceEpoch}',
    name: name.trim(),
    calendar: calendar.trim(),
  );

  Future<void> _saveFollowed() async {
    if (!SP.isInitialized) return;
    await SP.prefs.setString(
      followedKey,
      jsonEncode([for (final c in _followed) c.toJson()]),
    );
  }

  // --- Suggestion ----------------------------------------------------------

  /// The centre Home offers to follow: the nearest directory centre within
  /// [suggestionRadiusKm] of the reader, while they follow none and have
  /// not said "Not now". Null otherwise.
  (IslamicCenter, double)? suggestion({double? latitude, double? longitude}) {
    restore();
    if (_suggestionDismissed || hasFollowed) return null;
    final la = latitude ?? app.lat, lo = longitude ?? app.long;
    if (la == null || lo == null) return null;
    final nearest = centersByDistance(GeoPoint(la, lo)).firstOrNull;
    final distance = nearest?.$2;
    if (nearest == null || distance == null) return null;
    if (distance > suggestionRadiusKm) return null;
    return (nearest.$1, distance);
  }

  bool get suggestionDismissed => _suggestionDismissed;

  Future<void> dismissSuggestion() async {
    _suggestionDismissed = true;
    if (SP.isInitialized) {
      await SP.prefs.setBool(suggestionDismissedKey, true);
    }
    notifyListeners();
  }

  // --- Programmes ----------------------------------------------------------

  /// The followed centres' programmes still to come (or under way) at
  /// [now], soonest first.
  List<CenterEvent> upcoming({DateTime? now, int? limit}) {
    restore();
    final at = (now ?? _clock()).toUtc();
    final events =
        <CenterEvent>[
          for (final center in _followed)
            for (final o in _events[center.id] ?? const <IcsOccurrence>[])
              if (_isUpcoming(o, at))
                CenterEvent(center: center, occurrence: o),
        ]..sort((a, b) {
          final byStart = a.start.compareTo(b.start);
          if (byStart != 0) return byStart;
          if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
          return a.title.compareTo(b.title);
        });
    return limit == null || events.length <= limit
        ? events
        : events.sublist(0, limit);
  }

  static bool _isUpcoming(IcsOccurrence o, DateTime nowUtc) {
    if (o.allDay) {
      // Compared as local dates: an all-day programme lasts the whole day
      // wherever the reader is.
      final today = nowUtc.toLocal();
      final end = o.localEnd;
      return end.isAfter(DateTime(today.year, today.month, today.day));
    }
    return o.end.isAfter(nowUtc) ||
        (o.end == o.start && o.start.isAfter(nowUtc));
  }

  /// Fetches every followed centre's calendar that is older than
  /// [eventsMaxAge] (or all of them, [force]).
  Future<void> refreshAll({bool force = false}) async {
    restore();
    await Future.wait([
      for (final center in _followed) refreshCenter(center, force: force),
    ]);
  }

  Future<void> refreshCenter(IslamicCenter center, {bool force = false}) async {
    final fetchedAt = _eventsFetchedAt[center.id];
    if (!force &&
        fetchedAt != null &&
        _errors[center.id] == null &&
        _clock().difference(fetchedAt) < eventsMaxAge) {
      return;
    }
    if (!_refreshing.add(center.id)) return;
    notifyListeners();
    try {
      final events = await loadEvents(center);
      // Unfollowed while it loaded.
      if (!isFollowing(center.id)) return;
      _events[center.id] = events;
      _eventsFetchedAt[center.id] = _clock();
      _errors.remove(center.id);
      await _saveEvents();
    } on CenterFeedException catch (error) {
      _errors[center.id] = error.reason;
    } finally {
      _refreshing.remove(center.id);
      notifyListeners();
    }
  }

  /// [center]'s programmes from now to [eventWindow] ahead, fetched now.
  /// Throws [CenterFeedException]. Also the admin editor's "Test".
  Future<List<IcsOccurrence>> loadEvents(IslamicCenter center) async {
    final url = center.feedUrl;
    if (url == null) throw const CenterFeedException(CenterFeedError.badLink);
    final String body;
    try {
      body = await (_feedLoader ?? fetchFeed)(url);
    } on CenterFeedException {
      rethrow;
    } catch (error) {
      debugPrint('Calendar for ${center.name} failed to load: $error');
      throw const CenterFeedException(CenterFeedError.network);
    }
    final now = _clock();
    try {
      final request = _ParseRequest(
        body,
        now.subtract(const Duration(days: 1)),
        now.add(eventWindow),
      );
      // Off the UI isolate: a calendar with years of history is a few MB.
      return kIsWeb ? _parse(request) : await compute(_parse, request);
    } on IcsFormatException {
      throw const CenterFeedException(CenterFeedError.notPublic);
    }
  }

  /// GETs [url]. Google answers a private calendar with 404 (or an HTML
  /// page), which reads as [CenterFeedError.notPublic].
  static Future<String> fetchFeed(Uri url) async {
    var target = url;
    if (kIsWeb) {
      // Calendar hosts send no CORS headers, so the web build reads them
      // through the same public proxy as the news feed.
      target = Uri.parse(
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent('$url')}',
      );
    }
    final response = await http
        .get(target)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 404 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      throw const CenterFeedException(CenterFeedError.notPublic);
    }
    if (response.statusCode != 200) {
      throw http.ClientException('status ${response.statusCode}');
    }
    // Feeds are UTF-8; http assumes Latin-1 when the header has no charset.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  Future<void> _saveEvents() async {
    if (!SP.isInitialized) return;
    await SP.prefs.setString(
      eventsCacheKey,
      jsonEncode({
        for (final center in _followed)
          if (_events[center.id] case final events?)
            center.id: {
              'fetchedAt': _eventsFetchedAt[center.id]?.toIso8601String(),
              'events': [for (final e in events) e.toJson()],
            },
      }),
    );
  }

  @visibleForTesting
  void resetForTesting() {
    _restored = false;
    _directory = const [];
    _directoryFetchedAt = null;
    _followed = const [];
    _events.clear();
    _eventsFetchedAt.clear();
    _errors.clear();
    _refreshing.clear();
    _suggestionDismissed = false;
  }

  static List<IslamicCenter> _decodeCenters(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final entry in list)
          if (entry is Map)
            if (IslamicCenter.fromJson(Map<String, dynamic>.from(entry))
                case final c?)
              c,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      return map is Map ? Map<String, dynamic>.from(map) : null;
    } catch (_) {
      return null;
    }
  }
}

class CenterFeedException implements Exception {
  const CenterFeedException(this.reason);

  final CenterFeedError reason;

  @override
  String toString() => 'CenterFeedException($reason)';
}

class _ParseRequest {
  const _ParseRequest(this.ics, this.from, this.to);

  final String ics;
  final DateTime from;
  final DateTime to;
}

List<IcsOccurrence> _parse(_ParseRequest request) => parseIcsOccurrences(
  request.ics,
  windowStart: request.from,
  windowEnd: request.to,
);
