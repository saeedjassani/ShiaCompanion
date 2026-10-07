import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/widgets/responsive_content.dart'
    show compactContentWidth;

import '../constants.dart';
import '../l10n/l10n.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';

class DeepLinkNotFoundPage extends StatefulWidget {
  final String? target;

  const DeepLinkNotFoundPage({super.key, this.target});

  @override
  State<DeepLinkNotFoundPage> createState() => _DeepLinkNotFoundPageState();
}

class _DeepLinkNotFoundPageState extends State<DeepLinkNotFoundPage> {
  @override
  void initState() {
    super.initState();
    // A link landing here is itself the diagnostic signal — how often a
    // shared link or a home-widget tap fails to resolve — so the screen
    // count is the whole metric; no separate feature event needed.
    unawaited(trackScreen('Deep Link Not Found Page'));
  }

  String? get target => widget.target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gutter = pageGutter(context, maxWidth: compactContentWidth);
    final target = this.target;

    return LargeTitlePage(
      title: l10n.linkNotFoundTitle,
      maxWidth: compactContentWidth,
      slivers: [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmptyStateCard(
                  glyph: OutlineGlyph.link,
                  title: l10n.linkNotFoundBody,
                  body: target == null || target.isEmpty
                      ? null
                      : l10n.linkNotFoundRequested(target),
                ),
                const SizedBox(height: 14),
                PageButton(
                  label: l10n.linkNotFoundGoHome,
                  glyph: OutlineGlyph.home,
                  filled: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
