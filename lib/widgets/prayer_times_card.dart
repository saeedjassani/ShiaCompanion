import 'package:flutter/material.dart';
import 'package:shia_companion/utils/l10n_extension.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
import '../constants.dart';

/// The prayer times for one date.
///
/// Read-only by design. This card used to carry a notification bell on every
/// row, but it is only ever shown on the calendar — a page you page back and
/// forward through dates — so a global preference presented against a specific
/// date read as "notify me on this date", which it never was. The calendar now
/// links to the prayer notifications screen instead.
class PrayerTimesCard extends StatelessWidget {
  final DateTime date;
  final bool compact;

  const PrayerTimesCard({
    super.key,
    required this.date,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    PrayerTime prayerTime = getPrayerTimeObject();
    final prayerEntries = lat != null && long != null
        ? buildExtendedPrayerTimeEntries(
            prayerTime: prayerTime,
            date: date,
            latitude: lat!,
            longitude: long!,
            timeZone: date.timeZoneOffset.inMinutes / 60.0,
          )
        : null;
    if (prayerEntries == null) {
      return compact ? const _PrayerTimesUnavailable() : Container();
    }

    final content = ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (BuildContext context, int index) => Divider(
        height: compact ? 1.0 : 2.0,
      ),
      itemCount: prayerEntries.length,
      shrinkWrap: true,
      itemBuilder: (context, position) {
        return _PrayerTimeRow(
          prayerEntry: prayerEntries[position],
          compact: compact,
        );
      },
    );

    return compact
        ? content
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          );
  }
}

class _PrayerTimeRow extends StatelessWidget {
  final PrayerTimeDisplayEntry prayerEntry;
  final bool compact;

  const _PrayerTimeRow({
    required this.prayerEntry,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0.0 : 8.0,
        vertical: 8.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _PrayerIconBadge(name: prayerEntry.name),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              localizedPrayerName(context, prayerEntry.name),
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
