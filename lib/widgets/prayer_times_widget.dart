import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';

class PrayerTimesCard extends StatefulWidget {
  PrayerTimesCard();

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<PrayerTimesCard> {
  PrayerTimesState();
  List prayerTimes;
  LocationData currentLocation;
  DateTime today = DateTime.now();
  List<String> _prayerTimes = [];
  List<String> _prayerNames = [];

  Location location = Location();
  @override
  void initState() {
    super.initState();
    getLocation();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        itemCount: _prayerTimes.length,
        itemBuilder: (context, position) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "${_prayerNames[position]} : ${_prayerTimes[position]}",
              style: new TextStyle(fontSize: 20.0),
            ),
          );
        },
      ),
    );
  }

  getLocation() async {
    try {
      currentLocation = await location.getLocation();
    } catch (e) {
      debugPrint(e.toString());
      currentLocation = null;
    }
    if (currentLocation != null) calculatePrayerTimes();
    setState(() {});
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Check if prayer time exists or not, if not get from API for the whole month
  Future<void> calculatePrayerTimes() async {
    PrayerTime prayers = new PrayerTime();

    prayers.setTimeFormat(prayers.getTime12());
    prayers.setCalcMethod(prayers.getJafari());
    prayers.setAsrJuristic(prayers.getHanafi());
    prayers.setAdjustHighLats(prayers.getAdjustHighLats());

    _prayerNames = prayers.getTimeNames();

    DateTime currentTime = DateTime.now();
    // Get Notification set date

    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    String fp = sharedPreferences.getString('azan_notification');
    DateTime dateTimeCreatedAt =
        fp != null ? DateTime.parse(fp) : DateTime.now();
    DateTime dateTimeNow = DateTime.now();
    final differenceInDays = dateTimeCreatedAt.difference(dateTimeNow).inDays;
    if (differenceInDays < 4) {
      debugPrint("Setting Alarms since difference is $differenceInDays");
      setUpNotifications(dateTimeCreatedAt);
      sharedPreferences.setString(
          'azan_notification',
          dateTimeNow
              .add(Duration(days: 5))
              .toIso8601String()
              .substring(0, 10));
    } else {
      debugPrint("Skipped setting alarms");
    }

    setState(() {
      _prayerTimes = prayers.getPrayerTimes(
          currentTime,
          currentLocation.latitude,
          currentLocation.longitude,
          currentTime.timeZoneOffset.inMinutes / 60.0);
    });

    setState(() {});
  }

  void setUpNotifications(DateTime fromPrefs) {
    PrayerTime prayers = new PrayerTime();

    prayers.setTimeFormat(prayers.getTime24());
    prayers.setCalcMethod(prayers.getJafari());
    prayers.setAsrJuristic(prayers.getHanafi());
    prayers.setAdjustHighLats(prayers.getAdjustHighLats());

    DateTime now = DateTime.now();
    DateTime plusFive = now.add(Duration(days: 5));
    for (int i = fromPrefs.difference(now).inDays;
        i < plusFive.difference(fromPrefs).inDays;
        i++) {
      DateTime temp = now.add(Duration(days: i));
      List<String> prayerTimes = prayers.getPrayerTimes(
          temp,
          currentLocation.latitude,
          currentLocation.longitude,
          temp.timeZoneOffset.inMinutes / 60.0);

      schedulePrayerTimeNotification(
          10 + i,
          DateTime.parse(
              "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[0]}"),
          _prayerNames[0]);
      schedulePrayerTimeNotification(
          30 + i,
          DateTime.parse(
              "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[2]}"),
          _prayerNames[2]);
      schedulePrayerTimeNotification(
          60 + i,
          DateTime.parse(
              "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[5]}"),
          _prayerNames[5]);

      debugPrint("Setting Alarms for ${temp.day}");
    }
  }

  void schedulePrayerTimeNotification(
      int id, DateTime dateTime, String title) async {
    DateTime scheduledNotificationDateTime = dateTime;
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayerTimes',
      'Prayer Times',
      'Notifications for Prayer Times',
      importance: Importance.High,
      sound: RawResourceAndroidNotificationSound('slow_spring_board'),
    );
    IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails(sound: 'sharif.caf');
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        id,
        title,
        "It's time for " + title.toLowerCase(),
        scheduledNotificationDateTime,
        platformChannelSpecifics);
  }
}
