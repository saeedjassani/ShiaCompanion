import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location/location.dart' as location;
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/item_page.dart';
import 'package:shia_companion/pages/qibla_finder.dart';
import 'package:http/http.dart' as http;
import 'pages/calendar_page.dart';
import 'pages/library_page.dart';
import 'package:date_format/date_format.dart';
import 'package:shia_companion/pages/zikr_page.dart';
import 'data/live_streaming_data.dart';
import 'data/uid_title_data.dart';
import 'pages/chapter_list_page.dart';

import 'pages/list_items.dart';
import 'pages/video_player.dart';
import 'pages/favorites_page.dart';
import 'pages/todays_recitation_page.dart';
import 'package:shia_companion/pages/settings_page.dart';
import 'utils/shared_preferences.dart';
import 'widgets/tasbeeh_widget.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:flutter/cupertino.dart';

double screenWidth = 0;
double screenHeight = 0;

User? user;
bool isUserAdmin = false;

List<UniversalData>? favsData;

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

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
TextStyle smallText = TextStyle(fontSize: 14);
TextStyle boldText = TextStyle(fontWeight: FontWeight.bold);
String appVersion = '1.0';

bool showTranslation = true, showTransliteration = true;

bool shouldUseLiveLocation() {
  if (!SP.isInitialized) return false;
  return SP.prefs.getBool('use_live_location') ?? false;
}

// Helper to map a tile label to a freshly-built page instance.
Widget getPage(String label,
    {Future<void> Function()? loginCallback,
    bool scrollToPrayerTimes = false}) {
  switch (label) {
    case 'Favorites':
      return FavoritesPage();
    case "Today's Recitations":
      return TodaysRecitationPage();
    case 'Taqeebat e Namaz':
      return ItemList("D", "Taqeebat e Namaz");
    case 'Namaz':
      return ItemList("F", "Namaz");
    case 'Duas':
      return ItemList("E", "Duas");
    case 'Ziyarats':
      return ItemList("G", "Ziyarats");
    case 'Surahs':
      return ItemList("A", "Surahs");
    case 'Aamaal':
      return ItemList("C", "Aamaal");
    case 'Calendar':
      return Scaffold(
          appBar: AppBar(title: Text('Calendar')),
          body: CalendarPage(scrollToPrayerTimes));
    case 'Library':
      return Scaffold(
          appBar: AppBar(title: Text('Library')), body: LibraryPage());
    case 'Munajaats':
      return ItemList("H", "Munajaats");
    case 'Baaqeyaat As Saalehaat':
      return ItemList("I", "Baaqeyaat As Saalehaat");
    case 'Qibla Finder':
      return QiblaFinder();
    case 'Tasbeeh Counter':
      return TasbeehWidget();
    case 'Preferences':
      // SettingsPage expects a loginCallback; we pass it through when available
      return Scaffold(
          appBar: AppBar(title: Text('Preferences')),
          body: SettingsPage(loginCallback ?? () async {}));
    default:
      return Container();
  }
}

List<String> zikr = [
  "Favorites",
  "Today's Recitations",
  "Taqeebat e Namaz",
  "Namaz",
  "Duas",
  "Ziyarats",
  "Surahs",
  "Aamaal",
  "Calendar",
  "Library",
  "Munajaat",
  "Baaqeyaat As Saalehaat",
  "Qibla Finder",
  "Tasbeeh Counter",
  "Preferences",
];

// Icon mapping used for responsive grid in Home Page. Picked from Material icons
List<IconData> zikrIcons = [
  Icons.favorite, // Favorites
  Icons.book, // Today's Recitations
  Icons.bookmark, // Namaz
  Icons.wb_sunny, // Namaz
  Icons.menu_book, // Duas
  Icons.mosque, // Ziyarats
  Icons.menu_book, // Surahs
  Icons.check_circle, // Amaal
  Icons.calendar_today, // Calendar
  Icons.library_books, // Library
  Icons.menu_book, // Munajaats (Library book icon)
  Icons.list_alt, // Baaqeyaat As Saalehaat
  Icons.explore, // Qibla Finder
  tasbeehCounterIcon, // Tasbeeh Counter
  Icons.settings, // Preferences
];

