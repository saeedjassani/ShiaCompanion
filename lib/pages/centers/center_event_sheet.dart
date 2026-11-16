import 'dart:async';

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../models/islamic_center.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/external_launch.dart';
import '../../utils/ics_calendar.dart';
import '../../utils/maps_links.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import 'center_formatting.dart';

/// A programme's details: when, where (with directions), what the centre
/// wrote about it, its links, and Share.
Future<void> showCenterEventSheet(BuildContext context, CenterEvent event) {
  unawaited(
    AnalyticsService.feature(
      'center_event_opened',
      label: 'Center program opened',
    ),
  );
  return showRevampSheet<void>(
    context,
    title: event.title,
    builder: (_) => CenterEventDetails(event: event),
  );
}

class CenterEventDetails extends StatelessWidget {
  const CenterEventDetails({super.key, required this.event});

  final CenterEvent event;

  String _place() {
    final location = event.occurrence.location.trim();
    if (location.isNotEmpty) return location;
    final address = event.center.address.trim();
    return address.isNotEmpty ? address : event.center.name;
  }

  Future<void> _openMaps(BuildContext context) async {
    final point = event.center.point;
    final location = event.occurrence.location.trim();
    // The event's own place when it has one: a programme can be held away
    // from the centre (a hall, a park).
    final uri = location.isEmpty && point != null
        ? mapsUriFor(point, event.center.name)
        : mapsUriForQuery(_place());
    if (!await launchExternalUri(uri) && context.mounted) {
      showToast(context.l10n.newsNoBrowser);
    }
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchExternalUri(uri) && context.mounted) {
      showToast(context.l10n.newsNoBrowser);
    }
  }

  void _share(BuildContext context) {
    final l10n = context.l10n;
    final day = DateFormat('EEEE d MMMM').format(event.occurrence.localStart);
    final text = [
      event.title,
      '$day · ${centerEventTimeRange(event, l10n)}',
      _place(),
      if (event.occurrence.url case final url?) url,
    ].join('\n');
    unawaited(
      AnalyticsService.feature(
        'center_event_shared',
        label: 'Center program shared',
      ),
    );
    unawaited(SharePlus.instance.share(ShareParams(text: text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final o = event.occurrence;
    final description = icsPlainText(o.description);
    final links = <Uri>[
      if (o.url case final url?
          when Uri.tryParse(url)?.host.isNotEmpty ?? false)
        Uri.parse(url),
      for (final link in icsLinks(description))
        if (link.toString() != o.url) link,
    ];
    final day = centerDayLabel(o.localStart, DateTime.now(), l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardList(
          children: [
            CardListRow(
              first: true,
              leading: OutlineIcon(
                OutlineGlyph.clock,
                size: 20,
                color: colors.accent,
              ),
              title: Text(day),
              subtitle: Text(centerEventTimeRange(event, l10n)),
            ),
            CardListRow(
              leading: OutlineIcon(
                OutlineGlyph.pin,
                size: 20,
                color: colors.accent,
              ),
              title: Text(_place()),
              subtitle: Text(event.center.name),
              onTap: () => _openMaps(context),
              trailing: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  l10n.centerDirections,
                  style: ShiaText.secondary.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              last: true,
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(SliverCardList.radius),
              border: Border.all(color: colors.line),
            ),
            child: SelectableText(
              description,
              style: ShiaText.body.copyWith(color: colors.text),
            ),
          ),
        ],
        if (links.isNotEmpty) ...[
          const SizedBox(height: 14),
          CardList(
            children: [
              for (final (i, link) in links.indexed)
                CardListRow(
                  first: i == 0,
                  last: i == links.length - 1,
                  leading: OutlineIcon(
                    OutlineGlyph.link,
                    size: 20,
                    color: colors.accent,
                  ),
                  title: Text(
                    link.host.replaceFirst(RegExp(r'^www\.'), ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    link.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(context, link),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        PageButton(
          label: l10n.actionShare,
          glyph: OutlineGlyph.share,
          onPressed: () => _share(context),
        ),
      ],
    );
  }
}
