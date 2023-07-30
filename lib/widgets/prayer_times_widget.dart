import 'package:adhan_dart/adhan_dart.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
    PrayerTimes? prayerTimes = lat != null
        ? PrayerTimes(
            Coordinates(lat, long), currentTime, CalculationMethod.Tehran())
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
            prayerTimes?.fajr != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Location: $city",
                      ),
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
                              Text(DateFormat('hh:mm')
                                  .format(prayerTimes!.fajr!)),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Dhuhr"),
                              SizedBox(
                                height: 4,
                              ),
                              Text(DateFormat('hh:mm')
                                  .format(prayerTimes.dhuhr!)),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Maghrib"),
                              SizedBox(
                                height: 4,
                              ),
                              Text(DateFormat('hh:mm')
                                  .format(prayerTimes.maghrib!)),
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
                              )),
                          TextButton.icon(
                              icon: Icon(
                                Icons.share,
                                size: 18,
                              ),
                              onPressed: () {
                                String date = formatDate(DateTime.now(),
                                        [dd, " ", M, " ", yyyy]) +
                                    " (" +
                                    _today.toFormat("dd MMMM yyyy") +
                                    ")";
                                Share.share(
                                    '$date\n\nFajr : ${DateFormat('hh:mm').format(prayerTimes.fajr!)}\nDhuhr : ${DateFormat('hh:mm').format(prayerTimes.dhuhr!)}\nMaghrib : ${DateFormat('hh:mm').format(prayerTimes.maghrib!)}\n \n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                                    sharePositionOrigin: Rect.fromLTWH(
                                        MediaQuery.of(context).size.width / 2,
                                        0,
                                        2,
                                        2)); // todo
                              },
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
}
