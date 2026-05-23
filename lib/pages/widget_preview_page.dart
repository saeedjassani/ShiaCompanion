import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetPreviewPage extends StatefulWidget {
  const WidgetPreviewPage({super.key});

  @override
  State<WidgetPreviewPage> createState() => _WidgetPreviewPageState();
}

class _WidgetPreviewPageState extends State<WidgetPreviewPage> {
  late Future<Map<String, String>> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<Map<String, String>> _loadSnapshot() async {
    if (!SP.isInitialized) {
      await SP.init();
    }
    if (items.isEmpty) {
      await _loadItemsFromAssets();
    }
    favsData ??= items.entries
        .where((entry) => !entry.key.toString().contains('~'))
        .take(3)
        .map((entry) => UniversalData(entry.key.toString(), entry.value, 0))
        .toList();
    city ??= 'Karbala';
    lat ??= 32.616;
    long ??= 44.032;

    return HomeScreenWidgetService.instance.buildWidgetSnapshot();
  }

  Future<void> _loadItemsFromAssets() async {
    final data = await rootBundle.loadString('assets/zikr.json');
    final decoded = json.decode(data);
    items = {};
    itemOrder = {};
    itemMetadata = {};
    clearLocalSlugMaps();
    decoded.forEach((key, value) {
      if (value is Map) {
        final title = value['title']?.toString() ?? '';
        if (title.isEmpty) return;
        items[key.toString()] = title;
        final order = value['order'];
        if (order is num) itemOrder[key.toString()] = order.toDouble();
        final day = value['day'];
        if (day != null) itemMetadata[key.toString()] = {'day': day};
        setLocalSlugData(
          key.toString(),
          slug: value['slug']?.toString(),
          aliases: value['slugAliases'] is Iterable
              ? value['slugAliases'] as Iterable
              : null,
        );
      } else {
        final title = value?.toString() ?? '';
        if (title.isNotEmpty) items[key.toString()] = title;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Widget Preview')),
      body: FutureBuilder<Map<String, String>>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _ListWidgetPreview(
                    width: 180,
                    height: 180,
                    title: data[HomeScreenWidgetService.favoritesTitleKey] ??
                        'Favorites',
                    subtitle:
                        data[HomeScreenWidgetService.favoritesSubtitleKey] ??
                            '',
                    items: [
                      _PreviewItem(
                        data[HomeScreenWidgetService.favoriteItem1Key] ?? '',
                        data[HomeScreenWidgetService.favoriteUrl1Key] ?? '',
                      ),
                      _PreviewItem(
                        data[HomeScreenWidgetService.favoriteItem2Key] ?? '',
                        data[HomeScreenWidgetService.favoriteUrl2Key] ?? '',
                      ),
                      _PreviewItem(
                        data[HomeScreenWidgetService.favoriteItem3Key] ?? '',
                        data[HomeScreenWidgetService.favoriteUrl3Key] ?? '',
                      ),
                    ],
                  ),
                  _ListWidgetPreview(
                    width: 340,
                    height: 180,
                    title: data[HomeScreenWidgetService.recitationTitleKey] ??
                        "Today's Recitations",
                    subtitle:
                        data[HomeScreenWidgetService.recitationSubtitleKey] ??
                            '',
                    items: [
                      _PreviewItem(
                        data[HomeScreenWidgetService.recitationItem1Key] ?? '',
                        data[HomeScreenWidgetService.recitationUrl1Key] ?? '',
                      ),
                      _PreviewItem(
                        data[HomeScreenWidgetService.recitationItem2Key] ?? '',
                        data[HomeScreenWidgetService.recitationUrl2Key] ?? '',
                      ),
                      _PreviewItem(
                        data[HomeScreenWidgetService.recitationItem3Key] ?? '',
                        data[HomeScreenWidgetService.recitationUrl3Key] ?? '',
                      ),
                    ],
                  ),
                  _PrayerWidgetPreview(
                    width: 180,
                    height: 180,
                    title: data[HomeScreenWidgetService.prayerTitleKey] ??
                        'Upcoming Prayer',
                    name:
                        data[HomeScreenWidgetService.prayerNameKey] ?? 'Prayer',
                    time: data[HomeScreenWidgetService.prayerTimeKey] ?? '',
                    dateLabel:
                        data[HomeScreenWidgetService.prayerDateKey] ?? '',
                    location:
                        data[HomeScreenWidgetService.prayerLocationKey] ?? '',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Run this in debug web at /widget-preview. These cards use the same Dart snapshot that native widgets receive.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewItem {
  const _PreviewItem(this.title, this.url);

  final String title;
  final String url;
}

class _ListWidgetPreview extends StatelessWidget {
  const _ListWidgetPreview({
    required this.width,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final double width;
  final double height;
  final String title;
  final String subtitle;
  final List<_PreviewItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.title.isNotEmpty).toList();
    final palette = _WidgetPalette.of(context);
    return _WidgetShell(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.secondaryText),
            ),
          const Spacer(),
          for (final item in visibleItems.take(3))
            SizedBox(
              height: 30,
              child: InkWell(
                onTap: item.url.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(item.url)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          color: palette.bodyText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: palette.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrayerWidgetPreview extends StatelessWidget {
  const _PrayerWidgetPreview({
    required this.width,
    required this.height,
    required this.title,
    required this.name,
    required this.time,
    required this.dateLabel,
    required this.location,
  });

  final double width;
  final double height;
  final String title;
  final String name;
  final String time;
  final String dateLabel;
  final String location;

  @override
  Widget build(BuildContext context) {
    final palette = _WidgetPalette.of(context);
    return _WidgetShell(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
                  .copyWith(color: palette.secondaryText)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.secondaryText)),
          const Spacer(),
          Text(location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.secondaryText)),
        ],
      ),
    );
  }
}

class _WidgetShell extends StatelessWidget {
  const _WidgetShell({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = _WidgetPalette.of(context);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: palette.primaryText),
        child: child,
      ),
    );
  }
}

class _WidgetPalette {
  const _WidgetPalette({
    required this.background,
    required this.border,
    required this.primaryText,
    required this.bodyText,
    required this.secondaryText,
  });

  final Color background;
  final Color border;
  final Color primaryText;
  final Color bodyText;
  final Color secondaryText;

  static _WidgetPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _WidgetPalette(
        background: Color(0xFF241B17),
        border: Color(0xFF3A2B24),
        primaryText: Color(0xFFFFF3E7),
        bodyText: Color(0xFFE9D5C4),
        secondaryText: Color(0xFFBFA898),
      );
    }

    return const _WidgetPalette(
      background: Color(0xFF6D4C41),
      border: Color(0xFF8D6E63),
      primaryText: Color(0xFFFFF8F1),
      bodyText: Color(0xFFF7E4D3),
      secondaryText: Color(0xFFE4C7B3),
    );
  }
}
