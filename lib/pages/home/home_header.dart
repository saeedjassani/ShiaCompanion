import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../l10n/hijri_l10n.dart';
import '../../l10n/l10n.dart';
import '../../services/location_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/islamic_day.dart';
import '../../widgets/location_status_line.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/prayer_times_widget.dart';
import '../city_picker.dart';
import 'home_section.dart';

/// Today's Hijri date as Home's title, the year and the city under it (and,
/// once the phone's location is a day old, a line saying so), and the
/// profile button that opens Settings (docs/DESIGN_SPEC.md, Home
/// section 1). From Maghrib until Fajr the date is the next Islamic day's,
/// under a small "Eve of" - but only where Maghrib is known (see
/// [IslamicDay]).
class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  /// Lets tests pin the date the title shows.
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final LocationService _location = LocationService.instance;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onChanged);
    // The date turns over at midnight with nothing else rebuilding Home.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _onChanged());
  }

  @override
  void dispose() {
    _location.removeListener(_onChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _chooseCity() async {
    await chooseCityFlow(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final wide = isHomeWide(context);
    final islamicDay = islamicDayAt(HomeHeader.debugNow());
    final hijri = islamicDay.day.hijri;
    final dayAndMonth = '${localizeDigits('${hijri.hDay}', context.l10n)} '
        '${hijriMonthName(hijri.hMonth, context.l10n).replaceAll(' Al-', ' al-')}';

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (islamicDay.isEve)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ExcludeSemantics(
                    child: Text(
                      context.l10n.homeEveOf.toUpperCase(),
                      style: ShiaText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
              Semantics(
                header: true,
                label: islamicDay.isEve
                    ? '${context.l10n.homeEveOf} $dayAndMonth'
                    : null,
                excludeSemantics: islamicDay.isEve,
                child: Text(
                  dayAndMonth,
                  style: (wide ? ShiaText.homeTitleWide : ShiaText.homeTitle)
                      .copyWith(color: colors.text),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    context.l10n.homeHijriYear(
                        localizeDigits('${hijri.hYear}', context.l10n)),
                    style: ShiaText.secondary.copyWith(color: colors.textMuted),
                  ),
                  // With no location yet the prayer card asks for a city;
                  // a second "Your location" button here would only repeat it.
                  if (lat != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: CityButton(
                        location: _location,
                        onTap: _chooseCity,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _ProfileButton(onTap: widget.onOpenSettings),
      ],
    );
    // With no location the prayer card asks for one; there is nothing to
    // age.
    if (lat == null) return header;

    // A day-old location, and why: here rather than on the prayer card,
    // under the city it is about, with its fix one tap away. Full width, so
    // the profile button does not squeeze it onto a second line.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, const LocationStatusLine()],
    );
  }
}

/// The round profile button that opens Settings and sign-in.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Tooltip(
        message: context.l10n.homeSettingsAndAccount,
        child: Semantics(
          button: true,
          label: context.l10n.homeSettingsAndAccount,
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: colors.surface,
            shape: CircleBorder(side: BorderSide(color: colors.line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: OutlineIcon(
                    OutlineGlyph.profile,
                    size: 22,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
