import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/models/azaan_option.dart';
import 'package:shia_companion/pages/item_page.dart';
import 'package:http/http.dart' as http;
import 'package:date_format/date_format.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';
import 'data/live_streaming_data.dart';
import 'data/uid_title_data.dart';
import 'pages/chapter_list_page.dart';

import 'pages/video_player.dart';
import 'utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:flutter/cupertino.dart';

export 'utils/slug_registry.dart';

double screenWidth = 0;
double screenHeight = 0;

User? user;
bool isUserAdmin = false;

final String appName = "Shia Companion";
final Color appColor = Colors.brown;
const IconData tasbeehCounterIcon = Icons.exposure_plus_1;
int hijriDate = 0;
double arabicFontSize = 32.0;
double englishFontSize = 16.0;

String? city;
double? lat, long;
bool needToSchedule = true;
String arabicFont = "Qalam";
bool canScheduleExactPrayerNotifications = false;
bool _notificationTimeZoneInitialized = false;

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
TextStyle smallText = TextStyle(fontSize: 14);
TextStyle boldText = TextStyle(fontWeight: FontWeight.bold);
String appVersion = '1.0';

bool showTranslation = true, showTransliteration = true;

const MethodChannel _notificationAudioChannel =
    MethodChannel('shia_companion/notification_audio');
const String azaanPreferenceKey = 'azaan_preference';
const String azaanCustomFilePathKey = 'azaan_custom_file_path';
const String _azaanCustomNotificationUriKey = 'azaan_custom_notification_uri';
const String _azaanCustomNotificationSourcePathKey =
    'azaan_custom_notification_source_path';
const String _androidPrayerChannelMigrationKey =
    'android_prayer_notification_channel_migration';
const int _androidPrayerChannelMigrationVersion = 2;
const String _androidPrayerChannelVersion = 'v2';

bool shouldUseLiveLocation() {
  if (!SP.isInitialized) return false;
  return SP.prefs.getBool('use_live_location') ?? false;
}

bool shouldShowPrecisePrayerAlarmSetting({
  required TargetPlatform platform,
  bool isWeb = kIsWeb,
}) {
  return !isWeb && platform == TargetPlatform.android;
}

String defaultAzaanPreferenceId() {
  if (!kIsWeb && Platform.isIOS) return AzaanOptions.takbir.id;
  return AzaanOptions.azaan.id;
}

bool isAzaanOptionAvailableOnCurrentPlatform(AzaanOption option) {
  if (!kIsWeb && Platform.isIOS && option.id == AzaanOptions.azaan.id) {
    return false;
  }
  return true;
}

List<AzaanOption> getAvailableAzaanOptions() {
  return AzaanOptions.all
      .where(isAzaanOptionAvailableOnCurrentPlatform)
      .toList(growable: false);
}

AzaanOption resolveAzaanOptionForCurrentPlatform(String? azaanId) {
  final fallback =
      AzaanOptions.getById(defaultAzaanPreferenceId()) ?? AzaanOptions.takbir;
  final azaan = azaanId != null ? AzaanOptions.getById(azaanId) : null;

  if (azaan == null || !isAzaanOptionAvailableOnCurrentPlatform(azaan)) {
    return fallback;
  }

  return azaan;
}

String resolveAzaanPreferenceIdForCurrentPlatform(String? azaanId) {
  return resolveAzaanOptionForCurrentPlatform(azaanId).id;
}

const String prayerNotificationScheduleFingerprintKey =
    'prayer_notification_schedule_fingerprint';

Future<void> initializeNotificationTimeZone() async {
  if (kIsWeb) return;

  if (!_notificationTimeZoneInitialized) {
    ensureTimeZoneDatabaseInitialized();
    _notificationTimeZoneInitialized = true;
  }

  try {
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
  } catch (e) {
    debugPrint('Unable to resolve local timezone, using ${tz.local.name}: $e');
  }
}

String _scheduleDateKey(DateTime dateTime) =>
    dateTime.toIso8601String().substring(0, 10);

String _scheduleLocationKey(double? value) =>
    value == null ? 'unknown' : value.toStringAsFixed(4);

List<String> getPrayerNotificationPrayerNames() {
  return [
    ...getPrayerTimeObject().getTimeNames(),
    'Midnight',
  ];
}

