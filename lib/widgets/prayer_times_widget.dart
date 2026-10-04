import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/pages/city_picker.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/utils/prayer_clock.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
import 'package:shia_companion/widgets/widget_prayer_times_dialog.dart';
import '../constants.dart';
import '../l10n/l10n.dart';
import '../l10n/hijri_l10n.dart';

/// Home's prayer card: the Hijri date and the city, then the prayer times the
/// reader picked, starting with the next one. Tap for Calendar & Prayer
/// Times; long-press to choose which times are shown.
///
/// With no location yet it asks "Which city are you in?" instead.
class HomePrayerTimesCard extends StatefulWidget {
  const HomePrayerTimesCard({super.key, this.onTap});

  final VoidCallback? onTap;

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
    // The order of the times, and near midnight the list itself, move
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

  /// The city picker: a city by name, or back to the phone's location.
  Future<void> _chooseCity() async {
    await chooseCityFlow(context);
    if (mounted) setState(() {});
  }

  Future<void> _acceptGuess(City guess) async {
    await applyCityChoice(context, ChosenCity(guess), source: 'time_zone');
    if (mounted) setState(() {});
  }

  /// The city the phone's time zone points at, worked out once per run and
  /// only when the card has no location to show - so the city list is only
  /// read for someone who needs it.
  static Future<City?>? _timeZoneGuess;

  /// Where the phone's time zone is read from; tests pin it.
  @visibleForTesting
  static Future<String?> Function() timeZoneSource = deviceTimeZone;

  @visibleForTesting
  static void debugResetTimeZoneGuess() => _timeZoneGuess = null;

  static Future<City?> _guessCity() async {
    final zone = await timeZoneSource();
    if (zone == null || !zone.contains('/') || zone.startsWith('Etc/')) {
      return null;
    }
    await CityRepository.instance.load();
    return CityRepository.instance.guessForTimeZone(zone);
  }

