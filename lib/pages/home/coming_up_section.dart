import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../theme/shia_colors.dart';
import '../../utils/islamic_calendar_widget_data.dart';
import '../../utils/islamic_day.dart';
import '../../widgets/outline_icon.dart';

/// One upcoming event, for the prayer card's event row.
@immutable
class ComingUpEvent {
  const ComingUpEvent({
    required this.date,
    required this.title,
    required this.hijri,
  });

  /// Local midnight of the day it falls on.
  final DateTime date;

  /// "Birth of Hazrat Zainab bint-e-Ali (a.s.)". Two events on one day come
  /// joined ("Martyrdom of Imam Ali (a.s.) · Shab-e-Qadr"); see
  /// widgetEventText.
  final String title;

  /// "5 Jumada al-Awwal".
  final String hijri;

  /// Whether the event's Islamic day is the one in effect: today, or
  /// tonight once its eve has begun at Maghrib.
  bool isCurrent(IslamicDay islamicDay) =>
      _sameDate(date, islamicDay.day.civilDate);

  /// "Tonight", "Today", "Tomorrow" or "In 13 days". Tonight and Today follow
  /// the Islamic day ([islamicDay], from Maghrib); the rest count civil days
  /// from [now], as people do.
  String whenFrom(
    DateTime now, [
    AppLocalizations? l10n,
    IslamicDay? islamicDay,
  ]) {
    final strings = l10n ?? L10n.current;
    if (islamicDay != null && isCurrent(islamicDay)) {
      return islamicDay.isEve ? strings.homeEventTonight : strings.commonToday;
    }
    // Counted on UTC dates so a day that holds a clock change, 23 or 25
    // hours long locally, still counts as one.
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    if (days <= 0) return strings.commonToday;
    if (days == 1) return strings.commonTomorrow;
    return strings.homeEventInDays(days);
  }
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The next [limit] events from events.json, soonest first, from the same
/// builder the calendar widgets use - so Home and the widgets never disagree.
///
/// [now] is the start of the Islamic day in effect (its civil date), so once
/// Maghrib has passed today's event is over and tomorrow's is "tonight".
@visibleForTesting
List<ComingUpEvent> upcomingEvents({
  required DateTime now,
  required Map<String, dynamic> events,
  required int offsetDays,
  int limit = 1,
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
            : L10n.current.homeEventKindOf(
                event['kind'] as String, event['title'] as String),
        hijri: event['hijri'] as String,
      ),
  ];
}

/// The next event, as the last row of Home's prayer card: its date, when it
/// is and what. Gold while its day is the one in effect (today, or tonight
/// from Maghrib). Tap for the calendar. Nothing while there is no event.
///
/// Rebuilt with the card, which ticks, so it moves on by itself.
class ComingUpRow extends StatefulWidget {
  const ComingUpRow({super.key, required this.onOpenCalendar});

  final VoidCallback onOpenCalendar;

  /// Lets tests pin "now".
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  State<ComingUpRow> createState() => _ComingUpRowState();
}

class _ComingUpRowState extends State<ComingUpRow> {
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
        final now = ComingUpRow.debugNow();
        final islamicDay = islamicDayAt(now);
        final rows = upcomingEvents(
          now: islamicDay.day.civilDate,
          events: snapshot.data ?? const {},
          offsetDays: hijriDate,
        );
        if (rows.isEmpty) return const SizedBox.shrink();
        return _EventRow(
          event: rows.first,
          when: rows.first.whenFrom(now, context.l10n, islamicDay),
          current: rows.first.isCurrent(islamicDay),
          onTap: widget.onOpenCalendar,
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.when,
    required this.current,
    required this.onTap,
  });

  final ComingUpEvent event;
  final String when;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final whenLine = current ? when.toUpperCase() : '$when · ${event.hijri}';

    return Semantics(
      button: true,
      label: '$when, ${event.hijri}: ${event.title}',
      hint: context.l10n.homeOpenCalendar,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color:
            current ? colors.gold.withValues(alpha: 0.16) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: current
                      ? colors.gold.withValues(alpha: 0.35)
                      : colors.onPrayerCard.withValues(alpha: 0.14),
                ),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: current
                        ? colors.gold
                        : colors.onPrayerCard.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localizeDigits('${event.date.day}', context.l10n),
                        style: TextStyle(
                          fontSize: 16,
                          height: 19 / 16,
                          fontWeight: FontWeight.w700,
                          color: current ? colors.onGold : colors.onPrayerCard,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(event.date).toUpperCase(),
                        style: ShiaText.tabLabelSelected.copyWith(
                          fontSize: 10,
                          height: 12 / 10,
                          letterSpacing: 0.5,
                          color: current
                              ? colors.onGold
                              : colors.onPrayerCardMuted,
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
                        whenLine,
                        style: ShiaText.caption.copyWith(
                          fontSize: 12,
                          height: 15 / 12,
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: current ? 0.3 : null,
                          color:
                              current ? colors.gold : colors.onPrayerCardMuted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        event.title,
                        style: ShiaText.caption.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrayerCard,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlineIcon(
                  Directionality.of(context) == TextDirection.rtl
                      ? OutlineGlyph.chevronLeft
                      : OutlineGlyph.chevronRight,
                  size: 16,
                  strokeWidth: 2,
                  color: colors.onPrayerCardMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
