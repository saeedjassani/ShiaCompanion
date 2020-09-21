import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  SharedPreferences prefs;

  Location location = Location();
  @override
  void initState() {
    super.initState();
    getLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.brown[100],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ListView.separated(
          separatorBuilder: (BuildContext context, int index) => Divider(
            height: 2,
          ),
          itemCount: _prayerTimes.length,
          shrinkWrap: true,
          itemBuilder: (context, position) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                      flex: 1,
                      child: Text(
                        "${_prayerNames[position]} :",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "${_prayerTimes[position]}",
                    ),
                  ),
                  prefs != null
                      ? InkWell(
                          onTap: () {
                            inversePref(
                                "${_prayerNames[position].toLowerCase()}_notification");
                          },
                          child: prefs.getBool(
                                      "${_prayerNames[position].toLowerCase()}_notification") ??
                                  false
                              ? Icon(Icons.notifications_active)
                              : Icon(Icons.notifications_off))
                      : Container(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  getLocation() async {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('fajr_notification') == null) {
      prefs.setBool('fajr_notification', true);
      prefs.setBool('dhuhr_notification', true);
      prefs.setBool('maghrib_notification', true);
      prefs.setBool('sunrise_notification', false);
      prefs.setBool('asr_notification', false);
      prefs.setBool('sunset_notification', false);
      prefs.setBool('isha_notification', false);
    }
    try {
      currentLocation = await location.getLocation();
    } catch (e) {
      debugPrint(e.toString());
      currentLocation = null;
    }
    if (currentLocation != null) calculatePrayerTimes();
  }

  Future<void> calculatePrayerTimes() async {
    PrayerTime prayers = new PrayerTime();

    prayers.setTimeFormat(prayers.getTime12());
    prayers.setCalcMethod(prayers.getJafari());
    prayers.setAsrJuristic(prayers.getHanafi());
    prayers.setAdjustHighLats(prayers.getAdjustHighLats());

    _prayerNames = prayers.getTimeNames();

    DateTime currentTime = DateTime.now();
    setUpNotifications();

    setState(() {
      _prayerTimes = prayers.getPrayerTimes(
          currentTime,
          currentLocation.latitude,
          currentLocation.longitude,
          currentTime.timeZoneOffset.inMinutes / 60.0);
    });
  }

  void setUpNotifications() {
    PrayerTime prayers = PrayerTime();

    prayers.setTimeFormat(prayers.getTime24());
    prayers.setCalcMethod(prayers.getJafari());
    prayers.setAsrJuristic(prayers.getHanafi());
    prayers.setAdjustHighLats(prayers.getAdjustHighLats());

    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime temp = now.add(Duration(days: i));
      List<String> prayerTimes = prayers.getPrayerTimes(
          temp,
          currentLocation.latitude,
          currentLocation.longitude,
          temp.timeZoneOffset.inMinutes / 60.0);

      _prayerNames.asMap().forEach((index, prayerName) =>
          schedulePrayerTimeNotification(
              (10 * (index + 1)) + i,
              DateTime.parse(
                  "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[index]}"),
              prayerName,
              prayerTimes[index]));
    }
    scheduleNotification(
        786,
        now.add(Duration(days: 11)),
        'Open the app to continue getting Azan notifications',
        "It seems you've not used the applications since last 12 days. Please open the app continue getting Azan notifications",
        'prayerTimes',
        'Prayer Times',
        'Azan Notifications for Prayer Times');
  }

  void schedulePrayerTimeNotification(
      int id, DateTime dateTime, String prayerName, String prayerTime) async {
    if (dateTime.difference(DateTime.now()).isNegative ||
        !prefs.getBool(prayerName.toLowerCase() + "_notification")) return;
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayerTimes',
      'Prayer Times',
      'Azan Notifications for Prayer Times',
      importance: Importance.High,
      sound: RawResourceAndroidNotificationSound('sharif'),
    );
    IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails(sound: 'sharif.caf');
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        id,
        prayerTime + " : " + prayerName,
        "It's time for " + prayerName.toLowerCase(),
        dateTime,
        platformChannelSpecifics);
  }

  void inversePref(String s) async {
    await prefs.setBool(s, !prefs.getBool(s));
    setState(() {});
  }
}
