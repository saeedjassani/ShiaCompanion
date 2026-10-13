import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/widgets/now_playing_capsule.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> host(WidgetTester tester, Widget home) =>
      tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [nowPlayingRouteObserver],
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Stack(
          children: [
            Positioned.fill(child: child!),
            const NowPlayingCapsule(),
          ],
        ),
        home: home,
      ));

  testWidgets('taps reach the page under the capsule while nothing plays',
      (tester) async {
    var taps = 0;
    await host(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ElevatedButton(
              onPressed: () => taps++, child: const Text('Under')),
        ),
      ),
    );
    await tester.tap(find.text('Under'));
    expect(taps, 1);
  });

  testWidgets('follows the floating control of the page on top',
      (tester) async {
    await host(
      tester,
      const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FloatingBottomSlot(extent: 88, child: SizedBox(height: 62)),
        ),
      ),
    );
    await tester.pump();
    expect(FloatingBottomSlot.reserved.value, 88);

    // A pushed page without one: the control under it is not on screen.
    navigatorKey.currentState!
        .push(MaterialPageRoute(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(FloatingBottomSlot.reserved.value, 0);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(FloatingBottomSlot.reserved.value, 88);
  });

  testWidgets('a disabled control reserves nothing', (tester) async {
    await host(
      tester,
      const Scaffold(
        body: FloatingBottomSlot(
          extent: 88,
          enabled: false,
          child: SizedBox(height: 62),
        ),
      ),
    );
    await tester.pump();
    expect(FloatingBottomSlot.reserved.value, 0);
  });

  testWidgets('measures a docked bar that gives no extent', (tester) async {
    await host(
      tester,
      const Scaffold(
        bottomNavigationBar: FloatingBottomSlot(child: SizedBox(height: 70)),
      ),
    );
    await tester.pump();
    expect(FloatingBottomSlot.reserved.value, 70);
  });

  testWidgets('knows when a dialog is open over the page', (tester) async {
    await host(tester, const Scaffold());
    expect(nowPlayingRouteObserver.popupOnTop.value, isFalse);

    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('Hi')),
    );
    await tester.pumpAndSettle();
    expect(nowPlayingRouteObserver.popupOnTop.value, isTrue);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(nowPlayingRouteObserver.popupOnTop.value, isFalse);
  });
}
