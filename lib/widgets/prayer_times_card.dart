import 'package:flutter/material.dart';
import 'package:shia_companion/utils/prayer_times.dart';
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
    PrayerTime prayerTime = getPrayerTimeObject();
    prayerTime.setTimeFormat(prayerTime.getTime12());

    List<String> _prayerNames = prayerTime.getTimeNames();

    List<String>? _prayerTimes = city != null
        ? prayerTime.getPrayerTimes(currentTime, lat!, long!,
            DateTime.now().timeZoneOffset.inMinutes / 60.0)
        : null;
    return _prayerTimes != null
        ? Padding(
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
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "${_prayerTimes[position]}",
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
                          child: Icon(
                            SP.prefs.getBool(
                                        "${_prayerNames[position].toLowerCase()}_notification") ??
                                    false
                                ? Icons.volume_up
                                : Icons.block,
                            size: 20,
                          ),
                        ),
                      )
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
