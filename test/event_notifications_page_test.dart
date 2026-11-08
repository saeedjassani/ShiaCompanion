import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('the day before moves a default time to the evening',
      (tester) async {
    await service.setEnabled(true);
    await pump(tester);
    expect(find.text('9:00 am'), findsOneWidget);

    await tester.tap(find.text('The day before'));
    await tester.pumpAndSettle();
    expect(service.dayBefore, isTrue);
    expect(
        service.timeMinutes, EventNotificationService.defaultDayBeforeMinutes);
    expect(find.text('8:00 pm'), findsOneWidget);

    // A time the reader chose stays put.
    await service.setTimeMinutes(19 * 60 + 30);
    await tester.tap(find.text('On the day'));
    await tester.pumpAndSettle();
    expect(service.dayBefore, isFalse);
    expect(service.timeMinutes, 19 * 60 + 30);
  });
}
