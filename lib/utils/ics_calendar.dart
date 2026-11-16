import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'timezone_database.dart';

/// One occurrence of an event in an iCalendar (RFC 5545) feed: a single
/// event, or one date of a recurring one.
@immutable
class IcsOccurrence {
  const IcsOccurrence({
    required this.uid,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.description = '',
    this.location = '',
    this.url,
  });

  /// The event's UID; every occurrence of a recurring event shares it.
  final String uid;
  final String title;

  /// For a timed event, the instant it starts, in UTC.
  ///
  /// For an [allDay] one, the day it falls on as `DateTime.utc(y, m, d)`:
  /// a date, the same wherever the reader is, not an instant.
  final DateTime start;

  /// Exclusive, like [start]: the instant it ends, or the day after an
  /// all-day event's last day.
  final DateTime end;
  final bool allDay;

  /// As the feed has it: Google Calendar's descriptions are HTML.
  final String description;
  final String location;
  final String? url;

  /// [start] in the device's time zone, or the plain date when [allDay].
  DateTime get localStart =>
      allDay ? DateTime(start.year, start.month, start.day) : start.toLocal();

  DateTime get localEnd =>
      allDay ? DateTime(end.year, end.month, end.day) : end.toLocal();

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (allDay) 'allDay': true,
    if (description.isNotEmpty) 'description': description,
    if (location.isNotEmpty) 'location': location,
    if (url != null) 'url': url,
  };

  /// Null for a malformed entry, so one bad row can't sink a cached list.
  static IcsOccurrence? fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['start']?.toString() ?? '');
    final end = DateTime.tryParse(json['end']?.toString() ?? '');
    if (start == null || end == null) return null;
    return IcsOccurrence(
      uid: json['uid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      start: start.toUtc(),
      end: end.toUtc(),
      allDay: json['allDay'] == true,
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      url: json['url']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IcsOccurrence &&
      other.uid == uid &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay &&
      other.description == description &&
      other.location == location &&
      other.url == url;

  @override
  int get hashCode =>
      Object.hash(uid, title, start, end, allDay, description, location, url);

  @override
  String toString() => 'IcsOccurrence($title, $start, allDay: $allDay)';
}

/// Thrown when text is not an iCalendar feed at all: an HTML sign-in page,
/// say, which is what Google sends for a calendar that is not public.
class IcsFormatException implements Exception {
  const IcsFormatException(this.message);

  final String message;

  @override
  String toString() => 'IcsFormatException: $message';
}

/// The occurrences in [ics] that overlap [windowStart]..[windowEnd],
/// soonest first, recurring events expanded.
///
/// Handles what centres' calendars actually hold: single and all-day
/// events, DAILY/WEEKLY/MONTHLY/YEARLY rules with INTERVAL, COUNT, UNTIL,
/// BYDAY (with ordinals: "the last Friday"), BYMONTHDAY, BYMONTH and
/// BYSETPOS, EXDATE, RDATE, moved or cancelled single occurrences
/// (RECURRENCE-ID) and cancelled events. Times are kept in the event's own
/// time zone while repeating, so a weekly 7:30 pm programme stays at 7:30
/// across a clock change. A rule it cannot expand (BYWEEKNO, BYYEARDAY,
/// sub-daily) leaves just the first occurrence.
///
/// Throws [IcsFormatException] when [ics] is not a calendar.
List<IcsOccurrence> parseIcsOccurrences(
  String ics, {
  required DateTime windowStart,
  required DateTime windowEnd,
}) {
  final calendar = _IcsCalendar.parse(ics);
  final from = windowStart.toUtc();
  final to = windowEnd.toUtc();

  // Moved or cancelled single dates of recurring events, by UID and the
  // instant they replace.
  final overrides = <String, Set<int>>{};
  for (final event in calendar.events) {
    final recurrenceId = event.first('RECURRENCE-ID');
    if (recurrenceId == null) continue;
    final original = calendar.instant(recurrenceId);
    if (original == null) continue;
    overrides
        .putIfAbsent(event.uid, () => <int>{})
        .add(original.millisecondsSinceEpoch);
  }

  final results = <IcsOccurrence>[];
  for (final event in calendar.events) {
    if (event.isCancelled) continue;
    final startProp = event.first('DTSTART');
    if (startProp == null) continue;
    final start = calendar.wallTime(startProp);
    if (start == null) continue;

    final duration = calendar.durationOf(event, start);
    final title = event.text('SUMMARY');
    final description = event.text('DESCRIPTION');
    final location = event.text('LOCATION');
    final url = event.first('URL')?.value.trim();

    IcsOccurrence occurrence(_WallTime at) {
      final begin = at.allDay ? at.dateUtc : at.instant;
      return IcsOccurrence(
        uid: event.uid,
        title: title,
        start: begin,
        end: at.allDay
            ? begin.add(Duration(days: duration.inDays))
            : begin.add(duration),
        allDay: at.allDay,
        description: description,
        location: location,
        url: (url == null || url.isEmpty) ? null : url,
      );
    }

    bool overlaps(IcsOccurrence o) =>
        (o.end.isAfter(from) && o.start.isBefore(to)) ||
        // A zero-length event (no DTEND) at the window's start.
        (o.end == o.start && !o.start.isBefore(from) && o.start.isBefore(to));

    final ruleProp = event.first('RRULE');
    final isOverride = event.first('RECURRENCE-ID') != null;
    if (ruleProp == null || isOverride) {
      final single = occurrence(start);
      if (overlaps(single)) results.add(single);
      continue;
    }

    final excluded = <int>{
      ...?overrides[event.uid],
      for (final prop in event.all('EXDATE'))
        for (final value in prop.value.split(','))
          if (calendar.wallTime(prop.withValue(value)) case final at?) at.key,
    };
    final rule = _RecurrenceRule.tryParse(ruleProp.value, calendar, start);
    final dates = <_WallTime>[
      if (rule == null)
        start
      else
        ...rule.expand(
          start,
          // A day's slack either side: the window is in UTC, the rule in
          // the event's own zone.
          until: to.add(const Duration(days: 1)),
          skipBefore: from.subtract(duration + const Duration(days: 2)),
        ),
      for (final prop in event.all('RDATE'))
        for (final value in prop.value.split(','))
          if (calendar.wallTime(prop.withValue(value), like: start)
              case final at?)
            at,
    ];
    final seen = <int>{};
    for (final at in dates) {
      if (excluded.contains(at.key) || !seen.add(at.key)) continue;
      final o = occurrence(at);
      if (overlaps(o)) results.add(o);
    }
  }

  results.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    // All-day first, as calendars list them.
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.title.compareTo(b.title);
  });
  return results;
}

