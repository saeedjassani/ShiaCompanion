import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../models/ziyarat_guide.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import 'ziyarat_guide_widgets.dart';
import 'ziyarat_site_page.dart';

/// A city of the Ziyarat Guide: what it is, tips for the pilgrim, and its
/// places, each opening its own page.
class ZiyaratCityPage extends StatefulWidget {
  const ZiyaratCityPage({super.key, required this.city});

  final GuideCity city;

  @override
  State<ZiyaratCityPage> createState() => _ZiyaratCityPageState();
}

class _ZiyaratCityPageState extends State<ZiyaratCityPage> {
  GuideCity get city => widget.city;

  @override
  void initState() {
    super.initState();
    trackScreen('Ziyarat Guide City');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: city.name,
      subtitle: city.region.name,
      slivers: [
        if (city.sites.isNotEmpty)
          GuideSection(
            label: l10n.ziyaratGuidePlaces,
            sliver: SliverCardList(
              itemCount: city.sites.length,
              itemBuilder: (context, i) => _SiteRow(
                site: city.sites[i],
                first: i == 0,
                last: i == city.sites.length - 1,
              ),
            ),
          ),
        if (city.about != null)
          GuideSection(
            label: l10n.ziyaratGuideAbout,
            sliver:
                SliverToBoxAdapter(child: GuideTextCard(paragraph: city.about)),
          ),
        if (city.tips.isNotEmpty)
          GuideSection(
            label: l10n.ziyaratGuideTips,
            sliver:
                SliverToBoxAdapter(child: GuideTextCard(bullets: city.tips)),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site, required this.first, required this.last});

  final GuideSite site;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final kind = guideSiteKindLabel(l10n, site.kind);
    return CardListRow(
      first: first,
      last: last,
      minHeight: 60,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.well,
          borderRadius: BorderRadius.circular(10),
        ),
        child: OutlineIcon(OutlineGlyph.pin, size: 20, color: colors.accent),
      ),
      title: Text(site.name),
      titleStyle: ShiaText.body.copyWith(fontWeight: FontWeight.w600),
      subtitle: Text(site.ziyarat.isEmpty
          ? kind
          : '$kind · ${l10n.listCountZiyarats(site.ziyarat.length)}'),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
        child: OutlineIcon(OutlineGlyph.chevronRight,
            size: 16, color: colors.chevron, strokeWidth: 2.4),
      ),
      onTap: () {
        AnalyticsService.feature(
          'ziyarat_guide_site',
          label: site.englishName,
          parameters: {'site': site.id},
        );
        pushPageRoute(context, ZiyaratSitePage(site: site));
      },
    );
  }
}

String guideSiteKindLabel(AppLocalizations l10n, GuideSiteKind kind) =>
    switch (kind) {
      GuideSiteKind.shrine => l10n.ziyaratGuideKindShrine,
      GuideSiteKind.mosque => l10n.ziyaratGuideKindMosque,
      GuideSiteKind.cemetery => l10n.ziyaratGuideKindCemetery,
      GuideSiteKind.tomb => l10n.ziyaratGuideKindTomb,
      GuideSiteKind.maqam => l10n.ziyaratGuideKindMaqam,
      GuideSiteKind.other => l10n.ziyaratGuideKindOther,
    };
