import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/pages/prayer_calendar_page.dart';
import 'package:shia_companion/services/prayer_calendar_service.dart';
import 'package:shia_companion/utils/prayer_calendar_plan.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// A calendar in memory: what was added, and what was taken out.
class FakeCalendarBackend implements PrayerCalendarBackend {
  bool access = true;
  bool grant = true;
  bool calendarExists = true;
  List<PrayerCalendarChoice> calendars = const [
    PrayerCalendarChoice(id: 'home', name: 'Home', isPrimary: true),
    PrayerCalendarChoice(id: 'work', name: 'Work', account: 'me@example.com'),
  ];

  final Map<String, ({String calendar, String title, DateTime start})> events =
      {};
  int created = 0;
  int deleted = 0;
  int _next = 0;

  Iterable<String> titlesIn(String calendar) => events.values
      .where((event) => event.calendar == calendar)
      .map((event) => event.title);

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<bool> requestAccess() async => access = grant;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<PrayerCalendarChoice>> writableCalendars() async => calendars;

  @override
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    if (!calendarExists) throw const PrayerCalendarMissing();
    expect(end.difference(start), prayerCalendarEventLength);
    final id = 'e${_next++}';
    events[id] = (calendar: calendarId, title: title, start: start);
    created++;
    return id;
  }

  @override
  Future<void> deleteEvent(String id) async {
    events.remove(id);
    deleted++;
  }
}

