import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/models/azaan_option.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/azan_playback_service.dart';
import 'package:http/http.dart' as http;
import 'package:date_format/date_format.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';
import 'package:shia_companion/services/zikr_reminder_service.dart';
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
const IconData tasbeehCounterIcon = Icons.adjust_rounded;
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

/// Whether, in [isArabicOnlyReadingView](in zikr_content_viewer.dart) - both
/// English aids switched off - consecutive Arabic verses flow together as one
/// prose paragraph instead of staying as separate centered lines. Off by
/// default: it changes how the Arabic itself is laid out, not just what sits
/// alongside it, so it stays an opt-in rather than kicking in the moment a
/// reader turns off translation and transliteration.
bool showArabicAsParagraph = false;

const String azaanPreferenceKey = 'azaan_preference';
const String azaanCustomFilePathKey = 'azaan_custom_file_path';
const String _azaanCustomNotificationUriKey = 'azaan_custom_notification_uri';
const String _azaanCustomNotificationSourcePathKey =
    'azaan_custom_notification_source_path';
const String _androidPrayerChannelMigrationKey =
    'android_prayer_notification_channel_migration';
const int _androidPrayerChannelMigrationVersion = 3;
const String _androidPrayerChannelVersion = 'v3';

/// Why the most recent [initializeLocation] gave up, so callers can say
/// something more useful than "failed". Cleared on every success.
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

LocationFailure? lastLocationFailure;

/// When the position behind the current [lat] / [long] was actually measured.
///
/// Not the same as when we fetched it: [initializeLocation] falls back to
/// `getLastKnownPosition`, which can be hours or days old. Treating that as a
/// fresh reading would let a caller believe it has an up-to-date fix.
DateTime? lastLocationFixAt;

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
  if (!kIsWeb && Platform.isIOS) {
    // Custom audio has never actually worked on iOS: UNNotificationSound only
    // resolves names inside the app bundle or Library/Sounds, the picked file
    // was copied to Documents instead, and _iosPrayerNotificationDetails never
    // passed it along anyway — so every "custom" prayer silently played the
    // system default while Settings claimed otherwise. Android-only until
    // there is transcoding to back it up.
    if (option.isCustom) return false;
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

/// How far the device must move, in degrees, before the notification schedule
/// is worth rebuilding. Roughly 1 km, which shifts any prayer time by under two
/// seconds.
const double locationChangeThreshold = 0.01;

const String _scheduleAnchorLatKey = 'prayer_schedule_anchor_lat';
const String _scheduleAnchorLongKey = 'prayer_schedule_anchor_long';

/// Whether we have moved far enough from the position the current notification
/// schedule was built for to be worth rebuilding it.
///
/// Both callers — the check inside [initializeLocation] and
/// [shouldRefreshPrayerNotificationSchedule] — go through here, against the
/// same stored anchor, so they cannot disagree. Comparing against the anchor
/// rather than against the previous reading is what stops jitter accumulating:
/// a device wobbling either side of a boundary stays within the threshold of
/// the anchor and never triggers a rebuild.
bool hasPrayerScheduleLocationMoved() {
  if (lat == null || long == null) return false;
  if (!SP.isInitialized) return true;

  final anchorLat = SP.prefs.getDouble(_scheduleAnchorLatKey);
  final anchorLong = SP.prefs.getDouble(_scheduleAnchorLongKey);
  if (anchorLat == null || anchorLong == null) return true;

  return (anchorLat - lat!).abs() > locationChangeThreshold ||
      (anchorLong - long!).abs() > locationChangeThreshold;
}

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
    final soundKey = soundPreferenceKeyForPrayer(prayerName);
    final soundId = SP.prefs.getString(soundKey) ?? '';
    // The file a custom prayer points at is part of what the schedule was
    // built from: swapping the file without swapping the option would
    // otherwise leave the old sound scheduled.
    final customPath = soundId == 'custom'
        ? (SP.prefs.getString(customAudioPathKeyForPrayer(prayerName)) ?? '')
        : '';
    return '$key:${SP.prefs.getBool(key) == true ? 1 : 0}:$soundId:$customPath';
  }).join(',');
  final azaanId = resolveAzaanPreferenceIdForCurrentPlatform(
      SP.prefs.getString(azaanPreferenceKey));
  final customAudioPath =
      azaanId == 'custom' ? SP.prefs.getString(azaanCustomFilePathKey) : null;

  // Raw coordinates are deliberately absent: they are tracked by the schedule
  // anchor via hasPrayerScheduleLocationMoved(), which applies a distance
  // threshold. Any rounding of raw coordinates into this string would flip on
  // GPS jitter and force a full reschedule on the next app open.
  // Bumped to v10 when the Takbir Only iOS sound was renamed (see
  // AzaanOptions.takbir): the sound name is fixed at schedule time, so
  // already-scheduled notifications have to be rebuilt.
  return [
    'v10',
    'date:${_scheduleDateKey(scheduleDate ?? DateTime.now())}',
    'tz:${tz.local.name}',
    'azaan:$azaanId',
    'custom:${customAudioPath ?? ''}',
    'prayers:$enabledPrayerKeys',
    'times:${_scheduledPrayerMinutes(scheduleDate ?? DateTime.now())}',
  ].join('|');
}

