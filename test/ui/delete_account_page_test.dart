import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/delete_account_page.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'firebase_test_doubles.dart';

/// Covers what changed on DeleteAccountPage: it renders its signed-out call
/// to action like any other Firebase-backed screen, and back navigation does
/// the right thing in both shapes this page is opened in — pushed from
/// Settings, where back should return to Settings (covered here), and as the
/// Navigator's only route, the public `/delete-account` web link Google Play
/// requires apps to publish (covered by asserting `PopScope.canPop` is false
/// in that shape — the actual destination that back sends the user to,
/// MyHomePage, pulls in plugins such as app_links that this suite has no
/// mock for yet, so driving that pop end-to-end belongs in an integration
/// test rather than here).
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
  });

  testWidgets('renders the signed-out call to action without throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DeleteAccountPage()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Open Preferences in the app and use Delete My Account.'),
      findsOneWidget,
    );
  });

  testWidgets("has nothing to pop when it is the Navigator's only route",
      (tester) async {
    // This is exactly how main.dart mounts the page for a direct visit to
    // the public /delete-account link: as `home`, with no route beneath it.
    await tester.pumpWidget(
      const MaterialApp(home: DeleteAccountPage()),
    );
    await tester.pump();

    // byType compares runtime Type objects exactly, and PopScope is generic
    // (PopScope<T>) — bySubtype does the `is` check that actually matches an
    // instance whatever T got inferred to.
    final popScope = tester.widget<PopScope>(find.bySubtype<PopScope>());
    expect(popScope.canPop, isFalse);
  });

  testWidgets('pops back to the page it was pushed from, same as any route',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              // The same call Settings' "Delete My Account" tile makes.
              onPressed: () =>
                  pushPageRoute(context, const DeleteAccountPage()),
              child: const Text('Open delete account'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountPage), findsOneWidget);
    final popScope = tester.widget<PopScope>(find.bySubtype<PopScope>());
    expect(popScope.canPop, isTrue);

    await Navigator.maybePop(tester.element(find.byType(DeleteAccountPage)));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountPage), findsNothing);
    expect(find.text('Open delete account'), findsOneWidget);
  });
}