PrayerTime? prayerTime;

PrayerTime getPrayerTimeObject() {
  if (prayerTime != null) return prayerTime!;

  prayerTime = PrayerTime();

  prayerTime!.setCalcMethod(prayerTime!.getJafari());
  prayerTime!.setAsrJuristic(prayerTime!.getHanafi());
  prayerTime!.setAdjustHighLats(prayerTime!.getAdjustHighLats());

  return prayerTime!;
}

Map items = {};
Map<String, double> itemOrder = {};
Map<String, String> itemSlugs = {};
Map<String, List<String>> itemSlugAliases = {};
Map<String, String> slugToItemUid = {};
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

String normalizeSlug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), ' ')
      .replaceAll(RegExp(r'[_\s]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String slugifyTitle(String title) => normalizeSlug(title);

String slugifyUid(String uid) {
  return uid
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String buildSlugSeed({
  required String uid,
  required String title,
  String? rawSlug,
}) {
  final preferredSlug = normalizeSlug(rawSlug ?? '');
  if (preferredSlug.isNotEmpty) return preferredSlug;

  final titleSlug = slugifyTitle(title);
  if (titleSlug.isNotEmpty) return titleSlug;

  return slugifyUid(uid);
}

bool isSlugAvailable(String slug, {String? currentUid}) {
  final owner = slugToItemUid[slug];
  return owner == null || owner == currentUid;
}

String makeUniqueSlug(String baseSlug, {String? currentUid}) {
  final normalizedBase = normalizeSlug(baseSlug);
  final fallbackBase = normalizedBase.isNotEmpty
      ? normalizedBase
      : (currentUid == null ? 'zikr' : slugifyUid(currentUid));
  if (isSlugAvailable(fallbackBase, currentUid: currentUid)) {
    return fallbackBase;
  }

  var suffix = 2;
  while (true) {
    final candidate = '$fallbackBase-$suffix';
    if (isSlugAvailable(candidate, currentUid: currentUid)) {
      return candidate;
    }
    suffix++;
  }
}

List<String> normalizeSlugAliases(
  Iterable<dynamic>? values, {
  String? exclude,
}) {
  final normalizedExclude = normalizeSlug(exclude ?? '');
  final aliases = <String>[];
  final seen = <String>{};

  for (final value in values ?? const []) {
    final alias = normalizeSlug(value?.toString() ?? '');
    if (alias.isEmpty || alias == normalizedExclude || !seen.add(alias)) {
      continue;
    }
    aliases.add(alias);
  }

  return aliases;
}

void clearLocalSlugMaps() {
  itemSlugs = {};
  itemSlugAliases = {};
  slugToItemUid = {};
}

void removeLocalSlugData(String uid) {
  final previousSlug = itemSlugs.remove(uid);
  if (previousSlug != null && slugToItemUid[previousSlug] == uid) {
    slugToItemUid.remove(previousSlug);
  }

  final previousAliases = itemSlugAliases.remove(uid) ?? const <String>[];
  for (final alias in previousAliases) {
    if (slugToItemUid[alias] == uid) {
      slugToItemUid.remove(alias);
    }
  }
}

void setLocalSlugData(
  String uid, {
  String? slug,
  Iterable<dynamic>? aliases,
}) {
  removeLocalSlugData(uid);

  final normalizedSlug = normalizeSlug(slug ?? '');
  final normalizedAliases =
      normalizeSlugAliases(aliases, exclude: normalizedSlug);

  if (normalizedSlug.isNotEmpty) {
    itemSlugs[uid] = normalizedSlug;
    slugToItemUid[normalizedSlug] = uid;
  }
  if (normalizedAliases.isNotEmpty) {
    itemSlugAliases[uid] = normalizedAliases;
    for (final alias in normalizedAliases) {
      slugToItemUid[alias] = uid;
    }
  }
}

void applySlugLookupMap(
    Map<dynamic, dynamic>? rawLookup, Set<String> allowedUids) {
  if (rawLookup == null) return;

  rawLookup.forEach((rawSlug, rawUid) {
    final slug = normalizeSlug(rawSlug?.toString() ?? '');
    final uid = rawUid?.toString() ?? '';
    if (slug.isEmpty || uid.isEmpty || !allowedUids.contains(uid)) {
      return;
    }
    slugToItemUid[slug] = uid;
  });
}

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
            'Prayer times are unique to your location. We need your location to provide accurate prayer times for your area.',
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
    // On manual refresh, we want to show some feedback.
    // TODO For now, let's just print to debug, but could use a state management solution.
    location.LocationData currentLocation =
        await location.Location().getLocation();
    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return false;
    }
    lat = currentLocation.latitude;
    long = currentLocation.longitude;
    await SP.prefs.setDouble("lat", lat!);
    await SP.prefs.setDouble("long", long!);

    try {
      final response = await http.get(Uri.parse(
          "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$long&localityLanguage=en"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        city = data['locality'] ?? data['city'] ?? data['principalSubdivision'];
        if (SP.prefs.getString("city") != city) needToSchedule = true;
        if (city != null) await SP.prefs.setString("city", city!);
      }
    } catch (e) {
      debugPrint("Error getting city: $e");
    }
    return true;
  } catch (e) {
    debugPrint(e.toString());
    return false;
  }
}

void setUpNotifications() async {
  debugPrint("Scheduling Azan Notifications");

  DateTime now = DateTime.now();
  PrayerTime prayers = getPrayerTimeObject();
  prayers.setTimeFormat(prayers.getTime24());
  for (int i = 0; i < 12; i++) {
    DateTime temp = now.add(Duration(days: i));
    List<String> prayerTimes = prayers.getPrayerTimes(
        temp, lat!, long!, temp.timeZoneOffset.inMinutes / 60.0);

    List<String> _prayerNames = prayers.getTimeNames();
    _prayerNames
        .asMap()
        .forEach((index, prayerName) => schedulePrayerTimeNotification(
              (100 * (index + 1)) + i,
              DateTime.parse(
                  "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[index]}"),
              prayerName,
            ));
  }
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails("general", "General");
  DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails();
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin?.zonedSchedule(
      id: 786,
      title: "Open the app to continue getting Azan notifications",
      body:
          "It seems you've not used the application in last 12 days. Please open the app to continue receive Azan notifications",
      scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(days: 11)),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexact,
      payload: now.add(Duration(days: 11)).millisecondsSinceEpoch.toString());
}

