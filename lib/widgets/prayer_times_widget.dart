import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/pages/city_picker.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
import 'package:shia_companion/widgets/widget_prayer_times_dialog.dart';
import '../constants.dart';
import '../l10n/l10n.dart';

/// Home's prayer card: the next of the times the reader picked, large and
/// counting down to the second, then the ones after it in order (the Hijri
/// date and the city sit in Home's header above it). "Up next" reads
/// "Tomorrow" once every time shown is tomorrow's. Tap for Calendar & Prayer
/// Times; long-press to choose which times are shown.
///
/// With no location yet it asks "Which city are you in?" instead, until the
/// reader says "Not now": then a single slim row stands in for it, one tap
/// from the city picker. [footer], the next event, closes all three.
class HomePrayerTimesCard extends StatefulWidget {
  const HomePrayerTimesCard({super.key, this.onTap, this.footer});

  final VoidCallback? onTap;

  /// Drawn edge to edge under the times: Home's next-event row.
  final Widget? footer;

  @override
  PrayerTimesState createState() => PrayerTimesState();
}

class PrayerTimesState extends State<HomePrayerTimesCard> {
  PrayerTimesState();

  final LocationService _location = LocationService.instance;
  Timer? _ticker;

  /// Set once the reader answers "Which city are you in?" with "Not now":
  /// from then on the question shrinks to one row instead of taking over the
  /// top of Home. Nothing clears it - once a location is known the card shows
  /// times and the flag no longer matters.
  static const String cityPromptDismissedKey =
      'prayer_card_city_prompt_dismissed';

  bool get _cityPromptDismissed =>
      SP.isInitialized && (SP.prefs.getBool(cityPromptDismissedKey) ?? false);

  Future<void> _dismissCityPrompt() async {
    unawaited(AnalyticsService.feature(
      'city_prompt_dismissed',
      label: 'City prompt dismissed',
    ));
    if (SP.isInitialized) {
      await SP.prefs.setBool(cityPromptDismissedKey, true);
    }
    if (mounted) setState(() {});
  }

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

  /// The nudge's "Yes, still here": it stops asking until the city changes.
  Future<void> _stillInCity() async {
    unawaited(AnalyticsService.feature(
      'city_nudge_answered',
      label: 'City nudge answered',
      parameters: {'answer': 'still_there'},
    ));
    await _location.dismissZoneNudge();
  }

  Future<void> _changeCityFromNudge() async {
    unawaited(AnalyticsService.feature(
      'city_nudge_answered',
      label: 'City nudge answered',
      parameters: {'answer': 'change_city'},
    ));
    await _chooseCity();
  }

  /// The same picker Settings offers, reachable from the card it changes.
  Future<void> _editTimesShown() async {
    final changed = await showWidgetPrayerTimesDialog(context);
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final now = debugNow();
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
      if (_cityPromptDismissed) {
        return _SetCityRow(onTap: _chooseCity, footer: widget.footer);
      }
      return _ChooseLocationCard(
        location: _location,
        onUseLocation: _refreshLocation,
        onChooseCity: _chooseCity,
        onNotNow: _dismissCityPrompt,
        footer: widget.footer,
      );
    }

