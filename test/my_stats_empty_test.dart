import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/pages/my_stats_page.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

// Its own file, so the stores start empty: the stores are singletons, and
// my_stats_page_test.dart fills them.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
  });

  testWidgets('Before anything is read, one card says how it starts',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyStatsPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Your stats start here'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.text('Active days'), findsNothing);
    expect(find.textContaining('in a row'), findsNothing);
  });
}
