import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/prayer_times_card.dart';
import 'package:table_calendar/table_calendar.dart';

import '../constants.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.initialDate,
    this.initialEvents,
    this.trackScreenOnInit = true,
  });

  final DateTime? initialDate;
  final Map<String, dynamic>? initialEvents;
  final bool trackScreenOnInit;

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var eventsMap = {};

  DateTime? selectedDay;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    selectedDay = _localCalendarDate(widget.initialDate ?? DateTime.now());
    _focusedDay = selectedDay!;
    if (widget.trackScreenOnInit) {
      trackScreen('Calendar Page');
    }
    if (widget.initialEvents != null) {
      eventsMap = widget.initialEvents!;
    } else {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    String events = await rootBundle.loadString("assets/events.json");

    eventsMap = json.decode(events);

    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDate = selectedDay ?? DateTime.now();

    final calendarPanel = _CalendarPanel(
      child: TableCalendar(
        firstDay: DateTime.utc(2000, 1, 11),
        lastDay: DateTime.utc(2050, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        availableGestures: AvailableGestures.horizontalSwipe,
        daysOfWeekHeight: 30.0,
        rowHeight: 54.0,
        calendarStyle: CalendarStyle(
          cellMargin: EdgeInsets.zero,
          defaultTextStyle: theme.textTheme.bodyMedium!.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          outsideDaysVisible: true,
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: theme.textTheme.labelSmall!.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          weekendStyle: theme.textTheme.labelSmall!.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        headerStyle: HeaderStyle(
          headerPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10.0),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
          leftChevronMargin: EdgeInsets.zero,
          rightChevronMargin: EdgeInsets.zero,
          leftChevronIcon: _CalendarChevron(
            icon: Icons.chevron_left,
            color: colorScheme.primary,
          ),
          rightChevronIcon: _CalendarChevron(
            icon: Icons.chevron_right,
            color: colorScheme.primary,
          ),
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, date) {
            return _CalendarHeaderTitle(
              gregorianMonth: date,
              hijriMonth: _hijriDateFor(date),
            );
          },
          prioritizedBuilder: (BuildContext context, DateTime day, focusedDay) {
            final isOutsideMonth =
                day.month != focusedDay.month || day.year != focusedDay.year;
            return _CalendarDayCell(
              day: day,
              hijriDay: _hijriDateFor(day).hDay,
              event: isOutsideMonth ? null : _eventForDay(day),
              isSelected: isSameDay(selectedDay, day),
              isToday: !isOutsideMonth && isToday(day),
              isOutsideMonth: isOutsideMonth,
            );
          },
        ),
        onPageChanged: (focusedDay) {
          _focusedDay = _localCalendarDate(focusedDay);
        },
        onDaySelected: (DateTime date, DateTime focusedDay) {
          final selectedDate = _localCalendarDate(date);
          selectedDay = selectedDate;
          _focusedDay = selectedDate;
          setState(() {});
        },
      ),
    );

    final selectedSummary = _SelectedDateSummary(
      key: ValueKey("cal-key"),
      gregorianDate: selectedDate,
      hijriDate: _hijriDateFor(selectedDate),
      event: _eventForDay(selectedDate),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;
        return ResponsiveScrollableContent(
          maxWidth: isWide ? wideContentWidth : compactContentWidth,
          padding: responsivePagePadding(
            constraints.maxWidth,
            vertical: 16,
          ).copyWith(bottom: 24),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: calendarPanel,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: selectedSummary,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    calendarPanel,
                    const SizedBox(height: 14.0),
                    selectedSummary,
                  ],
                ),
        );
      },
    );
  }

  Map<String, dynamic>? _eventForDay(DateTime day) {
    final event = eventsMap[getStringFromDate(_hijriDateFor(day))];
    if (event is Map<String, dynamic>) return event;
    return null;
  }

  HijriCalendar _hijriDateFor(DateTime date) {
    return HijriCalendar.fromDate(
      _localCalendarDate(date).add(Duration(days: hijriDate)),
    );
  }

  String getStringFromDate(HijriCalendar dateTime) {
    List<String> temp = dateTime.toString().split('/');
    return int.parse(temp[0]).toString() + '-' + int.parse(temp[1]).toString();
  }

  bool isToday(DateTime dateTime) {
    DateTime now = DateTime.now();

    // Compare day, month, and year components to check if it's today
    return dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year;
  }
}

DateTime _localCalendarDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

class _CalendarPanel extends StatelessWidget {
  final Widget child;