    // The row after the next time is in order, so it needs no "next day"
    // marks: what follows is later. Only once *everything* shown is
    // tomorrow's does the label say so.
    final allTomorrow = readings.every((r) => !_isSameDate(r.dateTime, now));
    final next = readings.first;
    final later = readings.skip(1).toList(growable: false);
    final failed = _location.status == LocationRefreshStatus.failed;
    final showUpdated = !failed && city != null && _location.shouldDiscloseAge;
    // A chosen city whose clock no longer matches the phone's: most likely
    // one picked on a trip, still set after the flight home.
    final askStillInCity = _location.chosenCityClockDifference != null;

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
        child: InkWell(
          onTap: widget.onTap,
          // Long-press is the second way into the picker, after Settings,
          // for people who prod at a thing before hunting for its setting.
          onLongPress: _editTimesShown,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (failed || showUpdated)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                        child: Text(
                          failed
                              ? _location.failureMessage
                              : context.l10n.prayerUpdatedAgo(
                                  _ageLabel(_location.updatedAt!)),
                          style: ShiaText.caption.copyWith(
                            color: colors.onPrayerCardMuted,
                          ),
                        ),
                      ),
                    _NextPrayer(
                      reading: next,
                      label: allTomorrow
                          ? context.l10n.commonTomorrow
                          : context.l10n.prayerUpNext,
                      now: debugNow,
                      // The moment it arrives the next time is a different one.
                      onArrived: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    if (later.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reading in later)
                            Expanded(
                                child: _PrayerTimeColumn(reading: reading)),
                        ],
                      ),
                    ],
                    if (askStillInCity)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _StillInCityNudge(
                          city: city ?? context.l10n.prayerTheCityYouChose,
                          onStillThere: _stillInCity,
                          onChangeCity: _changeCityFromNudge,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// "Still in Karbala?", under the times when the chosen city's clock no
/// longer matches the phone's.
class _StillInCityNudge extends StatelessWidget {
  const _StillInCityNudge({
    required this.city,
    required this.onStillThere,
    required this.onChangeCity,
  });

  final String city;
  final VoidCallback onStillThere;
  final VoidCallback onChangeCity;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final buttonText = ShiaText.secondary.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            color: colors.onPrayerCard.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.prayerStillInCity(city),
            style: ShiaText.secondary.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onPrayerCard,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.prayerPhoneZoneDiffers,
            style: ShiaText.caption.copyWith(color: colors.onPrayerCardMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onChangeCity,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.gold,
                    foregroundColor: colors.onGold,
                    minimumSize: const Size.fromHeight(40),
                    shape: const StadiumBorder(),
                    textStyle: buttonText,
                  ),
                  child: Text(context.l10n.cityChangeCity),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onStillThere,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onPrayerCard,
                    minimumSize: const Size.fromHeight(40),
                    side: BorderSide(
                      color: colors.onPrayerCard.withValues(alpha: 0.4),
                    ),
                    shape: const StadiumBorder(),
                    textStyle: buttonText,
                  ),
                  child: Text(context.l10n.prayerYesStillHere),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The city, as a button: tap to choose another, or to go back to the
/// phone's own location. Sits under Home's title.
class CityButton extends StatelessWidget {
  const CityButton({super.key, required this.location, required this.onTap});

  final LocationService location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final foreground = colors.accent;
    final refreshing = location.isRefreshing;
    // A missing name does not mean a missing location: this only shows once
    // there are coordinates, and the geocode that names them can fail or
    // still be running on its own.
    // A refresh only swaps the pin for a spinner; the name stays put.
    final label = city ??
        (refreshing
            ? context.l10n.prayerLocating
            : context.l10n.prayerYourLocation);

    return Tooltip(
      message: context.l10n.cityChangeCity,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: context.l10n.prayerCityButtonSemantics(label),
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: colors.surface,
          shape: StadiumBorder(side: BorderSide(color: colors.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              // 34 px drawn, as in the mockup; what is around it takes the
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
                              color: foreground,
                            ),
                          )
                        : OutlineIcon(
                            OutlineGlyph.pin,
                            size: 16,
                            color: foreground,
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
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlineIcon(
                      OutlineGlyph.chevronDown,
                      size: 14,
                      color: foreground,
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

/// One of the times after the next: glyph, name and time, at equal weight.
class _PrayerTimeColumn extends StatelessWidget {
  const _PrayerTimeColumn({required this.reading});

  final WidgetPrayerTimeReading reading;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final textStyle = ShiaText.caption.copyWith(height: 16 / 13);

    return Padding(
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
            _clockLabel(reading),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: textStyle.copyWith(color: colors.onPrayerCardMuted),
          ),
        ],
      ),
    );
  }
}

/// "6:56 pm", not the widgets' zero-padded "06:56 pm".
String _clockLabel(WidgetPrayerTimeReading reading) => localizeClockTime(
    reading.displayTime.replaceFirst(RegExp(r'^0(?=\d)'), ''));

/// The next time, large: its glyph, "Up next" (or "Tomorrow") over its name,
/// and its time over a countdown that ticks every second.
class _NextPrayer extends StatelessWidget {
  const _NextPrayer({
    required this.reading,
    required this.label,
    required this.now,
    required this.onArrived,
  });

  final WidgetPrayerTimeReading reading;
  final String label;
  final DateTime Function() now;
  final VoidCallback onArrived;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final name = localizedPrayerName(reading.time.name, context.l10n);
    final time = _clockLabel(reading);

    return Semantics(
      container: true,
      // The countdown is left out: read aloud, it would change every second.
      label: context.l10n.prayerNextSemantics(label, name, time),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: colors.onPrayerCard.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: PrayerGlyph(
                name: reading.time.name,
                size: 22,
                color: colors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ShiaText.caption.copyWith(
                      fontSize: 12,
                      height: 15 / 12,
                      color: colors.onPrayerCardMuted,
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      height: 24 / 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onPrayerCard,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 24,
                    height: 28 / 24,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrayerCard,
                  ),
                ),
                _Countdown(
                  target: reading.dateTime,
                  now: now,
                  onArrived: onArrived,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "in 3h 05m 09s", redrawn every second on its own so the rest of the card
/// is left alone. Tells the card when the time arrives.
class _Countdown extends StatefulWidget {
  const _Countdown({
    required this.target,
    required this.now,
    required this.onArrived,
  });

  final DateTime target;
  final DateTime Function() now;
  final VoidCallback onArrived;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.now().isBefore(widget.target)) {
        widget.onArrived();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    var left = widget.target.difference(widget.now());
    if (left.isNegative) left = Duration.zero;
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    final minutes = left.inMinutes % 60;
    final text = left.inHours > 0
        ? context.l10n.prayerCountdownHours(
            left.inHours, minutes.toString().padLeft(2, '0'), seconds)
        : context.l10n.prayerCountdownMinutes(minutes, seconds);
    return Text(
      localizeDigits(text, context.l10n),
      style: ShiaText.caption.copyWith(
        height: 16 / 13,
        fontWeight: FontWeight.w600,
        color: colors.gold,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// No location has ever been resolved, so there are no times to show: ask
/// which city the reader is in. Three answers, one of each weight: share the
/// location, name a city (the picker opens on the cities of the phone's time
/// zone, so the likely one is a tap away), or not now. Never a dead end — "Use my location" stays live while a fetch
/// runs, since one that silently died must not strand anyone on a spinner.
class _ChooseLocationCard extends StatelessWidget {
  const _ChooseLocationCard({
    required this.location,
    required this.onUseLocation,
    required this.onChooseCity,
    required this.onNotNow,
    this.footer,
  });

  final LocationService location;
  final VoidCallback onUseLocation;
  final VoidCallback onChooseCity;

  /// Shrinks the card to [_SetCityRow], for someone who would rather neither
  /// share their location nor name a city.
  final VoidCallback onNotNow;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final refreshing = location.isRefreshing;
    final failed = location.status == LocationRefreshStatus.failed;
    final muted = ShiaText.secondary.copyWith(color: colors.onPrayerCardMuted);

    final useLocationLabel = refreshing
        ? context.l10n.prayerFindingLocation
        : failed
            ? context.l10n.commonTryAgain
            : context.l10n.qiblaUseMyLocation;
    final useLocationIcon = refreshing
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.onGold,
            ),
          )
        : OutlineIcon(
            OutlineGlyph.pin,
            size: 18,
            color: colors.onGold,
            strokeWidth: 2,
          );
    final chooseCity = _OutlineCardButton(
      icon: OutlineIcon(
        OutlineGlyph.search,
        size: 18,
        color: colors.onPrayerCard,
        strokeWidth: 2,
      ),
      label: context.l10n.prayerChooseCity,
      onPressed: onChooseCity,
    );

    return Semantics(
      container: true,
      label: context.l10n.prayerTimesTitle,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.prayerCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.prayerCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.prayerTimesTitle,
                    style: ShiaText.caption.copyWith(
                      fontSize: 14,
                      height: 18 / 14,
                      color: colors.onPrayerCardMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.prayerWhichCity,
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
                        : context.l10n.prayerWhichCityBody,
                    style: muted,
                  ),
                  const SizedBox(height: 14),
                  _GoldButton(
                    icon: useLocationIcon,
                    label: useLocationLabel,
                    onPressed: onUseLocation,
                  ),
                  const SizedBox(height: 8),
                  chooseCity,
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: onNotNow,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onPrayerCardMuted,
                      textStyle: ShiaText.secondary
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    child: Text(context.l10n.setupNotNow),
                  ),
                ],
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

/// What "Which city are you in?" shrinks to after "Not now": one row that
/// still says why the times are missing and opens the city picker on tap.
class _SetCityRow extends StatelessWidget {
  const _SetCityRow({required this.onTap, this.footer});

  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.prayerCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.prayerCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  OutlineIcon(
                    OutlineGlyph.pin,
                    size: 20,
                    color: colors.gold,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.prayerTimesTitle,
                          style: ShiaText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onPrayerCard,
                          ),
                        ),
                        Text(
                          context.l10n.prayerSetCityHint,
                          style: ShiaText.secondary
                              .copyWith(color: colors.onPrayerCardMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlineIcon(
                    OutlineGlyph.chevronRight,
                    size: 18,
                    color: colors.onPrayerCardMuted,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
          ),
          if (footer != null) footer!,
        ],
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
