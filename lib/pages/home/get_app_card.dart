import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import 'home_section.dart';

/// Shown on Home on the web only: the mobile app, with a badge for each
/// store. Both badges, whatever the browser, since someone at a computer may
/// carry either phone. (web/index.html's banner already offers a phone
/// browser its own store.)
class GetAppCard extends StatelessWidget {
  const GetAppCard({super.key});

  static const String appStoreUrl = 'https://apps.apple.com/app/id1492517189';
  static const String googlePlayUrl =
      'https://play.google.com/store/apps/details?id=com.developer110.shiacompanion';

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return Semantics(
      container: true,
      child: HomeCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.l10n.homeGetAppTitle,
                style: ShiaText.cardTitle.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.homeGetAppBody,
              style: ShiaText.secondary.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StoreBadge(
                  asset: 'assets/images/app_store_badge.png',
                  label: context.l10n.homeGetAppAppStore,
                  url: appStoreUrl,
                  store: 'app_store',
                ),
                _StoreBadge(
                  asset: 'assets/images/google_play_badge.png',
                  label: context.l10n.homeGetAppGooglePlay,
                  url: googlePlayUrl,
                  store: 'google_play',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A store's official badge, at the 40 px height both stores ask for.
class _StoreBadge extends StatelessWidget {
  const _StoreBadge({
    required this.asset,
    required this.label,
    required this.url,
    required this.store,
  });

  final String asset;
  final String label;
  final String url;
  final String store;

  void _open() {
    unawaited(AnalyticsService.feature(
      'home_get_app',
      label: 'Home get app',
      parameters: {'store': store},
    ));
    unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      excludeSemantics: true,
      onTap: _open,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child:
            Image.asset(asset, height: 40, filterQuality: FilterQuality.high),
      ),
    );
  }
}
