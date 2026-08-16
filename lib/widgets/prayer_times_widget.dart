import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/prayer_time_icons.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';
import '../constants.dart';

class HomePrayerTimesCard extends StatefulWidget {
  HomePrayerTimesCard();

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<HomePrayerTimesCard> {
  PrayerTimesState();

  final LocationService _location = LocationService.instance;
  Timer? _ticker;

  /// Lets tests pin "now" instead of racing the wall clock: which prayers
  /// count as "next" — and whether they belong to today or tomorrow — depends
  /// on the moment the card is built.
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
    // The highlighted "next" prayer, and near midnight the list itself, move
    // forward on their own even when nothing else changes. Without a tick the
    // card would only catch up the next time something else rebuilt it.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshLocation() async {
    // Explicit user action, so pass context: this is the one moment where an
    // interrupting dialog about permissions or location services is welcome.
    await _location.refresh(context: context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = debugNow();
    HijriCalendar _today =
        HijriCalendar.fromDate(now.add(Duration(days: hijriDate)));
    PrayerTime prayerTime = getPrayerTimeObject();
    final selected = selectedWidgetPrayerTimes();
    final dateText = _today.toFormat("dd MMMM yyyy");

    // Always render from the last known fix. A refresh in flight, or one that
    // just failed, never blanks times the user could still be relying on.
    List<WidgetPrayerTimeReading>? _readings = lat != null
        ? nextWidgetPrayerTimeReadings(
            prayerTime: prayerTime,
            latitude: lat!,
            longitude: long!,
            count: selected.length,
            now: now,
            times: selected,
          )
        : null;
    final hasReadings = _readings != null && _readings.isNotEmpty;
    // Where "tomorrow" starts, if at all — the row is chronological, so once
    // one column crosses midnight every column after it has too. Tagging only
    // that one boundary (instead of every rolled-over column) reads like a
    // date divider in a list, rather than repeating "Tomorrow" three times.
    final firstTomorrowIndex = _readings == null
        ? -1
        : _readings.indexWhere((r) => !_isSameDate(r.dateTime, now));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            hasReadings
                ? _CardHeader(
                    dateText: dateText,
                    location: _location,
                    onRefresh: _refreshLocation,
                  )
                // No coordinates yet: nothing to name the location with, so
                // just the date — _LocationEmptyState below explains why.
                : Text(dateText, style: boldText),
            const SizedBox(height: 6),
            hasReadings
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < _readings.length; i++)
                        Expanded(
                          child: _PrayerTimeColumn(
                            reading: _readings[i],
                            isTomorrowBoundary: i == firstTomorrowIndex,
                          ),
                        ),
                    ],
                  )
                : _LocationEmptyState(
                    location: _location,
                    onRefresh: _refreshLocation,
                  ),
          ],
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The single line above the times: the Hijri date, the location (or
/// whatever explains its absence), and the refresh affordance, all together
/// — location no longer gets a line of its own. A stale reading adds one
/// small caption underneath; nothing else grows the header.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.dateText,
    required this.location,
    required this.onRefresh,
  });

  final String dateText;
  final LocationService location;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = location.status == LocationRefreshStatus.failed;
    final label = city;

    final String suffix;
    if (failed) {
      suffix = label == null
          ? location.failureMessage
          : "$label · ${location.failureMessage}";
    } else if (label != null) {
      suffix = label;
    } else {
      // A missing label does not mean a missing location: this header only
      // renders once there are coordinates, and the geocode that names them
      // is allowed to fail or still be running on its own.
      suffix = location.isRefreshing
          ? "Locating…"
          : "Prayer times for your location";
    }

    // Only once there's a named location worth dating, and only when that
    // reading is actually old — this is the one thing about the header that
    // still changes on its own, so it stays a separate, smaller line.
    final showUpdated = !failed && label != null && location.shouldDiscloseAge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: dateText, style: boldText),
                    TextSpan(
                      text: " · $suffix",
                      style: TextStyle(
                        color: failed
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // The refresh affordance is always present, whatever the state —
            // a failed location must never be a dead end.
            location.isRefreshing
                ? const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : InkWell(
                    onTap: onRefresh,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.refresh,
                        size: 16,
                        color:
                            failed ? colorScheme.error : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ],
        ),
        if (showUpdated)
          Text(
            "updated ${_ageLabel(location.updatedAt!)}",
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// One prayer in the row: icon, name and time, all at equal weight — order
/// alone already says what's next, so nothing here is bolded or boxed to
/// repeat that. Only the single column where the row crosses into tomorrow
/// gets a divider on its left edge; no label needed there, since a time
/// that's earlier than the one before it already tells the story. Everything
/// after that divider is understood to be tomorrow too, the same way a date
/// divider works in a list.
class _PrayerTimeColumn extends StatelessWidget {
  const _PrayerTimeColumn({
    required this.reading,
    required this.isTomorrowBoundary,
  });

  final WidgetPrayerTimeReading reading;
  final bool isTomorrowBoundary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameStyle =
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: isTomorrowBoundary
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.outlineVariant),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            prayerIconFor(reading.time.name),
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            reading.time.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
          const SizedBox(height: 2),
          Text(
            reading.displayTime,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Shown only when no location has ever been resolved, so there are no times to
/// protect. Always tappable — including while a fetch is running, because a
/// fetch that silently died must not strand the user on a spinner.
class _LocationEmptyState extends StatelessWidget {
  const _LocationEmptyState({
    required this.location,
    required this.onRefresh,
  });

  final LocationService location;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refreshing = location.isRefreshing;
    final failed = location.status == LocationRefreshStatus.failed;

    final String title;
    final String subtitle;
    if (refreshing) {
      title = "Finding your location";
      subtitle = "Prayer times will appear in a moment";
    } else if (failed) {
      title = location.failureMessage;
      subtitle = "Tap to try again";
    } else {
      title = "Location not available";
      subtitle = "Tap here to enable location";
    }

    return InkWell(
      onTap: onRefresh,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            refreshing
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(4.0),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  )
                : Icon(
                    failed ? Icons.location_disabled : Icons.location_off,
                    size: 40,
                    color: failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: failed ? theme.colorScheme.error : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _ageLabel(DateTime updatedAt) {
  final age = DateTime.now().difference(updatedAt);
  if (age.inDays >= 1) {
    return "${age.inDays}d ago";
  }
  return "${age.inHours}h ago";
}