/// Every minute the schedule would fire at, as the prayer times card and the
/// widgets show them.
///
/// A move under [locationChangeThreshold] shifts a prayer by a couple of
/// seconds, which is harmless until it straddles a rounding boundary: the card
/// then shows 7:02 while a notification scheduled from the anchor still says
/// and fires at 7:03. Carrying the minutes themselves means the schedule is
/// rebuilt exactly when a shown minute changes, and never otherwise.
String _scheduledPrayerMinutes(DateTime scheduleDate) {
  if (lat == null || long == null) return '';
  final prayers = getPrayerTimeObject();
  final days = prayerNotificationScheduleDays(
      enabledPrayerNotificationCount(getPrayerNotificationPrayerNames()));
  return [
    for (var day = 0; day < days; day++)
      for (final entry in buildPrayerNotificationEntriesForDay(
        prayerTime: prayers,
        date: scheduleDate.add(Duration(days: day)),
        latitude: lat!,
        longitude: long!,
      ))
        formatDate(entry.dateTime, [HH, nn]),
  ].join(',');
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

  if (hasPrayerScheduleLocationMoved()) return true;

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
// Flips to true once `items`/`itemOrder`/`itemMetadata` reflect a completed
// load attempt (success or failure) from assets/zikr.json, so UI that reads
// those maps (e.g. TodaysRecitationPage) can wait for them instead of
// racing a still-empty index on a slow first launch.
final ValueNotifier<bool> zikrIndexReady = ValueNotifier<bool>(false);
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
    {String source = ZikrOpenSource.unknown}) async {
  Widget? routeToPush;
  String contentType = 'universal';
  switch (itemData.type) {
    case 0:
      contentType = 'zikr';
      UidTitleData uidTitleData = UidTitleData(itemData.uid, itemData.title);
      routeToPush = ZikrPage(uidTitleData, source: source);
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
  if (contentType == 'library') {
    unawaited(AnalyticsService.libraryView(
      bookUid: itemData.uid,
      bookTitle: itemData.title,
    ));
  } else if (contentType == 'live-streaming') {
    unawaited(AnalyticsService.streamView(
      title: itemData.title,
      link: itemData.uid,
    ));
  }
  // Zikr is not logged here: ZikrPage logs its own view so the count is the
  // same whether the tap came from a list, the home grid, a shared link or a
  // link inside another zikr.
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
      lastLocationFailure = LocationFailure.serviceDisabled;
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
      lastLocationFailure =
          permissionStatus == LocationPermission.deniedForever
              ? LocationFailure.permissionDeniedForever
              : LocationFailure.permissionDenied;
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
      // Medium accuracy is a network/wifi fix rather than a GPS lock: it
      // returns in about a second instead of tens of seconds, and costs a
      // fraction of the battery. The precision it gives up is irrelevant here —
      // a few hundred metres moves any prayer time by well under a second.
      currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException catch (e) {
      if (lastKnownPosition != null) {
        debugPrint("Location request timed out; using last known position.");
        currentLocation = lastKnownPosition;
      } else {
        debugPrint("Location request timed out: $e");
        lastLocationFailure = LocationFailure.timeout;
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
        lastLocationFailure = LocationFailure.unknown;
        if (context != null && !kIsWeb) {
          _showLocationErrorDialog(context, e);
        }
        return false;
      }
    }
    lastLocationFailure = null;
    // A device clock ahead of ours would otherwise make a fix look permanently
    // fresh, so never accept a measurement timestamp from the future.
    final nowForFix = DateTime.now();
    final fixedAt = currentLocation.timestamp;
    lastLocationFixAt = fixedAt.isAfter(nowForFix) ? nowForFix : fixedAt;
    lat = currentLocation.latitude;
    long = currentLocation.longitude;
    final locationChanged = hasPrayerScheduleLocationMoved();
    if (locationChanged) {
      needToSchedule = true;
    }
    await SP.prefs.setDouble("lat", lat!);
    await SP.prefs.setDouble("long", long!);

    // The city label is cosmetic: prayer times are already correct at this
    // point regardless of what the geocoder says. So every failure below leaves
    // the previous label in place rather than degrading it — never coordinates,
    // never a dialog.
    try {
      final response = await http.get(Uri.parse(
          "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$long&localityLanguage=en"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resolvedCity =
            data['locality'] ?? data['city'] ?? data['principalSubdivision'];
        final resolvedLabel = _validateGeocodeResult(data, resolvedCity) ??
            _validateGeocodeResult(data, _geocodeFallbackLabel(data));
        if (resolvedLabel != null) {
          if (city != resolvedLabel) needToSchedule = true;
          city = resolvedLabel;
          await SP.prefs.setString("city", resolvedLabel);
        } else {
          debugPrint(
              "Geocode did not resolve a usable label ('$resolvedCity'); keeping ${city ?? 'no label'}.");
        }
      } else {
        debugPrint("Geocode returned status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error getting city: $e");
    }
    if (locationChanged && flutterLocalNotificationsPlugin != null && !kIsWeb) {
      await setUpNotifications();
      // Prayer-relative zikr reminders (e.g. "30 min after Maghrib") shift
      // with location exactly like Azan times do.
      await ZikrReminderService.instance.rescheduleAll();
    }
    return true;
  } catch (e) {
    debugPrint(e.toString());
    lastLocationFailure = LocationFailure.unknown;
    if (context != null && !kIsWeb) {
      _showLocationErrorDialog(context, e);
    }
    return false;
  }
}

/// Sanity-checks a reverse-geocode label before we show it.
///
/// The city name is display-only — prayer times are computed from lat/long, so
/// this guards a label, not a calculation, and it stays deliberately loose. A
/// two-letter `countryCode` means the coordinates landed in a real country,
/// which is what rules out the ocean fixes emulators produce at (0, 0). Nothing
/// more is required: demanding a populated `localityInfo.administrative` tree
/// on top of that rejected perfectly good names in city-states and small
/// territories, where the admin hierarchy is sparse.
String? _validateGeocodeResult(
    Map<String, dynamic> data, String? resolvedCity) {
  if (resolvedCity == null || resolvedCity.trim().isEmpty) return null;

  final trimmed = resolvedCity.trim();

  final countryCode =
      (data['countryCode'] ?? '').toString().trim().toUpperCase();
  if (countryCode.length != 2) return null;

  if (RegExp(r'^\d+\.?\d*\s*[ns]\s*\d+\.?\d*\s*[ew]$', caseSensitive: false)
      .hasMatch(trimmed)) {
    return null;
  }

  return trimmed;
}

/// Best readable label available from a geocode response when the primary
/// locality can't be used. Widens from the city outwards and gives up rather
/// than inventing something: returning null keeps whatever label we already
/// had, because a stale city name reads better than raw coordinates — and this
/// string is published to the home screen widget and watch complication.
String? _geocodeFallbackLabel(Map<String, dynamic> data) {
  for (final key in const [
    'locality',
    'city',
    'principalSubdivision',
    'countryName',
  ]) {
    final candidate = (data[key] ?? '').toString().trim();
    if (candidate.isNotEmpty) return candidate;
  }
  return null;
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

/// Which of [prayerNames] currently raise a notification.
///
/// The shared source for anything that needs to say *which* prayers are on —
/// [enabledPrayerNotificationCount] included — so a subtitle listing them by
/// name and a count summing them can never disagree.
List<String> enabledPrayerNotificationNames(List<String> prayerNames) {
  if (!SP.isInitialized) return const [];
  return prayerNames
      .where((prayerName) =>
          SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayerName)) ==
          true)
      .toList(growable: false);
}

int enabledPrayerNotificationCount(List<String> prayerNames) =>
    enabledPrayerNotificationNames(prayerNames).length;

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
  await Future.wait(notificationIds.map(AzanPlaybackService.cancel));
}

