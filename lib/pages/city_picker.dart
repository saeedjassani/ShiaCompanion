import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/city.dart';
import '../services/analytics_service.dart';
import '../services/city_repository.dart';
import '../services/location_service.dart';
import '../theme/shia_colors.dart';
import '../utils/city_clock.dart';
import '../widgets/outline_icon.dart';
import 'city_prayer_times_page.dart';

/// What the reader chose in the city picker.
sealed class CityChoice {
  const CityChoice();
}

/// A city from the list, to use from now on.
class ChosenCity extends CityChoice {
  const ChosenCity(this.city);
  final City city;
}

/// Go back to the phone's own position.
class UseDeviceLocation extends CityChoice {
  const UseDeviceLocation();
}

/// What the picker is choosing a city for.
enum CityPickerPurpose {
  /// Where the reader is: their prayer times, widgets and notifications
  /// follow it.
  location,

  /// Only to look at its prayer times (see CityPrayerTimesPage).
  lookup,
}

/// The phone's IANA time zone ("Europe/London"), or null where it cannot be
/// read. Used only to suggest a city, never to compute anything.
Future<String?> deviceTimeZone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null;
  }
}

/// The city picker: a tall bottom sheet on phones, a centred dialog from
/// tablet width up (docs/DESIGN_SPEC.md, "Responsive behaviour").
Future<CityChoice?> showCityPicker(
  BuildContext context, {
  CityPickerPurpose purpose = CityPickerPurpose.location,
}) {
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<CityChoice>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: ShiaColors.of(context).ground,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: CityPicker(purpose: purpose),
        ),
      ),
    );
  }
  return showModalBottomSheet<CityChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ShiaColors.of(context).ground,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: CityPicker(purpose: purpose),
    ),
  );
}

/// Opens the picker and applies the answer: the chosen city from now on, or
/// back to the phone's position (with the permission dialogs, if needed).
///
/// A city whose clock reads differently from the phone's is rarely where the
/// reader is - phones keep their own time zone up to date - and making it
/// the location would ring notifications at its prayer times, hours off
/// their own. So that choice asks first, and "Just checking times" only
/// shows that city's times.
Future<void> chooseCityFlow(BuildContext context) async {
  final choice = await showCityPicker(context);
  if (choice == null || !context.mounted) return;
  if (choice case ChosenCity(:final city)) {
    final difference = cityClockDifference(city);
    if (difference != null && difference != Duration.zero) {
      final inCity = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _InCityQuestion(city: city, difference: difference),
      );
      if (inCity == null || !context.mounted) return;
      if (!inCity) {
        await openCityPrayerTimes(context, city, source: 'picker');
        return;
      }
      await applyCityChoice(
        context,
        choice,
        source: 'picker',
        confirmedInCity: true,
      );
      return;
    }
  }
  await applyCityChoice(context, choice, source: 'picker');
}

/// Opens the picker to look up a city's prayer times, changing nothing - the
/// Calendar's "Another city". [date] starts on that date.
Future<void> lookUpCityFlow(BuildContext context, {DateTime? date}) async {
  final choice = await showCityPicker(
    context,
    purpose: CityPickerPurpose.lookup,
  );
  if (choice is! ChosenCity || !context.mounted) return;
  await openCityPrayerTimes(context, choice.city,
      source: 'calendar', date: date);
}

/// Applies [choice] through [LocationService] and counts it. [source] says
/// where it was made: the picker, or the time-zone guess on the prayer card.
/// [confirmedInCity]: see [LocationService.chooseCity].
Future<void> applyCityChoice(
  BuildContext context,
  CityChoice choice, {
  required String source,
  bool confirmedInCity = false,
}) async {
  switch (choice) {
    case ChosenCity(:final city):
      unawaited(AnalyticsService.feature(
        'city_chosen',
        label: 'City chosen',
        parameters: {'source': source, 'country': city.countryCode},
      ));
      await LocationService.instance
          .chooseCity(city, confirmedInCity: confirmedInCity);
    case UseDeviceLocation():
      unawaited(AnalyticsService.feature(
        'device_location_chosen',
        label: 'Device location chosen',
        parameters: {'source': source},
      ));
      await LocationService.instance.useDeviceLocation(context: context);
  }
}

/// The picker's content: offline search over the bundled city list, with the
/// phone's own location as the other way out.
class CityPicker extends StatefulWidget {
  const CityPicker({
    super.key,
    this.timeZone,
    this.purpose = CityPickerPurpose.location,
  });

  /// The time zone to suggest cities from; read from the phone when null.
  final String? timeZone;

  final CityPickerPurpose purpose;

  @override
  State<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  final TextEditingController _query = TextEditingController();
  String? _timeZone;
  bool _loaded = CityRepository.instance.isLoaded;

