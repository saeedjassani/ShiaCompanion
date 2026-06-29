import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';

class HomePrayerTimesCard extends StatefulWidget {
  HomePrayerTimesCard();

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
    final useLiveLocation = shouldUseLiveLocation();
    final isFetchingLiveLocation = useLiveLocation && !kIsWeb;

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
                                Flexible(
                                  child: Text(
                                    "Location: $city",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!useLiveLocation)
                                  InkWell(
                                    onTap: () async {
                                      bool success =
                                          await initializeLocation(force: true);
                                      if (success) {
                                        await HomeScreenWidgetService.instance
                                            .publishAll();
                                      }
                                      if (mounted) {
                                        setState(() {});
                                        if (success) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      "Location updated")));
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      "Failed to update location")));
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(Icons.refresh, size: 18),
                                    ),
                                  ),
                              ],
                            )
                          : Container(),
                      SizedBox(
                        height: 4,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Fajr"),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(_prayerTimes[0]),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Zuhr"),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(_prayerTimes[2]),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Maghrib"),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(_prayerTimes[5]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () async {
                      if (isFetchingLiveLocation) return;
                      final success = await initializeLocation(
                        force: true,
                        context: context,
                      );
                      if (success) {
                        await HomeScreenWidgetService.instance.publishAll();
                      }
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFetchingLiveLocation
                                ? Icons.location_searching
                                : Icons.location_off,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isFetchingLiveLocation
                                ? "Fetching live location to display prayer times"
                                : "Location not available",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFetchingLiveLocation
                                ? "Please wait..."
                                : "Tap here to enable location",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