String buildPrayerNotificationScheduleFingerprint({DateTime? scheduleDate}) {
  final prayerNames = getPrayerNotificationPrayerNames();
  final enabledPrayerKeys = prayerNames.map((prayerName) {
    final key = notificationPreferenceKeyForPrayer(prayerName);
    return '$key:${SP.prefs.getBool(key) == true ? 1 : 0}';
  }).join(',');
  final azaanId = resolveAzaanPreferenceIdForCurrentPlatform(
      SP.prefs.getString(azaanPreferenceKey));
  final customAudioPath =
      azaanId == 'custom' ? SP.prefs.getString(azaanCustomFilePathKey) : null;

  return [
    'v6',
    'date:${_scheduleDateKey(scheduleDate ?? DateTime.now())}',
    'lat:${_scheduleLocationKey(lat)}',
    'long:${_scheduleLocationKey(long)}',
    'tz:${tz.local.name}',
    'azaan:$azaanId',
    'custom:${customAudioPath ?? ''}',
    'prayers:$enabledPrayerKeys',
  ].join('|');
}

bool _hasFreshScheduleReminder(List<PendingNotificationRequest>? pending) {
  if (pending == null) return false;

  for (final request in pending) {
    if (request.id != 786 || request.payload == null) continue;

    final reminderDate = DateTime.tryParse(request.payload!) ??
        DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(request.payload!) ?? 0,
        );
    if (reminderDate.difference(DateTime.now()).inDays > 2) {
      return true;
    }
  }

  return false;
}

bool shouldRefreshPrayerNotificationSchedule(
    List<PendingNotificationRequest>? pending) {
  if (!SP.isInitialized) return true;

  final expectedFingerprint = buildPrayerNotificationScheduleFingerprint();
  final storedFingerprint =
      SP.prefs.getString(prayerNotificationScheduleFingerprintKey);
  if (storedFingerprint != expectedFingerprint) {
    return true;
  }

  if (lat == null || long == null) return false;

  final prayerNames = getPrayerNotificationPrayerNames();
  if (!areAnyPrayerNotificationsEnabled(prayerNames)) return false;

  return !_hasFreshScheduleReminder(pending);
}

PrayerTime? prayerTime;

PrayerTime getPrayerTimeObject() {
  if (prayerTime != null) return prayerTime!;

  prayerTime = PrayerTime();

  prayerTime!.setCalcMethod(prayerTime!.getJafari());
  prayerTime!.setAsrJuristic(prayerTime!.getHanafi());
  prayerTime!.setAdjustHighLats(prayerTime!.getAngleBased());

  return prayerTime!;
}

class PrayerNotificationScheduleEntry {
  const PrayerNotificationScheduleEntry({
    required this.name,
    required this.dateTime,
  });

  final String name;
  final DateTime dateTime;
}

