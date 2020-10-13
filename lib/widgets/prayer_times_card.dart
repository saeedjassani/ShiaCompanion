import 'package:flutter/material.dart';
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
                sharedPreferences != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: InkWell(
                            onTap: () {
                              inversePref(
                                  "${_prayerNames[position].toLowerCase()}_notification");
                              setUpNotifications();
                            },
                            child: sharedPreferences.getBool(
                                        "${_prayerNames[position].toLowerCase()}_notification") ??
                                    false
                                ? Icon(
                                    Icons.volume_up,
                                    size: 20,
                                  )
                                : Icon(
                                    Icons.block,
                                    size: 20,
                                  )),
                      )
                    : Container(),
              ],
            ),
          );
        },
      ),
    );
  }

  void inversePref(String s) async {
    await sharedPreferences.setBool(s, !sharedPreferences.getBool(s));
    setState(() {});
  }
}