/// [html], an event description as Google Calendar writes it, as plain
/// text: line breaks kept, tags dropped, entities decoded.
String icsPlainText(String html) {
  if (!html.contains('<') && !html.contains('&')) return html.trim();
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|h\d|ul|ol)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      // A link whose text is not its address keeps the address, so it can
      // still be found and opened.
      .replaceAllMapped(
        RegExp(
          r'''<a\s[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>''',
          caseSensitive: false,
          dotAll: true,
        ),
        (m) {
          final href = m[1]!;
          final label = m[2]!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (label.isEmpty || href.contains(label) || label.contains(href)) {
            return href;
          }
          return '$label ($href)';
        },
      )
      .replaceAll(RegExp(r'<[^>]*>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&rsquo;': '’',
    '&lsquo;': '‘',
    '&rdquo;': '”',
    '&ldquo;': '“',
    '&ndash;': '–',
    '&mdash;': '—',
  };
  entities.forEach((entity, char) => text = text.replaceAll(entity, char));
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m[1]!);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  // Last, so "&amp;lt;" stays "&lt;" rather than becoming "<".
  text = text.replaceAll('&amp;', '&');
  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// The web addresses in [text], in order, each once.
List<Uri> icsLinks(String text) {
  final links = <Uri>[];
  final seen = <String>{};
  for (final m in RegExp(r'''https?://[^\s<>"')\]]+''').allMatches(text)) {
    final raw = m[0]!.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host.isNotEmpty && seen.add(raw)) links.add(uri);
  }
  return links;
}