List<PrayerNotificationScheduleEntry> buildPrayerNotificationEntriesForDay({
  required PrayerTime prayerTime,
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  final originalFormat = prayerTime.getTimeFormat();
  try {
    prayerTime.setTimeFormat(prayerTime.getTime24());
    final names = prayerTime.getTimeNames();
    final times = prayerTime.getPrayerTimes(
      date,
      latitude,
      longitude,
      date.timeZoneOffset.inMinutes / 60.0,
    );
    final entries = <PrayerNotificationScheduleEntry>[];
    for (var index = 0; index < names.length; index++) {
      final dateTime = dateTimeForTime24(date, times[index]);
      if (dateTime == null) continue;
      entries.add(PrayerNotificationScheduleEntry(
        name: names[index],
        dateTime: dateTime,
      ));
    }
    final midnight = shiaMidnightForDate(
      prayerTime: prayerTime,
      date: date,
      latitude: latitude,
      longitude: longitude,
    );
    if (midnight != null) {
      entries.add(PrayerNotificationScheduleEntry(
        name: 'Midnight',
        dateTime: midnight,
      ));
    }
    return entries;
  } finally {
    prayerTime.setTimeFormat(originalFormat);
  }
}

Map items = {};
Map<String, double> itemOrder = {};
Map<String, dynamic> itemMetadata = {};
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

double getItemOrderValue(String uid) {
  final custom = itemOrder[uid];
  if (custom != null) return custom;
  final left = uid.split("|").first;
  final digits =
      left.replaceAll(RegExp("[A-Z].*~"), "").replaceAll(RegExp("[A-Z]"), "");
  return double.tryParse(digits) ?? 999999.0;
}

Future<void> handleUniversalDataClick(
    BuildContext context, UniversalData itemData,
    {bool itemPage = false}) async {
  Widget? routeToPush;
  String contentType = 'universal';
  switch (itemData.type) {
    case 0:
      contentType = 'zikr';
      UidTitleData uidTitleData = UidTitleData(itemData.uid, itemData.title);
      routeToPush = itemPage ? ItemPage(uidTitleData) : ZikrPage(uidTitleData);
      break;
    case 1:
      contentType = 'library';
      routeToPush = ChapterListPage(itemData.uid, itemData.title);
      break;
    case 2:
      contentType = 'live-streaming';
      routeToPush =
          VideoPlayer(LiveStreamingData(itemData.uid, itemData.title));
      break;
    default:
  }
  FirebaseAnalytics.instance
      .logSelectContent(contentType: contentType, itemId: itemData.title);
  if (routeToPush != null) {
    await pushPageRoute(context, routeToPush);
  }
}

Future<bool> initializeLocation(
    {bool force = false, BuildContext? context}) async {
  // If we are not forcing a refresh and we already have lat/long, just return.
  if (!force && lat != null && long != null) {
    return true;
  }

  // Show explanation dialog on first setup
  if (!force && context != null && lat == null && long == null) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Enable Location for Prayer Times'),
          content: Text(
            'Prayer times are unique to your location. We use your location while you are using the app so we can provide accurate prayer times for your area.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location service is disabled");
      if (context != null && !kIsWeb) {
        _showLocationServiceDialog(context);
      }
      return false;
    }

    var permissionStatus = await Geolocator.checkPermission();
    if (permissionStatus == LocationPermission.denied) {
      permissionStatus = await Geolocator.requestPermission();
    }

    if (permissionStatus == LocationPermission.denied ||
        permissionStatus == LocationPermission.deniedForever ||
        permissionStatus == LocationPermission.unableToDetermine) {
      debugPrint("Location permission not granted: $permissionStatus");
      if (context != null && !kIsWeb) {
        _showPermissionDeniedDialog(context, permissionStatus);
      }
      return false;
    }

    if (permissionStatus == LocationPermission.whileInUse ||
        permissionStatus == LocationPermission.always) {
      // Permission granted; fall through to fetch position.
    }

    // Use a time limit so we don't hang indefinitely on a cold/failing fetch,
    // and keep a last-known fix as a fallback when a fresh one can't be obtained.
    // getLastKnownPosition is unsupported on web, so skip it there.
    final Position? lastKnownPosition = kIsWeb
        ? null
        : await Geolocator.getLastKnownPosition();

    Position currentLocation;
    try {
      currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException catch (e) {
      if (lastKnownPosition != null) {
        debugPrint("Location request timed out; using last known position.");
        currentLocation = lastKnownPosition;
      } else {
        debugPrint("Location request timed out: $e");
        if (context != null && !kIsWeb) {
          _showLocationTimeoutDialog(context);
        }
        return false;
      }
    } catch (e) {
      if (lastKnownPosition != null) {
        debugPrint("Location fetch failed; using last known position: $e");
        currentLocation = lastKnownPosition;
      } else {
        debugPrint("Location fetch failed: $e");
        if (context != null && !kIsWeb) {
          _showLocationErrorDialog(context, e);
        }
        return false;
      }
    }
    final previousLat = lat;
    final previousLong = long;
    lat = currentLocation.latitude;
    long = currentLocation.longitude;
    final locationChanged = previousLat == null ||
        previousLong == null ||
        (previousLat - lat!).abs() > 0.0001 ||
        (previousLong - long!).abs() > 0.0001;
    if (locationChanged) {
      needToSchedule = true;
    }
    await SP.prefs.setDouble("lat", lat!);
    await SP.prefs.setDouble("long", long!);

    try {
      final response = await http.get(Uri.parse(
          "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$long&localityLanguage=en"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resolvedCity =
            data['locality'] ?? data['city'] ?? data['principalSubdivision'];
        final validCity = _validateGeocodeResult(data, resolvedCity);
        if (validCity != null) {
          city = validCity;
          if (SP.prefs.getString("city") != city) needToSchedule = true;
          if (city != null) await SP.prefs.setString("city", city!);
        } else {
          debugPrint(
              "Geocode did not resolve a city name ('$resolvedCity'); using a broader location label.");
          // Don't keep a stale previous city: reflect the new coordinates.
          final fallback = _geocodeFallbackLabel(data, lat!, long!);
          if (fallback != city) needToSchedule = true;
          city = fallback;
          await SP.prefs.setString("city", city!);
          if (context != null && !kIsWeb) {
            _showGeocodeFallbackDialog(context);
          }
        }
      } else {
        debugPrint("Geocode returned status ${response.statusCode}");
        if (locationChanged) {
          city = _geocodeFallbackLabel({}, lat!, long!);
          await SP.prefs.setString("city", city!);
        }
      }
    } catch (e) {
      debugPrint("Error getting city: $e");
      if (locationChanged) {
        city = _geocodeFallbackLabel({}, lat!, long!);
        await SP.prefs.setString("city", city!);
      }
    }
    if (locationChanged && flutterLocalNotificationsPlugin != null && !kIsWeb) {
      await setUpNotifications();
    }
    return true;
  } catch (e) {
    debugPrint(e.toString());
    if (context != null && !kIsWeb) {
      _showLocationErrorDialog(context, e);
    }
    return false;
  }
}

String? _validateGeocodeResult(
    Map<String, dynamic> data, String? resolvedCity) {
  if (resolvedCity == null || resolvedCity.trim().isEmpty) return null;

  final trimmed = resolvedCity.trim();

  final countryCode = (data['countryCode'] ?? '').toString().trim().toUpperCase();
  final hasCountryCode = countryCode.length == 2;
  if (!hasCountryCode) return null;

  final localityInfo = data['localityInfo'];
  if (localityInfo is Map) {
    final administrative = localityInfo['administrative'];
    if (administrative is List && administrative.isNotEmpty) {
      final hasAdminArea = administrative.any((entry) {
        if (entry is Map) {
          // BigDataCloud reports admin level as `adminLevel` (2 = country,
          // 4 = first-order subdivision). Older schemas used `level` '0'/'1'.
          final level = entry['adminLevel'] ?? entry['level'];
          final name = (entry['name'] ?? '').toString().trim();
          final isCountryOrState =
              level == 2 || level == 4 || level == '0' || level == '1';
          if (isCountryOrState) return name.isNotEmpty;
        }
        return false;
      });
      if (!hasAdminArea) return null;
    } else {
      return null;
    }
  } else {
    return null;
  }

  if (RegExp(r'^\d+\.?\d*\s*[ns]\s*\d+\.?\d*\s*[ew]$').hasMatch(trimmed)) {
    return null;
  }

  return trimmed;
}

/// Builds a readable location label from a geocode response when a precise
/// city name can't be validated. Prefers the subdivision/country and falls
/// back to raw coordinates so the UI never shows a stale previous location.
String _geocodeFallbackLabel(Map<String, dynamic> data, double lat, double long) {
  final candidate = (data['principalSubdivision'] ??
      data['countryName'] ??
      data['locality'] ??
      '').toString().trim();
  return candidate.isNotEmpty
      ? candidate
      : '${lat.toStringAsFixed(2)}, ${long.toStringAsFixed(2)}';
}

void _showLocationServiceDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are turned off. Please enable location services in your device settings to get accurate prayer times for your area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      );
    },
  );
}

