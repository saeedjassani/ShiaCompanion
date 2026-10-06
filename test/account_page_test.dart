import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/pages/account_page.dart';
import 'package:shia_companion/services/qaza_tracker_manager.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

const _profile = AccountProfile(
  name: 'Zahra Ali',
  initials: 'ZA',
  email: 'zahra@example.com',
  provider: 'Google',
);

void main() {
  setUpAll(() async {
    // Loaded here, outside any test's fake clock: a load a test starts can
    // be left waiting on it, and would hold up a later forced one.
    SharedPreferences.setMockInitialValues({
      'qaza_tracker_guest': jsonEncode({
        'fajr': {'remaining': 1000, 'completed': 0},
        'isha': {'remaining': 270, 'completed': 0},
      }),
    });
    await SP.init();
    await setUpFirebaseForRenderTests();
    await QazaTrackerManager.instance.loadQaza(force: true);
  });

  testWidgets('shows who is signed in and what the backup holds',
      (tester) async {
    await _pump(tester, checkBackup: () async => true);

    expect(find.text('Account'), findsWidgets);
    expect(find.text('ZA'), findsOneWidget);
    expect(find.text('Zahra Ali'), findsOneWidget);
    expect(find.text('zahra@example.com · Google'), findsOneWidget);
    expect(find.text('Backed up'), findsOneWidget);

    expect(find.text('KEPT SAFE IN YOUR BACKUP'), findsOneWidget);
    for (final item in [
      'Favorites',
      'Bookmarks',
      'Quran progress',
      'Saved verses',
      'Qaza tracker',
      'My Stats and shortcuts',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says when the backup is waiting for a connection',
      (tester) async {
    final check = Completer<bool>();
    await _pump(tester, checkBackup: () => check.future);
    expect(find.text('Checking your backup…'), findsOneWidget);

    check.complete(false);
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline · backs up when you reconnect'), findsOneWidget);
  });

  testWidgets('counts the qaza still owed', (tester) async {
    await _pump(tester, checkBackup: () async => true);

    expect(find.text('1,270 left'), findsOneWidget);
  });

  testWidgets('asks before deleting the account', (tester) async {
    await _pump(tester, checkBackup: () async => true);

    await tester.tap(find.text('Delete account…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
    expect(find.byType(AccountPage), findsOneWidget);
  });

  test('initials come from the first two names', () {
    expect(AccountProfile.initialsOf('Zahra Ali Hussain'), 'ZA');
    expect(AccountProfile.initialsOf('zahra'), 'Z');
    expect(AccountProfile.initialsOf(''), '');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<bool> Function() checkBackup,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: AccountPage(profile: _profile, checkBackup: checkBackup),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
