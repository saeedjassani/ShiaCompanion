import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shia_companion/pages/city_picker.dart';
import 'package:shia_companion/pages/prayer_notifications_page.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/utils/islamic_calendar_widget_data.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/widget_prayer_times_dialog.dart';

import '../constants.dart';
import '../l10n/hijri_l10n.dart';
import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import '../utils/calendar_events.dart';
import '../utils/islamic_day.dart';

/// Calendar & Prayer Times (docs/DESIGN_SPEC.md, "Calendar & Prayer Times"):
/// one page, no tabs. The month on top; under it the day picked, its event
/// and that day's prayer times, which follow every tap on the grid.
///
/// On a phone everything is one column. On a tablet the month runs full
/// width with the day and its times side by side under it; from desktop
/// width the month sits on the left and the day in a column on the right.
/// The wider layouts list the day's eight times top to bottom.
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

  /// Lets tests pin which day is today.
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final LocationService _location = LocationService.instance;
  Map<String, dynamic> _events = const {};

  late DateTime _selected;

  /// The first of the month on show; it can differ from [_selected]'s once
  /// the arrows have moved on.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _selected = _localDate(widget.initialDate ?? CalendarPage.debugNow());
    _month = DateTime(_selected.year, _selected.month);
    if (widget.trackScreenOnInit) {
      trackScreen('Calendar Page');
    }
    if (widget.initialEvents != null) {
      _events = widget.initialEvents!;
    } else {
      _loadEvents();
    }
    // A city chosen from the button up top changes every time below it.
    _location.addListener(_onChanged);
  }

  @override
  void dispose() {
    _location.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEvents() async {
    _events = await CalendarEvents.load();
    if (mounted) setState(() {});
  }

  void _pick(DateTime day) {
    setState(() {
      _selected = day;
      _month = DateTime(day.year, day.month);
    });
  }

  void _shiftMonth(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  Future<void> _chooseCity() async {
    await chooseCityFlow(context);
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? _eventFor(DateTime day) {
    final event = _events[hijriEventKey(_hijriFor(day))];
    return event is Map<String, dynamic> ? event : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final insets = MediaQuery.paddingOf(context);
    final screen = ScreenClass.of(context);
    final today = _localDate(CalendarPage.debugNow());
    final pushed = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    final topBar = Row(
      children: [
        if (pushed) const PageBackButton(),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: lat == null
                ? null
                : CityButton(location: _location, onTap: _chooseCity),
          ),
        ),
      ],
    );

    final showToday = !_isSameDay(_selected, today) ||
        _month.year != today.year ||
        _month.month != today.month;
    final monthHeader = _MonthHeader(
      month: _month,
      hijriSpan: _hijriSpan(context, _month),
      onToday: showToday ? () => _pick(today) : null,
      onPrevious: () => _shiftMonth(-1),
      onNext: () => _shiftMonth(1),
    );

    final grid = _MonthGrid(
      month: _month,
      selected: _selected,
      today: today,
      cellHeight: switch (screen) {
        ScreenClass.phone => 52,
        ScreenClass.tablet => 64,
        ScreenClass.desktop => 64,
      },
      wide: !screen.isPhone,
      hijriFor: _hijriFor,
      eventFor: _eventFor,
      onPick: _pick,
      onSwipe: _shiftMonth,
    );

    final event = _eventFor(_selected);
    final dayHeading = _DayHeading(
      day: _selected,
      today: today,
      hijri: _hijriFor(_selected),
    );
    final eventCard = event == null ? null : _EventCard(event: event);
    final otherCity = _OtherCityRow(date: _selected);

    Widget column(List<Widget> children, {double gap = 14}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );

    final Widget body = switch (screen) {
      ScreenClass.phone => column([
          topBar,
          monthHeader,
          grid,
          Divider(height: 1, thickness: 1, color: colors.line),
          dayHeading,
          if (eventCard != null) eventCard,
          _DayPrayerCard(date: _selected, vertical: false),
          otherCity,
        ]),
      ScreenClass.tablet => column([
          topBar,
          monthHeader,
          grid,
          Divider(height: 1, thickness: 1, color: colors.line),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: column([
                  dayHeading,
                  if (eventCard != null) eventCard,
                  otherCity,
                ]),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 340,
                child: _DayPrayerCard(date: _selected, vertical: true),
              ),
            ],
          ),
        ], gap: 20),
      ScreenClass.desktop => column([
          topBar,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column([monthHeader, grid], gap: 16)),
              const SizedBox(width: 40),
              SizedBox(
                width: 360,
                child: column([
                  dayHeading,
                  if (eventCard != null) eventCard,
                  _DayPrayerCard(date: _selected, vertical: true),
                  otherCity,
                ]),
              ),
            ],
          ),
        ], gap: 20),
    };

    return Scaffold(
      backgroundColor: colors.ground,
      body: SingleChildScrollView(
        padding: pageGutter(context, maxWidth: widePageWidth).copyWith(
          top: insets.top + 12,
          bottom: insets.bottom + 32,
        ),
        child: body,
      ),
    );
  }
}