void _showGeocodeFallbackDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Location Uncertain'),
        content: const Text(
          'We couldn\'t determine a precise city name for your current coordinates. Showing a broader location instead.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void _showPermissionDeniedDialog(
    BuildContext context, LocationPermission status) {
  String message;
  if (status == LocationPermission.deniedForever) {
    message =
        'Location permission was permanently denied. Please open app settings and grant location permission to get accurate prayer times.';
  } else if (status == LocationPermission.unableToDetermine) {
    message =
        'Unable to determine location permission status. Please open app settings and ensure location permission is granted.';
  } else {
    message =
        'Location permission is required to show accurate prayer times for your area.';
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Location Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      );
    },
  );
}

void _showLocationTimeoutDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Location Timeout'),
        content: const Text(
          'Unable to get your location within the expected time. This may be due to poor GPS signal or network issues. Please try again.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void _showLocationErrorDialog(BuildContext context, dynamic error) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Location Error'),
        content: Text(
          'An error occurred while getting your location: $error\n\nPlease check that location services are enabled and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      );
    },
  );
}

bool areAnyPrayerNotificationsEnabled(List<String> prayerNames) {
  return enabledPrayerNotificationCount(prayerNames) > 0;
}

int enabledPrayerNotificationCount(List<String> prayerNames) {
  var enabledCount = 0;
  for (final prayerName in prayerNames) {
    if (SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayerName)) ==
        true) {
      enabledCount++;
    }
  }
  return enabledCount;
}