void main() {
  final service = PrayerCalendarService.instance;
  const home = PrayerCalendarChoice(id: 'home', name: 'Home');
  const work = PrayerCalendarChoice(id: 'work', name: 'Work');
  late FakeCalendarBackend backend;
  var now = DateTime(2026, 12, 1, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    backend = FakeCalendarBackend();
    PrayerCalendarService.backend = backend;
    now = DateTime(2026, 12, 1, 9);
    PrayerCalendarService.debugNow = () => now;
    // London.
    lat = 51.5074;
    long = -0.1278;
    city = 'London';
  });

  tearDown(() {
    lat = null;
    long = null;
    city = null;
    PrayerCalendarService.debugNow = DateTime.now;
  });

  group('planPrayerCalendarEvents', () {
    test('lists the ticked times of each day, soonest first', () {
      final planned = planPrayerCalendarEvents(
        prayerTime: getPrayerTimeObject(),
        firstDay: DateTime(2026, 12, 1),
        days: 2,
        timeIds: {'fajr', 'maghrib', 'midnight'},
        latitude: 51.5074,
        longitude: -0.1278,
        titleFor: (name) => 'T:$name',
      );
      expect(planned.map((event) => event.title), [
        'T:Fajr',
        'T:Maghrib',
        'T:Midnight',
        'T:Fajr',
        'T:Maghrib',
        'T:Midnight',
      ]);
      // Halfway from sunset to the next Fajr: before 11:30 pm in London's
      // early winter sunset.
      expect(planned[2].start.day, 1);
      for (var i = 1; i < planned.length; i++) {
        expect(planned[i].start.isAfter(planned[i - 1].start), isTrue);
      }
    });
  });

  group('diffPrayerCalendar', () {
    final today = DateTime(2026, 12, 10);
    PlannedPrayerEvent planned(DateTime start, [String title = 'Fajr']) =>
        PlannedPrayerEvent(name: title, title: title, start: start);
    TrackedPrayerEvent tracked(
      String id,
      DateTime start, [
      String title = 'Fajr',
    ]) => TrackedPrayerEvent(id: id, start: start, title: title);

    test('keeps what is still right and past days, replaces what moved', () {
      final right = DateTime(2026, 12, 10, 6, 10);
      final moved = DateTime(2026, 12, 11, 6, 11);
      final changes = diffPrayerCalendar(
        tracked: [
          tracked('old', DateTime(2026, 12, 2, 6)),
          tracked('past', DateTime(2026, 12, 4, 6)),
          tracked('right', right),
          tracked('moved', moved),
          tracked('copy', right),
        ],
        planned: [planned(right), planned(DateTime(2026, 12, 11, 6, 12))],
        today: today,
      );
      expect(changes.keep.map((event) => event.id), ['past', 'right']);
      expect(changes.delete.map((event) => event.id), ['old', 'moved', 'copy']);
      expect(changes.create.map((event) => event.start), [
        DateTime(2026, 12, 11, 6, 12),
      ]);
    });

    test('a new title is a new event', () {
      final start = DateTime(2026, 12, 10, 6, 10);
      final changes = diffPrayerCalendar(
        tracked: [tracked('en', start)],
        planned: [planned(start, 'فجر')],
        today: today,
      );
      expect(changes.delete, hasLength(1));
      expect(changes.create, hasLength(1));
    });
  });

  group('PrayerCalendarService', () {
    test('fills the chosen calendar with the five prayers', () async {
      expect(service.isOn, isFalse);
      final added = await service.turnOn(home);

      expect(added, defaultPrayerCalendarDays * 5);
      expect(service.isOn, isTrue);
      expect(service.calendarName, 'Home');
      expect(backend.titlesIn('home').toSet(), {
        'Fajr',
        'Zuhr',
        'Asr',
        'Maghrib',
        'Isha',
      });
      expect(service.filledThrough, DateTime(2026, 12, 30));
    });

    test('touches nothing when nothing changed', () async {
      await service.turnOn(home);
      backend.created = 0;
      await service.refresh();
      expect(backend.created, 0);
      expect(backend.deleted, 0);
    });

    test('tops up one day as each day goes by, and drops old ones', () async {
      await service.setDays(7);
      await service.turnOn(home);
      expect(backend.events, hasLength(35));

      now = DateTime(2026, 12, 2, 9);
      backend.created = 0;
      await service.refresh();
      expect(backend.created, 5);
      expect(backend.deleted, 0);
      expect(service.filledThrough, DateTime(2026, 12, 8));

      // Over a week later the first day's times are taken out.
      now = DateTime(2026, 12, 9, 9);
      await service.refresh();
      final firstDay = backend.events.values.where(
        (event) => event.start.isBefore(DateTime(2026, 12, 2)),
      );
      expect(firstDay, isEmpty);
    });

    test('takes an unticked time out, and adds a ticked one', () async {
      await service.setDays(7);
      await service.turnOn(home);
      await service.setTimes({'fajr', 'zuhr', 'asr', 'maghrib', 'sunrise'});
      expect(backend.titlesIn('home').where((t) => t == 'Isha'), isEmpty);
      expect(
        backend.titlesIn('home').where((t) => t == 'Sunrise'),
        hasLength(7),
      );
      expect(backend.events, hasLength(35));
    });

    test('moves the times when the city changes', () async {
      await service.setDays(7);
      await service.turnOn(home);
      final before = backend.events.values.map((e) => e.start).toSet();

      // Karbala.
      lat = 32.6160;
      long = 44.0249;
      await service.refresh();

      expect(backend.events, hasLength(35));
      final after = backend.events.values.map((e) => e.start).toSet();
      expect(after.intersection(before), isEmpty);
    });

    test('moving to another calendar empties the first', () async {
      await service.setDays(7);
      await service.turnOn(home);
      await service.turnOn(work);
      expect(backend.titlesIn('home'), isEmpty);
      expect(backend.titlesIn('work'), hasLength(35));
      expect(service.calendarName, 'Work');
    });

    test('turning off takes out every event it added', () async {
      await service.turnOn(home);
      final removed = await service.turnOff();
      expect(removed, defaultPrayerCalendarDays * 5);
      expect(backend.events, isEmpty);
      expect(service.isOn, isFalse);
    });

    test('refresh asks for nothing when access was taken away', () async {
      await service.turnOn(home);
      backend.access = false;
      lat = 32.6160;
      long = 44.0249;
      backend.created = 0;
      await service.refresh();
      expect(backend.created, 0);
      expect(service.isOn, isTrue);
    });

    test('turns itself off when the calendar is gone', () async {
      await service.setDays(7);
      await service.turnOn(home);
      backend.calendarExists = false;
      now = DateTime(2026, 12, 2, 9);
      await service.refresh();
      expect(service.isOn, isFalse);
      expect(service.lostCalendar, isTrue);
    });
  });

  group('PrayerCalendarPage', () {
    Future<void> pump(WidgetTester tester) async {
      // Tall enough for every row at once.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PrayerCalendarPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('adds the ticked times to the calendar picked', (tester) async {
      await pump(tester);
      expect(find.text('Add to calendar'), findsOneWidget);

      await tester.tap(find.text('1 week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to calendar'));
      await tester.pumpAndSettle();

      // Two calendars: the reader picks.
      expect(find.text('Choose a calendar'), findsOneWidget);
      expect(find.text('me@example.com'), findsOneWidget);
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      expect(backend.titlesIn('work'), hasLength(35));
      expect(find.text('Added 35 prayer times to Work'), findsOneWidget);
      expect(find.text('Remove from calendar'), findsOneWidget);
      expect(find.text('Through 7 December'), findsOneWidget);
    });

    testWidgets('says so when access is refused', (tester) async {
      backend
        ..access = false
        ..grant = false;
      await pump(tester);
      await tester.tap(find.text('Add to calendar'));
      await tester.pumpAndSettle();
      expect(
        find.text("Shia Companion isn't allowed to use your calendar"),
        findsOneWidget,
      );
      expect(service.isOn, isFalse);
    });

    testWidgets('the Calendar page links to it, and says where they are', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CalendarPage.debugNow = () => now;
      addTearDown(() => CalendarPage.debugNow = DateTime.now);
      Future<void> pumpCalendar() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: appNavigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CalendarPage(
              initialEvents: {},
              trackScreenOnInit: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpCalendar();
      expect(find.text('Prayer times in your calendar'), findsOneWidget);
      expect(find.text('Add them to Google or Apple Calendar'), findsOneWidget);

      await service.setDays(7);
      await service.turnOn(home);
      await pumpCalendar();
      expect(find.text('In Home through 7 December'), findsOneWidget);

      await tester.tap(find.text('Prayer times in your calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from calendar'), findsOneWidget);
    });

    testWidgets('asks for a city first when there is none', (tester) async {
      lat = null;
      long = null;
      await pump(tester);
      expect(find.text('Choose city'), findsOneWidget);
      expect(find.text('Add to calendar'), findsNothing);
    });
  });
}
