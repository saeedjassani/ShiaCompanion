import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../constants.dart';
import '../l10n/hijri_l10n.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../services/prayer_calendar_service.dart';
import '../theme/shia_colors.dart';
import '../utils/prayer_calendar_plan.dart';
import '../utils/widget_prayer_time_selection.dart';
import '../widgets/app_toast.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/prayer_glyph.dart';
import '../widgets/widget_prayer_times_dialog.dart' show SelectionTick;
import 'city_picker.dart';

Future<void> showPrayerCalendarPage(BuildContext context) =>
    pushPageRoute(context, const PrayerCalendarPage());

/// "1 week", "2 weeks", "1 month": a choice of [prayerCalendarDayChoices].
String prayerCalendarRangeLabel(int days, AppLocalizations l10n) =>
    switch (days) {
      7 => l10n.prayerCalendarDays7,
      14 => l10n.prayerCalendarDays14,
      _ => l10n.prayerCalendarDays30,
    };

/// Puts the prayer times in a calendar on the phone (Google Calendar, Apple
/// Calendar), see [PrayerCalendarService]: which times, how far ahead, and
/// which calendar.
///
/// Before anything is added the ticks and the range are only a draft, and
/// Add to calendar asks for access, then for the calendar. Once they are in
/// a calendar every change is written as it is made, as on the Islamic
/// events page; there is no Done.
class PrayerCalendarPage extends StatefulWidget {
  const PrayerCalendarPage({super.key});

  @override
  State<PrayerCalendarPage> createState() => _PrayerCalendarPageState();
}

class _PrayerCalendarPageState extends State<PrayerCalendarPage> {
  final PrayerCalendarService _service = PrayerCalendarService.instance;
  late Set<String> _times = _service.timeIds;
  late int _days = _service.days;

  /// Set while asking for access and for a calendar, before the service is
  /// busy writing.
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Prayer Calendar Page');
    _service.addListener(_changed);
    LocationService.instance.addListener(_changed);
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    LocationService.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _busy => _starting || _service.busy;

  Future<void> _toggle(String id) async {
    final next = Set<String>.of(_times);
    if (!next.remove(id)) next.add(id);
    if (next.isEmpty) return;
    setState(() => _times = next);
    await _write(() => _service.setTimes(next));
  }

  Future<void> _pickDays(int days) async {
    setState(() => _days = days);
    await _write(() => _service.setDays(days));
  }

  /// Saves a change; written to the calendar only once it is on.
  Future<void> _write(Future<void> Function() change) async {
    try {
      await change();
      _sayIfCalendarGone();
    } catch (e) {
      debugPrint('Could not update the prayer calendar: $e');
      showToast(L10n.current.prayerCalendarFailed);
    }
  }

  /// [PrayerCalendarService] turns itself off when its calendar is deleted.
  void _sayIfCalendarGone() {
    if (_service.lostCalendar) {
      showToast(L10n.current.prayerCalendarCalendarGone);
    }
  }

