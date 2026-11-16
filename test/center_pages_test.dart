import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart' as app;
import 'package:shia_companion/models/islamic_center.dart';
import 'package:shia_companion/pages/centers/center_directory_page.dart';
import 'package:shia_companion/pages/centers/center_programs_page.dart';
import 'package:shia_companion/pages/home/center_card.dart';
import 'package:shia_companion/services/islamic_center_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';

const _houston = IslamicCenter(
  id: 'iec-houston',
  name: 'Islamic Education Center',
  calendar: 'iec@group.calendar.google.com',
  city: 'Houston, TX',
  latitude: 29.7604,
  longitude: -95.3698,
  address: '8715 Chimney Rock Rd, Houston, TX',
);

const _dallas = IslamicCenter(
  id: 'dallas',
  name: 'Dallas Center',
  calendar: 'https://example.org/dallas.ics',
  city: 'Dallas, TX',
  latitude: 32.7767,
  longitude: -96.7970,
);

/// A programme two days from now and one in a week, in UTC, so the test
/// reads the same in any time zone.
String _feed(DateTime now) {
  String at(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}T'
      '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}00Z';
  final soon = DateTime.utc(now.year, now.month, now.day + 2, 18);
  final later = DateTime.utc(now.year, now.month, now.day + 7, 18);
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    'DTSTART:${at(soon)}',
    'DTEND:${at(soon.add(const Duration(hours: 2)))}',
    'UID:a',
    'SUMMARY:Majlis of Imam Husayn (a.s.)',
    'LOCATION:Main Hall',
    'DESCRIPTION:Speaker: Sheikh A<br>Live: <a href="https://youtube.com/live/x">YouTube</a>',
    'END:VEVENT',
    'BEGIN:VEVENT',
    'DTSTART:${at(later)}',
    'UID:b',
    'SUMMARY:Youth class',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}

IslamicCenterService _service() => IslamicCenterService(
      directoryLoader: () async => [_houston, _dallas],
      feedLoader: (_) async => _feed(DateTime.now()),
    );

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  // Let a refresh the page starts (parsed on another isolate) finish.
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(ensureTimeZoneDatabaseInitialized);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    app.lat = null;
    app.long = null;
  });

  testWidgets('Programs: invites the reader to find a centre', (tester) async {
    await _pump(tester, CenterProgramsPage(service: _service()));
    expect(find.text('Follow your Islamic center'), findsOneWidget);
    await tester.tap(find.text('Find a center'));
    await tester.pumpAndSettle();
    expect(find.text('Islamic Centers'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Programs: lists the followed centre\'s programmes by day',
      (tester) async {
    final service = _service();
    await tester.runAsync(() => service.follow(_houston));
    await _pump(tester, CenterProgramsPage(service: service));

    expect(find.text('Islamic Education Center'), findsOneWidget);
    expect(find.text('Majlis of Imam Husayn (a.s.)'), findsOneWidget);
    expect(find.text('Youth class'), findsOneWidget);
    expect(find.text('Updated just now'), findsOneWidget);

    await tester.tap(find.text('Majlis of Imam Husayn (a.s.)'));
    await tester.pumpAndSettle();
    expect(find.text('Directions'), findsOneWidget);
    expect(find.text('Main Hall'), findsWidgets);
    expect(find.textContaining('Speaker: Sheikh A'), findsOneWidget);
    expect(find.text('youtube.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Programs: says when a calendar is not public', (tester) async {
    final service = IslamicCenterService(
      directoryLoader: () async => const [],
      feedLoader: (_) async => '<html>Sign in</html>',
    );
    await tester.runAsync(() => service.follow(_houston));
    await _pump(tester, CenterProgramsPage(service: service));
    expect(find.textContaining("calendar isn't public"), findsOneWidget);
    expect(find.text('No programs coming up'), findsOneWidget);
  });

  testWidgets('Directory: nearest first, follow and unfollow', (tester) async {
    app.lat = 29.62;
    app.long = -95.63;
    final service = _service();
    await tester.runAsync(service.loadDirectory);
    await _pump(tester, CenterDirectoryPage(service: service));

    expect(find.text('NEAR YOU'), findsOneWidget);
    final houston = tester.getTopLeft(find.text('Islamic Education Center'));
    final dallas = tester.getTopLeft(find.text('Dallas Center'));
    expect(houston.dy, lessThan(dallas.dy));
    expect(find.textContaining('km away'), findsNWidgets(2));

    await tester.runAsync(() async {
      await tester.tap(find.text('Follow').first);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(service.isFollowing(_houston.id), isTrue);
    expect(find.text('FOLLOWING'), findsOneWidget);

    await tester.tap(find.text('Unfollow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfollow').last);
    await tester.pumpAndSettle();
    expect(service.followed, isEmpty);
  });

  testWidgets('Directory: adds a centre by its calendar link', (tester) async {
    final service = _service();
    await _pump(tester, CenterDirectoryPage(service: service));
    await tester.ensureVisible(find.text('Add a calendar by link'));
    await tester.tap(find.text('Add a calendar by link'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'My Center');
    await tester.enterText(find.byType(TextField).at(1), 'not a link');
    await tester.pump();
    // Don't suggest: no Firebase here.
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pump();
    expect(find.text("That isn't a calendar link the app can read."),
        findsOneWidget);

    await tester.enterText(
        find.byType(TextField).at(1), 'mycenter@group.calendar.google.com');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(service.followed.single.name, 'My Center');
    expect(service.followed.single.isCustom, isTrue);
  });

  testWidgets('Home: suggests the nearby centre, and Not now puts it away',
      (tester) async {
    app.lat = 29.62;
    app.long = -95.63;
    final service = _service();
    await tester.runAsync(service.loadDirectory);
    await _pump(
      tester,
      Scaffold(
        body: HomeCenterCard(
            topSpacing: 0, onOpenPrograms: () {}, service: service),
      ),
    );
    expect(find.text('Programs at Islamic Education Center'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Programs at Islamic Education Center'), findsNothing);
  });

  testWidgets('Home: shows the next programmes at the reader\'s centre',
      (tester) async {
    final service = _service();
    await tester.runAsync(() => service.follow(_houston));
    var opened = false;
    await _pump(
      tester,
      Scaffold(
        body: HomeCenterCard(
            topSpacing: 0,
            onOpenPrograms: () => opened = true,
            service: service),
      ),
    );
    expect(find.text('Islamic Education Center'), findsOneWidget);
    expect(find.text('Majlis of Imam Husayn (a.s.)'), findsOneWidget);
    expect(find.text('Youth class'), findsOneWidget);
    await tester.tap(find.text('See all'));
    expect(opened, isTrue);
  });

  testWidgets('Home: nothing without a centre nearby', (tester) async {
    final service = _service();
    await tester.runAsync(service.loadDirectory);
    await _pump(
      tester,
      Scaffold(
        body: HomeCenterCard(
            topSpacing: 0, onOpenPrograms: () {}, service: service),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
