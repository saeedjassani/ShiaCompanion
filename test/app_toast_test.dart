import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/widgets/app_toast.dart';

void main() {
  Future<void> host(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [toastRouteObserver],
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

  Future<void> push(WidgetTester tester, String text) async {
    appNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(text))));
    await tester.pumpAndSettle();
  }

  testWidgets('goes when another page opens over its own', (tester) async {
    await host(tester);
    showToast('Logged a full day');
    await tester.pump();
    await push(tester, 'Duas');
    expect(find.text('Duas'), findsOneWidget);
    expect(find.text('Logged a full day'), findsNothing);
  });

  testWidgets(
      'goes when its page is popped, and one shown after the pop '
      'stays on the page underneath', (tester) async {
    await host(tester);
    await push(tester, 'Account');
    showToast('Account toast');
    await tester.pump();
    appNavigatorKey.currentState!.pop();
    showToast('Signed out');
    await tester.pumpAndSettle();
    expect(find.text('Account toast'), findsNothing);
    expect(find.text('Signed out'), findsOneWidget);
  });

  testWidgets('stays while a sheet opens over its page', (tester) async {
    await host(tester);
    showToast('Copied');
    await tester.pump();
    showModalBottomSheet<void>(
      context: appNavigatorKey.currentContext!,
      builder: (_) => const Text('Verse menu'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verse menu'), findsOneWidget);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('hideToast takes it down (as a tab switch does)', (tester) async {
    await host(tester);
    showToast('Reorder failed');
    await tester.pump();
    hideToast();
    await tester.pumpAndSettle();
    expect(find.text('Reorder failed'), findsNothing);
  });
}
