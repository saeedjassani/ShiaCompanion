import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/recitation_tracker_state.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../utils/quran_index.dart';
import 'verse_position_picker.dart';

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
      surahInfoFor(verse.surah)?.englishName ?? 'Surah ${verse.surah}';
  if (!byJuz) return ayah == 1 ? surahName : '$surahName $ayah';

  final juz = juzOf(verse.surah, ayah);
  final juzStart = allJuz()[juz - 1].start;
  return juzStart == VerseKey(verse.surah, ayah)
      ? 'Juz $juz'
      : compact
          ? 'Juz $juz · ${verse.surah}:$ayah'
          : 'Juz $juz · $surahName $ayah';
}

/// Creates a recitation track, or - with [label] - changes an existing one.
///
/// Both ask the same two things: read by surah or by juz, and where to start.
/// Creating also asks for a name; editing shows where the track has got to
/// as "Continue from", so moving a khatm along after reading some of it away
/// from the app is the same tap as choosing where a new one begins.
Future<void> showRecitationTrackSheet(BuildContext context, {String? label}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
  String? _nameError;

  bool get _isEditing => widget.label != null;

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
      confirmVerb: _isEditing ? 'Continue from' : 'Start at',
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
              )
            : RecitationTrackSettings(
                readByJuz: _readByJuz,
                startAt: current.startAt,
                startSetAt: current.startSetAt,
              ),
      ));
      Navigator.pop(context);
      return;
    }

    final name = _nameController.text.trim();
    final error = name.isEmpty
        ? 'Give the track a name'
        : name == unlabeledRecitationLabel ||
                manager.state.customLabels.contains(name)
            ? 'There is already a track called "$name"'
            : null;
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }

    final position = _position;
    final startsAtBeginning =
        position == null || position == const VerseKey(1, 1);
    unawaited(manager.addLabel(
      name,
      settings: RecitationTrackSettings(
        readByJuz: _readByJuz,
        startAt: startsAtBeginning ? null : position,
        startSetAt: startsAtBeginning ? null : DateTime.now(),
      ),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final position = _position;
    final positionText = position == null
        ? 'The beginning'
        : describeRecitationPosition(position, byJuz: _readByJuz);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? widget.label! : 'New recitation track',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (!_isEditing) ...[
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Family, Tahajjud',
                    errorText: _nameError,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: 20),
              ],
              Text('Read by', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Surah'),
                    icon: Icon(Icons.menu_book_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Juz (Para)'),
                    icon: Icon(Icons.auto_stories_outlined),
                  ),
                ],
                selected: {_readByJuz},
                onSelectionChanged: (selection) =>
                    _setReadByJuz(selection.first),
              ),
              const SizedBox(height: 20),
              Text(
                _isEditing ? 'Continue from' : 'Start from',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(positionText),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickPosition,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isEditing
                    ? 'Your track moves on by itself as you read. Change this '
                        'only to pick up somewhere else.'
                    : 'You can change these anytime from the track card.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save' : 'Create track'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
