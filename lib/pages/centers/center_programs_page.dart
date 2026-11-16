import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../models/islamic_center.dart';
import '../../services/islamic_center_service.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/responsive_content.dart' show compactContentWidth;
import 'center_directory_page.dart';
import 'center_event_sheet.dart';
import 'center_formatting.dart';

/// The programmes of the centres the reader follows, day by day, read from
/// each centre's public calendar (docs/ISLAMIC_CENTERS.md).
class CenterProgramsPage extends StatefulWidget {
  const CenterProgramsPage({super.key, this.service});

  /// [IslamicCenterService.instance] when null. For tests.
  final IslamicCenterService? service;

  @override
  State<CenterProgramsPage> createState() => _CenterProgramsPageState();
}

class _CenterProgramsPageState extends State<CenterProgramsPage> {
  IslamicCenterService get _service =>
      widget.service ?? IslamicCenterService.instance;

  @override
  void initState() {
    super.initState();
    trackScreen('Center Programs');
    _service.restore();
    unawaited(_service.refreshAll());
    unawaited(_service.loadDirectory());
  }

  void _openDirectory() {
    pushPageRoute(context, CenterDirectoryPage(service: widget.service));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);
    final followed = _service.followed;
    final now = DateTime.now();

    final manage = RoundIconButton(
      label: l10n.centerManage,
      icon: OutlineIcon(
        OutlineGlyph.sliders,
        size: 20,
        color: colors.accent,
        strokeWidth: 2,
      ),
      onPressed: _openDirectory,
    );

    if (followed.isEmpty) {
      return LargeTitlePage(
        title: l10n.menuCenterPrograms,
        maxWidth: compactContentWidth,
        actions: [manage],
        slivers: [
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: EmptyStateCard(
                glyph: OutlineGlyph.pin,
                title: l10n.centerEmptyTitle,
                body: l10n.centerEmptyBody,
                actionLabel: l10n.centerFind,
                onAction: _openDirectory,
              ),
            ),
          ),
        ],
      );
    }

    final events = _service.upcoming(now: now);
    final byDay = <DateTime, List<CenterEvent>>{};
    for (final event in events) {
      final start = event.occurrence.localStart;
      // Something that began before today and is still on shows under today.
      final today = DateTime(now.year, now.month, now.day);
      var day = DateTime(start.year, start.month, start.day);
      if (day.isBefore(today)) day = today;
      byDay.putIfAbsent(day, () => []).add(event);
    }
    final showCenter = followed.length > 1;

    final status = _StatusLine(service: _service, now: now);

    final slivers = <Widget>[
      SliverPadding(
        padding: gutter,
        sliver: SliverToBoxAdapter(child: status),
      ),
    ];
    if (events.isEmpty) {
      slivers.add(
        SliverPadding(
          padding: gutter.copyWith(top: 12),
          sliver: SliverToBoxAdapter(
            child: _service.isRefreshing && _service.eventsFetchedAt == null
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : EmptyStateCard(
                    glyph: OutlineGlyph.calendar,
                    title: l10n.centerNoProgramsTitle,
                    body: l10n.centerNoProgramsBody,
                    actionLabel: l10n.commonTryAgain,
                    onAction: () => _service.refreshAll(force: true),
                  ),
          ),
        ),
      );
    }
    for (final MapEntry(key: day, value: dayEvents) in byDay.entries) {
      slivers.add(
        SliverPadding(
          padding: gutter.copyWith(top: 18, bottom: 8),
          sliver: SliverToBoxAdapter(
            child: GroupLabel(centerDayLabel(day, now, l10n)),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: gutter,
          sliver: SliverCardList(
            itemCount: dayEvents.length,
            itemBuilder: (context, i) => CenterEventRow(
              event: dayEvents[i],
              now: now,
              showCenter: showCenter,
              first: i == 0,
              last: i == dayEvents.length - 1,
            ),
          ),
        ),
      );
    }

    return LargeTitlePage(
      title: l10n.menuCenterPrograms,
      subtitle: followed.length == 1
          ? followed.single.name
          : l10n.centerCount(followed.length),
      maxWidth: compactContentWidth,
      actions: [manage],
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// When the programmes were fetched, with Refresh; or, for a centre whose
/// calendar could not be read, why.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.service, required this.now});

  final IslamicCenterService service;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final problems = [
      for (final center in service.followed)
        if (service.errorFor(center.id) case final error?)
          centerErrorText(center, error, l10n),
    ];
    final fetchedAt = service.eventsFetchedAt;
    final refreshing = service.isRefreshing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final problem in problems)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OutlineIcon(
                    OutlineGlyph.alert,
                    size: 16,
                    color: colors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem,
                    style: ShiaText.secondary.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                refreshing
                    ? l10n.centerUpdating
                    : fetchedAt == null
                    ? ''
                    : centerUpdatedLabel(fetchedAt, now, l10n),
                style: ShiaText.caption.copyWith(color: colors.textMuted),
              ),
            ),
            if (refreshing)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              PageTextAction(
                label: l10n.centerRefresh,
                onPressed: () => service.refreshAll(force: true),
              ),
          ],
        ),
      ],
    );
  }
}

/// What went wrong reading [center]'s calendar, in a sentence.
String centerErrorText(
  IslamicCenter center,
  CenterFeedError error,
  AppLocalizations l10n,
) {
  return switch (error) {
    CenterFeedError.network => l10n.centerErrorNetwork(center.name),
    CenterFeedError.notPublic => l10n.centerErrorNotPublic(center.name),
    CenterFeedError.badLink => l10n.centerErrorBadLink(center.name),
  };
}

/// One programme in a list: its time on the left, then its title and
/// where (and which centre, when the reader follows more than one).
class CenterEventRow extends StatelessWidget {
  const CenterEventRow({
    super.key,
    required this.event,
    required this.now,
    this.showCenter = false,
    this.showDay = false,
    this.first = false,
    this.last = false,
  });

  final CenterEvent event;
  final DateTime now;
  final bool showCenter;

  /// Put the day before the time: for a list that is not grouped by day
  /// (Home's card).
  final bool showDay;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final o = event.occurrence;
    final happening =
        !o.allDay &&
        !o.start.isAfter(now.toUtc()) &&
        o.end.isAfter(now.toUtc());
    final where = [
      if (showCenter) event.center.name,
      if (o.location.trim().isNotEmpty) o.location.trim().split('\n').first,
    ].join(' · ');
    final time = centerEventTimeRange(event, l10n);
    final when = showDay
        ? '${centerDayLabel(o.localStart, now, l10n)} · $time'
        : time;

    return CardListRow(
      first: first,
      last: last,
      onTap: () => showCenterEventSheet(context, event),
      title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (happening)
                  TextSpan(
                    text: '${l10n.centerHappeningNow} · ',
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                TextSpan(text: when),
              ],
            ),
          ),
          if (where.isNotEmpty)
            Text(where, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: OutlineIcon(
        OutlineGlyph.chevronRight,
        size: 18,
        color: colors.chevron,
      ),
    );
  }
}
