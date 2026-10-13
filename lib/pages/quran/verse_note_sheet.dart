import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/analytics_service.dart';
import '../../services/verse_notes_manager.dart';
import '../../theme/shia_colors.dart';
import '../../utils/quran_index.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/app_toast.dart';

/// "Al-Baqarah 255" - how a note names its verse, in a title or a list row.
String verseNoteReference(VerseKey verse, {String? surahName}) {
  final name = (surahName?.isNotEmpty ?? false)
      ? surahName!
      : surahInfoFor(verse.surah)?.displayName ??
          L10n.current.quranSurahNumber(verse.surah);
  return L10n.current.quranSurahAyah(name, verse.ayah ?? 1);
}

/// Writes, edits or deletes the reader's note on [verse].
///
/// [excerpt] is the opening of the verse, kept with the note so the notes
/// list can show it without loading the surah.
Future<void> showVerseNoteSheet(
  BuildContext context, {
  required VerseKey verse,
  required String excerpt,
}) {
  return showRevampSheet<void>(
    context,
    title: context.l10n.quranNoteTitle(verseNoteReference(verse)),
    closeLabel: context.l10n.commonCancel,
    builder: (context) => _VerseNoteSheet(verse: verse, excerpt: excerpt),
  );
}

class _VerseNoteSheet extends StatefulWidget {
  const _VerseNoteSheet({required this.verse, required this.excerpt});

  final VerseKey verse;
  final String excerpt;

  @override
  State<_VerseNoteSheet> createState() => _VerseNoteSheetState();
}

class _VerseNoteSheetState extends State<_VerseNoteSheet> {
  late final VerseNote? _existing =
      VerseNotesManager.instance.noteFor(widget.verse);
  late final _controller = TextEditingController(text: _existing?.text ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Closes straight away: the note shows at once, and the save to the
  /// device and the account carries on behind it. Saving an emptied note
  /// deletes it.
  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _delete();
      return;
    }
    if (text == _existing?.text) {
      Navigator.pop(context);
      return;
    }

    final verse = widget.verse;
    unawaited(VerseNotesManager.instance.save(VerseNote(
      surah: verse.surah,
      ayah: verse.ayah ?? 1,
      surahName: surahInfoFor(verse.surah)?.displayName ?? '',
      // Keep an excerpt already stored when the page could not supply one.
      excerpt:
          widget.excerpt.isNotEmpty ? widget.excerpt : _existing?.excerpt ?? '',
      text: text,
      updatedAt: DateTime.now().toUtc(),
    )));
    unawaited(AnalyticsService.feature(
      _existing == null ? 'quran_note_added' : 'quran_note_edited',
      label: _existing == null ? 'Quran note added' : 'Quran note edited',
      parameters: {'verse': verse.toString()},
    ));
    final saved = context.l10n.quranNoteSaved;
    Navigator.pop(context);
    showToast(saved);
  }

  void _delete() {
    final deleted = context.l10n.quranNoteDeleted;
    Navigator.pop(context);
    if (_existing != null) {
      unawaited(VerseNotesManager.instance.remove(widget.verse));
      unawaited(AnalyticsService.feature(
        'quran_note_deleted',
        label: 'Quran note deleted',
        parameters: {'verse': widget.verse.toString()},
      ));
      showToast(deleted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: _existing == null,
          minLines: 4,
          maxLines: 12,
          maxLength: verseNoteMaxLength,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: ShiaText.body.copyWith(color: colors.text),
          decoration: revampFieldDecoration(context, hint: l10n.quranNoteHint),
        ),
        const SizedBox(height: 12),
        PageButton(
          label: l10n.commonSave,
          filled: true,
          onPressed: _save,
        ),
        if (_existing != null) ...[
          const SizedBox(height: 10),
          PageButton(
            label: l10n.quranDeleteNote,
            danger: true,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}
