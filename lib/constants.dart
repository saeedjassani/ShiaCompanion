import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/live_streaming_page.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:webfeed/webfeed.dart';

import 'data/live_streaming_data.dart';
import 'data/uid_title_data.dart';
import 'pages/chapter_list_page.dart';
import 'pages/item_page.dart';
import 'pages/list_items.dart';
import 'pages/news_page.dart';
import 'pages/video_player.dart';

double screenWidth = 0;
double screenHeight = 0;

User user;

List<UniversalData> favsData;

final String appName = "Shia Companion";
int hijriDate = 0;
double arabicFontSize = 28.0;
double englishFontSize = 12.0;

PrayerTime prayerTime;
LocationData currentLocation;
SharedPreferences sharedPreferences;

PrayerTime getPrayerTimeObject() {
  if (prayerTime != null) return prayerTime;

  prayerTime = PrayerTime();

  prayerTime.setTimeFormat(prayerTime.getTime12());
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
  ItemList("TR"),
  ItemList("F"),
  ItemList("E"),
  ItemList("G"),
  ItemList("A"),
  ItemList("H"),
  // /*"C", "A", */ "H",
  /* "I", "B" */
  NewsPage(),
  LiveStreamingPage(0),
  LiveStreamingPage(1),
];

List<String> zikr = [
  "Today's Recitations",
  "Namaz",
  "Duas",
  "Ziyarats",
  // "Amaal",
  "Surahs",
  "Munajaats",
  // "Baaqeyaat As Saalehaat",
  // "Ziyarat of Hijaz, Iran & Iraq"
  "Latest Shia News",
  "Holy Shrines",
  "Islamic Channels"
];

List<String> zikrImages = [
  "assets/images/taaqebaat_namaz",
  "assets/images/namaz_home_min",
  "assets/images/dua_home",
  "assets/images/najaf_min",
  // "assets/images/amaal",
  "assets/images/surah_home",
  "assets/images/munajat_home",
  // "assets/images/taaqebaat_namaz",
  // "assets/images/mashhad_min"
];

Map items = {};

// HomePage key
GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

ListTile buildZikrRow(BuildContext context, UidTitleData itemData) {
  return ListTile(
    onTap: () {
      if (itemData.getUId().contains("~")) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    ItemList(itemData.getUId().split("~")[1])));
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => ItemPage(itemData)));
      }
    },
    title: Text(itemData.title),
  );
}

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
    currentLocation = await Location().getLocation();
  } catch (e) {
    currentLocation = null;
    debugPrint(e);
  }
}

void scheduleNotification(
    int id,
    DateTime dateTime,
    String title,
    String description,
    String channelID,
    String channelTitle,
    String channelDescription) async {
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    channelID,
    channelTitle,
    channelDescription,
  );
  IOSNotificationDetails iOSPlatformChannelSpecifics = IOSNotificationDetails();
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.schedule(
      id, title, description, dateTime, platformChannelSpecifics,
      androidAllowWhileIdle: true);
  await flutterLocalNotificationsPlugin.schedule(
      id, title, description, dateTime, platformChannelSpecifics,
      androidAllowWhileIdle: true);
}

void setUpNotifications() async {
  debugPrint("Scheduling Azan Notifications");
  PrayerTime prayers = getPrayerTimeObject();
  prayerTime.setTimeFormat(prayerTime.getTime24());

  DateTime now = DateTime.now();
  for (int i = 0; i < 12; i++) {
    DateTime temp = now.add(Duration(days: i));
    List<String> prayerTimes = prayers.getPrayerTimes(
        temp,
        currentLocation.latitude,
        currentLocation.longitude,
        temp.timeZoneOffset.inMinutes / 60.0);

    var _prayerNames = prayers.getTimeNames();
    _prayerNames.asMap().forEach((index, prayerName) =>
        schedulePrayerTimeNotification(
            (10 * (index + 1)) + i,
            DateTime.parse(
                "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[index]}"),
            prayerName,
            prayerTimes[index]));
  }
  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    "prayerTimes",
    "Prayer Times",
    "Azan Notifications for Prayer Times",
  );
  IOSNotificationDetails iOSPlatformChannelSpecifics = IOSNotificationDetails();
  NotificationDetails platformChannelSpecifics = NotificationDetails(
      androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.schedule(
      786,
      "Open the app to continue getting Azan notifications",
      "It seems you've not used the applications since last 12 days. Please open the app continue getting Azan notifications",
      now.add(Duration(days: 11)),
      platformChannelSpecifics,
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
      importance: Importance.High,
      sound: RawResourceAndroidNotificationSound('sharif'),
    );
    IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails(sound: 'azan.caf');
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        id,
        prayerTime + " : " + prayerName,
        "It's time for " + prayerName.toLowerCase(),
        dateTime,
        platformChannelSpecifics,
        androidAllowWhileIdle: true);
  } else {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
