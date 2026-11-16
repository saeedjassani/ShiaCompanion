import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/geo_utils.dart';
import '../utils/ics_calendar.dart';

/// A mosque, imambargah or Islamic centre whose programmes the app can show,
/// from the directory (docs/ISLAMIC_CENTERS.md) or added by the reader from
/// a calendar link.
@immutable
class IslamicCenter {
  const IslamicCenter({
    required this.id,
    required this.name,
    required this.calendar,
    this.city = '',
    this.latitude,
    this.longitude,
    this.address = '',
    this.website,
  });

  /// Stable: a directory centre's id never changes, so following it
  /// survives edits to everything else. A reader's own begins `custom-`.
  final String id;
  final String name;

  /// What the calendar was given as: a Google Calendar ID, a share or
  /// embed link, or any iCalendar (.ics / webcal) address. See
  /// [calendarFeedUrl].
  final String calendar;

  /// "Houston, TX": shown under the name.
  final String city;
  final double? latitude;
  final double? longitude;
  final String address;
  final String? website;

  static const String customPrefix = 'custom-';

  bool get isCustom => id.startsWith(customPrefix);

  GeoPoint? get point => latitude == null || longitude == null
      ? null
      : GeoPoint(latitude!, longitude!);

  /// Where its programmes are read from; null when [calendar] is not
  /// something this understands.
  Uri? get feedUrl => calendarFeedUrl(calendar);

  IslamicCenter copyWith({
    String? name,
    String? calendar,
    String? city,
    double? latitude,
    double? longitude,
    String? address,
    String? website,
  }) => IslamicCenter(
    id: id,
    name: name ?? this.name,
    calendar: calendar ?? this.calendar,
    city: city ?? this.city,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    address: address ?? this.address,
    website: website ?? this.website,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calendar': calendar,
    if (city.isNotEmpty) 'city': city,
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lng': longitude,
    if (address.isNotEmpty) 'address': address,
    if (website != null && website!.isNotEmpty) 'website': website,
  };

  /// Null for an entry without an id, name or calendar, so one bad row in
  /// the directory can't hide the rest.
  static IslamicCenter? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final calendar = json['calendar']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty || calendar.isEmpty) return null;
    double? number(Object? v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    final website = json['website']?.toString().trim();
    return IslamicCenter(
      id: id,
      name: name,
      calendar: calendar,
      city: json['city']?.toString().trim() ?? '',
      latitude: number(json['lat']),
      longitude: number(json['lng']),
      address: json['address']?.toString().trim() ?? '',
      website: website == null || website.isEmpty ? null : website,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IslamicCenter &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'IslamicCenter($id, $name)';
}

/// One programme on a followed centre's calendar.
@immutable
class CenterEvent {
  const CenterEvent({required this.center, required this.occurrence});

  final IslamicCenter center;
  final IcsOccurrence occurrence;

  String get title => occurrence.title;
  DateTime get start => occurrence.start;
  DateTime get end => occurrence.end;
  bool get allDay => occurrence.allDay;
}

/// The iCalendar address [input] stands for, or null when it is none of:
///
/// * a Google Calendar ID (`abc123@group.calendar.google.com`, or a Gmail
///   address for someone's main calendar);
/// * a Google Calendar link with one in it: the embed link
///   (`calendar.google.com/calendar/embed?src=...`), or the "public URL" /
///   share link (`.../calendar/u/0?cid=...`, the ID in base64);
/// * any iCalendar address: `https://...` (Google's "public address in
///   iCal format", Outlook's and iCloud's published calendars) or `webcal://`.
///
/// A Google calendar's address only answers once its owner has ticked
/// "Make available to public" in its settings.
Uri? calendarFeedUrl(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  if (!text.contains('://') && !text.contains('/')) {
    final id = Uri.decodeComponent(text);
    return _looksLikeCalendarId(id) ? googleCalendarFeedUrl(id) : null;
  }

  var uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme == 'webcal' || uri.scheme == 'webcals') {
    uri = uri.replace(scheme: 'https');
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  if (uri.host.isEmpty) return null;

  if (uri.host == 'calendar.google.com' || uri.host == 'www.google.com') {
    // Already the feed: .../calendar/ical/<id>/public/basic.ics
    if (uri.path.contains('/ical/')) return uri.replace(scheme: 'https');
    final src = uri.queryParametersAll['src'];
    if (src != null && src.isNotEmpty) {
      final id = src.first.trim();
      if (_looksLikeCalendarId(id)) return googleCalendarFeedUrl(id);
    }
    final cid = uri.queryParameters['cid']?.trim();
    if (cid != null && cid.isNotEmpty) {
      if (_looksLikeCalendarId(cid)) return googleCalendarFeedUrl(cid);
      final decoded = _decodeBase64Id(cid);
      if (decoded != null) return googleCalendarFeedUrl(decoded);
    }
    return null;
  }
  return uri;
}

/// The public iCalendar feed of the Google calendar [calendarId].
Uri googleCalendarFeedUrl(String calendarId) => Uri.parse(
    // Built as text: Uri.https would encode the ID's %40 a second time.
    'https://calendar.google.com/calendar/ical/'
    '${Uri.encodeComponent(calendarId)}/public/basic.ics');

bool _looksLikeCalendarId(String id) =>
    RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$').hasMatch(id);

String? _decodeBase64Id(String value) {
  var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  try {
    final id = utf8.decode(base64.decode(normalized)).trim();
    return _looksLikeCalendarId(id) ? id : null;
  } catch (_) {
    return null;
  }
}