int prayerNotificationScheduleDays(int enabledPrayerCount) {
  const defaultScheduleDays = 12;
  if (!Platform.isIOS || enabledPrayerCount <= 0) return defaultScheduleDays;

  // iOS keeps only 64 pending notifications. Reserve one slot for the reminder.
  const maxIosPrayerNotifications = 63;
  final iosDays = maxIosPrayerNotifications ~/ enabledPrayerCount;
  return iosDays.clamp(1, defaultScheduleDays).toInt();
}

Iterable<int> prayerNotificationIds(
    {int days = 12, int prayerCount = 8}) sync* {
  for (int dayOffset = 0; dayOffset < days; dayOffset++) {
    for (int prayerIndex = 0; prayerIndex < prayerCount; prayerIndex++) {
      yield (100 * (prayerIndex + 1)) + dayOffset;
    }
  }
}

Future<void> cancelPrayerNotifications({bool includeReminder = true}) async {
  final plugin = flutterLocalNotificationsPlugin;
  if (plugin == null) return;

  final notificationIds = prayerNotificationIds().toList();
  if (includeReminder) {
    notificationIds.add(786);
  }

  await Future.wait(notificationIds.map((id) => plugin.cancel(id: id)));
}

Future<void> setUpNotifications() async {
  debugPrint("Scheduling Azan Notifications");

  final plugin = flutterLocalNotificationsPlugin;
  if (plugin == null) return;
  await initializeNotificationTimeZone();
  await refreshLegacyAndroidPrayerNotificationChannelsIfNeeded();

  final selectedAzaanId = resolveAzaanPreferenceIdForCurrentPlatform(
      SP.isInitialized ? SP.prefs.getString(azaanPreferenceKey) : null);
  final prayerNames = getPrayerNotificationPrayerNames();
  final enabledPrayerCount = enabledPrayerNotificationCount(prayerNames);
  final scheduleDays = prayerNotificationScheduleDays(enabledPrayerCount);
  final scheduleFingerprint = buildPrayerNotificationScheduleFingerprint();

  await cancelPrayerNotifications();

  if (lat == null || long == null) {
    debugPrint("Skipping Azan notifications: location unavailable");
    await SP.prefs.remove(prayerNotificationScheduleFingerprintKey);
    return;
  }

  if (enabledPrayerCount == 0) {
    debugPrint("Skipping Azan notifications: all prayers disabled");
    await SP.prefs.setString(
        prayerNotificationScheduleFingerprintKey, scheduleFingerprint);
    return;
  }

  DateTime now = DateTime.now();
  PrayerTime prayers = getPrayerTimeObject();
  final List<Future<void>> schedulingTasks = [];
  for (int i = 0; i < scheduleDays; i++) {
    DateTime temp = now.add(Duration(days: i));
    final entries = buildPrayerNotificationEntriesForDay(
      prayerTime: prayers,
      date: temp,
      latitude: lat!,
      longitude: long!,
    );
    entries.asMap().forEach((index, entry) {
      schedulingTasks.add(schedulePrayerTimeNotification(
        (100 * (index + 1)) + i,
        entry.dateTime,
        entry.name,
        azaanId: selectedAzaanId,
      ));
    });
  }
  await Future.wait(schedulingTasks);
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails("general", "General");
  DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails();
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics);
  await plugin.zonedSchedule(
      id: 786,
      title: "Open the app to continue getting Azan notifications",
      body:
          "It seems you've not used the application in last $scheduleDays days. Please open the app to continue receive Azan notifications",
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(Duration(days: scheduleDays - 1)),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexact,
      payload: now.add(Duration(days: scheduleDays - 1)).toIso8601String());
  await SP.prefs
      .setString(prayerNotificationScheduleFingerprintKey, scheduleFingerprint);
}

