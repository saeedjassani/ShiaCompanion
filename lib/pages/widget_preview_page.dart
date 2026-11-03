import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
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
    final previewFavorites = items.entries
        .where((entry) => !entry.key.toString().contains('~'))
        .take(3)
        .map((entry) => UniversalData(entry.key.toString(), entry.value, 0))
        .toList();
    city ??= 'Karbala';
    lat ??= 32.616;
    long ??= 44.032;

    return HomeScreenWidgetService.instance.buildWidgetSnapshot(
      favorites: previewFavorites,
    );
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
                    width: 340,
                    height: 180,
                    title: data[HomeScreenWidgetService.favoritesTitleKey] ??
                        'Favorites',
                    items: [
                      ..._itemsFromSnapshot(
                        data,
                        HomeScreenWidgetService.favoriteItemKeys,
                        HomeScreenWidgetService.favoriteUrlKeys,
                      ),
                    ],
                  ),
                  _ListWidgetPreview(
                    width: 340,
                    height: 220,
                    title: data[HomeScreenWidgetService.recitationTitleKey] ??
                        "Today's Recitations",
                    items: [
                      ..._itemsFromSnapshot(
                        data,
                        HomeScreenWidgetService.recitationItemKeys,
                        HomeScreenWidgetService.recitationUrlKeys,
                      ),
                    ],
                  ),
                  _PrayerWidgetPreview(
                    width: 180,
                    height: 180,
                    title: data[HomeScreenWidgetService.prayerTitleKey] ??
                        'Up Next',
                    name:
                        data[HomeScreenWidgetService.prayerNameKey] ?? 'Prayer',
                    time: data[HomeScreenWidgetService.prayerTimeKey] ?? '',
                    location:
                        data[HomeScreenWidgetService.prayerLocationKey] ?? '',
                    secondaryName:
                        data[HomeScreenWidgetService.prayerSecondaryNameKey] ??
                            '',
                    secondaryTime:
                        data[HomeScreenWidgetService.prayerSecondaryTimeKey] ??
                            '',
                  ),
                  _DailyPrayerTimesWidgetPreview(
                    width: 340,
                    height: 180,
                    location:
                        data[HomeScreenWidgetService.prayerLocationKey] ?? '',
                    nextPrayer: _nextPrayerFromSnapshot(data),
                    items: [
                      for (var index = 0;
                          index <
                              HomeScreenWidgetService.dailyPrayerTimesItemCount;
                          index++)
                        _PreviewPrayerTime(
                          data[HomeScreenWidgetService
                                  .dailyPrayerNameKeys[index]] ??
                              '',
                          data[HomeScreenWidgetService
                                  .dailyPrayerTimeKeys[index]] ??
                              '',
                        ),
                    ],
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

List<_PreviewItem> _itemsFromSnapshot(
  Map<String, String> data,
  List<String> titleKeys,
  List<String> urlKeys,
) {
  return [
    for (var index = 0; index < titleKeys.length; index++)
      _PreviewItem(data[titleKeys[index]] ?? '', data[urlKeys[index]] ?? ''),
  ];
}

_PreviewNextPrayer? _nextPrayerFromSnapshot(Map<String, String> data) {
  final schedule = data[HomeScreenWidgetService.prayerScheduleKey] ?? '';
  final now = DateTime.now();
  final nextEntry = schedule
      .split(';')
      .map((rawEntry) => rawEntry.split('|'))
      .where((parts) => parts.length == 4 || parts.length == 6)
      .map((parts) {
        final epochMillis = int.tryParse(parts.first);
        if (epochMillis == null) return null;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(epochMillis);
        if (!dateTime.isAfter(now)) return null;
        return _ScheduledPreviewPrayer(parts[1], dateTime);
      })
      .whereType<_ScheduledPreviewPrayer>()
      .fold<_ScheduledPreviewPrayer?>(null, (current, candidate) {
        if (current == null || candidate.dateTime.isBefore(current.dateTime)) {
          return candidate;
        }
        return current;
      });

  if (nextEntry == null) return null;
  return _PreviewNextPrayer(
    nextEntry.name,
    _countdownLabel(nextEntry.dateTime.difference(now)),
  );
}

String _countdownLabel(Duration duration) {
  final totalMinutes =
      duration.inMinutes + (duration.inSeconds % 60 == 0 ? 0 : 1);
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  final minutes = totalMinutes % 60;

  if (days > 0 && hours > 0) return 'in ${days}d ${hours}h';
  if (days > 0) return 'in ${days}d';
  if (hours > 0 && minutes > 0) return 'in ${hours}h ${minutes}m';
  if (hours > 0) return 'in ${hours}h';
  return 'in ${minutes.clamp(1, 59)}m';
}

class _ScheduledPreviewPrayer {
  const _ScheduledPreviewPrayer(this.name, this.dateTime);

  final String name;
  final DateTime dateTime;
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
    required this.items,
  });

  final double width;
  final double height;
  final String title;
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
          const SizedBox(height: 8),
          if (visibleItems.length == 1 && visibleItems.first.url.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  visibleItems.first.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: palette.bodyText),
                ),
              ),
            )
          else
            for (final item in visibleItems.take(6))
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
                      if (item.url.isNotEmpty)
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
    required this.location,
    required this.secondaryName,
    required this.secondaryTime,
  });

  final double width;
  final double height;
  final String title;
  final String name;
  final String time;
  final String location;
  final String secondaryName;
  final String secondaryTime;

  @override
  Widget build(BuildContext context) {
    final palette = _WidgetPalette.of(context);
    final footer = secondaryName.isNotEmpty && secondaryTime.isNotEmpty
        ? '$secondaryName: $secondaryTime'
        : location;
    return _WidgetShell(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _compactNextTitle(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.secondaryText,
                  ),
                ),
              ),
              _PrayerIconBadge(name: name, size: 24, iconSize: 13),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.secondaryText)),
        ],
      ),
    );
  }
}

