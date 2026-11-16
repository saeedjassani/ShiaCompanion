import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../models/islamic_center.dart';
import '../../services/analytics_service.dart';
import '../../services/islamic_center_service.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/page_chrome.dart';
import '../centers/center_formatting.dart';
import '../centers/center_programs_page.dart';
import 'home_section.dart';

/// Home's link to the reader's Islamic centre (docs/ISLAMIC_CENTERS.md).
///
/// For someone who follows no centre, the nearest one in the directory -
/// if there is one within [IslamicCenterService.suggestionRadiusKm] - with
/// "Follow" and "Not now". For someone who does, the next programmes on
/// their centres' calendars. Nothing otherwise, so Home stays as it was for
/// everyone without a centre nearby.
class HomeCenterCard extends StatefulWidget {
  const HomeCenterCard({
    super.key,
    required this.topSpacing,
    required this.onOpenPrograms,
    this.service,
  });

  final double topSpacing;
  final VoidCallback onOpenPrograms;
  final IslamicCenterService? service;

  /// How many programmes Home lists.
  static const int limit = 2;

  @override
  State<HomeCenterCard> createState() => _HomeCenterCardState();
}

class _HomeCenterCardState extends State<HomeCenterCard> {
  IslamicCenterService get _service =>
      widget.service ?? IslamicCenterService.instance;

  @override
  void initState() {
    super.initState();
    _service.restore();
    // At most a read a day for the directory, and a fetch every few hours
    // per followed calendar: both no-ops while their copies are fresh.
    unawaited(_service.loadDirectory());
    unawaited(_service.refreshAll());
  }

  Future<void> _follow(IslamicCenter center) async {
    unawaited(
      AnalyticsService.feature(
        'center_followed',
        label: 'Center followed',
        parameters: {'source': 'home_suggestion', 'custom': 'false'},
      ),
    );
    showToast(context.l10n.centerFollowing(center.name));
    await _service.follow(center);
  }

  void _notNow() {
    unawaited(
      AnalyticsService.feature(
        'center_suggestion_dismissed',
        label: 'Center suggestion dismissed',
      ),
    );
    unawaited(_service.dismissSuggestion());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final Widget? child;
        if (_service.hasFollowed) {
          child = _programs(context);
        } else if (_service.suggestion() case (final center, final km)) {
          child = _suggestion(context, center, km);
        } else {
          child = null;
        }
        if (child == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: widget.topSpacing),
          child: child,
        );
      },
    );
  }

  Widget _suggestion(BuildContext context, IslamicCenter center, double km) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    return Semantics(
      container: true,
      child: HomeCard(
        radius: 20,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Text(
                l10n.centerNearbyLabel.toUpperCase(),
                style: ShiaText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.accent,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Semantics(
              header: true,
              child: Text(
                l10n.centerSuggestionTitle(center.name),
                style: ShiaText.cardTitle.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.centerSuggestionBody(centerDistance(km, l10n)),
              style: ShiaText.secondary.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: l10n.setupNotNow,
                    height: 44,
                    onPressed: _notNow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    label: l10n.centerFollow,
                    height: 44,
                    filled: true,
                    onPressed: () => _follow(center),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _programs(BuildContext context) {
    final now = DateTime.now();
    final events = _service.upcoming(now: now, limit: HomeCenterCard.limit);
    if (events.isEmpty) return null;
    final l10n = context.l10n;
    final followed = _service.followed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: followed.length == 1
              ? followed.single.name
              : l10n.centerHomeTitle,
          actionLabel: l10n.homeTodaySeeAll,
          actionSemanticsLabel: l10n.centerSeeAllPrograms,
          onAction: widget.onOpenPrograms,
        ),
        const SizedBox(height: 10),
        CardList(
          children: [
            for (final (i, event) in events.indexed)
              CenterEventRow(
                event: event,
                now: now,
                showDay: true,
                showCenter: followed.length > 1,
                first: i == 0,
                last: i == events.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}
