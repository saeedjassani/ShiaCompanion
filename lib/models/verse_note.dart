import 'package:flutter/foundation.dart';

import '../utils/quran_index.dart';
import 'saved_verse.dart';

/// The longest note kept, in characters: room for a few paragraphs of
/// reflection, short enough that a few hundred notes stay well inside one
/// Firestore document's 1 MiB.
const int verseNoteMaxLength = 2000;

/// What the reader wrote about one Quran verse.
///
/// The surah name and excerpt are denormalised for the same reason
/// [SavedVerse] keeps them: the notes list has to render without loading a
/// surah document per row.
@immutable
class VerseNote {
  const VerseNote({
    required this.surah,
    required this.ayah,
    required this.surahName,
    required this.excerpt,
    required this.text,
    required this.updatedAt,
  });

  factory VerseNote.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
    return VerseNote(
      surah: asInt(json['surah']),
      ayah: asInt(json['ayah']),
      surahName: json['surahName']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final int surah;
  final int ayah;
  final String surahName;

  /// The opening of the verse, for the list. Empty is fine - the reference
  /// alone still identifies it.
  final String excerpt;

  /// The note itself, as the reader typed it.
  final String text;

  /// When it was last written; the later of two edits wins, whichever device
  /// made it and whichever order they reach the account in.
  final DateTime updatedAt;

  VerseKey get verse => VerseKey(surah, ayah);

  /// How the note is keyed wherever a set of them is stored: `"2:255"`.
  String get key => savedVerseKey(verse);

  bool get isValid =>
      surah >= 1 && surah <= surahCount && ayah >= 1 && text.trim().isNotEmpty;

  VerseNote copyWith({String? text, DateTime? updatedAt}) {
    return VerseNote(
      surah: surah,
      ayah: ayah,
      surahName: surahName,
      excerpt: excerpt,
      text: text ?? this.text,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surah': surah,
      'ayah': ayah,
      'surahName': surahName,
      if (excerpt.isNotEmpty) 'excerpt': excerpt,
      'text': text,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// Every note the reader wrote, keyed by [VerseNote.key] - one per verse.
///
/// Two devices can edit the same verse's note, so every change is decided by
/// [VerseNote.updatedAt]: the later one wins, whichever order they reach the
/// document in. The same rule [ZikrBookmarksState] follows.
@immutable
class VerseNotesState {
  VerseNotesState([Map<String, VerseNote>? notes])
      : notes = Map.unmodifiable(notes ?? const {});

  factory VerseNotesState.fromJson(dynamic value) {
    if (value is! Map) return empty;
    final raw = value['notes'];
    if (raw is! List) return empty;

    var state = empty;
    for (final entry in raw.whereType<Map>()) {
      state = state.save(VerseNote.fromJson(Map<String, dynamic>.from(entry)));
    }
    return state;
  }

  static final empty = VerseNotesState();

  final Map<String, VerseNote> notes;

  bool get isEmpty => notes.isEmpty;

  VerseNote? noteFor(VerseKey verse) => notes[savedVerseKey(verse)];

  /// Every note in mushaf order, like the saved verses: a commentary on the
  /// reader's own Quran, not a feed.
  List<VerseNote> get inMushafOrder {
    final list = notes.values.toList()
      ..sort((a, b) {
        final bySurah = a.surah.compareTo(b.surah);
        return bySurah != 0 ? bySurah : a.ayah.compareTo(b.ayah);
      });
    return list;
  }

  /// Keeps [note] as its verse's note, unless that verse already has one
  /// written later - a stale edit replayed from an offline queue must not
  /// undo a newer one made on another device.
  VerseNotesState save(VerseNote note) {
    if (!note.isValid) return this;
    final existing = notes[note.key];
    if (existing != null && note.updatedAt.isBefore(existing.updatedAt)) {
      return this;
    }
    return VerseNotesState({...notes, note.key: note});
  }

  /// Removes the note on [key], unless it was written after [removedAt] -
  /// then it is a newer note than the one the reader deleted.
  VerseNotesState remove(String key, DateTime removedAt) {
    final existing = notes[key];
    if (existing == null || existing.updatedAt.isAfter(removedAt)) return this;
    return VerseNotesState({...notes}..remove(key));
  }

  /// Unions two states by verse, the later note winning where both have one.
  /// Safe to call with the same addition twice - that is how a guest-to-user
  /// import survives being retried.
  VerseNotesState plus(VerseNotesState other) {
    var state = this;
    for (final note in other.notes.values) {
      state = state.save(note);
    }
    return state;
  }

  Map<String, Object> toJson() => {
        'notes': [for (final note in inMushafOrder) note.toJson()],
      };
}