// ---------------------------------------------------------------------------

/// One content line: `NAME;PARAM=x:value`.
class _IcsProperty {
  const _IcsProperty(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;

  _IcsProperty withValue(String value) => _IcsProperty(name, params, value);

  static _IcsProperty? parse(String line) {
    // The value starts at the first colon outside a quoted parameter.
    var inQuotes = false;
    var colon = -1;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') inQuotes = !inQuotes;
      if (c == ':' && !inQuotes) {
        colon = i;
        break;
      }
    }
    if (colon <= 0) return null;
    final head = line.substring(0, colon);
    final value = line.substring(colon + 1);
    final parts = <String>[];
    final buffer = StringBuffer();
    inQuotes = false;
    for (var i = 0; i < head.length; i++) {
      final c = head[i];
      if (c == '"') inQuotes = !inQuotes;
      if (c == ';' && !inQuotes) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    parts.add(buffer.toString());
    final params = <String, String>{};
    for (final part in parts.skip(1)) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      var v = part.substring(eq + 1);
      if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
        v = v.substring(1, v.length - 1);
      }
      params[part.substring(0, eq).toUpperCase()] = v;
    }
    return _IcsProperty(parts.first.toUpperCase(), params, value);
  }
}

class _IcsEvent {
  final Map<String, List<_IcsProperty>> props = {};

  void add(_IcsProperty prop) =>
      props.putIfAbsent(prop.name, () => []).add(prop);

  _IcsProperty? first(String name) => props[name]?.first;

  List<_IcsProperty> all(String name) => props[name] ?? const [];

  String get uid => first('UID')?.value ?? '';

  bool get isCancelled =>
      first('STATUS')?.value.trim().toUpperCase() == 'CANCELLED';

  /// A TEXT value, unescaped (RFC 5545 §3.3.11).
  String text(String name) {
    final raw = first(name)?.value;
    if (raw == null) return '';
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == r'\' && i + 1 < raw.length) {
        final next = raw[++i];
        out.write(next == 'n' || next == 'N' ? '\n' : next);
      } else {
        out.write(c);
      }
    }
    return out.toString().trim();
  }
}

class _IcsCalendar {
  _IcsCalendar(this.events, this.defaultZone);

  final List<_IcsEvent> events;

  /// X-WR-TIMEZONE: where floating times are, if the feed says.
  final tz.Location? defaultZone;

