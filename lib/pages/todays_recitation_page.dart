import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/l10n/hijri_l10n.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/utils/todays_recitation.dart';
import 'package:shia_companion/utils/zikr_lists.dart';
import 'package:shia_companion/utils/zikr_occasions.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/widgets/zikr_list_row.dart';

import '../constants.dart';
import 'package:shia_companion/services/analytics_service.dart';
import '../l10n/l10n.dart';

/// Today's Recitations (docs/DESIGN_SPEC.md, "Lists"; mockup
/// `R3-Todays-recitations`): today's civil and Hijri dates under the title,
/// then one labelled card per occasion - tonight, today's date, the month,
/// the weekday, every day - most specific first.
class TodaysRecitationPage extends StatefulWidget {
  const TodaysRecitationPage({super.key});

  @override
  State<TodaysRecitationPage> createState() => _TodaysRecitationPageState();
}

class _TodaysRecitationPageState extends State<TodaysRecitationPage> {
  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Todays Recitation Page'));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: zikrIndexReady,
      builder: (context, ready, _) {
        final today = todaysLunarDays();
        final hijri = today.day.hijri;
        final dates = '${DateFormat('EEEE d MMMM').format(today.day.civilDate)}'
            ' · ${localizeDigits('${hijri.hDay}', context.l10n)} '
            '${hijriMonthName(hijri.hMonth, context.l10n).replaceAll(' Al-', ' al-')} '
            '${localizeDigits('${hijri.hYear}', context.l10n)}';

        return LargeTitlePage(
          maxWidth: widePageWidth,
          title: context.l10n.menuTodaysRecitations,
          subtitle: dates,
          slivers: ready
              ? _buildGroups(context, today)
              : const [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ],
        );
      },
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    ({LunarDay day, LunarDay? night}) today,
  ) {
    final l10n = context.l10n;
    final gutter = pageGutter(context, maxWidth: widePageWidth);
    final groups = buildTodaysRecitationGroups();

    if (groups.isEmpty) {
      return [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: EmptyStateCard(
              glyph: OutlineGlyph.calendar,
              title: l10n.todaysNone,
            ),
          ),
        ),
      ];
    }

    return [
      for (final group in groups) ...[
        SliverPadding(
          padding: gutter.copyWith(bottom: 8),
          sliver: SliverToBoxAdapter(
            child: GroupLabel(_label(group.kind, today, l10n)),
          ),
        ),
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverCardList(
            itemCount: group.items.length,
            itemBuilder: (context, i) => _buildRow(
              context,
              group.items[i],
              first: i == 0,
              last: i == group.items.length - 1,
            ),
          ),
        ),
      ],
    ];
  }

  String _label(
    TodaysRecitationKind kind,
    ({LunarDay day, LunarDay? night}) today,
    AppLocalizations l10n,
  ) {
    String date(LunarDay lunarDay) => l10n.occasionDaysOfMonth(
          localizeDigits('${lunarDay.hijri.hDay}', l10n),
          zikrMonthName(lunarDay.hijri.hMonth, l10n),
        );
    return switch (kind) {
      TodaysRecitationKind.night =>
        l10n.occasionNightsOf(1, date(today.night ?? today.day)),
      TodaysRecitationKind.date => date(today.day),
      TodaysRecitationKind.month =>
        l10n.todaysGroupMonth(zikrMonthName(today.day.hijri.hMonth, l10n)),
      TodaysRecitationKind.weekday =>
        l10n.todaysGroupWeekday(weekdayName(today.day.weekday)),
      TodaysRecitationKind.everyDay => l10n.occasionEveryDay,
    };
  }

  Widget _buildRow(
    BuildContext context,
    UidTitleData entry, {
    required bool first,
    required bool last,
  }) {
    final itemData = UniversalData(entry.uid, entry.title, 0);
    final title = isUserAdmin
        ? '${itemData.uid} ${itemData.displayTitle}'
        : itemData.displayTitle;

    if (isZikrGroup(entry)) {
      return ZikrGroupRow(
        first: first,
        last: last,
        title: title,
        onTap: () => pushPageRoute(context,
            ItemList(entry.getUId().split("~")[1], itemData.displayTitle)),
      );
    }

    return ZikrListRow(
      item: itemData,
      title: title,
      first: first,
      last: last,
      onTap: () => handleUniversalDataClick(context, itemData,
          source: ZikrOpenSource.todaysRecitation),
    );
  }
}
