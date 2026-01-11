import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';

class HomePrayerTimesCard extends StatefulWidget {
  final callback;
  HomePrayerTimesCard(this.callback);

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<HomePrayerTimesCard> {
  PrayerTimesState();

  @override
  Widget build(BuildContext context) {
    DateTime currentTime = DateTime.now();
    HijriCalendar _today =
        HijriCalendar.fromDate(DateTime.now().add(Duration(days: hijriDate)));
    PrayerTime prayerTime = getPrayerTimeObject();
    prayerTime.setTimeFormat(prayerTime.getTime12());

    List<String>? _prayerTimes = lat != null
        ? prayerTime.getPrayerTimes(currentTime, lat!, long!,
            currentTime.timeZoneOffset.inMinutes / 60.0)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
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
                      city != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Location: $city",
                                ),
                                InkWell(
                                  onTap: () async {
                                    bool success = await initializeLocation(force: true);
                                    if (mounted) {
                                      setState(() {});
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Location updated")));
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Failed to update location")));
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(Icons.refresh, size: 18),
                                  ),
                                )
                              ],
                            )
                          : Container(),
                      SizedBox(
                        height: 4,
                      ),
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
                              Text(_prayerTimes[5]),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: Icon(
                              Icons.exit_to_app,
                              size: 18,
                            ),
                            onPressed: () {
                              widget.callback();
                            },
                            label: Text(
                              "All Prayers",
                              style: smallText,
                            ),
                          ),
                          TextButton.icon(
                            icon: Icon(
                              Icons.share,
                              size: 18,
                            ),
                            onPressed: () {
                              String date = formatDate(
                                      DateTime.now(), [dd, " ", M, " ", yyyy]) +
                                  " (" +
                                  _today.toFormat("dd MMMM yyyy") +
                                  ")";
                              SharePlus.instance.share(
                                ShareParams(
                                  text: '$date\n\nFajr : ${_prayerTimes[0]}\nDhuhr : ${_prayerTimes[2]}\nMaghrib : ${_prayerTimes[5]}\n \n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                                  sharePositionOrigin: Rect.fromLTWH(
                                      MediaQuery.of(context).size.width / 2,
                                      0,
                                      2,
                                      2),
                                ));
                            },
                            label: Text(
                              "Share",
                              style: smallText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () async {
                      await initializeLocation(force: true);
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      child: Text("Enable location to display prayer times",
                          textAlign: TextAlign.center),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
