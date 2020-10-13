import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';

class HomePrayerTimesCard extends StatefulWidget {
  HomePrayerTimesCard();

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<HomePrayerTimesCard> {
  PrayerTimesState();
  List prayerTimes;
  DateTime today = DateTime.now();
  List<String> _prayerTimes;
  SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    DateTime currentTime = DateTime.now();
    HijriCalendar _today = HijriCalendar.fromDate(DateTime.now());
    PrayerTime prayerTime = getPrayerTimeObject();

    _prayerTimes = currentLocation != null
        ? prayerTime.getPrayerTimes(
            currentTime,
            currentLocation.latitude,
            currentLocation.longitude,
            currentTime.timeZoneOffset.inMinutes / 60.0)
        : null;
    return Card(
      color: Colors.brown[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _today.toFormat("dd MMMM yyyy"),
              style: boldText,
            ),
            SizedBox(
              height: 4,
            ),
            _prayerTimes != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Fajr"),
                              SizedBox(
                                height: 4,
                              ),
                              Text(_prayerTimes[0]),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Dhuhr"),
                              SizedBox(
                                height: 4,
                              ),
                              Text(_prayerTimes[2]),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Maghrib"),
                              SizedBox(
                                height: 4,
                              ),
                              Text(_prayerTimes[4]),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FlatButton.icon(
                              icon: Icon(
                                Icons.exit_to_app,
                                size: 18,
                              ),
                              onPressed: () {},
                              label: Text(
                                "All Prayers",
                                style: smallText,
                              )),
                          FlatButton.icon(
                              icon: Icon(
                                Icons.share,
                                size: 18,
                              ),
                              onPressed: () {},
                              label: Text(
                                "Share",
                                style: smallText,
                              )),
                        ],
                      ),
                    ],
                  )
                : Text("Please check if location is allowed"),
          ],
        ),
      ),
    );
  }

  // void setUpNotifications() {
  //   PrayerTime prayers = getPrayerTimeObject();
  //   prayerTime.setTimeFormat(prayerTime.getTime24());

  //   DateTime now = DateTime.now();
  //   for (int i = 0; i < 12; i++) {
  //     DateTime temp = now.add(Duration(days: i));
  //     List<String> prayerTimes = prayers.getPrayerTimes(
  //         temp,
  //         currentLocation.latitude,
  //         currentLocation.longitude,
  //         temp.timeZoneOffset.inMinutes / 60.0);

  //     _prayerNames.asMap().forEach((index, prayerName) =>
  //         schedulePrayerTimeNotification(
  //             (10 * (index + 1)) + i,
  //             DateTime.parse(
  //                 "${temp.toIso8601String().substring(0, 10)} ${prayerTimes[index]}"),
  //             prayerName,
  //             prayerTimes[index]));
  //   }
  //   scheduleNotification(
  //       786,
  //       now.add(Duration(days: 11)),
  //       'Open the app to continue getting Azan notifications',
  //       "It seems you've not used the applications since last 12 days. Please open the app continue getting Azan notifications",
  //       'prayerTimes',
  //       'Prayer Times',
  //       'Azan Notifications for Prayer Times');
  // }

  // void schedulePrayerTimeNotification(
  //     int id, DateTime dateTime, String prayerName, String prayerTime) async {
  //   if (dateTime.difference(DateTime.now()).isNegative ||
  //       !prefs.getBool(prayerName.toLowerCase() + "_notification")) return;
  //   AndroidNotificationDetails androidPlatformChannelSpecifics =
  //       AndroidNotificationDetails(
  //     'prayerTimes',
  //     'Prayer Times',
  //     'Azan Notifications for Prayer Times',
  //     importance: Importance.High,
  //     sound: RawResourceAndroidNotificationSound('sharif'),
  //   );
  //   IOSNotificationDetails iOSPlatformChannelSpecifics =
  //       IOSNotificationDetails(sound: 'sharif.caf');
  //   NotificationDetails platformChannelSpecifics = NotificationDetails(
  //       androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  //   await flutterLocalNotificationsPlugin.schedule(
  //       id,
  //       prayerTime + " : " + prayerName,
  //       "It's time for " + prayerName.toLowerCase(),
  //       dateTime,
  //       platformChannelSpecifics);
  // }

  // void inversePref(String s) async {
  //   await prefs.setBool(s, !prefs.getBool(s));
  //   setState(() {});
  // }
}
