import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/widgets/app_toast.dart';

void main() {
  Future<void> host(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        navigatorKey: appNavigatorKey,
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: SizedBox()),
      ));

  testWidgets('shows a message and takes it down after its time',
      (tester) async {
    await host(tester);
    showToast('Saved for offline');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved for offline'), findsOneWidget);

    await tester.pump(toastDuration);
    await tester.pumpAndSettle();
    expect(find.text('Saved for offline'), findsNothing);
  });

  testWidgets('a new toast takes the place of the one on screen',
      (tester) async {
    await host(tester);
    showToast('First');
    await tester.pump();
    showToast('Second');
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('its action runs and dismisses it', (tester) async {
    await host(tester);
    var undone = false;
    showToast('Logged a full day',
        actionLabel: 'Undo', onAction: () => undone = true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.text('Logged a full day'), findsNothing);
  });

  testWidgets('stays over a route pushed after it', (tester) async {
    await host(tester);
    showToast('Copied');
    await tester.pump();
    appNavigatorKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next page'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Next page'), findsOneWidget);
    expect(find.text('Copied').hitTestable(), findsOneWidget);
  });
}
