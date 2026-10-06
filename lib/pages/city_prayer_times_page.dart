import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

import '../constants.dart';
import '../l10n/hijri_l10n.dart';
import '../l10n/l10n.dart';
import '../models/city.dart';
import '../services/analytics_service.dart';
import '../theme/shia_colors.dart';
import '../utils/city_clock.dart';
import '../utils/prayer_time_entries.dart';
import '../utils/timezone_database.dart';
import '../utils/widget_prayer_time_selection.dart';
import '../widgets/outline_icon.dart';
import '../widgets/prayer_times_card.dart';
import '../widgets/responsive_content.dart';

/// Opens [city]'s prayer times to look at, and counts it. [source] says where
/// from: the city picker's "Just checking times", or the Calendar's link.
/// [date] starts on that date rather than the city's today.
Future<void> openCityPrayerTimes(
  BuildContext context,
  City city, {
  required String source,
  DateTime? date,
}) {
  unawaited(AnalyticsService.feature(
    'city_times_viewed',
    label: 'City times viewed',
    parameters: {'source': source, 'country': city.countryCode},
  ));
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => CityPrayerTimesPage(city: city, initialDate: date),
  ));
}

/// Another city's prayer times, just to look at: "what will the times be
/// when I land in Karbala?"
///
/// Told on the city's own clock - what the clocks there will say - and it
/// says so once. Nothing here touches the reader's own location, widgets or
/// notifications; choosing where they are is the city picker's job.
class CityPrayerTimesPage extends StatefulWidget {
  const CityPrayerTimesPage({super.key, required this.city, this.initialDate});

  final City city;

  /// The calendar date to start on (its year, month and day); the city's
  /// today when null.
  final DateTime? initialDate;

  @override
  State<CityPrayerTimesPage> createState() => _CityPrayerTimesPageState();
}

class _CityPrayerTimesPageState extends State<CityPrayerTimesPage> {
  /// The city's zone, or null to fall back on the phone's clock when the
  /// list has none for it.
  late final tz.Location? _zone = widget.city.timeZone.isEmpty
      ? null
      : tryGetLocation(widget.city.timeZone);

  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final today = _today();
    final start = widget.initialDate ?? today;
    _day = dateTimeOnClockOf(today, start.year, start.month, start.day);
  }

  /// The start of today on the city's clock.
  DateTime _today() {
    final zone = _zone;
    final now = zone == null ? DateTime.now() : tz.TZDateTime.now(zone);
    return dateTimeOnClockOf(now, now.year, now.month, now.day);
  }

  void _move(int days) => setState(() => _day = calendarDayFrom(_day, days));

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final city = widget.city;
    final zone = _zone;
    final today = _today();
    final isToday = _day.year == today.year &&
        _day.month == today.month &&
        _day.day == today.day;
    final hijri = HijriCalendar.fromDate(
      DateTime(_day.year, _day.month, _day.day + hijriDate),
    );
    // Midday, so a day the clocks change on compares the hours that count.
    final difference = zone == null
        ? null
        : zoneClockDifference(
            zone,
            dateTimeOnClockOf(_day, _day.year, _day.month, _day.day, 12),
          );
    final clockLabel = clockDifferenceLabel(difference, context.l10n);

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(city.name),
            Text(
              [
                if (city.admin1Name.isNotEmpty) city.admin1Name,
                city.countryName,
              ].join(', '),
              style: ShiaText.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
      body: ResponsiveContent(
        maxWidth: compactContentWidth,
        child: ListView(
          padding: EdgeInsets.only(
            top: 8,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: colors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _DayButton(
                          glyph: OutlineGlyph.chevronLeft,
                          tooltip: context.l10n.cityPreviousDay,
                          onPressed: () => _move(-1),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                DateFormat('EEEE d MMMM').format(_day),
                                textAlign: TextAlign.center,
                                style: ShiaText.cardTitle
                                    .copyWith(color: colors.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${hijri.hDay} '
                                '${hijriMonthName(hijri.hMonth, context.l10n).replaceAll(' Al-', ' al-')} '
                                '${hijri.hYear}',
                                textAlign: TextAlign.center,
                                style: ShiaText.secondary
                                    .copyWith(color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        _DayButton(
                          glyph: OutlineGlyph.chevronRight,
                          tooltip: context.l10n.cityNextDay,
                          onPressed: () => _move(1),
                        ),
                      ],
                    ),
                    if (!isToday)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _day = today),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.accent,
                          ),
                          child: Text(context.l10n.cityTodayIn(city.name)),
                        ),
                      ),
                    if (clockLabel != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text(
                          context.l10n
                              .cityTimeDifference(city.name, clockLabel),
                          style: ShiaText.caption
                              .copyWith(color: colors.textMuted),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: PrayerTimesCard(
                        date: _day,
                        latitude: city.latitude,
                        longitude: city.longitude,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.l10n.cityJustLookingNote,
                style: ShiaText.caption.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
  });

  final OutlineGlyph glyph;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.well,
        minimumSize: const Size(44, 44),
      ),
      icon: OutlineIcon(glyph, size: 20, color: colors.accent, strokeWidth: 2),
    );
  }
}