/// Prepares custom audio file for notification playback
/// On iOS: Handles restricted file locations and copies to app documents
/// On Android: Registers a MediaStore content URI for notification channels
Future<dynamic> prepareCustomAudioForNotification(String filePath) async {
  try {
    debugPrint('Preparing audio file: $filePath');

    // On iOS, file picker might return security-restricted paths
    // We need to handle this carefully
    if (Platform.isIOS) {
      try {
        final file = File(filePath);

        // Try to read file first to check accessibility
        final exists = await file.exists();
        if (!exists) {
          debugPrint('iOS: File does not exist: $filePath');
          return 'file://$filePath'; // Fallback - let iOS handle it
        }

        // Try to copy to documents directory
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final fileName = file.path.split('/').last;
          final targetPath = '${appDocDir.path}/$fileName';

          debugPrint('iOS: Copying file to documents: $targetPath');
          final copiedFile = await file.copy(targetPath);
          final documentUrl = 'file://${copiedFile.path}';
          debugPrint('iOS: File copied successfully to: $documentUrl');
          return documentUrl;
        } catch (copyError) {
          // If copy fails, try using original path as file:// URL
          debugPrint('iOS: Copy failed ($copyError), using original path');
          return 'file://$filePath';
        }
      } catch (e) {
        debugPrint('iOS: Error handling file: $e');
        // Last resort fallback
        return 'file://$filePath';
      }
    } else if (Platform.isAndroid) {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Android: File does not exist: $filePath');
        return null;
      }

      final mediaStoreUri = await _registerAndroidNotificationSound(filePath);
      if (mediaStoreUri != null && mediaStoreUri.isNotEmpty) {
        debugPrint('Android: Registered custom sound URI: $mediaStoreUri');
        return mediaStoreUri;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = file.path.split('/').last;
      final targetPath = '${appDocDir.path}/azaan_$fileName';
      final copiedFile = await file.copy(targetPath);
      final fileUri = Uri.file(copiedFile.path).toString();
      debugPrint('Android: Copied custom sound to: $fileUri');
      return fileUri;
    }
  } catch (e) {
    debugPrint('Error preparing custom audio: $e');
    return null;
  }

  return null;
}

Future<String?> _registerAndroidNotificationSound(String filePath) async {
  if (!SP.isInitialized) return null;

  final cachedSource =
      SP.prefs.getString(_azaanCustomNotificationSourcePathKey);
  final cachedUri = SP.prefs.getString(_azaanCustomNotificationUriKey);
  if (cachedSource == filePath && cachedUri != null && cachedUri.isNotEmpty) {
    return cachedUri;
  }

  try {
    final uri = await _notificationAudioChannel.invokeMethod<String>(
      'registerNotificationSound',
      {'path': filePath},
    );
    if (uri != null && uri.isNotEmpty) {
      await SP.prefs.setString(_azaanCustomNotificationSourcePathKey, filePath);
      await SP.prefs.setString(_azaanCustomNotificationUriKey, uri);
    }
    return uri;
  } on MissingPluginException catch (e) {
    debugPrint('Android custom sound helper is unavailable: $e');
  } on PlatformException catch (e) {
    debugPrint('Android custom sound registration failed: ${e.message}');
  } catch (e) {
    debugPrint('Android custom sound registration failed: $e');
  }

  return null;
}

String _stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _androidPrayerChannelId(AzaanOption azaan, {String? customSoundUri}) {
  switch (azaan.id) {
    case 'takbir':
      return 'prayer_takbir_$_androidPrayerChannelVersion';
    case 'system_default':
      return 'prayer_system_default_$_androidPrayerChannelVersion';
    case 'custom':
      return 'prayer_custom_${_stableHash(customSoundUri ?? 'missing')}_$_androidPrayerChannelVersion';
    case 'azaan':
    default:
      return 'prayer_full_azaan_$_androidPrayerChannelVersion';
  }
}