  static _IcsCalendar parse(String ics) {
    final text = ics.startsWith('﻿') ? ics.substring(1) : ics;
    if (!text.trimLeft().toUpperCase().startsWith('BEGIN:VCALENDAR')) {
      throw const IcsFormatException('not an iCalendar feed');
    }
    // Unfold: a line starting with a space or tab continues the last one.
    final lines = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      if ((raw.startsWith(' ') || raw.startsWith('\t')) && lines.isNotEmpty) {
        lines[lines.length - 1] += raw.substring(1);
      } else if (raw.isNotEmpty) {
        lines.add(raw);
      }
    }
    final events = <_IcsEvent>[];
    tz.Location? zone;
    _IcsEvent? current;
    // Nested components (VALARM inside a VEVENT) are skipped.
    var depth = 0;
    for (final line in lines) {
      final prop = _IcsProperty.parse(line);
      if (prop == null) continue;
      if (prop.name == 'BEGIN') {
        if (prop.value.toUpperCase() == 'VEVENT' && current == null) {
          current = _IcsEvent();
          depth = 0;
        } else if (current != null) {
          depth++;
        }
        continue;
      }
      if (prop.name == 'END') {
        if (current == null) continue;
        if (depth > 0) {
          depth--;
        } else if (prop.value.toUpperCase() == 'VEVENT') {
          events.add(current);
          current = null;
        }
        continue;
      }
      if (current != null) {
        if (depth == 0) current.add(prop);
      } else if (prop.name == 'X-WR-TIMEZONE') {
        zone = tryGetLocation(prop.value.trim());
      }
    }
    return _IcsCalendar(events, zone);
  }

  /// A DATE or DATE-TIME property as wall-clock fields in its own zone.
  /// [like] gives a value with no zone of its own (an RDATE) the zone of
  /// the event's start.
  _WallTime? wallTime(_IcsProperty prop, {_WallTime? like}) {
    final value = prop.value.trim();
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$')
        .firstMatch(value);
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (m[4] == null || prop.params['VALUE']?.toUpperCase() == 'DATE') {
      return _WallTime.date(DateTime.utc(y, mo, d));
    }
    final fields = DateTime.utc(
      y,
      mo,
      d,
      int.parse(m[4]!),
      int.parse(m[5]!),
      int.parse(m[6] ?? '0'),
    );
    if (m[7] != null) return _WallTime(fields, _Zone.utc);
    final zoneId = prop.params['TZID'];
    if (zoneId != null) {
      final location = tryGetLocation(_cleanZoneId(zoneId));
      if (location != null) return _WallTime(fields, _Zone(location));
    }
    if (like != null && !like.allDay) return _WallTime(fields, like.zone);
    final fallback = defaultZone;
    return _WallTime(fields, fallback == null ? _Zone.device : _Zone(fallback));
  }

  /// A RECURRENCE-ID or similar as an instant (a date as UTC midnight).
  DateTime? instant(_IcsProperty prop) {
    final at = wallTime(prop);
    if (at == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(at.key, isUtc: true);
  }

  Duration durationOf(_IcsEvent event, _WallTime start) {
    final endProp = event.first('DTEND');
    if (endProp != null) {
      final end = wallTime(endProp, like: start);
      if (end != null) {
        if (start.allDay) {
          final days = end.dateUtc.difference(start.dateUtc).inDays;
          return Duration(days: days < 1 ? 1 : days);
        }
        final d = end.instant.difference(start.instant);
        return d.isNegative ? Duration.zero : d;
      }
    }
    final durationProp = event.first('DURATION');
    if (durationProp != null) {
      final d = _parseDuration(durationProp.value.trim());
      if (d != null)
        return start.allDay && d.inDays < 1 ? const Duration(days: 1) : d;
    }
    return start.allDay ? const Duration(days: 1) : Duration.zero;
  }

  /// Outlook writes some zones with quotes or a leading slash.
  static String _cleanZoneId(String id) =>
      id.replaceAll('"', '').replaceFirst(RegExp(r'^/+'), '').trim();
}

Duration? _parseDuration(String value) {
  final m = RegExp(
    r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
  ).firstMatch(value);
  if (m == null) return null;
  int n(int i) => int.tryParse(m[i] ?? '') ?? 0;
  final d = Duration(
    days: n(2) * 7 + n(3),
    hours: n(4),
    minutes: n(5),
    seconds: n(6),
  );
  return m[1] == '-' ? Duration.zero : d;
}

/// Where a wall-clock time is: UTC, a named zone, or the device's own.
class _Zone {
  const _Zone(this.location) : _device = false;
  const _Zone._special(this._device) : location = null;

  static const _Zone utc = _Zone._special(false);
  static const _Zone device = _Zone._special(true);

  final tz.Location? location;
  final bool _device;

