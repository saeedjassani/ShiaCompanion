import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
import 'package:shia_companion/widgets/prayer_notifications_sheet.dart';
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
          onNotificationTap: () => setState(() {}),
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
            _PrayerNotificationButton(
              prayerName: prayerEntry.notificationPrayerName!,
              displayName: prayerEntry.name,
              onChanged: onNotificationTap,
            ),
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

    // No circular fill behind the glyph: on this card that badge sat on top
    // of an already-tinted surface, reading as two mismatched shades of
    // brown rather than one. The home card's row of the same glyphs has
    // never had a background — this now matches it.
    return SizedBox(
      width: 30.0,
      height: 30.0,
      child: Center(
        child: PrayerGlyph(
          name: name,
          size: 17.0,
          color: colorScheme.primary,
        ),
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

class _PrayerNotificationButton extends StatelessWidget {
  const _PrayerNotificationButton({
    required this.prayerName,
    required this.displayName,
    required this.onChanged,
  });

  final String prayerName;
  final String displayName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifKey = notificationPreferenceKeyForPrayer(prayerName);
    final isEnabled = SP.isInitialized && (SP.prefs.getBool(notifKey) ?? false);
    final soundOption = getAzaanOptionForPrayer(prayerName);
    // Distinguishes a sound this prayer picked for itself from one it is only
    // following on the app's global default, so the tooltip/snackbar don't
    // imply a choice the user never actually made for this prayer.
    final soundLabel = hasCustomAzaanPreferenceForPrayer(prayerName)
        ? '${soundOption.name} (custom)'
        : soundOption.name;

    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Tooltip(
        message: isEnabled
            ? '$displayName reminder on ($soundLabel). Tap to toggle, long-press to customize.'
            : '$displayName reminder off. Tap to enable, long-press to customize.',
        child: InkWell(
          onTap: () async {
            final nextValue = !isEnabled;
            await SP.prefs.setBool(notifKey, nextValue);
            if (nextValue) {
              await SP.prefs.setBool(AzaanOptInService.askedKey, true);
              await requestNotificationPermissions();
            }
            await setUpNotifications();
            // setUpNotifications() can take a while (it schedules up to 12
            // days x 8 prayers), so the widget owning onChanged may already
            // be gone by the time it returns — never setState past that.
            if (!context.mounted) return;
            onChanged();

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(
                  nextValue
                      ? '$displayName reminder enabled ($soundLabel)'
                      : '$displayName reminder muted',
                ),
                action: nextValue
                    ? SnackBarAction(
                        label: 'SOUND',
                        onPressed: () async {
                          final changed = await showPrayerNotificationsSheet(
                            context,
                            highlightPrayer: prayerName,
                          );
                          if (changed && context.mounted) onChanged();
                        },
                      )
                    : null,
              ),
            );
          },
          onLongPress: () async {
            final changed = await showPrayerNotificationsSheet(
              context,
              highlightPrayer: prayerName,
            );
            if (changed && context.mounted) onChanged();
          },
          borderRadius: BorderRadius.circular(18.0),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(
              isEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              size: 20,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
