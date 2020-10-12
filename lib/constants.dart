import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location/location.dart';
import 'package:shia_companion/utils/prayer_times.dart';

import 'data/uid_title_data.dart';
import 'pages/item_page.dart';
import 'pages/list_items.dart';

double screenWidth = 0;
double screenHeight = 0;

User user;

final String appName = "Shia Companion";
int hijriDate = 0;
double arabicFontSize = 28.0;
double englishFontSize = 14.0;

PrayerTime prayerTime;
LocationData currentLocation;

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
List<String> tableCode = [
  "TR",
  "F",
  "E",
  "G",
  "A",
  /*"C", "A", */ "H", /* "I", "B" */
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

initializeLocation() async {
  try {
    currentLocation = await Location().getLocation();
  } catch (e) {
    currentLocation = null;
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
