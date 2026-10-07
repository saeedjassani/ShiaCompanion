import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:webfeed_revised/domain/rss_feed.dart';
import 'package:webfeed_revised/domain/rss_item.dart';

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;

/// The latest headlines from ABNA (AhlulBayt News Agency), each opening the
/// full story in the browser.
class NewsPage extends StatefulWidget {
  const NewsPage({super.key, this.loadFeed});

  /// Where the feed comes from; ABNA's RSS when null. For tests.
  final Future<RssFeed> Function()? loadFeed;

  static const String feedUrl = 'https://en.abna24.com/rss';

  /// Fetches and parses [feedUrl]. Throws when it cannot be reached.
  static Future<RssFeed> fetchFeed() async {
    var url = feedUrl;
    if (kIsWeb) {
      // The feed sends no CORS headers, so the web build reads it through a
      // public CORS proxy.
      url = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    }
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException('status ${response.statusCode}');
    }
    return RssFeed.parse(response.body);
  }

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<RssItem>? _items;
  bool _failed = false;

  static final DateFormat _dateFormat = DateFormat('d MMM y');

  @override
  void initState() {
    super.initState();
    trackScreen('News Page');
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _failed = false;
    });
    try {
      final feed = await (widget.loadFeed ?? NewsPage.fetchFeed)();
      if (!mounted) return;
      setState(() => _items = [
            for (final item in feed.items ?? const <RssItem>[])
              if ((item.title ?? '').trim().isNotEmpty) item,
          ]);
    } catch (error) {
      debugPrint('News failed to load: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(RssItem item) async {
    final link = item.link?.trim() ?? '';
    final uri = Uri.tryParse(link);
    final opened = uri != null && link.isNotEmpty && await launchExternalUri(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.newsNoBrowser)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gutter = pageGutter(context, maxWidth: compactContentWidth);
    final items = _items;

    final Widget body;
    if (_failed) {
      body = SliverToBoxAdapter(
        child: EmptyStateCard(
          glyph: OutlineGlyph.cloud,
          title: l10n.newsUnavailable,
          body: l10n.newsUnavailableBody,
          actionLabel: l10n.commonTryAgain,
          onAction: _load,
        ),
      );
    } else if (items == null) {
      body = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (items.isEmpty) {
      body = SliverToBoxAdapter(
        child: EmptyStateCard(
          glyph: OutlineGlyph.globe,
          title: l10n.newsNone,
          actionLabel: l10n.commonTryAgain,
          onAction: _load,
        ),
      );
    } else {
      body = SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _NewsCard(
          item: items[index],
          dateFormat: _dateFormat,
          onTap: () => _open(items[index]),
        ),
      );
    }

    return LargeTitlePage(
      title: l10n.menuNews,
      subtitle: l10n.newsSource,
      maxWidth: compactContentWidth,
      slivers: [SliverPadding(padding: gutter, sliver: body)],
    );
  }
}

/// One headline: its date, the title, the first lines of the story and,
/// when the feed has one, its picture.
class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.dateFormat,
    required this.onTap,
  });

  final RssItem item;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  /// The story's picture, from whichever of the feed's fields carries one.
  String? get _imageUrl {
    final enclosure = item.enclosure;
    if (enclosure?.url != null &&
        (enclosure!.type ?? 'image').startsWith('image')) {
      return enclosure.url;
    }
    final thumbnail = item.media?.thumbnails?.firstOrNull?.url;
    if (thumbnail != null) return thumbnail;
    return item.media?.contents?.firstOrNull?.url;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final summary = newsPlainText(item.description ?? '');
    final date = item.pubDate;
    final image = _imageUrl;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SliverCardList.radius),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date != null) ...[
                      Text(
                        dateFormat.format(date.toLocal()),
                        style: ShiaText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      newsPlainText(item.title ?? ''),
                      style: ShiaText.cardTitle.copyWith(color: colors.text),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: ShiaText.secondary
                            .copyWith(color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (image != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    // A picture that will not load just leaves the text.
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [html] as plain text: tags dropped, the common entities decoded and runs
/// of white space collapsed. Feed descriptions are often HTML.
@visibleForTesting
String newsPlainText(String html) {
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&rsquo;': '’',
    '&lsquo;': '‘',
    '&rdquo;': '”',
    '&ldquo;': '“',
    '&ndash;': '–',
    '&mdash;': '—',
  };
  var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  entities.forEach((entity, char) => text = text.replaceAll(entity, char));
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m[1]!);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
