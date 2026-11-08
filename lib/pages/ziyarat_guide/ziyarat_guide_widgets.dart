import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../data/universal_data.dart';
import '../../models/ziyarat_guide.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/deep_links.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/zikr_list_row.dart';
import '../zikr/zikr_content_viewer.dart' show buildZikrTextSpanWithLinks;
import '../zikr/zikr_page.dart';

/// One section of a guide page: a label over a card, in the page gutter.
class GuideSection extends StatelessWidget {
  const GuideSection({super.key, required this.label, required this.sliver});

  final String label;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: pageGutter(context, maxWidth: widePageWidth)
          .copyWith(top: 20, bottom: 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GroupLabel(label),
            ),
          ),
          sliver,
        ],
      ),
    );
  }
}

/// A card of text: a paragraph or a list of tips, links in it opening the
/// zikr they name.
class GuideTextCard extends StatelessWidget {
  const GuideTextCard({super.key, this.paragraph, this.bullets = const []});

  final String? paragraph;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final style = ShiaText.body.copyWith(height: 1.45, color: colors.text);
    final linkStyle = style.copyWith(
      color: colors.accent,
      decoration: TextDecoration.underline,
    );
    Widget text(String raw) => Text.rich(
          buildZikrTextSpanWithLinks(
            rawLine: raw,
            baseStyle: style,
            linkStyle: linkStyle,
            onLinkTap: (href) => openGuideZikrLink(context, href),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(SliverCardList.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paragraph != null) text(paragraph!),
          for (var i = 0; i < bullets.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(top: i == 0 && paragraph == null ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 9, end: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: text(bullets[i])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// [refs] as zikr rows: the label (or the zikr's own title) with its note
/// under it and the heart, opening the zikr at the ref's tab.
class GuideZiyaratList extends StatelessWidget {
  const GuideZiyaratList({super.key, required this.refs});

  final List<ZiyaratRef> refs;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final ref in refs)
        if (items.containsKey(ref.uid)) ref,
    ];
    return SliverCardList(
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final ref = shown[i];
        final item = UniversalData(ref.uid, items[ref.uid].toString(), 0);
        return ZikrListRow(
          item: item,
          title: ref.label,
          subtitle: ref.note,
          first: i == 0,
          last: i == shown.length - 1,
          onTap: () => openGuideZikr(context, ref),
        );
      },
    );
  }
}

/// One [ZiyaratRef] as a row of a [CardList] (outside a sliver list).
class ZikrRefRow extends StatelessWidget {
  const ZikrRefRow({
    super.key,
    required this.ref,
    this.first = false,
    this.last = false,
  });

  final ZiyaratRef ref;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final item = UniversalData(ref.uid, items[ref.uid].toString(), 0);
    return ZikrListRow(
      item: item,
      title: ref.label,
      subtitle: ref.note,
      first: first,
      last: last,
      onTap: () => openGuideZikr(context, ref),
    );
  }
}

Future<void> openGuideZikr(BuildContext context, ZiyaratRef ref) {
  final title = items[ref.uid]?.toString() ?? ref.uid;
  return pushPageRoute(
    context,
    ZikrPage(
      UidTitleData(ref.uid, title),
      source: ZikrOpenSource.ziyaratGuide,
      initialTab: ref.initialTabIndex,
    ),
  );
}

/// A `[text](uid)` link in the guide's prose: a zikr uid or slug, with an
/// optional `?tab=N`.
Future<void> openGuideZikrLink(BuildContext context, String href) async {
  final target = extractZikrLinkTarget(href);
  if (target == null || target.segments.isEmpty) return;
  final segment = target.segments.first;
  final uid = items.containsKey(segment) ? segment : slugToItemUid[segment];
  if (uid == null) return;
  await pushPageRoute(
    context,
    ZikrPage(
      UidTitleData(uid, items[uid]?.toString() ?? uid),
      source: ZikrOpenSource.ziyaratGuide,
      initialTab: zikrDeepLinkTab(target),
    ),
  );
}