  DateTime toInstant(DateTime f) {
    final location = this.location;
    if (location != null) {
      // As a plain DateTime: a TZDateTime is never == a DateTime.
      return DateTime.fromMillisecondsSinceEpoch(
        tz.TZDateTime(
          location,
          f.year,
          f.month,
          f.day,
          f.hour,
          f.minute,
          f.second,
        ).millisecondsSinceEpoch,
        isUtc: true,
      );
    }
    if (_device) {
      return DateTime(
        f.year,
        f.month,
        f.day,
        f.hour,
        f.minute,
        f.second,
      ).toUtc();
    }
    return f;
  }
}

/// A date, or a date and time of day in a [_Zone]. The fields are held in a
/// UTC [DateTime] only because that does calendar arithmetic without clock
/// changes; they are not a UTC time.
class _WallTime {
  _WallTime(this.fields, this.zone) : allDay = false;

  _WallTime.date(DateTime date)
    : fields = DateTime.utc(date.year, date.month, date.day),
      zone = _Zone.utc,
      allDay = true;

  final DateTime fields;
  final _Zone zone;
  final bool allDay;

  DateTime get dateUtc => DateTime.utc(fields.year, fields.month, fields.day);

  late final DateTime instant = allDay ? dateUtc : zone.toInstant(fields);

  /// What EXDATE and RECURRENCE-ID are matched on.
  int get key => instant.millisecondsSinceEpoch;

  _WallTime withFields(DateTime f) =>
      allDay ? _WallTime.date(f) : _WallTime(f, zone);
}

enum _Freq { daily, weekly, monthly, yearly }

/// A weekday in BYDAY, with its ordinal (`-1FR`: the last Friday) if any.
class _ByDay {
  const _ByDay(this.weekday, this.ordinal);

  /// DateTime.monday..DateTime.sunday.
  final int weekday;

  /// 0 for every such weekday.
  final int ordinal;
}

class _RecurrenceRule {
  _RecurrenceRule({
    required this.freq,
    required this.interval,
    this.count,
    this.until,
    this.byDay = const [],
    this.byMonthDay = const [],
    this.byMonth = const [],
    this.bySetPos = const [],
  });

  final _Freq freq;
  final int interval;
  final int? count;

  /// Inclusive, as an instant.
  final DateTime? until;
  final List<_ByDay> byDay;
  final List<int> byMonthDay;
  final List<int> byMonth;
  final List<int> bySetPos;

  /// Safety valve: no feed should need more periods than this.
  static const int _maxPeriods = 20000;

