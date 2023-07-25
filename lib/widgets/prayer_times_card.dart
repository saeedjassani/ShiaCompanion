import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../utils/shared_preferences.dart';

class PrayerTimesCard extends StatefulWidget {
  final DateTime date;
  PrayerTimesCard({required this.date});

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<PrayerTimesCard> {
  PrayerTimesState();

  @override
  Widget build(BuildContext context) {
    DateTime currentTime = widget.date;

    PrayerTimes prayerTimes = PrayerTimes(
        Coordinates(lat, long), currentTime, CalculationMethod.Tehran());

    List<String> _prayerNames = getPrayerName();

    List<DateTime> _prayerTimes = getPrayerTimes(prayerTimes);

    return prayerTimes.fajr != null
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (BuildContext context, int index) => Divider(
                height: 2,
              ),
              itemCount: 7,
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
                          DateFormat('hh:mm').format(_prayerTimes[position]),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: InkWell(
                            onTap: () {
                              inversePref(
                                  "${_prayerNames[position].toLowerCase()}_notification");
                              setUpNotifications();
                            },
                            child: SP.prefs.getBool(
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
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        : Container();
  }

  void inversePref(String s) async {
    bool? value = SP.prefs.getBool(s);
    if (value != null) {
      await SP.prefs.setBool(s, !value);
      setState(() {});
    }
  }
}
