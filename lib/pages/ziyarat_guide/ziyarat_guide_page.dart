import 'package:material_ui/material_ui.dart';

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../models/ziyarat_guide.dart';
import '../../services/analytics_service.dart';
import '../../services/ziyarat_guide_repository.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/zikr_list_row.dart';
import 'ziyarat_city_page.dart';
import 'ziyarat_guide_widgets.dart';

/// The Ziyarat Guide's front page (docs/ZIYARAT_GUIDE.md): what to read
/// before any ziyarat, then the cities pilgrims visit, region by region.
class ZiyaratGuidePage extends StatefulWidget {
  const ZiyaratGuidePage({super.key, this.guide});

  /// Injected by tests; otherwise loaded from the bundle.
  final ZiyaratGuide? guide;

  @override
  State<ZiyaratGuidePage> createState() => _ZiyaratGuidePageState();
}

class _ZiyaratGuidePageState extends State<ZiyaratGuidePage> {
  late Future<ZiyaratGuide> _guide;

  @override
  void initState() {
    super.initState();
    trackScreen('Ziyarat Guide');
    _guide = _load();
  }

  Future<ZiyaratGuide> _load() => widget.guide != null
      ? Future.value(widget.guide)
      : ZiyaratGuideRepository.load();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<ZiyaratGuide>(
      future: _guide,
      builder: (context, snapshot) {
        final guide = snapshot.data;
        return LargeTitlePage(
          maxWidth: widePageWidth,
          title: l10n.menuZiyaratGuide,
          subtitle: guide == null
              ? null
              : l10n.ziyaratGuidePlaceCount(guide.sites.length),
          slivers: [
            if (snapshot.hasError)
              SliverPadding(
                padding: pageGutter(context, maxWidth: widePageWidth),
                sliver: SliverToBoxAdapter(
                  child: EmptyStateCard(
                    glyph: OutlineGlyph.alert,
                    title: l10n.ziyaratGuideLoadFailed,
                    actionLabel: l10n.commonRetry,
                    onAction: () => setState(() => _guide = _load()),
                  ),
                ),
              )
            else if (guide == null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else ...[
              if (guide.general.isNotEmpty)
                GuideSection(
                  label: l10n.ziyaratGuideBeforeYouGo,
                  sliver: GuideZiyaratList(refs: guide.general),
                ),
              for (final region in guide.regions)
                if (region.cities.isNotEmpty)
                  GuideSection(
                    label: region.name,
                    sliver: SliverCardList(
                      itemCount: region.cities.length,
                      itemBuilder: (context, i) => _CityRow(
                        city: region.cities[i],
                        first: i == 0,
                        last: i == region.cities.length - 1,
                      ),
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        );
      },
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.city, required this.first, required this.last});

  final GuideCity city;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ZikrGroupRow(
      first: first,
      last: last,
      title: city.name,
      subtitle: guideCountsLine(l10n, city.sites.length, city.ziyaratCount),
      onTap: () {
        AnalyticsService.feature(
          'ziyarat_guide_city',
          label: city.englishName,
          parameters: {'city': city.id},
        );
        pushPageRoute(context, ZiyaratCityPage(city: city));
      },
    );
  }
}

/// "3 places · 9 ziyarats" under a city, "9 ziyarats" alone when there is
/// one place.
String guideCountsLine(AppLocalizations l10n, int places, int ziyarats) {
  final ziyaratLine = l10n.listCountZiyarats(ziyarats);
  if (places <= 1) return ziyaratLine;
  return '${l10n.ziyaratGuidePlaceCount(places)} · $ziyaratLine';
}