class _PreviewPrayerTime {
  const _PreviewPrayerTime(this.name, this.time);

  final String name;
  final String time;
}

class _DailyPrayerTimesWidgetPreview extends StatelessWidget {
  const _DailyPrayerTimesWidgetPreview({
    required this.width,
    required this.height,
    required this.location,
    required this.nextPrayer,
    required this.items,
  });

  final double width;
  final double height;
  final String location;
  final _PreviewNextPrayer? nextPrayer;
  final List<_PreviewPrayerTime> items;

  @override
  Widget build(BuildContext context) {
    final palette = _WidgetPalette.of(context);
    final visibleItems = items
        .where((item) => item.name.isNotEmpty || item.time.isNotEmpty)
        .take(6)
        .toList();

    return _WidgetShell(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 11,
                      color: palette.secondaryText,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (nextPrayer != null) const SizedBox(width: 6),
              if (nextPrayer != null)
                Expanded(
                  child: Text(
                    '${nextPrayer!.name} ${nextPrayer!.countdown}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.bodyText,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              for (var i = 0; i < visibleItems.length; i++) ...[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PrayerIconBadge(
                        name: visibleItems[i].name,
                        size: 25,
                        iconSize: 13,
                      ),
                      const SizedBox(height: 4),
                      Text(visibleItems[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.secondaryText)),
                      Text(visibleItems[i].time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.bodyText)),
                    ],
                  ),
                ),
                if (i != visibleItems.length - 1)
                  SizedBox(width: visibleItems.length > 5 ? 2 : 6),
              ],
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PreviewNextPrayer {
  const _PreviewNextPrayer(this.name, this.countdown);

  final String name;
  final String countdown;
}

class _PrayerIconBadge extends StatelessWidget {
  const _PrayerIconBadge({
    required this.name,
    required this.size,
    required this.iconSize,
  });

  final String name;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = _WidgetPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.iconBackground,
        shape: BoxShape.circle,
      ),
      child: PrayerGlyph(
        name: name,
        size: iconSize,
        color: palette.accentText,
      ),
    );
  }
}

String _compactNextTitle(String title) {
  return title.replaceAll('Upcoming', 'Next').replaceAll(' Prayer', '');
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
    required this.iconBackground,
    required this.accentText,
  });

  final Color background;
  final Color border;
  final Color primaryText;
  final Color bodyText;
  final Color secondaryText;
  final Color iconBackground;
  final Color accentText;

  static _WidgetPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _WidgetPalette(
        background: Color(0xFF241B17),
        border: Color(0xFF3A2B24),
        primaryText: Color(0xFFFFF3E7),
        bodyText: Color(0xFFE9D5C4),
        secondaryText: Color(0xFFBFA898),
        iconBackground: Color(0x29FFD879),
        accentText: Color(0xFFFFD879),
      );
    }

    return const _WidgetPalette(
      background: Color(0xFF6D4C41),
      border: Color(0xFF8D6E63),
      primaryText: Color(0xFFFFF8F1),
      bodyText: Color(0xFFF7E4D3),
      secondaryText: Color(0xFFE4C7B3),
      iconBackground: Color(0x33FFC857),
      accentText: Color(0xFFFFC857),
    );
  }
}
