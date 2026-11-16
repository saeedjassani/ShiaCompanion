import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/islamic_center.dart';
import 'package:shia_companion/services/islamic_center_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

const _houston = IslamicCenter(
  id: 'iec-houston',
  name: 'Islamic Education Center',
  calendar: 'iec@group.calendar.google.com',
  city: 'Houston, TX',
  latitude: 29.7604,
  longitude: -95.3698,
);

const _dallas = IslamicCenter(
  id: 'dallas',
  name: 'Dallas Center',
  calendar: 'https://example.org/dallas.ics',
  city: 'Dallas, TX',
  latitude: 32.7767,
  longitude: -96.7970,
);

const _noCoordinates = IslamicCenter(
  id: 'nowhere',
  name: 'Another Center',
  calendar: 'x@group.calendar.google.com',
);

String _feed(String events) => [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'X-WR-TIMEZONE:America/Chicago',
      events.trim(),
      'END:VCALENDAR',
    ].join('\r\n');

void main() {
  group('calendarFeedUrl', () {
    const id = 'c_abc123@group.calendar.google.com';
    final feed = Uri.parse('https://calendar.google.com/calendar/ical/'
        'c_abc123%40group.calendar.google.com/public/basic.ics');

    test('a bare calendar ID', () {
      expect(calendarFeedUrl(id), feed);
      expect(calendarFeedUrl('  $id\n'), feed);
      expect(calendarFeedUrl('center@gmail.com').toString(),
          contains('center%40gmail.com'));
    });

    test('Google embed and share links', () {
      expect(
          calendarFeedUrl('https://calendar.google.com/calendar/embed?'
              'src=${Uri.encodeComponent(id)}&ctz=America%2FChicago'),
          feed);
      final cid = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
      expect(
          calendarFeedUrl('https://calendar.google.com/calendar/u/0?cid=$cid'),
          feed);
      expect(
          calendarFeedUrl(
              'https://calendar.google.com/calendar/r?cid=${Uri.encodeComponent(id)}'),
          feed);
    });

    test('feed addresses pass through, webcal becomes https', () {
      expect(calendarFeedUrl(feed.toString()), feed);
      expect(calendarFeedUrl('webcal://example.org/center.ics'),
          Uri.parse('https://example.org/center.ics'));
      expect(calendarFeedUrl('https://outlook.office365.com/owa/calendar/x/'
              'reachcalendar.ics')
          ?.host,
          'outlook.office365.com');
    });

    test('anything else is not a calendar', () {
      expect(calendarFeedUrl(''), isNull);
      expect(calendarFeedUrl('Islamic Center of Houston'), isNull);
      expect(calendarFeedUrl('ftp://example.org/x.ics'), isNull);
      expect(calendarFeedUrl('https://calendar.google.com/calendar/u/0/r'),
          isNull);
    });
  });

  test('IslamicCenter JSON round trip, and bad rows are skipped', () {
    expect(IslamicCenter.fromJson(_houston.toJson()), _houston);
    expect(
      IslamicCenterService.centersFromDirectoryDoc({
        'centers': [
          _dallas.toJson(),
          {'id': 'x', 'name': 'No calendar'},
          'junk',
          _houston.toJson(),
        ],
      }),
      [_dallas, _houston],
    );
    expect(IslamicCenterService.centersFromDirectoryDoc(null), isEmpty);
  });

  test('newDirectoryId', () {
    expect(IslamicCenterService.newDirectoryId('Islamic Center of Houston!', []),
        'islamic-center-of-houston');
    expect(
        IslamicCenterService.newDirectoryId(
            'Dallas Center', ['dallas-center', 'dallas-center-2']),
        'dallas-center-3');
    expect(IslamicCenterService.newDirectoryId('مرکز', []), 'center');
  });

  group('IslamicCenterService', () {
    final now = DateTime.utc(2026, 11, 16, 18); // Mon 16 Nov, noon Chicago
    late List<Uri> fetched;
    late String body;

    IslamicCenterService make({List<IslamicCenter>? directory}) =>
        IslamicCenterService(
          clock: () => now,
          directoryLoader: () async => directory ?? [_houston, _dallas],
          feedLoader: (url) async {
            fetched.add(url);
            return body;
          },
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      fetched = [];
      body = _feed('''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261015T200000
DTEND;TZID=America/Chicago:20261015T213000
RRULE:FREQ=WEEKLY;BYDAY=TH
UID:kumayl
SUMMARY:Dua Kumayl
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261116T110000
DTEND;TZID=America/Chicago:20261116T113000
UID:over
SUMMARY:Already over
END:VEVENT
''');
    });

    test('suggests the nearest centre within reach, until dismissed',
        () async {
      final service = make(directory: [_houston, _dallas, _noCoordinates]);
      await service.loadDirectory();
      // Sugar Land, ~30 km from Houston.
      final suggestion =
          service.suggestion(latitude: 29.6197, longitude: -95.6349);
      expect(suggestion?.$1, _houston);
      expect(suggestion!.$2, closeTo(28, 4));
      // Austin: both over 50 km away.
      expect(service.suggestion(latitude: 30.2672, longitude: -97.7431),
          isNull);
      await service.dismissSuggestion();
      expect(service.suggestion(latitude: 29.6197, longitude: -95.6349),
          isNull);
      // It stays dismissed after a restart.
      final again = make();
      again.restore();
      expect(again.suggestionDismissed, isTrue);
    });

    test('no suggestion once a centre is followed', () async {
      final service = make();
      await service.loadDirectory();
      await service.follow(_dallas);
      expect(service.suggestion(latitude: 29.76, longitude: -95.37), isNull);
    });

    test('follow fetches, keeps upcoming programmes, and caches them',
        () async {
      final service = make();
      await service.follow(_houston);
      expect(fetched, [_houston.feedUrl]);
      final events = service.upcoming();
      expect(events.first.title, 'Dua Kumayl');
      // Thursday 19 Nov, 8 pm CST.
      expect(events.first.start, DateTime.utc(2026, 11, 20, 2));
      expect(events.every((e) => e.title != 'Already over'), isTrue);
      // Weekly for 60 days.
      expect(events.length, inInclusiveRange(8, 9));
      expect(service.upcoming(limit: 2), hasLength(2));

      // A fresh start reads the cache without fetching.
      final restarted = make();
      restarted.restore();
      expect(restarted.followed, [_houston]);
      expect(restarted.upcoming().length, events.length);
      await restarted.refreshAll();
      expect(fetched, hasLength(1));
      await restarted.refreshAll(force: true);
      expect(fetched, hasLength(2));
    });

    test('a calendar that is not public is reported, not thrown', () async {
      body = '<!DOCTYPE html><html>Sign in</html>';
      final service = make();
      await service.follow(_houston);
      expect(service.errorFor(_houston.id), CenterFeedError.notPublic);
      expect(service.upcoming(), isEmpty);
    });

    test('a link that is not a calendar is reported', () async {
      final service = make();
      await service.follow(const IslamicCenter(
          id: 'custom-1', name: 'Mine', calendar: 'not a link'));
      expect(service.errorFor('custom-1'), CenterFeedError.badLink);
      expect(fetched, isEmpty);
    });

    test('unfollow drops the centre and its programmes', () async {
      final service = make();
      await service.follow(_houston);
      await service.unfollow(_houston.id);
      expect(service.followed, isEmpty);
      expect(service.upcoming(), isEmpty);
      final restarted = make()..restore();
      expect(restarted.followed, isEmpty);
    });

    test('a followed directory centre picks up directory edits', () async {
      final service = make();
      await service.follow(_houston);
      final moved = _houston.copyWith(calendar: 'new@group.calendar.google.com');
      final updated = make(directory: [moved])..restore();
      await updated.loadDirectory();
      expect(updated.followed.single.calendar, moved.calendar);
    });

    test('custom centres get their own ids', () {
      final center = IslamicCenterService.customCenter(
        name: ' My Center ',
        calendar: ' x@group.calendar.google.com ',
        now: DateTime.utc(2026),
      );
      expect(center.isCustom, isTrue);
      expect(center.name, 'My Center');
      expect(center.feedUrl, isNotNull);
    });
  });
}
