import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/islamic_calendar_widget_data.dart';

void main() {
  group('widgetEventTitle', () {
    test('drops the trailing hijri year', () {
      expect(
        widgetEventTitle(
          'Birth of Imam Mohammad Baqir(a.s.) – the 5th Holy Imam ‐ (57 A.H.)',
        ),
        'Birth of Imam Mohammad Baqir(a.s.) – the 5th Holy Imam',
      );
      expect(
        widgetEventTitle('Battle of Siffin started – (36‐37 A.H.)'),
        'Battle of Siffin started',
      );
      expect(widgetEventTitle('Eid e Mubahila - 9 A.H.'), 'Eid e Mubahila');
    });

    test('keeps only the first line of a paragraph', () {
      expect(
        widgetEventTitle(
          'Demolition of Jannatul Baqi by Aal e Saud.\n'
          'May Allah (s.w.t.) curse those who harmed the Ahlul Bayt (a.s.).',
        ),
        'Demolition of Jannatul Baqi by Aal e Saud.',
      );
    });

    test('joins separate events on the same day', () {
      expect(
        widgetEventTitle(
          'Conquest of Makkah ‐ (8 A.H.)\n\n\n'
          'Evening ‐ Probable night of Shab‐e‐Qadr ‐ the night of power',
        ),
        'Conquest of Makkah · '
        'Evening ‐ Probable night of Shab‐e‐Qadr ‐ the night of power',
      );
    });

    test('leaves a title with no year alone', () {
      expect(widgetEventTitle('Eid ul Azha'), 'Eid ul Azha');
    });
  });

  group('calendar snapshot', () {
    // 2026-09-26 is 15 Rabi' al-Thani 1448 in the Umm al-Qura calendar.
    final now = DateTime(2026, 9, 26, 15, 30);
    final events = <String, dynamic>{
      '15-4': {
        'header': '15th Rabi ul-Aakhar',
        'content': 'Today event - 64 A.H.',
        'color': 1,
      },
      '18-4': {
        'header': '18th Rabi ul-Aakhar',
        'content': 'Three days on',
        'color': 1,
      },
      '8-5': {
        'header': '8th Jamadi ul-Awwal',
        'content': 'Later this year',
        'color': 0,
      },
      '10-1': {'content': 'Ashoora'},
    };

    test('publishes one day per entry from local midnight', () {
      final days = buildCalendarWidgetDays(
        now: now,
        events: events,
        offsetDays: 0,
        dayCount: 4,
      );

      expect(days, hasLength(4));
      expect(days.first['start'], DateTime(2026, 9, 26).millisecondsSinceEpoch);
      expect(days[1]['start'], DateTime(2026, 9, 27).millisecondsSinceEpoch);
      expect(days.first['day'], 15);
      expect(days.first['month'], "Rabi' Al-Thani");
      expect(days.first['monthShort'], 'Rab II');
      expect(days.first['year'], 1448);
      expect(days.first['event'], 'Today event');
      expect(days.first['color'], 1);
      expect(days[1]['event'], '');
      expect(days[1]['color'], -1);
    });

    test('applies the hijri date adjustment', () {
      final days = buildCalendarWidgetDays(
        now: now,
        events: events,
        offsetDays: 3,
        dayCount: 1,
      );

      expect(days.single['day'], 18);
      expect(days.single['event'], 'Three days on');
    });

    test('lists upcoming events soonest first, today included', () {
      final upcoming = buildUpcomingCalendarWidgetEvents(
        now: now,
        events: events,
        offsetDays: 0,
        limit: 3,
      );

      expect(upcoming.map((e) => e['title']), [
        'Today event',
        'Three days on',
        'Later this year',
      ]);
      expect(upcoming[1]['hijri'], "18 Rabi' Al-Thani");
      expect(
          upcoming[1]['start'], DateTime(2026, 9, 29).millisecondsSinceEpoch);
      expect(upcoming[2]['color'], 0);
    });

    test('an event with no colour publishes -1', () {
      final upcoming = buildUpcomingCalendarWidgetEvents(
        now: now,
        events: events,
        offsetDays: 0,
      );

      final ashoora = upcoming.firstWhere((e) => e['title'] == 'Ashoora');
      expect(ashoora['color'], -1);
    });

    test('the service snapshot carries days, events and the calendar link', () {
      final snapshot = HomeScreenWidgetService.instance.buildCalendarSnapshot(
        now: now,
        events: events,
        hijriOffsetDays: 0,
      );

      expect(snapshot[HomeScreenWidgetService.calendarTitleKey],
          'Islamic Calendar');
      expect(snapshot[HomeScreenWidgetService.calendarUrlKey],
          'https://shia-companion.web.app/calendar');
      final days =
          jsonDecode(snapshot[HomeScreenWidgetService.calendarDaysKey]!)
              as List;
      expect(days, hasLength(calendarWidgetDayCount));
      final upcoming =
          jsonDecode(snapshot[HomeScreenWidgetService.calendarEventsKey]!)
              as List;
      expect(upcoming.first['title'], 'Today event');
    });
  });
}
