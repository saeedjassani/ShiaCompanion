import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import 'verse_position_picker.dart';
import '../../l10n/l10n.dart';

/// "Juz 5" / "Juz 5 · An-Nisa 30" when reading by juz, "Al-Baqarah" /
/// "Al-Baqarah 142" when reading by surah - the start of a unit reads as just
/// the unit, anywhere inside it as the verse too.
///
/// [compact] gives the juz form as "Juz 5 · 4:30", short enough for a
/// track card.
String describeRecitationPosition(
  VerseKey verse, {
  required bool byJuz,
  bool compact = false,
}) {
  final ayah = verse.ayah ?? 1;
  final surahName =
      surahInfoFor(verse.surah)?.displayName ??
          L10n.current.quranSurahNumber(verse.surah);
  if (!byJuz) {
    return ayah == 1 ? surahName : L10n.current.quranSurahAyah(surahName, ayah);
  }

  final juz = juzOf(verse.surah, ayah);
  final juzStart = allJuz()[juz - 1].start;
  final juzLabel = L10n.current.quranJuzNumber(juz);
  return juzStart == VerseKey(verse.surah, ayah)
      ? juzLabel
      : compact
          ? '$juzLabel · ${verse.surah}:$ayah'
          : '$juzLabel · ${L10n.current.quranSurahAyah(surahName, ayah)}';
}

/// Creates a recitation track, or - with [label] - changes an existing one.
///
/// Both ask the same two things: read by surah or by juz, and where to start.
/// Creating also asks for a name; editing shows where the track has got to
/// as "Continue from", so moving a khatm along after reading some of it away
/// from the app is the same tap as choosing where a new one begins.
Future<void> showRecitationTrackSheet(BuildContext context, {String? label}) {
  return showRevampSheet<void>(
    context,
    title: label ?? context.l10n.trackNew,
    closeLabel: context.l10n.commonCancel,
    builder: (context) => _RecitationTrackSheet(label: label),
  );
}

class _RecitationTrackSheet extends StatefulWidget {
  const _RecitationTrackSheet({this.label});

  final String? label;

  @override
  State<_RecitationTrackSheet> createState() => _RecitationTrackSheetState();
}

class _RecitationTrackSheetState extends State<_RecitationTrackSheet> {
  final _nameController = TextEditingController();
  late bool _readByJuz;

  /// Where the track picks up: what was chosen here, or, editing, where it
  /// already is. Null on a new track means the beginning.
  VerseKey? _position;
  bool _positionChanged = false;

  /// Whether a new track starting part-way counts what comes before its
  /// start as already read - see [RecitationTrackSettings.readBefore].
  bool _markEarlierRead = true;
  String? _nameError;

  bool get _isEditing => widget.label != null;

  bool get _startsAtBeginning =>
      _position == null || _position == const VerseKey(1, 1);

  @override
  void initState() {
    super.initState();
    final label = widget.label;
    if (label == null) {
      _readByJuz = false;
      return;
    }
    final state = RecitationTrackerManager.instance.state;
    final target = state.resumeTargetFor(label);
    _readByJuz = target.inJuz;
    _position = target.verse;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Only the view changes: a chosen verse stays exactly where it was, and
  /// just reads differently - "Al-Ahzab 33" becomes "Juz 22 · Al-Ahzab 33".
  void _setReadByJuz(bool byJuz) => setState(() => _readByJuz = byJuz);

  Future<void> _pickPosition() async {
    final readByJuz = _readByJuz;
    final picked = await showVersePositionPicker(
      context,
      initial: _position ?? const VerseKey(1, 1),
      browseByJuz: readByJuz,
      describe: (verse) => describeRecitationPosition(verse, byJuz: readByJuz),
      confirmVerb: _isEditing ? context.l10n.trackContinueFrom : context.l10n.trackStartAt,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _position = picked;
      _positionChanged = true;
    });
  }

