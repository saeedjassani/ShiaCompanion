import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/holy_sites.dart';
import '../../l10n/l10n.dart';
import '../../models/ziyarat_guide.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/external_launch.dart';
import '../../utils/maps_links.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../qibla_finder.dart';
import 'ziyarat_city_page.dart' show guideSiteKindLabel;
import 'shrine_plan_view.dart';
import 'ziyarat_guide_widgets.dart';

/// One place of the Ziyarat Guide: the ziyarats to recite there, what it
/// is, who else is buried there and tips for the pilgrim, with directions
/// and the compass a tap away.
class ZiyaratSitePage extends StatefulWidget {
  const ZiyaratSitePage({super.key, required this.site});

  final GuideSite site;

  @override
  State<ZiyaratSitePage> createState() => _ZiyaratSitePageState();
}

class _ZiyaratSitePageState extends State<ZiyaratSitePage> {
  GuideSite get site => widget.site;

  @override
  void initState() {
    super.initState();
    trackScreen('Ziyarat Guide Site');
  }

  Future<void> _openDirections() async {
    AnalyticsService.feature(
      'ziyarat_guide_directions',
      label: site.englishName,
      parameters: {'site': site.id},
    );
    final opened = await launchExternalUri(
        mapsUriFor(site.location, site.arabicName ?? site.englishName));
    if (!opened && mounted) showToast(context.l10n.ziyaratGuideMapsFailed);
  }

  void _openCompass(HolySite target) {
    pushPageRoute(context, QiblaFinder(initialTarget: target));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final holySite = site.holySiteId == null
        ? null
        : allHolySites.where((s) => s.id == site.holySiteId).firstOrNull;
    final buried = site.buried;
    final plan = site.plan;

    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: site.name,
      subtitle: '${guideSiteKindLabel(l10n, site.kind)} · ${site.city.name}',
      slivers: [
        SliverPadding(
          padding: pageGutter(context, maxWidth: widePageWidth),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (site.arabicName != null && site.arabicName != site.name)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      site.arabicName!,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.start,
                      style: ShiaText.sectionTitle.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PageButton(
                      label: l10n.ziyaratGuideDirections,
                      glyph: OutlineGlyph.pin,
                      filled: true,
                      onPressed: _openDirections,
                    ),
                    if (holySite != null)
                      PageButton(
                        label: l10n.ziyaratGuideCompass,
                        glyph: OutlineGlyph.compass,
                        onPressed: () => _openCompass(holySite),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (plan != null)
          SliverPadding(
            padding: pageGutter(context, maxWidth: widePageWidth)
                .copyWith(top: 16, bottom: 0),
            sliver: SliverToBoxAdapter(
              child: ShrinePlanCard(site: site, plan: plan),
            ),
          ),
        if (site.ziyarat.isNotEmpty)
          GuideSection(
            label: l10n.ziyaratGuideZiyarat,
            sliver: GuideZiyaratList(refs: site.ziyarat),
          ),
        if (site.about != null)
          GuideSection(
            label: l10n.ziyaratGuideAbout,
            sliver:
                SliverToBoxAdapter(child: GuideTextCard(paragraph: site.about)),
          ),
        if (buried.isNotEmpty)
          GuideSection(
            label: l10n.ziyaratGuideBuried,
            sliver: SliverCardList(
              itemCount: buried.length,
              itemBuilder: (context, i) => _BurialRow(
                person: buried[i],
                first: i == 0,
                last: i == buried.length - 1,
              ),
            ),
          ),
        if (site.tips.isNotEmpty)
          GuideSection(
            label: l10n.ziyaratGuideTips,
            sliver:
                SliverToBoxAdapter(child: GuideTextCard(bullets: site.tips)),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _BurialRow extends StatelessWidget {
  const _BurialRow({
    required this.person,
    required this.first,
    required this.last,
  });

  final GuideBurial person;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final died = person.diedAh;
    return CardListRow(
      first: first,
      last: last,
      title: Text(person.name),
      titleStyle: ShiaText.body.copyWith(fontWeight: FontWeight.w600),
      subtitle: person.note == null ? null : Text(person.note!),
      trailing: died == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
              child: Text(
                l10n.ziyaratGuideDiedAh(died),
                style: ShiaText.caption.copyWith(color: colors.textMuted),
              ),
            ),
    );
  }
}