  /// The same picker Settings offers, reachable from the card it changes.
  Future<void> _editTimesShown() async {
    final changed = await showWidgetPrayerTimesDialog(context);
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    // On a chosen city's clock, so are the times, "next day" and the date.
    final now = PrayerClock.now(debugNow());
    final hijri = HijriCalendar.fromDate(now.add(Duration(days: hijriDate)));
    final dateText = '${hijri.hDay} '
        '${hijriMonthName(hijri.hMonth, context.l10n).replaceAll(' Al-', ' al-')} '
        '${hijri.hYear}';
    final selected = selectedWidgetPrayerTimes();

    // Always render from the last known fix. A refresh in flight, or one that
    // just failed, never blanks times the user could still be relying on.
    final readings = lat != null
        ? nextWidgetPrayerTimeReadings(
            prayerTime: getPrayerTimeObject(),
            latitude: lat!,
            longitude: long!,
            count: selected.length,
            now: now,
            times: selected,
          )
        : const <WidgetPrayerTimeReading>[];

    if (readings.isEmpty) {
      return FutureBuilder<City?>(
        future: _timeZoneGuess ??= _guessCity().catchError((_) => null),
        builder: (context, snapshot) => _ChooseLocationCard(
          location: _location,
          guess: snapshot.data,
          onUseLocation: _refreshLocation,
          onChooseCity: _chooseCity,
          onAcceptGuess: _acceptGuess,
        ),
      );
    }

    // Where "tomorrow" starts, if at all — the row is chronological, so once
    // one time crosses midnight every time after it has too. Only that first
    // one is marked, like a date divider in a list.
    final firstTomorrowIndex =
        readings.indexWhere((r) => !_isSameDate(r.dateTime, now));
    final failed = _location.status == LocationRefreshStatus.failed;
    final showUpdated = !failed && city != null && _location.shouldDiscloseAge;
    // Times on a city's clock, beside a phone that reads otherwise.
    final clock = PrayerClock.describe(now);
    final notes = [
      if (failed) _location.failureMessage,
      if (showUpdated) 'updated ${_ageLabel(_location.updatedAt!)}',
      if (clock != null) clock,
    ];

    return Semantics(
      container: true,
      label: 'Prayer times',
      child: Material(
        color: colors.prayerCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.prayerCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          // Long-press is the second way into the picker, after Settings,
          // for people who prod at a thing before hunting for its setting.
          onLongPress: _editTimesShown,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateText,
                          style: ShiaText.secondary.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onPrayerCard,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Capped so a long place name ("City of
                      // Westminster") gives way to the date, not the reverse.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.42,
                        ),
                        child: _CityButton(
                          location: _location,
                          onTap: _chooseCity,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      notes.join(' · '),
                      style: ShiaText.caption.copyWith(
                        color: colors.onPrayerCardMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < readings.length; i++)
                      Expanded(
                        child: _PrayerTimeColumn(
                          reading: readings[i],
                          startsNextDay: i == firstTomorrowIndex,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The city, as a button: tap to choose another, or to go back to the
/// phone's own location.
class _CityButton extends StatelessWidget {
  const _CityButton({required this.location, required this.onTap});

  final LocationService location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final refreshing = location.isRefreshing;
    // A missing name does not mean a missing location: this only shows once
    // there are coordinates, and the geocode that names them can fail or
    // still be running on its own.
    // A refresh only swaps the pin for a spinner; the name stays put.
    final label = city ?? (refreshing ? context.l10n.prayerLocating : 'Your location');

    return Tooltip(
      message: 'Change city',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: '$label. Change city',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: colors.onPrayerCard.withValues(alpha: 0.12),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              // 34 px drawn, as in the mockup; the card around it takes the
              // tap when it lands just outside.
              constraints: const BoxConstraints(minHeight: 34),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    refreshing
                        ? SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrayerCard,
                            ),
                          )
                        : OutlineIcon(
                            OutlineGlyph.pin,
                            size: 16,
                            color: colors.onPrayerCard,
                          ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiaText.secondary.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrayerCard,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlineIcon(
                      OutlineGlyph.chevronDown,
                      size: 14,
                      color: colors.onPrayerCard,
                      strokeWidth: 2.2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One prayer: glyph, name and time, all at equal weight — order alone says
/// what's next. The first time that falls tomorrow is set off by a dashed
/// rule and says "next day" under it.
class _PrayerTimeColumn extends StatelessWidget {
  const _PrayerTimeColumn({
    required this.reading,
    required this.startsNextDay,
  });

  final WidgetPrayerTimeReading reading;
  final bool startsNextDay;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final textStyle = ShiaText.caption.copyWith(height: 16 / 13);

    final column = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrayerGlyph(
            name: reading.time.name,
            size: 18,
            color: colors.onPrayerCard,
          ),
          const SizedBox(height: 3),
          Text(
            localizedPrayerName(reading.time.name, context.l10n),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onPrayerCard,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            // "6:56 pm", not the widgets' zero-padded "06:56 pm".
            reading.displayTime.replaceFirst(RegExp(r'^0(?=\d)'), ''),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: textStyle.copyWith(color: colors.onPrayerCardMuted),
          ),
          if (startsNextDay) ...[
            const SizedBox(height: 3),
            Text(
              'next day',
              textAlign: TextAlign.center,
              style: ShiaText.tabLabel.copyWith(
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: colors.onPrayerCardMuted,
              ),
            ),
          ],
        ],
      ),
    );

    if (!startsNextDay) return column;
    return CustomPaint(
      painter: _DashedStartRule(colors.onPrayerCard.withValues(alpha: 0.3)),
      child: column,
    );
  }
}

/// A 1 px dashed rule down the leading edge.
class _DashedStartRule extends CustomPainter {
  _DashedStartRule(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 3.0;
    for (var y = 0.0; y < size.height; y += dash * 2) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + dash), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedStartRule old) => old.color != color;
}

/// No location has ever been resolved, so there are no times to show: ask
/// which city the reader is in, suggesting the one their phone's time zone
/// points at. Never a dead end — "Use my location" stays live while a fetch
/// runs, since one that silently died must not strand anyone on a spinner.
class _ChooseLocationCard extends StatelessWidget {
  const _ChooseLocationCard({
    required this.location,
    required this.guess,
    required this.onUseLocation,
    required this.onChooseCity,
    required this.onAcceptGuess,
  });

  final LocationService location;
  final City? guess;
  final VoidCallback onUseLocation;
  final VoidCallback onChooseCity;
  final ValueChanged<City> onAcceptGuess;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final refreshing = location.isRefreshing;
    final failed = location.status == LocationRefreshStatus.failed;
    final muted = ShiaText.secondary.copyWith(color: colors.onPrayerCardMuted);
    final guess = this.guess;

    final useLocationLabel = refreshing
        ? 'Finding your location…'
        : failed
            ? 'Try again'
            : 'Use my location';
    final useLocationIcon = refreshing
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: guess == null ? colors.onGold : colors.onPrayerCard,
            ),
          )
        : OutlineIcon(
            OutlineGlyph.pin,
            size: 18,
            color: guess == null ? colors.onGold : colors.onPrayerCard,
            strokeWidth: 2,
          );
    final chooseCity = _OutlineCardButton(
      icon: OutlineIcon(
        OutlineGlyph.search,
        size: 18,
        color: colors.onPrayerCard,
        strokeWidth: 2,
      ),
      label: 'Choose city',
      onPressed: onChooseCity,
    );

    return Semantics(
      container: true,
      label: 'Prayer times',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.prayerCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.prayerCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prayer times',
              style: ShiaText.caption.copyWith(
                fontSize: 14,
                height: 18 / 14,
                color: colors.onPrayerCardMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Which city are you in?',
              style: TextStyle(
                fontSize: 23,
                height: 28 / 23,
                fontWeight: FontWeight.w700,
                color: colors.onPrayerCard,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              failed
                  ? location.failureMessage
                  : "We'll show today's prayer times and the next azan.",
              style: muted,
            ),
            const SizedBox(height: 14),
            if (guess != null) ...[
              Text(
                "Your phone's time zone suggests ${guess.name}.",
                style: ShiaText.caption.copyWith(
                  fontSize: 14,
                  height: 18 / 14,
                  color: colors.onPrayerCardMuted,
                ),
              ),
              const SizedBox(height: 8),
              _GoldButton(
                label: "Yes, I'm in ${guess.name}",
                onPressed: () => onAcceptGuess(guess),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _OutlineCardButton(
                      icon: useLocationIcon,
                      label: refreshing ? 'Locating…' : useLocationLabel,
                      onPressed: onUseLocation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: chooseCity),
                ],
              ),
            ] else ...[
              _GoldButton(
                icon: useLocationIcon,
                label: useLocationLabel,
                onPressed: onUseLocation,
              ),
              const SizedBox(height: 8),
              chooseCity,
            ],
          ],
        ),
      ),
    );
  }
}

/// The one primary button on the prayer card, in gold.
class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.gold,
        foregroundColor: colors.onGold,
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: ShiaText.body.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// A secondary button on the prayer card: outlined in the card's own text
/// colour.
class _OutlineCardButton extends StatelessWidget {
  const _OutlineCardButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onPrayerCard,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: colors.onPrayerCard.withValues(alpha: 0.4)),
        shape: const StadiumBorder(),
        textStyle: ShiaText.secondary.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

String _ageLabel(DateTime updatedAt) {
  final age = DateTime.now().difference(updatedAt);
  if (age.inDays >= 1) {
    return L10n.current.timeDaysAgo(age.inDays);
  }
  return L10n.current.timeHoursAgo(age.inHours);
}