  /// Closes straight away: the track updates on screen at once, and the
  /// save to the device and the account carries on behind it.
  void _save() {
    final manager = RecitationTrackerManager.instance;
    final label = widget.label;

    if (label != null) {
      final current = manager.state.settingsFor(label);
      final position = _position;
      unawaited(manager.updateTrackSettings(
        label,
        _positionChanged && position != null
            ? RecitationTrackSettings(
                readByJuz: _readByJuz,
                startAt: position,
                startSetAt: DateTime.now(),
                readBefore: current.readBefore,
              )
            : RecitationTrackSettings(
                readByJuz: _readByJuz,
                startAt: current.startAt,
                startSetAt: current.startSetAt,
                readBefore: current.readBefore,
              ),
      ));
      Navigator.pop(context);
      return;
    }

    final name = _nameController.text.trim();
    final error = name.isEmpty
        ? context.l10n.trackNameRequired
        : isDefaultRecitationTrackName(name, context.l10n) ||
                manager.state.customLabels.contains(name)
            ? context.l10n.trackNameTaken(name)
            : null;
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }

    final position = _position;
    final startsAtBeginning = _startsAtBeginning;
    unawaited(manager.addLabel(
      name,
      settings: RecitationTrackSettings(
        readByJuz: _readByJuz,
        startAt: startsAtBeginning ? null : position,
        startSetAt: startsAtBeginning ? null : DateTime.now(),
        readBefore: !startsAtBeginning && _markEarlierRead ? position : null,
      ),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final position = _position;
    final positionText = position == null
        ? l10n.trackBeginning
        : describeRecitationPosition(position, byJuz: _readByJuz);
    final canMarkEarlierRead = !_isEditing && !_startsAtBeginning;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isEditing) ...[
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: ShiaText.body.copyWith(color: colors.text),
            decoration: revampFieldDecoration(
              context,
              label: l10n.trackName,
              hint: l10n.trackNameHint,
              error: _nameError,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 18),
        ],
        GroupLabel(l10n.trackReadBy),
        const SizedBox(height: 8),
        SegmentedSwitcher<bool>(
          segments: [
            Segment(false, l10n.trackBySurah),
            Segment(true, l10n.trackByJuz),
          ],
          selected: _readByJuz,
          onChanged: _setReadByJuz,
        ),
        const SizedBox(height: 18),
        GroupLabel(_isEditing ? l10n.trackContinueFrom : l10n.trackStartFrom),
        const SizedBox(height: 8),
        CardList(children: [
          CardListRow(
            first: true,
            last: !canMarkEarlierRead,
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(12),
              ),
              child: OutlineIcon(OutlineGlyph.bookmark,
                  size: 20, color: colors.accent),
            ),
            title: Text(positionText),
            titleStyle: ShiaText.cardTitle,
            trailing: SizedBox.square(
              dimension: 36,
              child: Center(
                child: OutlineIcon(OutlineGlyph.chevronRight,
                    size: 18, color: colors.chevron, strokeWidth: 2),
              ),
            ),
            onTap: _pickPosition,
          ),
          if (canMarkEarlierRead) _buildMarkEarlierReadRow(l10n),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _isEditing ? l10n.trackEditNote : l10n.trackNewNote,
            style: ShiaText.caption.copyWith(
              height: 18 / 13,
              color: colors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        PageButton(
          label: _isEditing ? l10n.commonSave : l10n.trackCreate,
          filled: true,
          onPressed: _save,
        ),
      ],
    );
  }

  /// "Count earlier verses towards progress", under a new track's start: counts what comes
  /// before it towards the Khatm without logging it as recited.
  Widget _buildMarkEarlierReadRow(AppLocalizations l10n) {
    return CardSwitchRow(
      last: true,
      label: l10n.trackMarkEarlierRead,
      hint: l10n.trackMarkEarlierReadHint,
      value: _markEarlierRead,
      onChanged: (value) => setState(() => _markEarlierRead = value),
    );
  }
}
