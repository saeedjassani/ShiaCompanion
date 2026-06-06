import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  var canScheduleExactNotifications = false;
  var requestExactAlarmsPermission = true;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    canScheduleExactPrayerNotifications = false;
    canScheduleExactNotifications = false;
    requestExactAlarmsPermission = true;
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'canScheduleExactNotifications':
          return canScheduleExactNotifications;
        case 'requestExactAlarmsPermission':
          return requestExactAlarmsPermission;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    flutterLocalNotificationsPlugin = null;
    canScheduleExactPrayerNotifications = false;
  });

  test('startup status refresh checks exact alarm access without requesting it',
      () async {
    final result = await refreshExactPrayerAlarmPermissionStatus();

    expect(result, isFalse);
    expect(canScheduleExactPrayerNotifications, isFalse);
    expect(
      calls,
      <Matcher>[
        isMethodCall('canScheduleExactNotifications', arguments: null),
      ],
    );
  });

  test('explicit exact alarm request opens permission flow only when needed',
      () async {
    final result = await requestExactPrayerAlarmPermissionIfNeeded();

    expect(result, isTrue);
    expect(canScheduleExactPrayerNotifications, isTrue);
    expect(
      calls,
      <Matcher>[
        isMethodCall('canScheduleExactNotifications', arguments: null),
        isMethodCall('requestExactAlarmsPermission', arguments: null),
      ],
    );
  });

  test('explicit exact alarm request does not prompt when already granted',
      () async {
    canScheduleExactNotifications = true;

    final result = await requestExactPrayerAlarmPermissionIfNeeded();

    expect(result, isTrue);
    expect(canScheduleExactPrayerNotifications, isTrue);
    expect(
      calls,
      <Matcher>[
        isMethodCall('canScheduleExactNotifications', arguments: null),
      ],
    );
  });

  test('precise prayer alarm setting is Android app only', () {
    expect(
      shouldShowPrecisePrayerAlarmSetting(platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      shouldShowPrecisePrayerAlarmSetting(platform: TargetPlatform.iOS),
      isFalse,
    );
    expect(
      shouldShowPrecisePrayerAlarmSetting(
        platform: TargetPlatform.android,
        isWeb: true,
      ),
      isFalse,
    );
  });
}