  /// Asks for access, then for the calendar, and fills it. Also how the
  /// calendar is changed once they are in one.
  Future<void> _chooseCalendarAndAdd() async {
    final l10n = context.l10n;
    setState(() => _starting = true);
    try {
      if (!await _service.hasAccess() && !await _service.requestAccess()) {
        showToast(
          l10n.prayerCalendarNoAccess,
          actionLabel: l10n.commonOpenSettings,
          onAction: _service.openSettings,
        );
        return;
      }
      final calendars = await _service.writableCalendars();
      if (!mounted) return;
      if (calendars.isEmpty) {
        showToast(l10n.prayerCalendarNoCalendars);
        return;
      }
      // No spinner behind the list: nothing is happening until a pick.
      setState(() => _starting = false);
      final calendar = calendars.length == 1
          ? calendars.single
          : await _pickCalendar(calendars);
      if (calendar == null || !mounted) return;

      final wasOn = _service.isOn;
      final added = await _service.turnOn(calendar);
      if (!_service.isOn) {
        showToast(l10n.prayerCalendarCalendarGone);
        return;
      }
      showToast(
        added == 0
            ? l10n.prayerCalendarUpToDate(calendar.name)
            : l10n.prayerCalendarAdded(added, calendar.name),
      );
      if (!wasOn) {
        unawaited(
          AnalyticsService.prayerCalendarAdded(
            days: _service.days,
            times: _service.timeIds.length,
          ),
        );
      }
    } catch (e) {
      debugPrint('Could not add the prayer times to the calendar: $e');
      showToast(l10n.prayerCalendarFailed);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<PrayerCalendarChoice?> _pickCalendar(
    List<PrayerCalendarChoice> calendars,
  ) {
    final current = _service.calendarId;
    return showRevampSheet<PrayerCalendarChoice>(
      context,
      title: context.l10n.prayerCalendarChoose,
      builder: (context) {
        final colors = ShiaColors.of(context);
        return CardList(
          children: [
            for (final (i, calendar) in calendars.indexed)
              CardListRow(
                first: i == 0,
                last: i == calendars.length - 1,
                leading: _CalendarDot(colorHex: calendar.colorHex),
                title: Text(calendar.name),
                subtitle:
                    calendar.account == null ||
                        calendar.account == calendar.name
                    ? null
                    : Text(calendar.account!),
                trailing: calendar.id == current
                    ? OutlineIcon(
                        OutlineGlyph.check,
                        size: 18,
                        color: colors.accent,
                        strokeWidth: 2.4,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(calendar),
              ),
          ],
        );
      },
    );
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final name = _service.calendarName ?? '';
    try {
      await _service.turnOff();
      showToast(l10n.prayerCalendarRemoved(name));
      unawaited(AnalyticsService.prayerCalendarRemoved());
    } catch (e) {
      debugPrint('Could not take the prayer times out of the calendar: $e');
      showToast(l10n.prayerCalendarFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final on = _service.isOn;
    final hasLocation = lat != null && long != null;
    final through = _service.filledThrough;

    SliverPadding box(Widget child, {double bottom = 14}) => SliverPadding(
      padding: gutter.copyWith(bottom: bottom),
      sliver: SliverToBoxAdapter(child: child),
    );

    Widget note(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: ShiaText.caption.copyWith(
          height: 18 / 13,
          color: colors.textMuted,
        ),
      ),
    );

    return LargeTitlePage(
      title: l10n.prayerCalendarTitle,
      subtitle: l10n.prayerCalendarSubtitle,
      slivers: [
        if (!hasLocation && !on) ...[
          box(note(l10n.prayerCalendarNoLocation), bottom: 10),
          box(
            PageButton(
              label: l10n.prayerChooseCity,
              glyph: OutlineGlyph.pin,
              onPressed: () => chooseCityFlow(context),
            ),
            bottom: 20,
          ),
        ],
        if (on) ...[
          box(GroupLabel(l10n.prayerCalendarCalendarLabel), bottom: 8),
          box(
            CardList(
              children: [
                CardListRow(
                  first: true,
                  last: true,
                  leading: OutlineIcon(
                    OutlineGlyph.calendarCheck,
                    size: 24,
                    color: colors.accent,
                  ),
                  title: Text(_service.calendarName ?? ''),
                  subtitle: through == null
                      ? null
                      : Text(
                          l10n.prayerCalendarFilledThrough(
                            civilDayMonth(through, l10n),
                          ),
                        ),
                  trailing: OutlineIcon(
                    OutlineGlyph.chevronRight,
                    size: 16,
                    color: colors.chevron,
                    strokeWidth: 2.4,
                  ),
                  onTap: _busy ? null : _chooseCalendarAndAdd,
                ),
              ],
            ),
          ),
        ],
        box(GroupLabel(l10n.prayerCalendarTimesLabel), bottom: 8),
        box(
          CardList(
            children: [
              for (final (i, time) in widgetPrayerTimes.indexed)
                _TimeRow(
                  time: time,
                  ticked: _times.contains(time.id),
                  // One time is the least a calendar of them can hold.
                  enabled:
                      !_busy &&
                      !(_times.length == 1 && _times.contains(time.id)),
                  first: i == 0,
                  last: i == widgetPrayerTimes.length - 1,
                  onTap: () => _toggle(time.id),
                ),
            ],
          ),
        ),
        box(GroupLabel(l10n.prayerCalendarDaysLabel), bottom: 8),
        box(
          IgnorePointer(
            ignoring: _busy,
            child: SegmentedSwitcher<int>(
              segments: [
                for (final days in prayerCalendarDayChoices)
                  Segment(days, prayerCalendarRangeLabel(days, l10n)),
              ],
              selected: _days,
              onChanged: _pickDays,
            ),
          ),
        ),
        box(
          note(
            l10n.prayerCalendarFootnote(prayerCalendarRangeLabel(_days, l10n)),
          ),
        ),
      ],
      bottomBar: !on && !hasLocation
          ? null
          : _ActionBar(
              child: on
                  ? PageButton(
                      label: l10n.prayerCalendarRemove,
                      glyph: OutlineGlyph.trash,
                      danger: true,
                      busy: _busy,
                      onPressed: _remove,
                    )
                  : PageButton(
                      label: l10n.prayerCalendarAdd,
                      glyph: OutlineGlyph.calendar,
                      filled: true,
                      busy: _busy,
                      onPressed: _chooseCalendarAndAdd,
                    ),
            ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.time,
    required this.ticked,
    required this.enabled,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final WidgetPrayerTime time;
  final bool ticked;
  final bool enabled;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return MergeSemantics(
      child: Semantics(
        checked: ticked,
        enabled: enabled,
        child: Opacity(
          opacity: enabled || ticked ? 1 : 0.5,
          child: CardListRow(
            first: first,
            last: last,
            leading: PrayerGlyph(
              name: time.name,
              size: 24,
              color: colors.accent,
            ),
            title: Text(localizedPrayerName(time.name, context.l10n)),
            trailing: SizedBox.square(
              dimension: 44,
              child: Center(child: SelectionTick(selected: ticked)),
            ),
            onTap: enabled ? onTap : null,
          ),
        ),
      ),
    );
  }
}

/// The calendar's own colour, as the phone's calendar apps show it.
class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.colorHex});

  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final hex = colorHex?.replaceFirst('#', '');
    final value = hex != null && hex.length == 6
        ? int.tryParse(hex, radix: 16)
        : null;
    return SizedBox.square(
      dimension: 24,
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value == null ? colors.accent : Color(0xFF000000 | value),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.ground,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: pageGutter(context).copyWith(top: 12, bottom: 12),
          child: child,
        ),
      ),
    );
  }
}
