import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/widgets/prayer_times_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    hijriDate = 0;
    lat = null;
    long = null;
    city = null;
  });

  testWidgets('calendar does not overflow in dark theme on a phone viewport',
      (tester) async {
    await _pumpCalendar(
      tester,
      brightness: Brightness.dark,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar does not overflow in light theme on a phone viewport',
      (tester) async {
    await _pumpCalendar(
      tester,
      brightness: Brightness.light,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar shows muted days from adjacent months', (tester) async {
    await _pumpCalendar(
      tester,
      brightness: Brightness.dark,
    );

    expect(find.text('28'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapped calendar date stays local for prayer time calculation',
      (tester) async {
    await _pumpCalendar(
      tester,
      brightness: Brightness.dark,
    );

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    final prayerTimesCard =
        tester.widget<PrayerTimesCard>(find.byType(PrayerTimesCard));
    expect(prayerTimesCard.date.isUtc, isFalse);
    expect(prayerTimesCard.date.year, 2026);
    expect(prayerTimesCard.date.month, 7);
    expect(prayerTimesCard.date.day, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar embeds prayer rows with widget prayer icons',
      (tester) async {
    lat = 21.4225;
    long = 39.8262;

    await _pumpCalendar(
      tester,
      brightness: Brightness.dark,
    );

    expect(find.text('Prayer Times'), findsNothing);
    expect(find.byType(PrayerTimesCard), findsOneWidget);
    expect(find.byIcon(Icons.wb_twilight), findsWidgets);
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.byIcon(Icons.brightness_5), findsOneWidget);
    expect(find.byIcon(Icons.wb_twilight_outlined), findsOneWidget);
    expect(find.byIcon(Icons.nights_stay), findsOneWidget);
    expect(find.byIcon(Icons.bedtime), findsOneWidget);
    expect(find.byIcon(Icons.mosque), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected event summary does not repeat the lunar date header',
      (tester) async {
    await _pumpCalendar(
      tester,
      brightness: Brightness.dark,
      initialDate: DateTime(2026, 6, 22),
      events: _eventSummaryTestEvents,
    );

    expect(find.text('7th Moharram'), findsNothing);
    expect(find.textContaining('Access to water was blocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required Brightness brightness,
  DateTime? initialDate,
  Map<String, dynamic> events = const <String, dynamic>{},
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Calendar')),
        body: CalendarPage(
          key: ValueKey(initialDate ?? _calendarTestDate),
          initialDate: initialDate ?? _calendarTestDate,
          initialEvents: events,
          trackScreenOnInit: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _calendarTestDate = DateTime(2026, 7, 1);

const _eventSummaryTestEvents = <String, dynamic>{
  '7-1': <String, dynamic>{
    'header': '7th Moharram',
    'content':
        'Access to water was blocked from the camp of Imam Hussain(a.s.) - the 3rd Holy Imam - (61 A.H.)',
    'color': 0,
  },
};
