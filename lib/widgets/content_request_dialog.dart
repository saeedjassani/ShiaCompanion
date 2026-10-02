import 'dart:async';

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/content_request_service.dart';

/// What the reader filled in, before it is sent anywhere.
class ContentRequestDraft {
  const ContentRequestDraft({
    required this.type,
    required this.title,
    required this.details,
  });

  final ContentRequestType type;
  final String title;
  final String details;
}

/// Asks the reader which zikr or book they'd like added, files it with
/// [ContentRequestService], and confirms with a snackbar. [initialTitle]
/// pre-fills the name - search passes the query that found nothing.
///
/// [source] is only for analytics: which entry point the request came from.
Future<void> showContentRequestDialog(
  BuildContext context, {
  ContentRequestType initialType = ContentRequestType.zikr,
  String initialTitle = '',
  required String source,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final draft = await showDialog<ContentRequestDraft>(
    context: context,
    builder: (_) => ContentRequestDialog(
      initialType: initialType,
      initialTitle: initialTitle,
    ),
  );
  if (draft == null) return; // Cancelled.

  unawaited(AnalyticsService.feature(
    'content_requested',
    label: 'Zikr or book requested',
    parameters: {'request_type': draft.type.name, 'source': source},
  ));

  final submitted = await ContentRequestService.submit(
    type: draft.type,
    title: draft.title,
    details: draft.details,
  );

  messenger?.showSnackBar(
    SnackBar(
      content: Text(submitted
          ? "Thanks - we've received your request."
          : 'Could not send the request. Please try again.'),
    ),
  );
}

class ContentRequestDialog extends StatefulWidget {
  const ContentRequestDialog({
    super.key,
    this.initialType = ContentRequestType.zikr,
    this.initialTitle = '',
  });

  final ContentRequestType initialType;
  final String initialTitle;

  @override
  State<ContentRequestDialog> createState() => _ContentRequestDialogState();
}

class _ContentRequestDialogState extends State<ContentRequestDialog> {
  late ContentRequestType _type = widget.initialType;
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  final TextEditingController _details = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  bool get _canSubmit => _title.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(ContentRequestDraft(
      type: _type,
      title: _title.text.trim(),
      details: _details.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isBook = _type == ContentRequestType.book;
    return AlertDialog(
      title: const Text('Request a Zikr or Book'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ContentRequestType>(
              segments: [
                for (final type in ContentRequestType.values)
                  ButtonSegment(value: type, label: Text(type.label)),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.initialTitle.isEmpty,
              maxLength: 200,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: isBook ? 'Book title' : 'Name of dua, ziyarat, etc.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isBook
                    ? 'Author, translator or link (optional)'
                    : 'Source, occasion or link (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Send'),
        ),
      ],
    );
  }
}
