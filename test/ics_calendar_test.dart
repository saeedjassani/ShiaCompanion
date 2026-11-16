import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/ics_calendar.dart';

/// Wraps VEVENTs the way Google Calendar's public basic.ics does.
String feed(String events, {String zone = 'America/Chicago'}) => [
  'BEGIN:VCALENDAR',
  'PRODID:-//Google Inc//Google Calendar 70.9054//EN',
  'VERSION:2.0',
  'CALSCALE:GREGORIAN',
  'METHOD:PUBLISH',
  'X-WR-CALNAME:Test Center',
  'X-WR-TIMEZONE:$zone',
  'BEGIN:VTIMEZONE',
  'TZID:America/Chicago',
  'BEGIN:STANDARD',
  'TZOFFSETFROM:-0500',
  'TZOFFSETTO:-0600',
  'DTSTART:19701101T020000',
  'END:STANDARD',
  'END:VTIMEZONE',
  events.trim(),
  'END:VCALENDAR',
].join('\r\n');

List<IcsOccurrence> parse(
  String events, {
  required DateTime from,
  required DateTime to,
}) => parseIcsOccurrences(feed(events), windowStart: from, windowEnd: to);

void main() {
  final from = DateTime.utc(2026, 11, 1);
  final to = DateTime.utc(2027, 1, 1);

  test('a single timed event in a named zone becomes a UTC instant', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261120T193000
DTEND;TZID=America/Chicago:20261120T213000
UID:a@google.com
SUMMARY:Dua Kumayl\\, with majlis
LOCATION:Main Hall\\; 123 Street
DESCRIPTION:Line one\\nLine two
STATUS:CONFIRMED
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:This is an alarm, not the event
END:VALARM
END:VEVENT
''',
      from: from,
      to: to,
    );
    expect(events, hasLength(1));
    final e = events.single;
    expect(e.title, 'Dua Kumayl, with majlis');
    expect(e.location, 'Main Hall; 123 Street');
    expect(e.description, 'Line one\nLine two');
    // CST is UTC-6 in November.
    expect(e.start, DateTime.utc(2026, 11, 21, 1, 30));
    expect(e.end, DateTime.utc(2026, 11, 21, 3, 30));
    expect(e.allDay, isFalse);
  });

  test('folded lines are joined', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART:20261120T010000Z
UID:b
SUMMARY:Majlis on the martyrdom of Lady Fatimah al-
 Zahra (s.a.)
END:VEVENT
''',
      from: from,
      to: to,
    );
    expect(
      events.single.title,
      'Majlis on the martyrdom of Lady Fatimah al-Zahra (s.a.)',
    );
    // No DTEND: it lasts no time at all, and still shows.
    expect(events.single.end, events.single.start);
  });

  test('all-day events keep their date', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261125
DTEND;VALUE=DATE:20261127
UID:c
SUMMARY:Youth retreat
END:VEVENT
''',
      from: from,
      to: to,
    );
    final e = events.single;
    expect(e.allDay, isTrue);
    expect(e.start, DateTime.utc(2026, 11, 25));
    expect(e.end, DateTime.utc(2026, 11, 27));
    expect(e.localStart, DateTime(2026, 11, 25));
  });

  test('weekly rule keeps its wall-clock time across a clock change', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261015T200000
DTEND;TZID=America/Chicago:20261015T210000
RRULE:FREQ=WEEKLY;BYDAY=TH
UID:d
SUMMARY:Thursday Dua Kumayl
END:VEVENT
''',
      from: from,
      to: DateTime.utc(2026, 11, 21),
    );
    // Thursdays 5, 12 and 19 November, 8 pm CST = 02:00 UTC next day.
    expect(events.map((e) => e.start), [
      DateTime.utc(2026, 11, 6, 2),
      DateTime.utc(2026, 11, 13, 2),
      DateTime.utc(2026, 11, 20, 2),
    ]);
    // October's were CDT (UTC-5): still 8 pm local.
    final october = parseIcsOccurrences(
      feed('''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261015T200000
RRULE:FREQ=WEEKLY;BYDAY=TH
UID:d
SUMMARY:Thursday Dua Kumayl
END:VEVENT
'''),
      windowStart: DateTime.utc(2026, 10, 15),
      windowEnd: DateTime.utc(2026, 10, 17),
    );
    expect(october.single.start, DateTime.utc(2026, 10, 16, 1));
  });

  test('COUNT, UNTIL, INTERVAL and EXDATE', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART:20261102T000000Z
RRULE:FREQ=DAILY;COUNT=3
UID:count
SUMMARY:Count
END:VEVENT
BEGIN:VEVENT
DTSTART:20261102T120000Z
RRULE:FREQ=WEEKLY;INTERVAL=2;UNTIL=20261201T000000Z
EXDATE:20261116T120000Z
UID:until
SUMMARY:Until
END:VEVENT
''',
      from: from,
      to: to,
    );
    expect(events.where((e) => e.uid == 'count').map((e) => e.start.day), [
      2,
      3,
      4,
    ]);
    // 2, (16 excluded), 30 November.
    expect(events.where((e) => e.uid == 'until').map((e) => e.start.day), [
      2,
      30,
    ]);
  });

  test('COUNT is counted from the series start, not the window', () {
    final events = parseIcsOccurrences(
      feed('''
BEGIN:VEVENT
DTSTART:20261028T000000Z
RRULE:FREQ=DAILY;COUNT=7
UID:x
SUMMARY:Week of majalis
END:VEVENT
'''),
      windowStart: DateTime.utc(2026, 11, 1),
      windowEnd: to,
    );
    // 28 Oct .. 3 Nov: the last three fall in the window.
    expect(events.map((e) => e.start.day), [1, 2, 3]);
  });

  test('monthly by ordinal weekday and by negative month day', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260904T190000
RRULE:FREQ=MONTHLY;BYDAY=1FR
UID:first-friday
SUMMARY:First Friday
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260930T190000
RRULE:FREQ=MONTHLY;BYMONTHDAY=-1
UID:last-day
SUMMARY:Last day
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260925T190000
RRULE:FREQ=MONTHLY;BYDAY=-1FR
UID:last-friday
SUMMARY:Last Friday
END:VEVENT
''',
      from: DateTime.utc(2026, 11, 2),
      to: DateTime.utc(2027, 1, 2),
    );
    List<DateTime> local(String uid) => [
      for (final e in events.where((e) => e.uid == uid))
        DateTime(e.localStart.year, e.localStart.month, e.localStart.day),
    ];
    // Compare dates in Chicago: 7 pm there is next day in UTC.
    List<int> chicagoDays(String uid) => [
      for (final e in events.where((e) => e.uid == uid))
        e.start.subtract(const Duration(hours: 6)).day,
    ];
    expect(local('first-friday'), hasLength(2));
    expect(chicagoDays('first-friday'), [6, 4]); // 6 Nov, 4 Dec
    expect(chicagoDays('last-day'), [30, 31]); // 30 Nov, 31 Dec
    expect(chicagoDays('last-friday'), [27, 25]); // 27 Nov, 25 Dec
  });

  test('a long-running rule from years ago is cheap and still right', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20120105T200000
RRULE:FREQ=WEEKLY;BYDAY=TH,SU
UID:old
SUMMARY:Old weekly
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20120110T200000
RRULE:FREQ=MONTHLY
UID:old-monthly
SUMMARY:Old monthly
END:VEVENT
''',
      from: from,
      to: DateTime.utc(2026, 11, 15),
    );
    final weekly = events.where((e) => e.uid == 'old').toList();
    // Thu 5, Sun 8, Thu 12 Nov (local), each 02:00 UTC the next day.
    expect(weekly.map((e) => e.start.day), [2, 6, 9, 13]);
    // 1 Nov 02:00 UTC is Sunday 1 Nov 8 pm... Chicago is still CDT till
    // 1 Nov 2 am, so Sun 1 Nov 8 pm CST = 2 Nov 02:00 UTC.
    expect(weekly.first.start, DateTime.utc(2026, 11, 2, 2));
    expect(
      events.where((e) => e.uid == 'old-monthly').single.start,
      DateTime.utc(2026, 11, 11, 2),
    );
  });

  test('a moved occurrence replaces the original; a cancelled one goes', () {
    final events = parse(
      '''
BEGIN:VEVENT
DTSTART:20261102T010000Z
RRULE:FREQ=WEEKLY;COUNT=4
UID:series
SUMMARY:Weekly class
END:VEVENT
BEGIN:VEVENT
DTSTART:20261110T010000Z
RECURRENCE-ID:20261109T010000Z
UID:series
SUMMARY:Weekly class (moved to Tuesday)
END:VEVENT
BEGIN:VEVENT
DTSTART:20261116T010000Z
RECURRENCE-ID:20261116T010000Z
UID:series
STATUS:CANCELLED
SUMMARY:Weekly class
END:VEVENT
BEGIN:VEVENT
DTSTART:20261105T010000Z
UID:gone
STATUS:CANCELLED
SUMMARY:Cancelled programme
END:VEVENT
''',
      from: from,
      to: to,
    );
    expect(events.map((e) => '${e.start.day} ${e.title}'), [
      '2 Weekly class',
      '10 Weekly class (moved to Tuesday)',
      '23 Weekly class',
    ]);
  });

  test('events that already ended are left out; ongoing ones stay', () {
    final events = parseIcsOccurrences(
      feed('''
BEGIN:VEVENT
DTSTART:20261116T100000Z
DTEND:20261116T110000Z
UID:over
SUMMARY:Over
END:VEVENT
BEGIN:VEVENT
DTSTART:20261116T110000Z
DTEND:20261116T130000Z
UID:ongoing
SUMMARY:Ongoing
END:VEVENT
'''),
      windowStart: DateTime.utc(2026, 11, 16, 12),
      windowEnd: to,
    );
    expect(events.map((e) => e.uid), ['ongoing']);
  });

  test('a page that is not a calendar is an error', () {
    expect(
      () => parseIcsOccurrences(
        '<html><body>Sign in</body></html>',
        windowStart: from,
        windowEnd: to,
      ),
      throwsA(isA<IcsFormatException>()),
    );
  });

  test('JSON round trip', () {
    final e = IcsOccurrence(
      uid: 'u',
      title: 'T',
      start: DateTime.utc(2026, 11, 20, 1),
      end: DateTime.utc(2026, 11, 20, 2),
      description: 'd',
      location: 'l',
      url: 'https://example.org',
    );
    expect(IcsOccurrence.fromJson(e.toJson()), e);
  });

  test('icsPlainText and icsLinks read Google descriptions', () {
    const html =
        'Join us for <b>Dua Kumayl</b><br>Speaker: Sheikh A&amp;B'
        '<br><br><br>Live: <a href="https://youtube.com/live/x">YouTube</a>'
        '<ul><li>Dinner</li><li>Kids program</li></ul>';
    final text = icsPlainText(html);
    expect(
      text,
      'Join us for Dua Kumayl\nSpeaker: Sheikh A&B\n\n'
      'Live: YouTube (https://youtube.com/live/x)\n• Dinner\n• Kids program',
    );
    expect(icsLinks('$text and https://center.org/page.'), [
      Uri.parse('https://youtube.com/live/x'),
      Uri.parse('https://center.org/page'),
    ]);
  });
}