void schedulePrayerTimeNotification(
    int id, DateTime dateTime, String prayerName) async {
  if (dateTime.difference(DateTime.now()).isNegative) return;
  if (SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayerName)) ==
      true) {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayerTimes',
      'Prayer Times',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('sharif'),
    );
    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(sound: 'azan.caf');
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin?.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: canScheduleExactPrayerNotifications
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title:
            formatDate(dateTime, [hh, ":", nn, " ", am]) + " : " + prayerName,
        body: "It's time for " + prayerName.toLowerCase());
  } else {
    await flutterLocalNotificationsPlugin?.cancel(id: id);
  }
}

void testNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'prayerTimes',
    'Prayer Times',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('sharif'),
  );
  DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(sound: 'azan.caf');
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 999,
      scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(minutes: 1)),
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
      await androidImplementation.requestExactAlarmsPermission() ?? false;
  return canScheduleExactPrayerNotifications;
}

AppBar getAppBar() {
  return AppBar(
    title: Text(appName),
  );
}

Icon getFavIcon(BuildContext context, UniversalData itemData) {
  return favsData!.contains(itemData)
      ? Icon(
          Icons.star,
          color: Theme.of(context).colorScheme.primary,
        )
      : Icon(
          Icons.star_border,
          color: Theme.of(context).colorScheme.primary,
        );
}

Future<void> trackScreen(String screenName) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'screen_view',
    parameters: {'screen_name': screenName},
  );
}

// Platform-aware route push that supports back navigation
Future<T?> pushPageRoute<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    kIsWeb
        ? MaterialPageRoute(builder: (context) => page)
        : CupertinoPageRoute(builder: (context) => page),
  );
}