Future<void> refreshLegacyAndroidPrayerNotificationChannelsIfNeeded() async {
  if (!Platform.isAndroid || !SP.isInitialized) return;

  final previousMigration =
      SP.prefs.getInt(_androidPrayerChannelMigrationKey) ?? 0;
  if (previousMigration >= _androidPrayerChannelMigrationVersion) return;

  final androidImplementation =
      flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation == null) return;

  final legacyChannelIds = <String>{
    'prayerTimes',
    'prayer_full_azaan_v1',
    'prayer_takbir_v1',
    'prayer_system_default_v1',
  };

  try {
    final channels = await androidImplementation.getNotificationChannels();
    for (final channel in channels ?? const <AndroidNotificationChannel>[]) {
      if (channel.id.startsWith('prayer_custom_') &&
          channel.id.endsWith('_v1')) {
        legacyChannelIds.add(channel.id);
      }
    }

    for (final channelId in legacyChannelIds) {
      await androidImplementation.deleteNotificationChannel(
        channelId: channelId,
      );
    }

    await SP.prefs.setInt(
      _androidPrayerChannelMigrationKey,
      _androidPrayerChannelMigrationVersion,
    );
  } catch (e) {
    debugPrint('Unable to refresh Android prayer notification channels: $e');
  }
}

String _androidPrayerChannelName(AzaanOption azaan) {
  switch (azaan.id) {
    case 'takbir':
      return 'Prayer Times - Takbir';
    case 'system_default':
      return 'Prayer Times - System Default';
    case 'custom':
      return 'Prayer Times - Custom Sound';
    case 'azaan':
    default:
      return 'Prayer Times - Full Azan';
  }
}

Future<AndroidNotificationDetails> _androidPrayerNotificationDetails(
    AzaanOption azaan) async {
  AndroidNotificationSound? sound;
  String? customSoundUri;

  if (azaan.id == 'system_default') {
    sound = null;
  } else if (azaan.id == 'custom') {
    final customAudioPath = getCustomAudioFilePath();
    if (customAudioPath != null && customAudioPath.isNotEmpty) {
      customSoundUri =
          await prepareCustomAudioForNotification(customAudioPath) as String?;
      if (customSoundUri != null && customSoundUri.isNotEmpty) {
        sound = UriAndroidNotificationSound(customSoundUri);
      }
    }
  } else {
    sound = RawResourceAndroidNotificationSound(azaan.androidFile ?? 'sharif');
  }

  return AndroidNotificationDetails(
    _androidPrayerChannelId(azaan, customSoundUri: customSoundUri),
    _androidPrayerChannelName(azaan),
    channelDescription: 'Prayer time notifications',
    importance: Importance.max,
    priority: Priority.high,
    sound: sound,
    playSound: true,
    enableVibration: true,
  );
}

DarwinNotificationDetails _iosPrayerNotificationDetails(AzaanOption azaan) {
  if (azaan.id == 'system_default' || azaan.id == 'custom') {
    return DarwinNotificationDetails();
  }

  return DarwinNotificationDetails(sound: azaan.iosFile ?? 'azan.caf');
}

Future<NotificationDetails> prayerNotificationDetails(AzaanOption azaan) async {
  return NotificationDetails(
    android: Platform.isAndroid
        ? await _androidPrayerNotificationDetails(azaan)
        : null,
    iOS: Platform.isIOS ? _iosPrayerNotificationDetails(azaan) : null,
  );
}

Future<void> schedulePrayerTimeNotification(
    int id, DateTime dateTime, String prayerName,
    {String? azaanId}) async {
  if (dateTime.difference(DateTime.now()).isNegative) return;
  if (SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayerName)) ==
      true) {
    final azaan = azaanId != null
        ? resolveAzaanOptionForCurrentPlatform(azaanId)
        : getSelectedAzaan();

    final platformChannelSpecifics = await prayerNotificationDetails(azaan);

    await flutterLocalNotificationsPlugin?.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: canScheduleExactPrayerNotifications
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title:
            formatDate(dateTime, [hh, ":", nn, " ", am]) + " : " + prayerName,
        body: "It's time for " + prayerName.toLowerCase(),
        payload: dateTime.toIso8601String());
  } else {
    await flutterLocalNotificationsPlugin?.cancel(id: id);
  }
}

