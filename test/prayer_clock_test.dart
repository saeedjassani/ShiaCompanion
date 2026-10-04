import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/prayer_clock.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';
import 'package:shia_companion/utils/zikr_reminder_scheduling.dart';
import 'package:shia_companion/widgets/prayer_times_card.dart';
import 'package:timezone/timezone.dart' as tz;

/// Prayer times for a city chosen in another time zone are told on that
/// city's clock. The suite runs in whatever zone the machine is in, so the
/// city is one whose clock is sure to read differently from it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 22:30 UTC on Sunday 4 October 2026: 01:30 on Monday the 5th in Karbala,
  // before its Fajr. (Karachi, used instead on a machine already on
  // Baghdad's clock, is 03:30 then, also before Fajr.)
  final moment = DateTime.utc(2026, 10, 4, 22, 30);
  final onBaghdadClock =
      moment.toLocal().timeZoneOffset == const Duration(hours: 3);
  final zone = onBaghdadClock ? 'Asia/Karachi' : 'Asia/Baghdad';
  final place = onBaghdadClock ? 'Karachi' : 'Karbala';
  final latitude = onBaghdadClock ? 24.86 : 32.62;
  final longitude = onBaghdadClock ? 67.01 : 44.03;
  final cityOffset = Duration(hours: onBaghdadClock ? 5 : 3);

  setUpAll(ensureTimeZoneDatabaseInitialized);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    PrayerClock.resetForTest();
    lat = latitude;
    long = longitude;
    city = place;
  });

  tearDown(PrayerClock.resetForTest);

  String expectedDescription() {
    final difference = cityOffset - moment.toLocal().timeZoneOffset;
    final minutes = difference.inMinutes.abs();
    final amount = [
      if (minutes >= 60) '${minutes ~/ 60} hr',
      if (minutes % 60 != 0) '${minutes % 60} min',
    ].join(' ');
    return difference.isNegative
        ? '$place time, $amount behind your phone'
        : '$place time, $amount ahead of your phone';
  }

  group('the clock', () {
    test('follows the phone until a city is chosen', () {
      expect(PrayerClock.zone, isNull);
      expect(PrayerClock.now(moment), same(moment));
      expect(PrayerClock.day(2026, 10, 5), DateTime(2026, 10, 5));
      expect(PrayerClock.label(moment), isNull);
    });

    test('is the chosen city\'s, and says so', () async {
      expect(await PrayerClock.use(zone, place: place), isTrue);

      final now = PrayerClock.now(moment);
      expect(now, isA<tz.TZDateTime>());
      expect(now.isAtSameMomentAs(moment), isTrue);
      expect(now.timeZoneOffset, cityOffset);
      // Today is the city's: already Monday there.
      expect(now.day, 5);
      expect(PrayerClock.label(moment), '$place time');
      expect(PrayerClock.describe(moment), expectedDescription());
      // Asked about a moment already on the city's clock, as the card does:
      // compared with the phone's clock all the same, not the timezone
      // package's idea of local (UTC unless something set it - here, set to
      // somewhere neither the machine nor the city is).
      final packageLocal = tz.local;
      addTearDown(() => tz.setLocalLocation(packageLocal));
      tz.setLocalLocation(tz.getLocation('Pacific/Kiritimati'));
      expect(PrayerClock.describe(now), expectedDescription());
      expect(
        PrayerClock.describe(tz.TZDateTime.from(moment, tz.UTC)),
        expectedDescription(),
      );

      expect(await PrayerClock.use(zone, place: place), isFalse);
    });

    test('says nothing when the city reads the same as the phone', () async {
      // Any zone on the machine's own offset that day.
      final local = moment.toLocal().timeZoneOffset;
      final same = tz.timeZoneDatabase.locations.values.firstWhere(
        (location) =>
            tz.TZDateTime.from(moment, location).timeZoneOffset == local,
      );
      await PrayerClock.use(same.name, place: 'Elsewhere');

      expect(PrayerClock.zone, isNotNull);
      expect(PrayerClock.label(moment), isNull);
      expect(PrayerClock.describe(moment), isNull);
    });

    test('an unknown zone keeps the phone\'s clock', () async {
      await PrayerClock.use(zone, place: place);
      await PrayerClock.use('Nowhere/Nothing', place: 'Nowhere');
      expect(PrayerClock.zone, isNull);

      await PrayerClock.use('', place: 'Nowhere');
      expect(PrayerClock.zone, isNull);
    });

    test('is restored after a restart', () async {
      await PrayerClock.use(zone, place: place);
      PrayerClock.resetForTest();

      PrayerClock.restore();
      expect(PrayerClock.zone?.name, zone);
      expect(PrayerClock.label(moment), '$place time');

      await PrayerClock.usePhoneClock();
      PrayerClock.restore();
      expect(PrayerClock.zone, isNull);
    });
  });

  test('dates built from a city\'s date stay on its clock', () {
    final location = tz.getLocation(zone);
    final start = tz.TZDateTime(location, 2026, 10, 31);

    final next = calendarDayFrom(start, 1);
    expect(next, isA<tz.TZDateTime>());
    expect((next as tz.TZDateTime).location, location);
    expect([next.year, next.month, next.day, next.hour], [2026, 11, 1, 0]);

    final fajr = dateTimeForTime24(next, '04:52')!;
    expect(
        fajr.isAtSameMomentAs(
            DateTime.utc(2026, 11, 1, 4, 52).subtract(cityOffset)),
        isTrue);
  });

  test('the next prayers are the city\'s, written on its clock', () async {
    final onPhoneClock = nextWidgetPrayerTimeReadings(
      prayerTime: getPrayerTimeObject(),
      latitude: latitude,
      longitude: longitude,
      count: 5,
      now: moment,
      times: defaultWidgetPrayerTimeSelection,
    );
    await PrayerClock.use(zone, place: place);
    final readings = nextWidgetPrayerTimeReadings(
      prayerTime: getPrayerTimeObject(),
      latitude: latitude,
      longitude: longitude,
      count: 5,
      times: defaultWidgetPrayerTimeSelection,
      now: PrayerClock.now(moment),
    );

    // The same moments...
    expect(
      [for (final r in readings) r.dateTime.millisecondsSinceEpoch],
      [for (final r in onPhoneClock) r.dateTime.millisecondsSinceEpoch],
    );
    // ...told on the city's clock: Fajr before dawn there, not hours off.
    expect(readings.first.time.id, 'fajr');
    for (final reading in readings) {
      expect(reading.dateTime.timeZoneOffset, cityOffset);
      expect(reading.displayTime, formatPrayerDateTime12(reading.dateTime));
    }
    expect(readings.first.dateTime.hour, inInclusiveRange(4, 5));
  });

  group('notifications', () {
    test('fire at the city\'s prayer times, titled on its clock', () async {
      await PrayerClock.use(zone, place: place);
      final entries = buildPrayerNotificationEntriesForDay(
        prayerTime: getPrayerTimeObject(),
        date: PrayerClock.day(2026, 10, 5),
        latitude: latitude,
        longitude: longitude,
      );

      final fajr = entries.first;
      expect(fajr.name, 'Fajr');
      expect(fajr.dateTime.hour, inInclusiveRange(4, 5));
      expect(fajr.dateTime.isAfter(moment), isTrue);
      expect(
        prayerNotificationTitle(fajr.dateTime, 'Fajr'),
        matches(RegExp('^0[45]:\\d\\d AM $place time : Fajr\$')),
      );
      expect(entries.last.name, 'Midnight');
      expect(entries.last.dateTime.timeZoneOffset, cityOffset);
    });

    test('keep the plain title on the phone\'s clock', () {
      expect(
        prayerNotificationTitle(DateTime(2026, 10, 5, 4, 41), 'Fajr'),
        '04:41 AM : Fajr',
      );
    });

    test('are rebuilt when the clock changes', () async {
      final date = PrayerClock.now(moment);
      final onPhoneClock =
          buildPrayerNotificationScheduleFingerprint(scheduleDate: date);
      expect(onPhoneClock, isNot(contains('clock:')));

      await PrayerClock.use(zone, place: place);
      final onCityClock = buildPrayerNotificationScheduleFingerprint(
          scheduleDate: PrayerClock.now(moment));
      expect(onCityClock, contains('clock:$zone'));
      expect(onCityClock, isNot(onPhoneClock));
    });

    test('prayer-relative reminders keep to the city\'s weekdays', () async {
      await PrayerClock.use(zone, place: place);
      final occurrences = upcomingPrayerRelativeOccurrences(
        prayerTime: getPrayerTimeObject(),
        now: PrayerClock.now(moment),
        weekday: DateTime.monday,
        prayerName: 'Fajr',
        offsetMinutes: 10,
        latitude: latitude,
        longitude: longitude,
        count: 2,
      );

      expect(occurrences, hasLength(2));
      for (final occurrence in occurrences) {
        expect(occurrence.timeZoneOffset, cityOffset);
        expect(occurrence.weekday, DateTime.monday);
        expect(occurrence.hour, inInclusiveRange(4, 5));
      }
      // This very Monday's, a few hours from now there.
      expect(occurrences.first.day, 5);
    });
  });

  test('widgets name the clock their times are on', () async {
    await PrayerClock.use(zone, place: place);
    final snapshot = HomeScreenWidgetService.instance
        .buildDailyPrayerTimesSnapshot(now: moment);

    expect(snapshot[HomeScreenWidgetService.prayerLocationKey], '$place time');
    expect(snapshot[HomeScreenWidgetService.dailyPrayerNameKeys.first], 'Fajr');
    expect(
      snapshot[HomeScreenWidgetService.dailyPrayerTimeKeys.first],
      matches(RegExp(r'^0?[45]:\d\d am$')),
    );

    await PrayerClock.usePhoneClock();
    expect(
      HomeScreenWidgetService.instance.buildDailyPrayerTimesSnapshot(
          now: moment)[HomeScreenWidgetService.prayerLocationKey],
      place,
    );
  });

  testWidgets('the calendar\'s times are the city\'s, and say whose',
      (tester) async {
    await PrayerClock.use(zone, place: place);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrayerTimesCard(date: DateTime(2026, 10, 5), compact: true),
        ),
      ),
    ));

    final day = PrayerClock.day(2026, 10, 5);
    final fajr = buildPrayerNotificationEntriesForDay(
      prayerTime: getPrayerTimeObject(),
      date: day,
      latitude: latitude,
      longitude: longitude,
    ).first;
    expect(find.text(PrayerClock.describe(day)!), findsOneWidget);
    expect(find.text(formatPrayerDateTime12(fajr.dateTime)), findsOneWidget);
  });
}
