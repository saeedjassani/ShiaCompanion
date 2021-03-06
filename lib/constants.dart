import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as location;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/live_streaming_page.dart';
import 'package:shia_companion/pages/qibla_finder.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:date_format/date_format.dart';
import 'data/live_streaming_data.dart';
import 'data/uid_title_data.dart';
import 'pages/chapter_list_page.dart';
import 'pages/item_page.dart';
import 'pages/list_items.dart';
import 'pages/news_page.dart';
import 'pages/video_player.dart';
import 'widgets/tasbeeh_widget.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

double screenWidth = 0;
double screenHeight = 0;

User user;

List<UniversalData> favsData;

final String appName = "Shia Companion";
int hijriDate = 0;
double arabicFontSize = 32.0;
double englishFontSize = 16.0;
bool screenOn;

PrayerTime prayerTime;
String city;
double lat, long;
bool needToSchedule = true;

SharedPreferences sharedPreferences;

PrayerTime getPrayerTimeObject() {
  if (prayerTime != null) return prayerTime;

  prayerTime = PrayerTime();

  prayerTime.setCalcMethod(prayerTime.getJafari());
  prayerTime.setAsrJuristic(prayerTime.getHanafi());
  prayerTime.setAdjustHighLats(prayerTime.getAdjustHighLats());

  return prayerTime;
}

TextStyle smallText = TextStyle(fontSize: 14);
TextStyle boldText = TextStyle(fontWeight: FontWeight.bold);

bool showTranslation = true, showTransliteration = true;
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
List tableCode = [
  ItemList("F"),
  ItemList("E"),
  ItemList("G"),
  ItemList("A"),
  ItemList("C"),
  ItemList("H"),
  ItemList("I"),
  ItemList("B"),
  LiveStreamingPage(0),
  LiveStreamingPage(1),
  NewsPage(),
  QiblaFinder(),
  TasbeehWidget(),
];

List<String> zikr = [
  "Namaz",
  "Duas",
  "Ziyarats",
  "Surahs",
  "Amaal",
  "Munajaats",
  "Baaqeyaat As Saalehaat",
  "Ziyarat of Hijaz, Iran & Iraq",
  "Holy Shrines",
  "Islamic Channels",
  "Latest Shia News",
  "Qibla Finder",
  "Tasbeeh Counter",
];

List<String> zikrImages = [
  "assets/images/namaz_home_min.jpg",
  "assets/images/dua_home.jpg",
  "assets/images/najaf_min.jpg",
  "assets/images/surah_home.jpg",
  "assets/images/amaal.jpg",
  "assets/images/munajat_home.jpg",
  "assets/images/taaqebaat_namaz.jpg",
  "assets/images/amaal.jpg",
  "assets/images/mashhad_min.jpg",
  "assets/images/zainabia_channel.jpg",
  "assets/images/sc_news.png",
  "assets/images/qibla_finder.png",
  "assets/images/counter.png",
];

Map items = {};
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// HomePage key
GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

void handleUniversalDataClick(BuildContext context, UniversalData itemData) {
  switch (itemData.type) {
    case 0:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ItemPage(UidTitleData(itemData.uid, itemData.title))));
      break;
    case 1:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ChapterListPage(itemData.uid, itemData.title)));
      break;
    case 2:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => VideoPlayer(
                  LiveStreamingData(itemData.uid, itemData.title, null))));
      break;
    default:
  }
}

initializeLocation() async {
  try {
    location.LocationData currentLocation =
        await location.Location().getLocation();
    if (currentLocation != null) {
      lat = currentLocation.latitude;
      long = currentLocation.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks != null && placemarks.isNotEmpty) {
        city = placemarks[0].locality;

        if (sharedPreferences.getString("city") != city) needToSchedule = true;

        sharedPreferences.setDouble("lat", currentLocation.latitude);
        sharedPreferences.setDouble("long", currentLocation.longitude);
        sharedPreferences.setString("city", placemarks[0].locality);
      }
    }
  } catch (e) {
    debugPrint(e);
  }
}

void setUpNotifications() async {
  debugPrint("Scheduling Azan Notifications");

  PrayerTime prayers = getPrayerTimeObject();
  prayers.setTimeFormat(prayers.getTime24());

  DateTime now = DateTime.now();
  for (int i = 0; i < 12; i++) {
    DateTime temp = now.add(Duration(days: i));
    List<String> prayerTimes = prayers.getPrayerTimes(
        temp, lat, long, temp.timeZoneOffset.inMinutes / 60.0);

    var _prayerNames = prayers.getTimeNames();
    _prayerNames.asMap().forEach((index, prayerName) =>
        schedulePrayerTimeNotification(
            (100 * (index + 1)) + i,
            DateTime.parse(
                "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[index]}"),
            prayerName,
            prayerTimes[index]));
  }
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails("general", "General", "General notifications");
  IOSNotificationDetails iOSPlatformChannelSpecifics = IOSNotificationDetails();
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.zonedSchedule(
      786,
      "Open the app to continue getting Azan notifications",
      "It seems you've not used the application in last 12 days. Please open the app to continue receive Azan notifications",
      tz.TZDateTime.now(tz.local).add(Duration(days: 11)),
      platformChannelSpecifics,
      androidAllowWhileIdle: false,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      payload: now.add(Duration(days: 11)).millisecondsSinceEpoch.toString());
}

void schedulePrayerTimeNotification(
    int id, DateTime dateTime, String prayerName, String prayerTime) async {
  if (dateTime.difference(DateTime.now()).isNegative ||
      sharedPreferences == null) return;
  if (sharedPreferences.getBool(prayerName.toLowerCase() + "_notification")) {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayerTimes',
      'Prayer Times',
      'Azan Notifications for Prayer Times',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('sharif'),
    );
    IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails(sound: 'azan.caf');
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        formatDate(dateTime, [hh, ":", nn, " ", am]) + " : " + prayerName,
        "It's time for " + prayerName.toLowerCase(),
        tz.TZDateTime.from(dateTime, tz.local),
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime);
  } else {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}

void testNotification() async {
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'prayerTimes',
    'Prayer Times',
    'Azan Notifications for Prayer Times',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('sharif'),
  );
  IOSNotificationDetails iOSPlatformChannelSpecifics =
      IOSNotificationDetails(sound: 'azan.caf');
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.zonedSchedule(
      999,
      "Test",
      "Test notification",
      tz.TZDateTime.now(tz.local).add(Duration(minutes: 1)),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime);
}
