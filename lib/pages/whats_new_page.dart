import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/whats_new_notes.dart';
import '../l10n/l10n.dart';
import '../services/whats_new_service.dart';
import '../theme/shia_colors.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;

/// Settings › What's new: every release's notes, newest first, each under
/// its version, with a "New" tag on those that came out since this page was
/// last opened. Opening it clears the dot on Home's profile button.
class WhatsNewPage extends StatefulWidget {
  const WhatsNewPage({super.key, this.platform});

  /// Lets tests pick the platform whose notes show.
  final TargetPlatform? platform;

  @override
  State<WhatsNewPage> createState() => _WhatsNewPageState();
}

class _WhatsNewPageState extends State<WhatsNewPage> {
  late final List<WhatsNewEntry> _entries =
      WhatsNewService.entries(platform: widget.platform);

  /// Read before [WhatsNewService.markSeen] moves the mark, so what was new
  /// on the way in stays tagged while the page is open.
  late final Set<int> _unseen;

  @override
  void initState() {
    super.initState();
    trackScreen('Whats New Page');
    _unseen = WhatsNewService.unseenBuilds(platform: widget.platform);
    unawaited(WhatsNewService.markSeen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);
    final target = widget.platform ?? defaultTargetPlatform;

    return LargeTitlePage(
      title: l10n.whatsNewTitle,
      maxWidth: compactContentWidth,
      slivers: [
        for (final entry in _entries)
          SliverPadding(
            padding: gutter.copyWith(bottom: 22),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Row(
                      children: [
                        Flexible(
                          child:
                              GroupLabel(l10n.aboutVersion(entry.versionName)),
                        ),
                        if (_unseen.contains(entry.buildNumber)) ...[
                          const SizedBox(width: 8),
                          _NewTag(label: l10n.whatsNewUnread),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CardList(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final note in entry.bulletsFor(target))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ExcludeSemantics(
                                      child: Text('•  ',
                                          style: ShiaText.body
                                              .copyWith(color: colors.accent)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        note(l10n),
                                        style: ShiaText.body
                                            .copyWith(color: colors.text),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The small accent pill beside a release that is new since the last visit.
class _NewTag extends StatelessWidget {
  const _NewTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: ShiaText.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: colors.onAccent,
        ),
      ),
    );
  }
}
