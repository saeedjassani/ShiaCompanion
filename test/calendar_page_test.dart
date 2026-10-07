import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    hijriDate = 0;
    lat = null;
    long = null;
    city = null;
    CalendarPage.debugNow = () => DateTime(2026, 7, 1, 12);
  });

  tearDown(() => CalendarPage.debugNow = DateTime.now);

  for (final brightness in Brightness.values) {
    for (final size in const [
      Size(393, 852),
      Size(820, 1180),
      Size(1440, 900),
    ]) {
      testWidgets(
          'lays out without overflowing: ${brightness.name}, '
          '${size.width.toInt()} wide', (tester) async {
        lat = 51.5074;
        long = -0.1278;
        await _pumpCalendar(tester,
            brightness: brightness,
            size: size,
            events: _markerTestEvents(0));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shows muted days from the months either side', (tester) async {
    await _pumpCalendar(tester);

    expect(find.text('28'), findsNWidgets(2));
  });

  testWidgets('a tapped day becomes the day shown, prayer times and all',
      (tester) async {
    lat = 21.4225;
    long = 39.8262;
    await _pumpCalendar(tester);

    expect(find.text('Wednesday 1 July'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(find.text('Friday 10 July'), findsOneWidget);
    expect(find.text('In 9 days'), findsOneWidget);
    // Picked away from today, the Today button comes back.
    expect(find.widgetWithText(OutlinedButton, 'Today'), findsOneWidget);
    expect(find.text('Times for 10 July somewhere else, e.g. Karbala'),
        findsOneWidget);
  });

  testWidgets('the arrows change month and Today comes back to it',
      (tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('July 2026'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Today'), findsNothing);
  });

  testWidgets('the phone card has a glyph for each of the eight times',
      (tester) async {
    lat = 21.4225;
    long = 39.8262;
    await _pumpCalendar(tester);

    final glyphs = tester.widgetList<PrayerGlyph>(find.byType(PrayerGlyph));
    expect(glyphs.map((glyph) => prayerGlyphTypeFor(glyph.name)).toSet(), {
      PrayerGlyphType.fajr,
      PrayerGlyphType.sunrise,
      PrayerGlyphType.zuhr,
      PrayerGlyphType.asr,
      PrayerGlyphType.sunset,
      PrayerGlyphType.maghrib,
      PrayerGlyphType.isha,
      PrayerGlyphType.midnight,
    });
    expect(find.text('Times on Home'), findsOneWidget);
    expect(find.text('5 shown'), findsOneWidget);
  });

  testWidgets('with no location the card offers a city instead',
      (tester) async {
    await _pumpCalendar(tester);

    expect(find.text('Choose city'), findsOneWidget);
    expect(find.byType(PrayerGlyph), findsNothing);
  });

  testWidgets("offers another city's times for the day picked",
      (tester) async {
    CityRepository.instance.seedForTesting(const []);
    await _pumpCalendar(tester);

    final link = find.text('Prayer times in another city');
    await tester.scrollUntilVisible(link, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(link);
    await tester.pumpAndSettle();

    // The picker, for looking only: no way to move the location from here.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Use my current location'), findsNothing);
  });

  testWidgets('colours mourning days green and days of joy red',
      (tester) async {
    // events.json numbers its two colours 0 and 1; the day cell has to keep
    // reading them the way the data has always meant them (H. Karmali's
    // calendar: green for mourning, red for joy).
    for (final (color, tint) in const [
      (0, Color(0xFFE1EFE4)),
      (1, Color(0xFFF9E2DE)),
    ]) {
      await _pumpCalendar(tester,
          initialDate: DateTime(2026, 6, 22), events: _markerTestEvents(color));
      expect(_cellColor(tester, DateTime(2026, 6, 24)), tint);
      expect(_cellColor(tester, DateTime(2026, 6, 23)), Colors.transparent);
    }
  });

  testWidgets('the picked day writes its event out in full', (tester) async {
    await _pumpCalendar(tester,
        initialDate: DateTime(2026, 6, 22), events: _eventSummaryTestEvents);

    expect(find.text('7th Moharram'), findsNothing);
    expect(find.textContaining('Access to water was blocked'), findsOneWidget);
  });

  testWidgets('wide layouts name each event in its day and list the times',
      (tester) async {
    lat = 51.5074;
    long = -0.1278;
    await _pumpCalendar(tester,
        size: const Size(1440, 900),
        initialDate: DateTime(2026, 6, 22),
        events: _markerTestEvents(1));

    expect(find.text('Shab e Ashoor'), findsOneWidget);
    for (final name in ['Fajr', 'Sunrise', 'Midnight']) {
      expect(find.text(name), findsOneWidget);
    }
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = const Size(393, 852),
  DateTime? initialDate,
  Map<String, dynamic> events = const <String, dynamic>{},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: CalendarPage(
        key: ValueKey((initialDate, events)),
        initialDate: initialDate,
        initialEvents: events,
        trackScreenOnInit: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _eventSummaryTestEvents = <String, dynamic>{
  '01-07': <String, dynamic>{
    'content':
        'Access to water was blocked from the camp of Imam Hussain(a.s.) - the 3rd Holy Imam - (61 A.H.)',
    'color': 0,
  },
};

/// A single event a couple of days after the picked one, so the day it
/// lands on keeps its own colour instead of the selection's.
Map<String, dynamic> _markerTestEvents(int color) => <String, dynamic>{
      '01-09': <String, dynamic>{
        'content': 'Shab e Ashoor',
        'color': color,
      },
    };

Color? _cellColor(WidgetTester tester, DateTime day) => tester
    .widget<Material>(
        find.byKey(ValueKey('calendar-day-${day.year}-${day.month}-${day.day}')))
    .color;
