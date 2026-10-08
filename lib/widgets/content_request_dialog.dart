import 'dart:async';

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/content_request_service.dart';
import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'choice_sheet.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';
import 'app_toast.dart';

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
  final draft = await showRevampSheet<ContentRequestDraft>(
    context,
    title: context.l10n.settingsRequestContent,
    closeLabel: context.l10n.commonCancel,
    builder: (_) => ContentRequestForm(
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

  showToast(
      submitted ? L10n.current.requestThanks : L10n.current.requestFailed);
}

/// The request form [showContentRequestDialog] opens in a sheet: zikr or
/// book, its name, and anything else that helps find it. Pops the draft on
/// Send.
class ContentRequestForm extends StatefulWidget {
  const ContentRequestForm({
    super.key,
    this.initialType = ContentRequestType.zikr,
    this.initialTitle = '',
  });

  final ContentRequestType initialType;
  final String initialTitle;

  @override
  State<ContentRequestForm> createState() => _ContentRequestFormState();
}

class _ContentRequestFormState extends State<ContentRequestForm> {
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
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final isBook = _type == ContentRequestType.book;
    final fieldStyle = ShiaText.body.copyWith(color: colors.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedSwitcher<ContentRequestType>(
          segments: [
            for (final type in ContentRequestType.values)
              Segment(
                type,
                type == ContentRequestType.book
                    ? l10n.requestTypeBook
                    : l10n.requestTypeZikr,
              ),
          ],
          selected: _type,
          onChanged: (type) => setState(() => _type = type),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.initialTitle.isEmpty,
          maxLength: 200,
          textInputAction: TextInputAction.next,
          style: fieldStyle,
          onChanged: (_) => setState(() {}),
          decoration: revampFieldDecoration(
            context,
            label: isBook ? l10n.requestBookTitle : l10n.requestZikrName,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _details,
          maxLength: 1000,
          maxLines: 3,
          style: fieldStyle,
          decoration: revampFieldDecoration(
            context,
            label: isBook ? l10n.requestBookDetails : l10n.requestZikrDetails,
          ),
        ),
        const SizedBox(height: 12),
        PageButton(
          label: l10n.commonSend,
          glyph: OutlineGlyph.mail,
          filled: true,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
