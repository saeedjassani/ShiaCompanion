import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
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

    List<int> offsets = [
      0,
      0,
      0,
      0,
      0,
      0,
      0
    ]; // {Fajr,Sunrise,Dhuhr,Asr,Sunset,Maghrib,Isha}
    prayers.tune(offsets);

    var currentTime = DateTime.now();
    print(currentTime.timeZoneOffset.inHours.toDouble());
    print(currentTime.timeZoneOffset.inMinutes.toDouble());
    print(currentLocation.latitude);
    print(currentLocation.longitude);

    setState(() {
      _prayerTimes = prayers.getPrayerTimes(
          currentTime,
          currentLocation.latitude,
          currentLocation.longitude,
          currentTime.timeZoneOffset.inMinutes / 60.0);
      _prayerNames = prayers.getTimeNames();
    });

    setState(() {});
  }

  void setNotifications() async {
    DateTime now = DateTime.now();
    now.add(Duration(days: 5));
    for (var prayerTime in prayerTimes) {}
  }

  Future<String> getPrayerTimesFromAPI() async {
    String prayerTimesJson;
    String url =
        "https://api.aladhan.com/v1/calendar?latitude=${currentLocation.latitude}&longitude=${currentLocation.longitude}&method=0&month=${today.month}&year=${today.year}&midnightMode=1&tune=0,0,0,0,0,0,0,0,0&adjustment=$hijriDate";
    debugPrint(url);
    var request = await get(url);
    if (request.statusCode == 200) {
      prayerTimesJson = request.body;
    } else {
      key.currentState.showSnackBar(SnackBar(
        content: Text("Unable to get prayer times"),
      ));
    }
    return prayerTimesJson;
  }
}