  const _CalendarPanel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.42 : 0.58,
          ),
        ),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18.0,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child,
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final int hijriDay;
  final Map<String, dynamic>? event;
  final bool isSelected;
  final bool isToday;
  final bool isOutsideMonth;

  const _CalendarDayCell({
    required this.day,
    required this.hijriDay,
    required this.event,
    required this.isSelected,
    required this.isToday,
    required this.isOutsideMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final eventColor = _eventColor(context, event);
    final Color backgroundColor;
    final Color borderColor;
    final Color primaryTextColor;
    final Color secondaryTextColor;
    final Color? markerColor;

    if (isOutsideMonth) {
      backgroundColor = Colors.transparent;
      borderColor = Colors.transparent;
      primaryTextColor = colorScheme.onSurfaceVariant.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.5 : 0.46,
      );
      secondaryTextColor = colorScheme.onSurfaceVariant.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.42 : 0.38,
      );
      markerColor = null;
    } else if (isSelected) {
      backgroundColor = colorScheme.primary;
      borderColor = colorScheme.primary;
      primaryTextColor = colorScheme.onPrimary;
      secondaryTextColor = colorScheme.onPrimary.withValues(alpha: 0.82);
      markerColor = eventColor == null ? null : colorScheme.onPrimary;
    } else if (eventColor != null) {
      backgroundColor = eventColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
      );
      borderColor = eventColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.7 : 0.35,
      );
      primaryTextColor = colorScheme.onSurface;
      secondaryTextColor = colorScheme.onSurfaceVariant;
      markerColor = eventColor;
    } else if (isToday) {
      final todayColor = _todayColor(context);
      backgroundColor = todayColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.2 : 0.1,
      );
      borderColor = todayColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.72 : 0.44,
      );
      primaryTextColor = colorScheme.onSurface;
      secondaryTextColor = colorScheme.onSurfaceVariant;
      markerColor = null;
    } else {
      backgroundColor = Colors.transparent;
      borderColor = Colors.transparent;
      primaryTextColor = colorScheme.onSurface;
      secondaryTextColor = colorScheme.onSurfaceVariant;
      markerColor = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 6.0,
            left: 8.0,
            child: Text(
              day.day.toString(),
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: primaryTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            right: 7.0,
            bottom: 5.0,
            child: Text(
              convertNumberToUrdu(hijriDay.toString()),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: secondaryTextColor,
                fontSize: 10.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (markerColor != null)
            Positioned(
              top: 9.0,
              right: 9.0,
              child: Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarHeaderTitle extends StatelessWidget {
  final DateTime gregorianMonth;
  final HijriCalendar hijriMonth;

  const _CalendarHeaderTitle({
    required this.gregorianMonth,
    required this.hijriMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          "${formatDate(gregorianMonth, [
                M,
                " ",
                yyyy
              ])} / ${hijriMonth.toFormat("MMMM yyyy")}",
          maxLines: 1,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SelectedDateSummary extends StatelessWidget {
  final DateTime gregorianDate;
  final HijriCalendar hijriDate;
  final Map<String, dynamic>? event;

  const _SelectedDateSummary({
    super.key,
    required this.gregorianDate,
    required this.hijriDate,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final eventColor = _eventColor(context, event);

    return _CalendarPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hijriDate.toFormat("dd MMMM, yyyy"),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      formatDate(
                          gregorianDate, [DD, ", ", M, " ", d, ", ", yyyy]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (event != null) ...[
            const SizedBox(height: 14.0),
            Container(
              padding: const EdgeInsets.only(left: 12.0),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: eventColor ?? colorScheme.primary,
                    width: 3.0,
                  ),
                ),
              ),
              child: Text(
                event!['content'] ?? "",
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14.0),
            Text(
              "No event listed for this date.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16.0),
          Divider(
            height: 1.0,
            color: colorScheme.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.48 : 0.72,
            ),
          ),
          const SizedBox(height: 8.0),
          PrayerTimesCard(
            date: gregorianDate,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _CalendarChevron extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CalendarChevron({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38.0,
      height: 38.0,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.1,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22.0,
      ),
    );
  }
}

Color? _eventColor(BuildContext context, Map<String, dynamic>? event) {
  if (event == null) return null;

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final value = event['color'];
  if (value == 0) {
    return theme.brightness == Brightness.dark
        ? Colors.red.shade400
        : Colors.red.shade700;
  }
  if (value == 1) {
    return theme.brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;
  }
  return colorScheme.tertiary;
}

Color _todayColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.lightBlue.shade300
      : Colors.blue.shade700;
}

String convertNumberToUrdu(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], farsi[i]);
  }
  return input;
}