Future<void> setUpNotifications() async {
  debugPrint("Scheduling Azan Notifications");

  final plugin = flutterLocalNotificationsPlugin;
  if (plugin == null) return;
  await initializeNotificationTimeZone();
  await refreshLegacyAndroidPrayerNotificationChannelsIfNeeded();

  final prayerNames = getPrayerNotificationPrayerNames();
  final enabledPrayerCount = enabledPrayerNotificationCount(prayerNames);
  final scheduleDays = prayerNotificationScheduleDays(enabledPrayerCount);
  final scheduleFingerprint = buildPrayerNotificationScheduleFingerprint();

  await cancelPrayerNotifications();

  if (lat == null || long == null) {
    debugPrint("Skipping Azan notifications: location unavailable");
    await SP.prefs.remove(prayerNotificationScheduleFingerprintKey);
    await SP.prefs.remove(_scheduleAnchorLatKey);
    await SP.prefs.remove(_scheduleAnchorLongKey);
    return;
  }

  if (enabledPrayerCount == 0) {
    debugPrint("Skipping Azan notifications: all prayers disabled");
    await _storePrayerScheduleAnchor(scheduleFingerprint);
    return;
  }

  // Every route to an enabled prayer passes through here — the first-run
  // opt-in, the Settings switch, and a bell tapped on the prayer times card by
  // someone who declined at first run. Asking here means none of them can
  // schedule notifications the OS will silently drop. It costs nothing when
  // permission is already settled: neither platform re-prompts.
  await requestNotificationPermissions();

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
      final prayerAzaan = getAzaanOptionForPrayer(entry.name);
      schedulingTasks.add(schedulePrayerTimeNotification(
        (100 * (index + 1)) + i,
        entry.dateTime,
        entry.name,
        azaanId: prayerAzaan.id,
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
  await _storePrayerScheduleAnchor(scheduleFingerprint);
}

/// Records what this schedule was built from: the fingerprint, and the position
/// that future moves are measured against.
Future<void> _storePrayerScheduleAnchor(String scheduleFingerprint) async {
  await SP.prefs
      .setString(prayerNotificationScheduleFingerprintKey, scheduleFingerprint);
  if (lat != null && long != null) {
    await SP.prefs.setDouble(_scheduleAnchorLatKey, lat!);
    await SP.prefs.setDouble(_scheduleAnchorLongKey, long!);
  }
}

String _androidPrayerChannelId(AzaanOption azaan) {
  switch (azaan.id) {
    case 'takbir':
      return 'prayer_takbir_$_androidPrayerChannelVersion';
    case 'system_default':
      return 'prayer_system_default_$_androidPrayerChannelVersion';
    case 'silent':
      return 'prayer_silent_$_androidPrayerChannelVersion';
    case 'custom':
      // No longer keyed by the file (there is no longer a channel sound to
      // key at all - see _androidPrayerNotificationDetails), so every custom
      // choice shares this one channel instead of minting a new one per file.
      return 'prayer_custom_$_androidPrayerChannelVersion';
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
    // v2 -> v3: Full Azan's channel stopped carrying its own sound (the
    // audio now comes from AzanPlaybackService instead), which Android would
    // otherwise keep playing from the old channel's cached settings forever.
    'prayer_full_azaan_v2',
    'prayer_takbir_v2',
    'prayer_system_default_v2',
  };

  try {
    final channels = await androidImplementation.getNotificationChannels();
    for (final channel in channels ?? const <AndroidNotificationChannel>[]) {
      // Sweeps every per-file custom channel, current version included: a
      // device that already ran the build where Custom Audio still minted
      // one channel per file (before it shared the one fixed
      // prayer_custom_v3 channel below) would otherwise keep an orphaned
      // channel behind for each file it ever picked.
      if (channel.id.startsWith('prayer_custom_') &&
          channel.id != _androidPrayerChannelId(AzaanOptions.custom)) {
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
    case 'silent':
      return 'Prayer Times - Silent';
    case 'custom':
      return 'Prayer Times - Custom Sound';
    case 'azaan':
    default:
      return 'Prayer Times - Full Azan';
  }
}

Future<AndroidNotificationDetails> _androidPrayerNotificationDetails(
    AzaanOption azaan,
    {String? prayerName}) async {
  if (azaan.id == 'silent') {
    return AndroidNotificationDetails(
      _androidPrayerChannelId(azaan),
      _androidPrayerChannelName(azaan),
      channelDescription: 'Silent prayer time notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
    );
  }

  // Full Azan and Custom Audio both get no channel sound of their own:
  // AzanPlaybackService plays the real file as app-controlled audio instead
  // (see schedulePrayerTimeNotification), so a notification-channel sound
  // here would just be a second, competing copy racing it - and the whole
  // reason for that separate player is that a channel sound cannot outlast a
  // phone unlock or another app's ping the way real playback can.
  final playsViaAzanPlaybackService =
      azaan.id == AzaanOptions.azaan.id || azaan.id == AzaanOptions.custom.id;

  AndroidNotificationSound? sound;
  final androidFile = azaan.androidFile;
  if (!playsViaAzanPlaybackService && androidFile != null) {
    sound = RawResourceAndroidNotificationSound(androidFile);
  }

  return AndroidNotificationDetails(
    _androidPrayerChannelId(azaan),
    _androidPrayerChannelName(azaan),
    channelDescription: 'Prayer time notifications',
    importance: Importance.max,
    priority: Priority.high,
    sound: playsViaAzanPlaybackService ? null : sound,
    playSound: !playsViaAzanPlaybackService,
    enableVibration: true,
  );
}

DarwinNotificationDetails _iosPrayerNotificationDetails(AzaanOption azaan) {
  if (azaan.id == 'silent') {
    return const DarwinNotificationDetails(
      presentSound: false,
    );
  }
  if (azaan.id == 'system_default' || azaan.id == 'custom') {
    return DarwinNotificationDetails();
  }

  // Full Azan runs well past the ~30 seconds Apple allows a notification
  // sound to play before it silently falls back to the default system tone
  // (see handlePrayerNotificationResponse) - so on iOS its notification
  // always carries the Takbir Only clip instead, the same one that option
  // plays, rather than a sound of its own. The full recording still plays in
  // full once the user taps in; this is only about what they hear the
  // instant the notification itself arrives.
  return DarwinNotificationDetails(sound: AzaanOptions.takbir.iosFile);
}

Future<NotificationDetails> prayerNotificationDetails(
  AzaanOption azaan, {
  String? prayerName,
}) async {
  return NotificationDetails(
    android: Platform.isAndroid
        ? await _androidPrayerNotificationDetails(azaan, prayerName: prayerName)
        : null,
    iOS: Platform.isIOS ? _iosPrayerNotificationDetails(azaan) : null,
  );
}

/// The text under a prayer notification's title.
///
/// On iOS the Full Azan notification only carries the short Takbir clip (see
/// _iosPrayerNotificationDetails) and the full recording starts from a tap on
/// it, so the banner has to say so - nothing else on it does.
String prayerNotificationBody(String prayerName, AzaanOption azaan,
    {bool? isIOS}) {
  final body = "It's time for ${prayerName.toLowerCase()}";
  final onIOS = isIOS ?? (!kIsWeb && Platform.isIOS);
  if (onIOS && azaan.id == AzaanOptions.azaan.id) {
    return '$body · Tap to hear the full azan';
  }
  return body;
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

    final platformChannelSpecifics =
        await prayerNotificationDetails(azaan, prayerName: prayerName);

    await flutterLocalNotificationsPlugin?.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: canScheduleExactPrayerNotifications
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title:
            formatDate(dateTime, [hh, ":", nn, " ", am]) + " : " + prayerName,
        body: prayerNotificationBody(prayerName, azaan),
        payload: dateTime.toIso8601String());

    // Android only: the notification above is now silent for Full Azan and
    // Custom Audio (see _androidPrayerNotificationDetails), so this alarm is
    // what actually plays them, as real app-controlled audio that survives
    // being backgrounded rather than a notification sound any other ping can
    // cut off. iOS has no equivalent background trigger - there, full
    // playback starts from a tap on the notification instead (see
    // handlePrayerNotificationResponse); Custom Audio isn't offered on iOS
    // at all (see isAzaanOptionAvailableOnCurrentPlatform).
    if (azaan.id == AzaanOptions.azaan.id || azaan.id == AzaanOptions.custom.id) {
      await AzanPlaybackService.schedule(
        alarmId: id,
        fireTime: dateTime,
        prayerName: prayerName,
        exact: canScheduleExactPrayerNotifications,
        customFilePath: azaan.id == AzaanOptions.custom.id
            ? _customAudioPathForPlayback(prayerName)
            : null,
      );
    } else {
      await AzanPlaybackService.cancel(id);
    }
  } else {
    await flutterLocalNotificationsPlugin?.cancel(id: id);
    await AzanPlaybackService.cancel(id);
  }
}

/// The custom audio file a Full-Azan-or-Custom-Audio notification should
/// play through AzanPlaybackService, mirroring the same "own file, or follow
/// the app default" resolution [getCustomAudioFilePathForPrayer] already
/// does. Null (nothing recorded to play) is handled by AzanPlaybackService
/// itself, the same way a missing custom file has always degraded here.
String? _customAudioPathForPlayback(String? prayerName) {
  return prayerName != null
      ? getCustomAudioFilePathForPrayer(prayerName)
      : getCustomAudioFilePath();
}

/// Which prayer a scheduled prayer-time notification's id was built for -
/// the inverse of the `(100 * (prayerIndex + 1)) + dayOffset` scheme
/// [setUpNotifications] assigns ids with. Used to work out, when a
/// notification is tapped, which prayer (and so which Azan preference) it
/// was for.
String? prayerNameForNotificationId(int id) {
  final dayOffset = id % 100;
  // The reminder notification (id 786) and the test notification (id 999)
  // both sit inside the same (100 * (prayerIndex + 1)) + dayOffset range as
  // real prayer ids and would otherwise decode to whichever prayer happens
  // to occupy that slot. Real schedules never run a month out, so a
  // generously-bounded dayOffset is enough to tell them apart without
  // hardcoding those two ids specifically.
  if (dayOffset >= 31) return null;

  final prayerNames = getPrayerNotificationPrayerNames();
  final prayerIndex = (id ~/ 100) - 1;
  if (prayerIndex < 0 || prayerIndex >= prayerNames.length) return null;
  return prayerNames[prayerIndex];
}

/// Starts the full Azan when a tapped notification was for a prayer whose
/// chosen sound is Full Azan or Custom Audio.
///
/// This is iOS's only trigger for full-length Full-Azan playback: the
/// platform has no background alarm equivalent to Android's, so its
/// notification sound stays capped at the ~30 seconds Apple allows, and this
/// is what plays the rest once the user actually opens it (Custom Audio
/// isn't offered on iOS at all). On Android it doubles as a way to replay an
/// Azan that already finished.
///
/// Shared by the foreground callback and
/// [handlePrayerNotificationResponseBackground] - flutter_local_notifications
/// invokes whichever one matches where the tap arrived.
Future<void> handlePrayerNotificationResponse(
    NotificationResponse response) async {
  final payload = response.payload;
  if (payload != null &&
      payload.startsWith(ZikrReminderService.payloadPrefix)) {
    await _openZikrReminderNotification(
      payload.substring(ZikrReminderService.payloadPrefix.length),
    );
    return;
  }

  final id = response.id;
  if (id == null) return;
  final prayerName = prayerNameForNotificationId(id);
  if (prayerName == null) return;

  // Tapping a prayer notification while the app is already running (the
  // common case: backgrounded, not terminated) resumes it on whatever
  // screen it was left on, not the home page - and the Full Azan banner
  // and stop control only live on the home page's Scaffold (see
  // AzanPlayingBanner). Without this, a reader who tapped the notification
  // to silence the Azan had to manually navigate back to home first. A
  // terminated-app launch already lands on home for free, so this is a
  // no-op there. No-op too from the background isolate
  // (handlePrayerNotificationResponseBackground) - there is no navigator
  // attached to appNavigatorKey outside the main isolate.
  appNavigatorKey.currentState?.popUntil((route) => route.isFirst);

  final azaan = getAzaanOptionForPrayer(prayerName);
  if (azaan.id != AzaanOptions.azaan.id && azaan.id != AzaanOptions.custom.id) {
    return;
  }
  await AzanPlaybackService.playNow(
    prayerName: prayerName,
    customFilePath: azaan.id == AzaanOptions.custom.id
        ? _customAudioPathForPlayback(prayerName)
        : null,
  );
}

/// Opens what a tapped zikr reminder notification was for: the linked zikr
/// itself when it was created by picking one from the library, or just the
/// app's home page for a free-text reminder with nothing to open directly.
///
/// Meant only for the main isolate (a foreground tap, or the
/// launched-from-terminated path in home_page.dart that runs once the app is
/// up, both after `SP.init()`) - [appNavigatorKey] has no navigator attached
/// from the background isolate [handlePrayerNotificationResponseBackground]
/// can run in, and that isolate never called `SP.init()` either, so this
/// bails out on the same `SP.isInitialized` guard the rest of this file uses
/// rather than crashing on the unguarded `SP.prefs` read underneath.
Future<void> _openZikrReminderNotification(String reminderId) async {
  if (!SP.isInitialized) return;
  final reminder = await ZikrReminderService.instance.byId(reminderId);
  if (reminder == null) return;

  final zikrUid = reminder.zikrUid;
  final title = zikrUid == null ? null : items[zikrUid];
  if (zikrUid != null && title is String && title.isNotEmpty) {
    pushRootPageRoute(ZikrPage(
      UidTitleData(zikrUid, title),
      source: ZikrOpenSource.reminder,
    ));
    return;
  }

  // The home page is already the navigator's root route - just surface it
  // rather than pushing the reminders list on top of it.
  appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}

/// Background-isolate counterpart of [handlePrayerNotificationResponse], for
/// a tap that arrives while the app process isn't already running.
/// flutter_local_notifications requires this to be a distinct top-level
/// function carrying this pragma.
@pragma('vm:entry-point')
void handlePrayerNotificationResponseBackground(
    NotificationResponse response) {
  handlePrayerNotificationResponse(response);
}

/// Which azaan a preview should actually play.
///
/// [azaanId] is always the sound the caller is trying to preview and wins
/// whenever it is given - the sound picker passes one for every concrete
/// option, including when previewing a per-prayer sound that differs from
/// what that prayer is actually configured to play. [prayerName] alone (no
/// azaanId) is what a real prayer notification's own preview - one with
/// nothing explicit chosen - resolves through instead. Putting prayerName
/// first used to mean every preview in the per-prayer picker ignored the
/// tapped option and played whatever that prayer was already set to - e.g.
/// tapping "preview" on System Default would play a Full Azan the prayer
/// happened to have saved.
AzaanOption azaanOptionForPreview({String? azaanId, String? prayerName}) {
  if (azaanId != null) return resolveAzaanOptionForCurrentPlatform(azaanId);
  if (prayerName != null) return getAzaanOptionForPrayer(prayerName);
  return getSelectedAzaan();
}

/// Fires a sample notification.
///
/// [prayerName] makes it preview what that prayer will actually sound like —
/// its own override, or the default it is following. Without it the test could
/// only ever play the global sound, which is the one thing a user who has just
/// set a per-prayer sound is not trying to check.
Future<void> testNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    {String? azaanId,
    String? prayerName}) async {
  await initializeNotificationTimeZone();
  final azaan = azaanOptionForPreview(azaanId: azaanId, prayerName: prayerName);

  final platformChannelSpecifics =
      await prayerNotificationDetails(azaan, prayerName: prayerName);

  // Full Azan and Custom Audio no longer carry their own notification sound
  // (see _androidPrayerNotificationDetails) - without this, testing either
  // choice would fire a silent notification and the person trying it would
  // hear nothing at all.
  if (azaan.id == AzaanOptions.azaan.id || azaan.id == AzaanOptions.custom.id) {
    unawaited(AzanPlaybackService.playNow(
      prayerName: prayerName ?? 'Prayer',
      customFilePath: azaan.id == AzaanOptions.custom.id
          ? _customAudioPathForPlayback(prayerName)
          : null,
    ));
  }

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

/// The one spelling every per-prayer preference key is built from.
///
/// Zuhr and Dhuhr are the same prayer under two names, and the stored key has
/// always been the Dhuhr one. Centralised so the three key builders below
/// cannot drift apart.
String _normalizedPrayerKeyName(String prayerName) {
  final normalizedName = prayerName.trim().toLowerCase();
  if (normalizedName == 'dhuhr' || normalizedName == 'zuhr') return 'dhuhr';
  return normalizedName;
}

String notificationPreferenceKeyForPrayer(String prayerName) {
  return '${_normalizedPrayerKeyName(prayerName)}_notification';
}

String soundPreferenceKeyForPrayer(String prayerName) {
  return '${_normalizedPrayerKeyName(prayerName)}_notification_sound';
}

/// Where one prayer's own custom audio file is recorded.
///
/// Custom audio used to be global-only — a single file and a single pointer to
/// it — so a per-prayer "custom" choice had nothing of its own to name and was
/// made to fall back to the app default. Each prayer now owns a path.
String customAudioPathKeyForPrayer(String prayerName) {
  return '${_normalizedPrayerKeyName(prayerName)}_notification_sound_custom_path';
}

/// Returns the effective azaan option for a specific prayer time.
/// Defaults to global [getSelectedAzaan()] if not set or if set to 'app_default'.
AzaanOption getAzaanOptionForPrayer(String prayerName) {
  if (!SP.isInitialized) return getSelectedAzaan();
  final key = soundPreferenceKeyForPrayer(prayerName);
  final soundId = SP.prefs.getString(key);
  if (soundId == null || soundId.isEmpty || soundId == 'app_default') {
    return getSelectedAzaan();
  }
  final resolved = resolveAzaanOptionForCurrentPlatform(soundId);
  // A per-prayer custom choice is honoured only while a file is still recorded
  // for it. With nothing to point at there is no sound to play, so fall back
  // to the app default rather than scheduling a silent notification.
  if (resolved.isCustom) {
    final path = getCustomAudioFilePathForPrayer(prayerName);
    if (path == null || path.isEmpty) return getSelectedAzaan();
  }
  return resolved;
}

/// The custom audio file a given prayer should actually play, if any.
///
/// A prayer following the app default inherits whatever the global preference
/// points at; a prayer that chose custom for itself uses its own file.
String? getCustomAudioFilePathForPrayer(String prayerName) {
  if (!SP.isInitialized) return null;
  final soundId = SP.prefs.getString(soundPreferenceKeyForPrayer(prayerName));
  if (soundId == null || soundId.isEmpty || soundId == 'app_default') {
    return getCustomAudioFilePath();
  }
  if (soundId != 'custom') return null;

  final path = SP.prefs.getString(customAudioPathKeyForPrayer(prayerName));
  return (path == null || path.isEmpty) ? null : path;
}

/// Records the custom audio file for one prayer.
Future<void> saveCustomAudioFilePathForPrayer(
    String prayerName, String filePath) async {
  if (!SP.isInitialized) return;
  await SP.prefs.setString(customAudioPathKeyForPrayer(prayerName), filePath);
}

/// Returns true if this specific prayer has a custom sound chosen,
/// rather than following the app's global notification sound.
bool hasCustomAzaanPreferenceForPrayer(String prayerName) {
  if (!SP.isInitialized) return false;
  final key = soundPreferenceKeyForPrayer(prayerName);
  final soundId = SP.prefs.getString(key);
  return soundId != null && soundId.isNotEmpty && soundId != 'app_default';
}

/// Saves the sound preference for a specific prayer time.
/// Pass 'app_default' to reset to following the global setting.
Future<void> saveAzaanPreferenceForPrayer(
    String prayerName, String soundId) async {
  if (!SP.isInitialized) return;
  final key = soundPreferenceKeyForPrayer(prayerName);
  if (soundId == 'app_default') {
    await SP.prefs.remove(key);
  } else {
    await SP.prefs.setString(key, soundId);
  }
}

/// Asks the OS for permission to post notifications.
///
/// Prayer reminders are the only thing the app notifies about, so this is
/// deliberately not called at start-up for a user who has never opted into
/// azan — see [AzaanOptInService]. Both the first-run opt-in and the Settings
/// switch come through here when azan is turned on.
Future<void> requestNotificationPermissions() async {
  if (flutterLocalNotificationsPlugin == null) return;

  final iosImplementation =
      flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
  await iosImplementation?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

  final androidImplementation =
      flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidImplementation?.requestNotificationsPermission();
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
  unawaited(AnalyticsService.feature(
    'azaan_selected',
    label: 'Azaan changed',
    parameters: {'azaan_id': azaanId},
  ));
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
}) {
  // Screens call this unawaited from initState, so the missing-Firebase guard
  // and the swallowed failures both live in AnalyticsService — no app, no
  // analytics, rather than an unhandled async error taking the screen down.
  return AnalyticsService.screen(screenName, deferOnWeb: deferOnWeb);
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