DateTime _localDate(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

HijriCalendar _hijriFor(DateTime date) =>
    HijriCalendar.fromDate(_localDate(date).add(Duration(days: hijriDate)));

String _hijriMonth(BuildContext context, int month) =>
    hijriMonthName(month, context.l10n).replaceAll(' Al-', ' al-');

/// "26 Rabi' al-Thani 1448".
String _hijriLabel(BuildContext context, HijriCalendar hijri) =>
    '${hijri.hDay} ${_hijriMonth(context, hijri.hMonth)} ${hijri.hYear}';

/// The Hijri months a Gregorian month runs across: "Rabi' al-Thani –
/// Jumada al-Awwal 1448", with both years when it crosses into a new one.
String _hijriSpan(BuildContext context, DateTime month) {
  final first = _hijriFor(month);
  final last = _hijriFor(DateTime(month.year, month.month + 1, 0));
  if (first.hMonth == last.hMonth) {
    return '${_hijriMonth(context, first.hMonth)} ${first.hYear}';
  }
  final firstYear = first.hYear == last.hYear ? '' : ' ${first.hYear}';
  return '${_hijriMonth(context, first.hMonth)}$firstYear – '
      '${_hijriMonth(context, last.hMonth)} ${last.hYear}';
}

/// How an events.json day is coloured. Its `color` has always meant 0 green
/// and 1 red, the way the calendar printed by H. Karmali in Mumbai marks the
/// year: red for joy (a birth, an Eid), green for mourning (a martyrdom, a
/// death). Anything else gets the plain beige.
@immutable
class CalendarEventTone {
  const CalendarEventTone({
    required this.tint,
    required this.line,
    required this.dot,
    required this.selectedDot,
  });

  /// The day cell's and the event card's fill.
  final Color tint;
  final Color line;

  /// The event card's marker.
  final Color dot;

  /// The marker on the picked day, over the accent fill.
  final Color selectedDot;

  static CalendarEventTone of(
      BuildContext context, Map<String, dynamic> event) {
    final colors = ShiaColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (event['color']) {
      0 => dark ? _darkGreen : _lightGreen,
      1 => dark ? _darkRed : _lightRed,
      _ => CalendarEventTone(
          tint: colors.well,
          line: colors.line,
          dot: colors.accent,
          selectedDot: colors.onAccent,
        ),
    };
  }

  static const _lightGreen = CalendarEventTone(
    tint: Color(0xFFE1EFE4),
    line: Color(0xFFBFDCC7),
    dot: Color(0xFF2F7A4A),
    selectedDot: Color(0xFF9FD8B0),
  );
  static const _lightRed = CalendarEventTone(
    tint: Color(0xFFF9E2DE),
    line: Color(0xFFEDC3BC),
    dot: Color(0xFFB3261E),
    selectedDot: Color(0xFFF4B4AE),
  );
  static const _darkGreen = CalendarEventTone(
    tint: Color(0xFF1E3325),
    line: Color(0xFF2F5A3C),
    dot: Color(0xFF7FBF95),
    selectedDot: Color(0xFF1E5C35),
  );
  static const _darkRed = CalendarEventTone(
    tint: Color(0xFF3B201C),
    line: Color(0xFF6A302A),
    dot: Color(0xFFF2B8B5),
    selectedDot: Color(0xFF9C2A22),
  );
}

/// The month as the page's title, the Hijri months it spans under it, and
/// Today and the month arrows beside it.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.hijriSpan,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final String hijriSpan;

  /// Null while today is the day picked and its month is on show.
  final VoidCallback? onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    maxLines: 1,
                    style: ShiaText.largeTitle.copyWith(color: colors.text),
                  ),
                ),
              ),
            ),
            if (onToday != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onToday,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.line),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  textStyle: buttonTextStyle(context,
                      ShiaText.secondary.copyWith(fontWeight: FontWeight.w600)),
                ),
                child: Text(context.l10n.commonToday),
              ),
            ],
            const SizedBox(width: 8),
            RoundIconButton(
              label: context.l10n.calendarPreviousMonth,
              icon: OutlineIcon(OutlineGlyph.chevronLeft,
                  size: 20, color: colors.accent, strokeWidth: 2.2),
              onPressed: onPrevious,
            ),
            const SizedBox(width: 8),
            RoundIconButton(
              label: context.l10n.calendarNextMonth,
              icon: OutlineIcon(OutlineGlyph.chevronRight,
                  size: 20, color: colors.accent, strokeWidth: 2.2),
              onPressed: onNext,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          hijriSpan,
          style: ShiaText.secondary.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// The month's weeks, Sunday first, with the days either side of it muted.
/// Each day shows its date top-left and its Hijri day in the other corner;
/// an event's day is coloured by [CalendarEventTone]. A sideways swipe
/// changes month.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.cellHeight,
    required this.wide,
    required this.hijriFor,
    required this.eventFor,
    required this.onPick,
    required this.onSwipe,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final double cellHeight;

  /// Tablet and up: a little more room around the same cells.
  final bool wide;
  final HijriCalendar Function(DateTime) hijriFor;
  final Map<String, dynamic>? Function(DateTime) eventFor;
  final ValueChanged<DateTime> onPick;
  final ValueChanged<int> onSwipe;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final lead = month.weekday % 7; // Sunday first
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((lead + daysInMonth) / 7).ceil();
    final gap = wide ? 6.0 : 3.0;

    Widget row(List<Widget> cells) => Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: cells[i]),
            ],
          ],
        );

    final weekdays = row([
      for (var i = 0; i < 7; i++)
        ExcludeSemantics(
          child: Text(
            // Sunday is weekday 7.
            shortWeekdayName(i == 0 ? 7 : i, context.l10n),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: ShiaText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
        ),
    ]);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final forward = velocity < 0;
        onSwipe(forward != rtl ? 1 : -1);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          weekdays,
          for (var week = 0; week < weeks; week++) ...[
            SizedBox(height: gap),
            row([
              for (var i = 0; i < 7; i++)
                Builder(builder: (context) {
                  final day = DateTime(
                      month.year, month.month, 1 - lead + week * 7 + i);
                  final inMonth = day.month == month.month;
                  return _DayCell(
                    day: day,
                    hijri: hijriFor(day),
                    event: inMonth ? eventFor(day) : null,
                    height: cellHeight,
                    wide: wide,
                    inMonth: inMonth,
                    isSelected: _isSameDay(day, selected),
                    isToday: _isSameDay(day, today),
                    onTap: () => onPick(day),
                  );
                }),
            ]),
          ],
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hijri,
    required this.event,
    required this.height,
    required this.wide,
    required this.inMonth,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final HijriCalendar hijri;
  final Map<String, dynamic>? event;
  final double height;
  final bool wide;
  final bool inMonth;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final tone = event == null ? null : CalendarEventTone.of(context, event!);

    var fill = tone?.tint ?? Colors.transparent;
    var border = tone?.line ?? Colors.transparent;
    var foreground = inMonth ? colors.text : colors.chevron;
    var muted = inMonth ? colors.textMuted : colors.chevron;
    if (isToday) border = colors.accent;
    if (isSelected) {
      fill = colors.accent;
      border = tone?.selectedDot ?? colors.accent;
      foreground = colors.onAccent;
      muted = colors.onAccent.withValues(alpha: 0.85);
    }
    final strong = isSelected || isToday;
    final eventName = event == null ? '' : eventHeadline(event!).name;

    final label = [
      DateFormat('d MMMM').format(day),
      _hijriLabel(context, hijri),
      if (event != null)
        eventName.isNotEmpty ? eventName : context.l10n.calendarHasEvent,
      if (isToday) context.l10n.commonToday,
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(wide ? 14 : 12),
          side: BorderSide(
            color: border,
            width: isSelected && tone != null ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                PositionedDirectional(
                  top: wide ? 7 : 5,
                  start: wide ? 9 : 7,
                  child: Text(
                    '${day.day}',
                    style: ShiaText.body.copyWith(
                      fontSize: wide ? 18 : 16,
                      height: 20 / (wide ? 18 : 16),
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
                PositionedDirectional(
                  bottom: wide ? 6 : 4,
                  end: wide ? 9 : 6,
                  child: Text(
                    convertNumberToUrdu('${hijri.hDay}'),
                    style: ShiaText.caption.copyWith(
                      fontSize: wide ? 12 : 11,
                      height: 13 / (wide ? 12 : 11),
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picked day: "Saturday 24 October", then how far it is from today
/// and its Hijri date. Picked today after Maghrib, it also says whose eve
/// tonight is, as Home's title does.
class _DayHeading extends StatelessWidget {
  const _DayHeading({
    required this.day,
    required this.today,
    required this.hijri,
  });

  final DateTime day;
  final DateTime today;
  final HijriCalendar hijri;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final days = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
    final relative = switch (days) {
      0 => l10n.commonToday,
      1 => l10n.commonTomorrow,
      -1 => l10n.calendarYesterday,
      > 1 => l10n.homeEventInDays(days),
      _ => l10n.calendarDaysAgo(-days),
    };

    String? eveOf;
    if (days == 0) {
      final islamicDay = islamicDayAt(CalendarPage.debugNow());
      final tonight = islamicDay.day.hijri;
      if (islamicDay.isEve &&
          (tonight.hDay != hijri.hDay || tonight.hMonth != hijri.hMonth)) {
        eveOf = l10n.hijriEveOfDate(_hijriLabel(context, tonight));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            DateFormat('EEEE d MMMM').format(day),
            style: ShiaText.sectionTitle.copyWith(
              fontSize: 22,
              height: 28 / 22,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: days == 0
                    ? colors.accent.withValues(alpha: 0.12)
                    : colors.well,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                relative,
                style: ShiaText.caption.copyWith(
                  fontSize: 12,
                  height: 18 / 12,
                  fontWeight: FontWeight.w700,
                  color: days == 0 ? colors.accent : colors.textMuted,
                ),
              ),
            ),
            Text(
              _hijriLabel(context, hijri),
              style: ShiaText.secondary.copyWith(color: colors.textMuted),
            ),
          ],
        ),
        if (eveOf != null) ...[
          const SizedBox(height: 4),
          Text(
            eveOf,
            style: ShiaText.secondary.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ],
      ],
    );
  }
}

/// The picked day's event, written out in full, in its day's colour.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final tone = CalendarEventTone.of(context, event);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: tone.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${event['content'] ?? ''}'.trim(),
              style: ShiaText.body.copyWith(
                fontSize: 16,
                height: 22 / 16,
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The picked day's prayer times on Home's brown card, with Azan and Times
/// on Home along its bottom edge. [vertical] lists all eight times top to
/// bottom (tablet and up); otherwise the five prayers run across with
/// Sunrise, Sunset and Midnight under them.
class _DayPrayerCard extends StatefulWidget {
  const _DayPrayerCard({required this.date, required this.vertical});

  final DateTime date;
  final bool vertical;

  @override
  State<_DayPrayerCard> createState() => _DayPrayerCardState();
}

class _DayPrayerCardState extends State<_DayPrayerCard> {
  static const _prayers = ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'];
  static const _others = ['Sunrise', 'Sunset', 'Midnight'];

  Future<void> _openAzan() async {
    await showPrayerNotificationsPage(context);
    if (mounted) setState(() {});
  }

  Future<void> _editTimesOnHome() async {
    final changed = await showWidgetPrayerTimesDialog(context);
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final entries = lat != null && long != null
        ? buildExtendedPrayerTimeEntries(
            prayerTime: getPrayerTimeObject(),
            date: widget.date,
            latitude: lat!,
            longitude: long!,
            timeZone: prayerTimeZoneFor(widget.date),
          )
        : null;
    final times = {
      for (final entry in entries ?? const <PrayerTimeDisplayEntry>[])
        entry.name: entry.time.replaceFirst(RegExp(r'^0(?=\d)'), ''),
    };

    final Widget content;
    if (entries == null) {
      content = _NoLocation(onChooseCity: () => chooseCityFlow(context));
    } else if (widget.vertical) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
        child: Column(
          children: [
            for (final (i, name) in const [
              'Fajr',
              'Sunrise',
              'Zuhr',
              'Asr',
              'Sunset',
              'Maghrib',
              'Isha',
              'Midnight',
            ].indexed) ...[
              if (i > 0) const _CardDivider(),
              _TimeRow(
                name: name,
                time: times[name] ?? '',
                prayer: _prayers.contains(name),
              ),
            ],
          ],
        ),
      );
    } else {
      final caption = ShiaText.caption.copyWith(height: 16 / 13);
      content = Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final name in _prayers)
                  Expanded(
                    child: MergeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            PrayerGlyph(
                                name: name,
                                size: 18,
                                color: colors.onPrayerCard),
                            const SizedBox(height: 3),
                            Text(
                              localizedPrayerName(name, context.l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onPrayerCard,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              times[name] ?? '',
                              maxLines: 1,
                              style: caption.copyWith(
                                color: colors.onPrayerCardMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const _CardDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  for (final name in _others)
                    Expanded(
                      child: MergeSemantics(
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PrayerGlyph(
                                    name: name,
                                    size: 14,
                                    color: colors.onPrayerCardMuted),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    localizedPrayerName(name, context.l10n),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: caption.copyWith(
                                      fontSize: 12,
                                      color: colors.onPrayerCardMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              times[name] ?? '',
                              style: caption.copyWith(
                                color: colors.onPrayerCard,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final azanOn =
        enabledPrayerNotificationNames(kPrayerNotificationList).length;
    final shownOnHome = selectedWidgetPrayerTimes().length;
    // Prayer notifications are a phone feature; the web has none to set.
    final showAzan = !kIsWeb;

    return Semantics(
      container: true,
      label: context.l10n.prayerTimesTitle,
      child: Material(
        color: colors.prayerCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.prayerCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            const _CardDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  if (showAzan) ...[
                    Expanded(
                      child: _CardButton(
                        glyph: OutlineGlyph.bell,
                        label: context.l10n.azanTitle,
                        value: azanOn > 0
                            ? context.l10n.calendarAzanOnFor(azanOn)
                            : context.l10n.azanOff,
                        onTap: _openAzan,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 22,
                      color: colors.onPrayerCard.withValues(alpha: 0.16),
                    ),
                  ],
                  Expanded(
                    child: _CardButton(
                      glyph: OutlineGlyph.home,
                      label: context.l10n.calendarTimesOnHome,
                      value: context.l10n.calendarTimesShown(shownOnHome),
                      onTap: _editTimesOnHome,
                    ),
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

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: ShiaColors.of(context).onPrayerCard.withValues(alpha: 0.14),
    );
  }
}

/// One of the eight times in the wide layouts' list. The five prayers are
/// set larger than Sunrise, Sunset and Midnight.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.name,
    required this.time,
    required this.prayer,
  });

  final String name;
  final String time;
  final bool prayer;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final style = (prayer ? ShiaText.cardTitle : ShiaText.secondary).copyWith(
      color: prayer ? colors.onPrayerCard : colors.onPrayerCardMuted,
    );
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Center(
                child: PrayerGlyph(
                  name: name,
                  size: prayer ? 20 : 18,
                  color:
                      prayer ? colors.onPrayerCard : colors.onPrayerCardMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Text(localizedPrayerName(name, context.l10n), style: style),
            ),
            Text(
              time,
              style: style.copyWith(
                fontWeight: FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A button along the prayer card's bottom edge: what it opens, and what
/// is set there now.
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.glyph,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final OutlineGlyph glyph;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlineIcon(glyph, size: 18, color: colors.onPrayerCard),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiaText.caption.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrayerCard,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiaText.caption.copyWith(
                          fontSize: 12,
                          height: 15 / 12,
                          color: colors.onPrayerCardMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card with no location to work times out for: says so, and offers a
/// city, so it is never a dead end.
class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.onChooseCity});

  final VoidCallback onChooseCity;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.prayerLocationUnavailable,
            style: ShiaText.cardTitle.copyWith(color: colors.onPrayerCard),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.prayerEnableLocationBody,
            style: ShiaText.secondary.copyWith(color: colors.onPrayerCardMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onChooseCity,
            style: FilledButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.onGold,
              minimumSize: const Size(44, 44),
              shape: const StadiumBorder(),
            ),
            child: Text(context.l10n.prayerChooseCity),
          ),
        ],
      ),
    );
  }
}

/// Another city's prayer times for the picked day - "what will they be
/// when I land in Karbala on the 16th?" - without making it the location.
class _OtherCityRow extends StatelessWidget {
  const _OtherCityRow({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => lookUpCityFlow(context, date: date),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.well,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: OutlineIcon(OutlineGlyph.globe,
                        size: 22, color: colors.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.calendarOtherCity,
                        style: ShiaText.body.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        context.l10n.calendarOtherCityFor(
                            DateFormat('d MMMM').format(date)),
                        style: ShiaText.secondary.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlineIcon(OutlineGlyph.chevronRight,
                    size: 16, color: colors.chevron, strokeWidth: 2.4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String convertNumberToUrdu(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], farsi[i]);
  }
  return input;
}
