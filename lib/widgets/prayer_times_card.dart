import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';

class PrayerTimesCard extends StatefulWidget {
  final DateTime date;
  PrayerTimesCard({this.date});

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<PrayerTimesCard> {
  PrayerTimesState();
  List<String> _prayerTimes = [];
  List<String> _prayerNames = [];
  SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    DateTime currentTime = widget.date;
    PrayerTime prayerTime = getPrayerTimeObject();
    _prayerNames = prayerTime.getTimeNames();

    _prayerTimes = currentLocation != null
        ? prayerTime.getPrayerTimes(
            currentTime,
            currentLocation.latitude,
            currentLocation.longitude,
            DateTime.now().timeZoneOffset.inMinutes / 60.0)
        : null;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
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
                    )),
                Expanded(
                  flex: 1,
                  child: Text(
                    "${_prayerTimes[position]}",
                    textAlign: TextAlign.end,
                  ),
                ),
                prefs != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: InkWell(
                            onTap: () {
                              inversePref(
                                  "${_prayerNames[position].toLowerCase()}_notification");
                            },
                            child: prefs.getBool(
                                        "${_prayerNames[position].toLowerCase()}_notification") ??
                                    false
                                ? Icon(Icons.volume_up)
                                : Icon(Icons.block)),
                      )
                    : Container(),
              ],
            ),
          );
        },
      ),
    );
  }

  void setUpNotifications() {
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
