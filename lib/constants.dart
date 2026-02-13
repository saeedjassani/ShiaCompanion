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
import 'pages/news_page.dart';
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
int hijriDate = 0;
double arabicFontSize = 32.0;
double englishFontSize = 16.0;

String? city;
double? lat, long;
bool needToSchedule = true;
String arabicFont = "Qalam";

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
TextStyle smallText = TextStyle(fontSize: 14);
TextStyle boldText = TextStyle(fontWeight: FontWeight.bold);
String appVersion = '1.0';

bool showTranslation = true, showTransliteration = true;

// Helper to map a tile label to a freshly-built page instance.
Widget getPage(String label, {Function()? loginCallback, bool scrollToPrayerTimes = false}) {
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
    case 'Amaal':
      return ItemList("C", "Amaal");
    case 'Calendar':
      return Scaffold(appBar: AppBar(title: Text('Calendar')), body: CalendarPage(scrollToPrayerTimes));
    case 'Library':
      return Scaffold(appBar: AppBar(title: Text('Library')), body: LibraryPage());
    case 'Munajaats':
      return ItemList("H", "Munajaats");
    case 'Baaqeyaat As Saalehaat':
      return ItemList("I", "Baaqeyaat As Saalehaat");
    case 'Latest Shia News':
      return NewsPage();
    case 'Qibla Finder':
      return QiblaFinder();
    case 'Tasbeeh Counter':
      return TasbeehWidget();
    case 'Preferences':
      // SettingsPage expects a loginCallback; we pass it through when available
      return Scaffold(appBar: AppBar(title: Text('Preferences')), body: SettingsPage(loginCallback ?? () {}));
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
  "Amaal",
  "Calendar",
  "Library",
  "Munajaats",
  "Baaqeyaat As Saalehaat",
  "Latest Shia News",
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
  Icons.article, // Latest Shia News
  Icons.explore, // Qibla Finder
  Icons.format_list_numbered, // Tasbeeh Counter
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
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void handleUniversalDataClick(BuildContext context, UniversalData itemData,
    {bool itemPage = false}) {
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
    pushPageRoute(context, routeToPush);
  }
}

Future<bool> initializeLocation({bool force = false}) async {
  // If we are not forcing a refresh and we already have lat/long, just return.
  if (!force && lat != null && long != null) {
    return true;
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
      786,
      "Open the app to continue getting Azan notifications",
      "It seems you've not used the application in last 12 days. Please open the app to continue receive Azan notifications",
      tz.TZDateTime.now(tz.local).add(Duration(days: 11)),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexact,
      payload: now.add(Duration(days: 11)).millisecondsSinceEpoch.toString());
}

void schedulePrayerTimeNotification(
    int id, DateTime dateTime, String prayerName) async {
  if (dateTime.difference(DateTime.now()).isNegative) return;
  if (SP.prefs.getBool(prayerName.toLowerCase() + "_notification") == true) {
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
        id,
        formatDate(dateTime, [hh, ":", nn, " ", am]) + " : " + prayerName,
        "It's time for " + prayerName.toLowerCase(),
        tz.TZDateTime.from(dateTime, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
  } else {
    await flutterLocalNotificationsPlugin?.cancel(id);
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
      999,
      "Test",
      "Test notification",
      tz.TZDateTime.now(tz.local).add(Duration(minutes: 1)),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
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

Future<void> trackItemViewed(String itemId, String itemTitle, String itemType) async {
  await FirebaseAnalytics.instance.logViewItem(
    items: [
      AnalyticsEventItem(
        itemId: itemId,
        itemName: itemTitle,
        itemCategory: itemType,
      ),
    ],
  );
}

Future<void> trackFavoriteAdded(String itemId, String itemTitle, String itemType) async {
  await FirebaseAnalytics.instance.logAddToWishlist(
    items: [
      AnalyticsEventItem(
        itemId: itemId,
        itemName: itemTitle,
        itemCategory: itemType,
      ),
    ],
  );
}

Future<void> trackFavoriteRemoved(String itemId, String itemTitle, String itemType) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'remove_from_wishlist',
    parameters: {
      'item_id': itemId,
      'item_title': itemTitle,
      'item_type': itemType,
    },
  );
}

Future<void> trackZikrStarted(String zikrId, String zikrTitle) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'zikr_started',
    parameters: {
      'zikr_id': zikrId,
      'zikr_title': zikrTitle,
    },
  );
}
// Platform-aware route push that supports back navigation
void pushPageRoute(BuildContext context, Widget page) {
  Navigator.push(
    context,
    kIsWeb
        ? MaterialPageRoute(builder: (context) => page)
        : CupertinoPageRoute(builder: (context) => page),
  );
}
