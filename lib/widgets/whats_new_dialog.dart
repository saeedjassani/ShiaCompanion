import 'package:flutter/material.dart';

import '../data/whats_new_notes.dart';

/// Shows the accumulated [entries] from [WhatsNewService.pending] as one
/// dialog. Plain, short, and dismissed with a single tap — this is meant to
/// take a few seconds to read, not to be a release-notes page.
Future<void> showWhatsNewDialog(
  BuildContext context,
  List<WhatsNewEntry> entries,
) {
  if (entries.isEmpty) return Future<void>.value();

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(entries.length == 1 ? entries.first.title : "What's new"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in entries) ...[
              if (entries.length > 1) ...[
                Text(entry.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
              ],
              for (final bullet in entry.bullets)
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
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