  static const _weekdays = {
    'MO': DateTime.monday,
    'TU': DateTime.tuesday,
    'WE': DateTime.wednesday,
    'TH': DateTime.thursday,
    'FR': DateTime.friday,
    'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };

  /// Null for a rule this cannot expand (the caller keeps DTSTART alone).
  static _RecurrenceRule? tryParse(
    String value,
    _IcsCalendar calendar,
    _WallTime start,
  ) {
    final parts = <String, String>{};
    for (final part in value.trim().split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        parts[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
      }
    }
    final freq = switch (parts['FREQ']?.toUpperCase()) {
      'DAILY' => _Freq.daily,
      'WEEKLY' => _Freq.weekly,
      'MONTHLY' => _Freq.monthly,
      'YEARLY' => _Freq.yearly,
      _ => null,
    };
    if (freq == null ||
        parts.containsKey('BYWEEKNO') ||
        parts.containsKey('BYYEARDAY') ||
        parts.containsKey('BYHOUR') ||
        parts.containsKey('BYMINUTE')) {
      return null;
    }
    List<int> ints(String key) => [
      for (final s in (parts[key] ?? '').split(','))
        if (int.tryParse(s.trim()) case final n? when n != 0) n,
    ];
    final byDay = <_ByDay>[];
    for (final s in (parts['BYDAY'] ?? '').split(',')) {
      final m = RegExp(r'^([+-]?\d{1,2})?([A-Za-z]{2})$').firstMatch(s.trim());
      final weekday = m == null ? null : _weekdays[m[2]!.toUpperCase()];
      if (weekday == null) continue;
      byDay.add(_ByDay(weekday, int.tryParse(m![1] ?? '') ?? 0));
    }
    DateTime? until;
    final untilRaw = parts['UNTIL'];
    if (untilRaw != null) {
      final at = calendar.wallTime(
        _IcsProperty('UNTIL', const {}, untilRaw),
        like: start,
      );
      if (at != null) {
        // A date-only UNTIL takes in the whole of that day.
        until = at.allDay && !start.allDay
            ? start.zone.toInstant(
                at.dateUtc.add(
                  const Duration(hours: 23, minutes: 59, seconds: 59),
                ),
              )
            : at.instant;
      }
    }
    final interval = int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
    return _RecurrenceRule(
      freq: freq,
      interval: interval < 1 ? 1 : interval,
      count: int.tryParse(parts['COUNT'] ?? ''),
      until: until,
      byDay: byDay,
      byMonthDay: ints('BYMONTHDAY'),
      byMonth: ints('BYMONTH').where((m) => m >= 1 && m <= 12).toList(),
      bySetPos: ints('BYSETPOS'),
    );
  }

  /// The rule's dates from [start] on, stopping after [until] (the
  /// caller's horizon, not the rule's UNTIL) and leaving out those before
  /// [skipBefore] - though they still count towards COUNT.
  Iterable<_WallTime> expand(
    _WallTime start, {
    required DateTime until,
    required DateTime skipBefore,
  }) sync* {
    final first = start.fields;
    var produced = 0;
    var period = 0;
    // Without COUNT nothing before the window matters, so a daily or weekly
    // rule from years ago can start near it.
    if (count == null && start.instant.isBefore(skipBefore)) {
      final days = skipBefore.difference(start.instant).inDays;
      final periodDays = switch (freq) {
        _Freq.daily => interval,
        _Freq.weekly => 7 * interval,
        // Months and years at their longest, so the jump never overshoots.
        _Freq.monthly => 31 * interval,
        _Freq.yearly => 366 * interval,
      };
      period = days ~/ periodDays - 1;
      if (period < 0) period = 0;
    }
    for (; period < _maxPeriods; period++) {
      final candidates = _candidates(first, period);
      if (candidates == null) break;
      for (final fields in candidates) {
        if (fields.isBefore(first)) continue;
        final at = start.withFields(fields);
        final instant = at.instant;
        if (this.until case final ruleEnd? when instant.isAfter(ruleEnd)) {
          return;
        }
        if (instant.isAfter(until)) return;
        produced++;
        if (!instant.isBefore(skipBefore)) yield at;
        if (count case final c? when produced >= c) return;
      }
    }
  }

  /// The dates [period] periods after [first]'s, in order; null past the
  /// end of the calendar.
  List<DateTime>? _candidates(DateTime first, int period) {
    DateTime at(int y, int m, int d) =>
        DateTime.utc(y, m, d, first.hour, first.minute, first.second);
    bool monthOk(DateTime d) => byMonth.isEmpty || byMonth.contains(d.month);

    switch (freq) {
      case _Freq.daily:
        final d = at(first.year, first.month, first.day + period * interval);
        if (d.year > 9999) return null;
        final keep =
            monthOk(d) &&
            (byDay.isEmpty || byDay.any((b) => b.weekday == d.weekday)) &&
            (byMonthDay.isEmpty || _matchesMonthDay(d));
        return keep ? [d] : const [];
      case _Freq.weekly:
        // Weeks start on Monday (WKST=MO, the default).
        final weekStart = at(
          first.year,
          first.month,
          first.day - (first.weekday - 1) + period * 7 * interval,
        );
        if (weekStart.year > 9999) return null;
        final weekdays = byDay.isEmpty
            ? [first.weekday]
            : (byDay.map((b) => b.weekday).toSet().toList()..sort());
        return _setPos([
          for (final w in weekdays)
            if (at(weekStart.year, weekStart.month, weekStart.day + w - 1)
                case final d when monthOk(d))
              d,
        ]);
      case _Freq.monthly:
        final month = DateTime.utc(first.year, first.month + period * interval);
        if (month.year > 9999) return null;
        if (!monthOk(month)) return const [];
        return _setPos(_daysInMonth(first, month.year, month.month));
      case _Freq.yearly:
        final year = first.year + period * interval;
        if (year > 9999) return null;
        final months = byMonth.isEmpty
            ? [first.month]
            : (byMonth.toList()..sort());
        if (byMonth.isEmpty && byDay.isNotEmpty && byMonthDay.isEmpty) {
          // "The 20th Monday of the year": ordinals count through the year.
          return _setPos(
            _weekdaysIn(
              first,
              DateTime.utc(year, 1, 1),
              DateTime.utc(year + 1, 1, 1),
            ),
          );
        }
        return _setPos([
          for (final m in months) ..._daysInMonth(first, year, m),
        ]);
    }
  }

  bool _matchesMonthDay(DateTime d) {
    final length = DateTime.utc(d.year, d.month + 1, 0).day;
    return byMonthDay.any((n) => n > 0 ? n == d.day : length + n + 1 == d.day);
  }

  /// The dates a MONTHLY rule (or a YEARLY one, per month) picks in
  /// [year]-[month].
  List<DateTime> _daysInMonth(DateTime first, int year, int month) {
    DateTime at(int d) =>
        DateTime.utc(year, month, d, first.hour, first.minute, first.second);
    final length = DateTime.utc(year, month + 1, 0).day;
    if (byMonthDay.isNotEmpty) {
      final days = <int>{
        for (final n in byMonthDay)
          if (n > 0 && n <= length)
            n
          else if (n < 0 && length + n + 1 >= 1)
            length + n + 1,
      }.toList()..sort();
      return [
        for (final d in days)
          if (byDay.isEmpty || byDay.any((b) => b.weekday == at(d).weekday))
            at(d),
      ];
    }
    if (byDay.isNotEmpty) {
      return _weekdaysIn(
        first,
        DateTime.utc(year, month, 1),
        DateTime.utc(year, month + 1, 1),
      );
    }
    // Plain monthly: the start's day of the month, skipped in months
    // without one (RFC 5545: no 31st in April).
    return first.day <= length ? [at(first.day)] : const [];
  }

  /// The BYDAY weekdays between [from] and [to] (exclusive), ordinals
  /// counted within that span.
  List<DateTime> _weekdaysIn(DateTime first, DateTime from, DateTime to) {
    final days = <DateTime>{};
    for (final b in byDay) {
      final matches = <DateTime>[];
      for (var d = from; d.isBefore(to); d = d.add(const Duration(days: 1))) {
        if (d.weekday == b.weekday) {
          matches.add(
            DateTime.utc(
              d.year,
              d.month,
              d.day,
              first.hour,
              first.minute,
              first.second,
            ),
          );
        }
      }
      if (b.ordinal == 0) {
        days.addAll(matches);
      } else {
        final i = b.ordinal > 0 ? b.ordinal - 1 : matches.length + b.ordinal;
        if (i >= 0 && i < matches.length) days.add(matches[i]);
      }
    }
    return days.toList()..sort();
  }

  List<DateTime> _setPos(List<DateTime> days) {
    if (bySetPos.isEmpty || days.isEmpty) return days;
    final picked = <DateTime>{
      for (final p in bySetPos)
        if (p > 0 && p <= days.length)
          days[p - 1]
        else if (p < 0 && days.length + p >= 0)
          days[days.length + p],
    }.toList()..sort();
    return picked;
  }
}
