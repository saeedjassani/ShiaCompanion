import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';
import '../utils/shared_preferences.dart';

class PrayerTimesCard extends StatefulWidget {
  final DateTime date;
  final bool showNotificationControls;

  PrayerTimesCard({
    required this.date,
    this.showNotificationControls = true,
  });

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<PrayerTimesCard> {
  PrayerTimesState();

  @override
  Widget build(BuildContext context) {
    DateTime currentTime = widget.date;
    PrayerTime prayerTime = getPrayerTimeObject();
    final prayerEntries = lat != null
        ? buildExtendedPrayerTimeEntries(
            prayerTime: prayerTime,
            date: currentTime,
            latitude: lat!,
            longitude: long!,
            timeZone: currentTime.timeZoneOffset.inMinutes / 60.0,
          )
        : null;
    return prayerEntries != null
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (BuildContext context, int index) => Divider(
                height: 2,
              ),
              itemCount: prayerEntries.length,
              shrinkWrap: true,
              itemBuilder: (context, position) {
                final prayerEntry = prayerEntries[position];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Text(
                          "${prayerEntry.name} :",
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          prayerEntry.time,
                          textAlign: TextAlign.end,
                        ),
                      ),
                      if (widget.showNotificationControls &&
                          prayerEntry.canNotify &&
                          !kIsWeb)
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: InkWell(
                            onTap: () async {
                              await inversePref(
                                  notificationPreferenceKeyForPrayer(
                                      prayerEntry.notificationPrayerName!));
                              await setUpNotifications();
                            },
                            child: Icon(
                              SP.prefs.getBool(
                                          notificationPreferenceKeyForPrayer(
                                              prayerEntry
                                                  .notificationPrayerName!)) ??
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

  Future<void> inversePref(String s) async {
    final value = SP.prefs.getBool(s) ?? false;
    final nextValue = !value;
    if (nextValue) {
      await requestExactPrayerAlarmPermissionIfNeeded();
    }
    await SP.prefs.setBool(s, nextValue);
    setState(() {});
  }
}