  @override
  void initState() {
    super.initState();
    _timeZone = widget.timeZone;
    _query.addListener(() => setState(() {}));
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final zone = _timeZone ?? await deviceTimeZone();
    await CityRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _timeZone = zone;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _choose(CityChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final lookup = widget.purpose == CityPickerPurpose.lookup;
    final query = _query.text.trim();
    final List<CityMatch> results;
    final String? listLabel;
    if (!_loaded) {
      results = const [];
      listLabel = null;
    } else if (query.isEmpty && lookup) {
      // Suggesting the reader's own time zone is no help for looking
      // somewhere else up.
      results = const [];
      listLabel = null;
    } else if (query.isEmpty) {
      results = [
        for (final city in CityRepository.instance.biggestInTimeZone(_timeZone))
          CityMatch(city),
      ];
      listLabel = results.isEmpty ? null : 'In your time zone';
    } else {
      results = CityRepository.instance.search(query);
      listLabel = results.isEmpty ? null : 'Cities';
    }
    // Two results of the same name in the same country say which province.
    final nameCounts = <String, int>{};
    for (final match in results) {
      final key = '${match.city.name}|${match.city.countryCode}';
      nameCounts[key] = (nameCounts[key] ?? 0) + 1;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: colors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    minimumSize: const Size(44, 44),
                    textStyle: ShiaText.body,
                  ),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      lookup ? 'Another city' : 'Choose your city',
                      textAlign: TextAlign.center,
                      style: ShiaText.cardTitle.copyWith(color: colors.text),
                    ),
                  ),
                ),
                // Balances Cancel so the title stays centred.
                const SizedBox(width: 72),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _SearchField(controller: _query),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                if (!lookup) ...[
                  _UseLocationRow(
                    isManual: LocationService.instance.isManual,
                    onTap: () => _choose(const UseDeviceLocation()),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_loaded)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (query.isNotEmpty && results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'No city called “$query”. Try another spelling, or the '
                      'nearest bigger city - its prayer times will be within '
                      'a minute or two of yours.',
                      style:
                          ShiaText.secondary.copyWith(color: colors.textMuted),
                    ),
                  )
                else if (listLabel != null) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Text(
                      listLabel.toUpperCase(),
                      style: ShiaText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ResultsCard(
                    results: results,
                    showProvince: (match) =>
                        (nameCounts['${match.city.name}|'
                                '${match.city.countryCode}'] ??
                            0) >
                        1,
                    onTap: (city) => _choose(ChosenCity(city)),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    lookup
                        ? 'See any city\'s prayer times on its own clock. Your '
                            'own prayer times and notifications stay as they '
                            'are.'
                        : 'Prayer times are worked out on your phone, so this '
                            'works without internet. You can change city any '
                            'time from the prayer card.',
                    style: ShiaText.caption.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'City list: GeoNames (geonames.org), CC BY 4.0',
                    style: ShiaText.caption.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Are you in Karbala now?", asked when a city chosen as the location reads
/// a different time from the phone. Pops true for "I'm in Karbala now",
/// false for "Just checking times".
class _InCityQuestion extends StatelessWidget {
  const _InCityQuestion({required this.city, required this.difference});

  final City city;
  final Duration difference;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return AlertDialog(
      title: Text('Are you in ${city.name} now?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${city.name} is ${clockDifferenceLabel(difference)}. Checking '
            'its times won\'t change your own prayer times or notifications.',
            style: ShiaText.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              textStyle: ShiaText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            child: const Text('Just checking times'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: colors.accent,
              minimumSize: const Size.fromHeight(44),
              textStyle: ShiaText.body,
            ),
            child: Text("I'm in ${city.name} now"),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      style: ShiaText.body.copyWith(color: colors.text),
      decoration: InputDecoration(
        hintText: 'Search for a city',
        hintStyle: ShiaText.body.copyWith(color: colors.textMuted),
        filled: true,
        fillColor: colors.well,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: OutlineIcon(
            OutlineGlyph.search,
            size: 20,
            color: colors.textMuted,
            strokeWidth: 2,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: Icon(Icons.close_rounded, color: colors.textMuted),
                onPressed: controller.clear,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _UseLocationRow extends StatelessWidget {
  const _UseLocationRow({required this.isManual, required this.onTap});

  final bool isManual;
  final VoidCallback onTap;

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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.well,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: OutlineIcon(
                  OutlineGlyph.pin,
                  size: 22,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isManual
                          ? 'Use my current location instead'
                          : 'Use my current location',
                      style: TextStyle(
                        fontSize: 16,
                        height: 21 / 16,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Updates by itself when you travel',
                      style: ShiaText.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.results,
    required this.showProvince,
    required this.onTap,
  });

  final List<CityMatch> results;
  final bool Function(CityMatch match) showProvince;
  final ValueChanged<City> onTap;

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
      child: Column(
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: Divider(height: 1, color: colors.divider),
              ),
            _ResultRow(
              match: results[i],
              showProvince: showProvince(results[i]),
              onTap: () => onTap(results[i].city),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.match,
    required this.showProvince,
    required this.onTap,
  });

  final CityMatch match;
  final bool showProvince;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final city = match.city;
    final bold = match.nameMatchLength.clamp(0, city.name.length);
    final place = [
      if (showProvince && city.admin1Name.isNotEmpty) city.admin1Name,
      city.countryName,
    ].join(', ');
    final subtitle =
        match.alias == null ? place : '$place · also ${match.alias}';
    final nameStyle = ShiaText.body.copyWith(color: colors.text);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: nameStyle,
                        children: [
                          TextSpan(
                            text: city.name.substring(0, bold),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: city.name.substring(bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: ShiaText.caption.copyWith(
                        fontSize: 14,
                        height: 18 / 14,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
