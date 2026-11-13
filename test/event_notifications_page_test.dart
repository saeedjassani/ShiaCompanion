import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/event_notifications_page.dart';
import 'package:shia_companion/services/event_notification_service.dart';
import 'package:shia_companion/utils/event_notification_planning.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  final service = EventNotificationService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: EventNotificationsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('is off until turned on, then saves it', (tester) async {
    await pump(tester);
    expect(service.enabled, isFalse);
    expect(EventNotificationService.iosReservedSlots, 0);

    await tester.tap(find.text('Notify me of events'));
    await tester.pumpAndSettle();

    expect(service.enabled, isTrue);
    expect(SP.prefs.getBool(EventNotificationService.enabledKey), isTrue);
    expect(EventNotificationService.iosReservedSlots, greaterThan(0));
  });

  testWidgets('every kind is on by default; each can be turned off',
      (tester) async {
    await service.setEnabled(true);
    await pump(tester);
    expect(service.kinds, EventNotificationKind.values.toSet());

    await tester.tap(find.text('Shahadat and days of mourning'));
    await tester.pumpAndSettle();
    expect(service.kinds,
        {EventNotificationKind.celebration, EventNotificationKind.other});

    await tester.tap(find.text('Wiladat and Eids'));
    await tester.tap(find.text('Other days'));
    await tester.pumpAndSettle();
    expect(service.kinds, isEmpty);
    expect(find.text('Choose at least one kind of event'), findsOneWidget);
  });

  testWidgets('offers no choice of when: Maghrib on the eve', (tester) async {
    await pump(tester);

    expect(
        find.text('At Maghrib the evening before, when the Islamic day begins'),
        findsOneWidget);
    expect(find.textContaining('they come at 8:00 pm'), findsOneWidget);
  });

  group('eventMaghrib', () {
    tearDown(() {
      lat = null;
      long = null;
    });

    test('is 8:00 pm without a location', () {
      lat = null;
      long = null;
      expect(EventNotificationService.eventMaghrib(DateTime(2026, 12, 7)),
          DateTime(2026, 12, 7, 20));
    });

    test("is that evening's Maghrib where the reader is", () {
      // Accra, on UTC like the test machine's clock (times come out on the
      // device's): Maghrib is around 6 pm all year.
      lat = 5.6;
      long = -0.2;
      final maghrib =
          EventNotificationService.eventMaghrib(DateTime(2026, 12, 7));
      expect(DateTime(maghrib.year, maghrib.month, maghrib.day),
          DateTime(2026, 12, 7));
      expect(maghrib.hour, inInclusiveRange(17, 18));
    });
  });
}
