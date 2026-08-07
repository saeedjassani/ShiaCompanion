import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import '../constants.dart';

class HomePrayerTimesCard extends StatefulWidget {
  HomePrayerTimesCard();

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<HomePrayerTimesCard> {
  PrayerTimesState();

  final LocationService _location = LocationService.instance;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
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
    DateTime currentTime = DateTime.now();
    HijriCalendar _today =
        HijriCalendar.fromDate(DateTime.now().add(Duration(days: hijriDate)));
    PrayerTime prayerTime = getPrayerTimeObject();
    prayerTime.setTimeFormat(prayerTime.getTime12());

    // Always render from the last known fix. A refresh in flight, or one that
    // just failed, never blanks times the user could still be relying on.
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
                      _LocationStatusRow(
                        location: _location,
                        onRefresh: _refreshLocation,
                      ),
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

/// The one line above the times that carries every location state: which city
/// the times belong to, whether a refresh is running, how old the fix is, and
/// what went wrong last time. Deliberately the only thing that changes — the
/// prayer times below it never move.
class _LocationStatusRow extends StatelessWidget {
  const _LocationStatusRow({
    required this.location,
    required this.onRefresh,
  });

  final LocationService location;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = location.status == LocationRefreshStatus.failed;
    final label = city;

    final String text;
    if (failed) {
      text = label == null
          ? location.failureMessage
          : "$label · ${location.failureMessage}";
    } else if (label == null) {
      // A missing label does not mean a missing location: this row only renders
      // once there are coordinates, and the geocode that names them is allowed
      // to fail on its own. Only claim to be locating if we actually are.
      text = location.isRefreshing
          ? "Locating…"
          : "Prayer times for your location";
    } else if (location.shouldDiscloseAge) {
      text = "Location: $label · updated ${_ageLabel(location.updatedAt!)}";
    } else {
      text = "Location: $label";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: failed
                ? theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error)
                : null,
          ),
        ),
        // The refresh affordance is always present, whatever the state — a
        // failed location must never be a dead end.
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
                    size: 18,
                    color: failed ? colorScheme.error : null,
                  ),
                ),
              ),
      ],
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
