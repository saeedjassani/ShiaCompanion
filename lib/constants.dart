import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as location;
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/item_page.dart';
import 'package:shia_companion/pages/live_streaming_page.dart';
import 'package:shia_companion/pages/qibla_finder.dart';
import 'package:date_format/date_format.dart';
import 'package:shia_companion/pages/zikr_page.dart';
import 'data/live_streaming_data.dart';
import 'data/uid_title_data.dart';
import 'pages/chapter_list_page.dart';

import 'pages/list_items.dart';
import 'pages/news_page.dart';
import 'pages/video_player.dart';
import 'utils/shared_preferences.dart';
import 'widgets/tasbeeh_widget.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shia_companion/utils/prayer_times.dart';

double screenWidth = 0;
double screenHeight = 0;

User? user;

List<UniversalData>? favsData;

final String appName = "Shia Companion";
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

bool showTranslation = true, showTransliteration = true;
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

void handleUniversalDataClick(BuildContext context, UniversalData itemData) {
  Widget? routeToPush;
  String contentType = 'universal';
  switch (itemData.type) {
    case 0:
      contentType = 'zikr';
      UidTitleData uidTitleData = UidTitleData(itemData.uid, itemData.title);
      if (kIsWeb) {
        routeToPush = ZikrPage(uidTitleData);
      } else {
        routeToPush = ItemPage(uidTitleData);
      }
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
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => routeToPush!));
  }
}

initializeLocation() async {
  try {
    location.LocationData currentLocation =
        await location.Location().getLocation();
    lat = currentLocation.latitude;
    long = currentLocation.longitude;

    List<Placemark> placemarks = await placemarkFromCoordinates(lat!, long!);
    if (placemarks.isNotEmpty) {
      city = placemarks[0].locality;

      if (SP.prefs.getString("city") != city) needToSchedule = true;

      await SP.prefs.setDouble("lat", lat!);
      await SP.prefs.setDouble("long", long!);
      await SP.prefs.setString("city", city!);
    }
  } catch (e) {
    debugPrint(e.toString());
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
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime);
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime);
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
          color: Theme.of(context).colorScheme.secondary,
        )
      : Icon(
          Icons.star_border,
          color: Theme.of(context).colorScheme.secondary,
        );
}