Future<void> testNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    {String? azaanId}) async {
  await initializeNotificationTimeZone();
  final azaan = azaanId != null
      ? resolveAzaanOptionForCurrentPlatform(azaanId)
      : getSelectedAzaan();

  final platformChannelSpecifics = await prayerNotificationDetails(azaan);

  // Schedule for 2 seconds in the future to ensure it fires
  await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 999,
      scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(seconds: 2)),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: canScheduleExactPrayerNotifications
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: "Test",
      body: "Test notification");
}

String notificationPreferenceKeyForPrayer(String prayerName) {
  final normalizedName = prayerName.trim().toLowerCase();
  if (normalizedName == 'dhuhr' || normalizedName == 'zuhr') {
    return 'dhuhr_notification';
  }
  return '${normalizedName}_notification';
}

Future<bool> requestExactPrayerAlarmPermissionIfNeeded() async {
  final androidImplementation =
      flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation == null) {
    return canScheduleExactPrayerNotifications;
  }

  canScheduleExactPrayerNotifications =
      await androidImplementation.canScheduleExactNotifications() ?? false;
  if (canScheduleExactPrayerNotifications) {
    return true;
  }

  canScheduleExactPrayerNotifications =
      await androidImplementation.requestExactAlarmsPermission() ?? false;
  return canScheduleExactPrayerNotifications;
}

Future<bool> refreshExactPrayerAlarmPermissionStatus() async {
  final androidImplementation =
      flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation == null) {
    return canScheduleExactPrayerNotifications;
  }

  canScheduleExactPrayerNotifications =
      await androidImplementation.canScheduleExactNotifications() ?? false;
  return canScheduleExactPrayerNotifications;
}

/// Get the currently selected azaan option
AzaanOption getSelectedAzaan() {
  if (!SP.isInitialized) return resolveAzaanOptionForCurrentPlatform(null);

  return resolveAzaanOptionForCurrentPlatform(
      SP.prefs.getString(azaanPreferenceKey));
}

/// Get custom audio file path (if user selected custom)
String? getCustomAudioFilePath() {
  if (!SP.isInitialized) return null;

  final azaanId = SP.prefs.getString(azaanPreferenceKey);
  if (azaanId == 'custom') {
    return SP.prefs.getString(azaanCustomFilePathKey);
  }
  return null;
}

/// Save the user's azaan preference
Future<void> saveAzaanPreference(String azaanId) async {
  await SP.prefs.setString(
      azaanPreferenceKey, resolveAzaanPreferenceIdForCurrentPlatform(azaanId));
}

/// Save custom audio file path
Future<void> saveCustomAudioFilePath(String filePath) async {
  final previousPath = SP.prefs.getString(azaanCustomFilePathKey);
  await SP.prefs.setString(azaanCustomFilePathKey, filePath);
  if (previousPath != filePath) {
    await SP.prefs.remove(_azaanCustomNotificationUriKey);
    await SP.prefs.remove(_azaanCustomNotificationSourcePathKey);
  }
}

AppBar getAppBar() {
  return AppBar(
    title: Text(appName),
  );
}

Future<void> trackScreen(
  String screenName, {
  bool deferOnWeb = false,
}) async {
  if (kIsWeb && deferOnWeb) {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  await FirebaseAnalytics.instance.logEvent(
    name: 'screen_view',
    parameters: {'screen_name': screenName},
  );
}

// Platform-aware route push that supports back navigation
Future<T?> pushPageRoute<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(context, _pageRouteFor(page));
}

Future<T?>? pushRootPageRoute<T>(Widget page) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return null;
  return navigator.push<T>(_pageRouteFor(page));
}

PageRoute<T> _pageRouteFor<T>(Widget page) {
  return kIsWeb
      ? MaterialPageRoute<T>(builder: (context) => page)
      : CupertinoPageRoute<T>(builder: (context) => page);
}
