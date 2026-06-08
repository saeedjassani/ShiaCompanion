import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/calendar_page.dart';

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
