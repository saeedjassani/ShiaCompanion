import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../theme/shia_colors.dart';
import '../../utils/islamic_calendar_widget_data.dart';
import 'home_section.dart';

/// One row of Coming up.
@immutable
class ComingUpEvent {
  const ComingUpEvent({
    required this.date,
    required this.title,
    required this.hijri,
  });

  /// Local midnight of the day it falls on.
  final DateTime date;

  /// "Birth of Hazrat Zainab bint-e-Ali (a.s.)".
  final String title;

  /// "5 Jumada al-Awwal".
  final String hijri;

  /// "Today", "Tomorrow" or "In 13 days" - "Today" only for today's event.
  String whenFrom(DateTime now) {
    // Counted on UTC dates so a day that holds a clock change, 23 or 25
    // hours long locally, still counts as one.
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }
}

/// The next [limit] events from events.json, soonest first, from the same
/// builder the calendar widgets use - so Home and the widgets never disagree.
@visibleForTesting
List<ComingUpEvent> upcomingEvents({
  required DateTime now,
  required Map<String, dynamic> events,
  required int offsetDays,
  int limit = 2,
}) {
  return [
    for (final event in buildUpcomingCalendarWidgetEvents(
      now: now,
      events: events,
      offsetDays: offsetDays,
      limit: limit,
    ))
      ComingUpEvent(
        date: DateTime.fromMillisecondsSinceEpoch(event['start'] as int),
        // The widgets lead with who it is about; a full row has room to say
        // what happened too.
        title: (event['kind'] as String).isEmpty
            ? event['title'] as String
            : '${event['kind']} of ${event['title']}',
        hijri: event['hijri'] as String,
      ),
  ];
}

/// "Coming up": the next two events, with a link to the calendar. Hidden
/// while there is nothing to show.
class ComingUpSection extends StatefulWidget {
  const ComingUpSection({
    super.key,
    required this.onOpenCalendar,
    this.topSpacing = 0,
  });

  final VoidCallback onOpenCalendar;

  /// Space above the section, only when it shows.
  final double topSpacing;

  @override
  State<ComingUpSection> createState() => _ComingUpSectionState();
}

class _ComingUpSectionState extends State<ComingUpSection> {
  /// Loaded once for the life of the app: events.json never changes under
  /// a running build.
  static Future<Map<String, dynamic>>? _events;

  @override
  void initState() {
    super.initState();
    _events ??= _loadEvents();
  }

  static Future<Map<String, dynamic>> _loadEvents() async {
    try {
      final decoded =
          json.decode(await rootBundle.loadString('assets/events.json'));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('Unable to load events for Coming up: $e');
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _events,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final rows = upcomingEvents(
          now: now,
          events: snapshot.data ?? const {},
          offsetDays: hijriDate,
        );
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: widget.topSpacing),
            HomeSectionHeader(
              title: 'Coming up',
              actionLabel: 'Calendar',
              actionSemanticsLabel: 'Open the calendar',
              onAction: widget.onOpenCalendar,
            ),
            const SizedBox(height: 10),
            HomeCard(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 72),
                        child: Divider(
                          height: 1,
                          color: ShiaColors.of(context).divider,
                        ),
                      ),
                    _EventRow(
                      event: rows[i],
                      now: now,
                      onTap: widget.onOpenCalendar,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.now,
    required this.onTap,
  });

  final ComingUpEvent event;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${event.date.day}',
                    style: TextStyle(
                      fontSize: 19,
                      height: 22 / 19,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(event.date).toUpperCase(),
                    style: ShiaText.tabLabelSelected.copyWith(
                      letterSpacing: 0.5,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: ShiaText.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.whenFrom(now)} · ${event.hijri}',
                    style: ShiaText.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
