import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/zikr_reminder.dart';
import 'package:shia_companion/pages/zikr_reminders_page.dart';
import 'package:shia_companion/services/zikr_reminder_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await ZikrReminderService.instance.clearAll();
    items = {'Z1': 'Dua Tawassul', 'Z2': 'Dua Kumail'};
  });

  tearDown(() => items = {});

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ZikrRemindersPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state with no reminders', (tester) async {
    await pump(tester);

    expect(find.text('No reminders yet'), findsOneWidget);
  });

  testWidgets('adding a reminder shows it in the list', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dua Tawassul');
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet'), findsNothing);
    expect(find.text('Dua Tawassul'), findsOneWidget);
    expect(find.textContaining('Tue'), findsOneWidget);
    expect(ZikrReminderService.instance.reminders, hasLength(1));
  });

  testWidgets('toggling the switch updates the stored reminder',
      (tester) async {
    await ZikrReminderService.instance.addReminder(
      title: 'Dua Tawassul',
      daysOfWeek: {DateTime.tuesday},
      mode: ZikrReminderTimeMode.fixedTime,
      hour: 21,
      minute: 0,
    );

    await pump(tester);
    expect(ZikrReminderService.instance.reminders.single.enabled, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(ZikrReminderService.instance.reminders.single.enabled, isFalse);
  });

  testWidgets('deleting a reminder removes it after confirmation',
      (tester) async {
    await ZikrReminderService.instance.addReminder(
      title: 'Dua Tawassul',
      daysOfWeek: {DateTime.tuesday},
      mode: ZikrReminderTimeMode.fixedTime,
      hour: 21,
      minute: 0,
    );

    await pump(tester);
    expect(find.text('Dua Tawassul'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Dua Tawassul'), findsNothing);
    expect(ZikrReminderService.instance.reminders, isEmpty);
  });

  testWidgets('picking a zikr from the library prefills the title',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose from the zikr library'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dua Kumail'));
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextField>(find.byType(TextField).first);
    expect(titleField.controller?.text, 'Dua Kumail');
  });

  group('byId', () {
    test('finds a reminder created earlier by its id', () async {
      final reminder = await ZikrReminderService.instance.addReminder(
        title: 'Dua Tawassul',
        zikrUid: 'Z1',
        daysOfWeek: {DateTime.tuesday},
        mode: ZikrReminderTimeMode.fixedTime,
        hour: 21,
        minute: 0,
      );

      final found = await ZikrReminderService.instance.byId(reminder.id);

      expect(found, isNotNull);
      expect(found!.id, reminder.id);
      expect(found.zikrUid, 'Z1');
    });

    test('returns null for an id that was never created or was deleted',
        () async {
      expect(await ZikrReminderService.instance.byId('nope'), isNull);

      final reminder = await ZikrReminderService.instance.addReminder(
        title: 'Dua Kumail',
        daysOfWeek: {DateTime.thursday},
        mode: ZikrReminderTimeMode.fixedTime,
      );
      await ZikrReminderService.instance.deleteReminder(reminder.id);

      expect(await ZikrReminderService.instance.byId(reminder.id), isNull);
    });
  });
}
