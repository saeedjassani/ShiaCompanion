import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_time_icons.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';
import '../utils/shared_preferences.dart';

class PrayerTimesCard extends StatefulWidget {
  final DateTime date;
  final bool showNotificationControls;
  final bool compact;

  PrayerTimesCard({
    required this.date,
    this.showNotificationControls = true,
    this.compact = false,
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
    final prayerEntries = lat != null && long != null
        ? buildExtendedPrayerTimeEntries(
            prayerTime: prayerTime,
            date: currentTime,
            latitude: lat!,
            longitude: long!,
            timeZone: currentTime.timeZoneOffset.inMinutes / 60.0,
          )
        : null;
    if (prayerEntries == null) {
      return widget.compact ? const _PrayerTimesUnavailable() : Container();
    }

    final content = ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (BuildContext context, int index) => Divider(
        height: widget.compact ? 1.0 : 2.0,
      ),
      itemCount: prayerEntries.length,
      shrinkWrap: true,
      itemBuilder: (context, position) {
        final prayerEntry = prayerEntries[position];
        return _PrayerTimeRow(
          prayerEntry: prayerEntry,
          compact: widget.compact,
          notificationsEnabled: widget.showNotificationControls &&
              prayerEntry.canNotify &&
              !kIsWeb &&
              SP.isInitialized,
          onNotificationTap: () async {
            await inversePref(notificationPreferenceKeyForPrayer(
                prayerEntry.notificationPrayerName!));
            await setUpNotifications();
          },
        );
      },
    );

    return widget.compact
        ? content
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          );
  }

  Future<void> inversePref(String s) async {
    final value = SP.prefs.getBool(s) ?? false;
    final nextValue = !value;
    await SP.prefs.setBool(s, nextValue);
    setState(() {});
  }
}

class _PrayerTimeRow extends StatelessWidget {
  final PrayerTimeDisplayEntry prayerEntry;
  final bool compact;
  final bool notificationsEnabled;
  final VoidCallback onNotificationTap;

  const _PrayerTimeRow({
    required this.prayerEntry,
    required this.compact,
    required this.notificationsEnabled,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0.0 : 8.0,
        vertical: compact ? 8.0 : 8.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _PrayerIconBadge(name: prayerEntry.name),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              prayerEntry.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            prayerEntry.time,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (notificationsEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: InkWell(
                onTap: onNotificationTap,
                borderRadius: BorderRadius.circular(18.0),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    SP.prefs.getBool(notificationPreferenceKeyForPrayer(
                                prayerEntry.notificationPrayerName!)) ??
                            false
                        ? Icons.volume_up
                        : Icons.block,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _PrayerIconBadge extends StatelessWidget {
  final String name;

  const _PrayerIconBadge({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 30.0,
      height: 30.0,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        prayerIconFor(name),
        size: 17.0,
        color: colorScheme.primary,
      ),
    );
  }
}

class _PrayerTimesUnavailable extends StatelessWidget {
  const _PrayerTimesUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_off,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          "Location not available",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Enable location to display accurate prayer times for your area.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
