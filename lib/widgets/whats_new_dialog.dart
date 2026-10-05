import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/whats_new_notes.dart';
import '../l10n/l10n.dart';

/// Shows the accumulated [entries] from [WhatsNewService.pending] as one
/// context.l10n.whatsNewTitle dialog, with a "Version x.y.z" heading per release only
/// when someone skipped several and there is more than one to tell apart.
/// Plain, short, and dismissed with a single tap — this is meant to take a
/// few seconds to read, not to be a release-notes page.
Future<void> showWhatsNewDialog(
  BuildContext context,
  List<WhatsNewEntry> entries, {
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  // An entry may have nothing to say on this platform.
  entries = [
    for (final e in entries)
      if (e.bulletsFor(target).isNotEmpty) e,
  ];
  if (entries.isEmpty) return Future<void>.value();

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.whatsNewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in entries) ...[
              if (entries.length > 1) ...[
                Text(context.l10n.aboutVersion(entry.versionName),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
              ],
              for (final bullet in entry.bulletsFor(target))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(bullet)),
                    ],
                  ),
                ),
              if (entry != entries.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.whatsNewGotIt),
        ),
      ],
    ),
  );
}
