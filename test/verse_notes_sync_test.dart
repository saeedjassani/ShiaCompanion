import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/services/verse_notes_manager.dart';
import 'package:shia_companion/services/verse_notes_sync_policy.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

VerseNote _note(
  int surah,
  int ayah, {
  String text = 'A reflection',
  int minute = 0,
}) {
  return VerseNote(
    surah: surah,
    ayah: ayah,
    surahName: 'Surah $surah',
    excerpt: 'Excerpt of $surah:$ayah',
    text: text,
    updatedAt: DateTime.utc(2026, 10, 13, 12, minute),
  );
}

void main() {
  group('VerseNotesState', () {
    test('keeps one note per verse', () {
      final state = VerseNotesState.empty
          .save(_note(2, 255, text: 'first'))
          .save(_note(1, 1))
          .save(_note(2, 255, text: 'second', minute: 1));
      expect(state.notes.keys, unorderedEquals(['2:255', '1:1']));
      expect(state.noteFor(const VerseKey(2, 255))!.text, 'second');
    });

    test('an empty note is not kept', () {
      expect(VerseNotesState.empty.save(_note(2, 255, text: '  ')).isEmpty,
          isTrue);
    });

    test('an older edit does not undo a newer one', () {
      final state = VerseNotesState.empty
          .save(_note(2, 255, text: 'newer', minute: 5))
          .save(_note(2, 255, text: 'older', minute: 1));
      expect(state.noteFor(const VerseKey(2, 255))!.text, 'newer');
    });

    test('a deletion only takes out a note written before it', () {
      final state = VerseNotesState.empty.save(_note(2, 255, minute: 5));
      expect(
        state.remove('2:255', DateTime.utc(2026, 10, 13, 12, 6)).isEmpty,
        isTrue,
      );
      expect(
        state
            .remove('2:255', DateTime.utc(2026, 10, 13, 12, 4))
            .noteFor(const VerseKey(2, 255)),
        isNotNull,
        reason: 'the note was written again after this deletion',
      );
    });

    test('plus keeps the later note of each verse, and can be retried', () {
      final account = VerseNotesState.empty
          .save(_note(1, 1, text: 'account', minute: 9))
          .save(_note(1, 2, text: 'account', minute: 1));
      final guest = VerseNotesState.empty
          .save(_note(1, 1, text: 'guest', minute: 2))
          .save(_note(1, 2, text: 'guest', minute: 3))
          .save(_note(1, 3, text: 'guest'));

      final merged = account.plus(guest).plus(guest);
      expect(merged.noteFor(const VerseKey(1, 1))!.text, 'account');
      expect(merged.noteFor(const VerseKey(1, 2))!.text, 'guest');
      expect(merged.noteFor(const VerseKey(1, 3))!.text, 'guest');
    });

    test('lists notes in mushaf order', () {
      final state = VerseNotesState.empty
          .save(_note(3, 7))
          .save(_note(2, 255))
          .save(_note(2, 3));
      expect(
          state.inMushafOrder.map((note) => note.key), ['2:3', '2:255', '3:7']);
    });

    test('survives the JSON round trip', () {
      final state = VerseNotesState.empty
          .save(_note(2, 255, text: 'Ayat al-Kursi\nsecond line'))
          .save(_note(112, 1));
      final restored =
          VerseNotesState.fromJson(jsonDecode(jsonEncode(state.toJson())));
      expect(restored.notes.keys, unorderedEquals(['2:255', '112:1']));
      final note = restored.noteFor(const VerseKey(2, 255))!;
      expect(note.text, 'Ayat al-Kursi\nsecond line');
      expect(note.excerpt, 'Excerpt of 2:255');
      expect(note.updatedAt, DateTime.utc(2026, 10, 13, 12));
    });

    test('nonsense rows are dropped', () {
      final state = VerseNotesState.fromJson({
        'notes': [
          'not a map',
          {'surah': 0, 'ayah': 1, 'text': 'no surah'},
          {'surah': 2, 'ayah': 255},
          _note(1, 1).toJson(),
        ],
      });
      expect(state.notes.keys, ['1:1']);
    });
  });

  group('verse note operations', () {
    test('round trip through JSON', () {
      final save = PendingVerseNoteOperation.fromJson(
        PendingVerseNoteOperation.save(_note(2, 255, text: 'kept')).toJson(),
      )!;
      expect(save.kind, VerseNoteOperationKind.save);
      expect(save.note!.text, 'kept');

      final removedAt = DateTime.utc(2026, 10, 13, 13);
      final remove = PendingVerseNoteOperation.fromJson(
        PendingVerseNoteOperation.remove('2:255', removedAt).toJson(),
      )!;
      expect(remove.kind, VerseNoteOperationKind.remove);
      expect(remove.at, removedAt);
    });

    test('every change to one verse shares an id', () {
      expect(
        PendingVerseNoteOperation.save(_note(2, 255)).id,
        PendingVerseNoteOperation.remove('2:255', DateTime.now()).id,
      );
    });
  });

  group('VerseNotesManager, signed out', () {
    setUpAll(setUpFirebaseForRenderTests);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      VerseNotesManager.instance.resetForTesting();
    });

    VerseNotesManager manager() => VerseNotesManager.instance;

    test('saves, reads back and deletes a note', () async {
      await manager().loadNotes();
      await manager().save(_note(2, 255, text: 'Throne verse'));

      expect(manager().noteFor(const VerseKey(2, 255))!.text, 'Throne verse');

      await manager().remove(const VerseKey(2, 255));
      expect(manager().noteFor(const VerseKey(2, 255)), isNull);
    });

    test('saving an empty note deletes it', () async {
      await manager().loadNotes();
      await manager().save(_note(2, 255));
      await manager().save(_note(2, 255, text: '', minute: 1));
      expect(manager().state.isEmpty, isTrue);
    });

    test('editing a note replaces it even if it was dated later', () async {
      // As when another device with a fast clock wrote it.
      await manager().loadNotes();
      await manager().save(_note(2, 255, text: 'first', minute: 50));
      await manager().save(_note(2, 255, text: 'edited', minute: 10));

      expect(manager().noteFor(const VerseKey(2, 255))!.text, 'edited');
    });

    test('deleting a note dated in the future still deletes it', () async {
      await manager().loadNotes();
      await manager()
          .save(_note(2, 255).copyWith(updatedAt: DateTime.utc(2099)));
      await manager().remove(const VerseKey(2, 255));
      expect(manager().noteFor(const VerseKey(2, 255)), isNull);
    });

    test('notes survive a restart', () async {
      await manager().loadNotes();
      await manager().save(_note(36, 1, text: 'Ya-Sin'));

      manager().resetForTesting();
      await manager().loadNotes();
      expect(manager().noteFor(const VerseKey(36, 1))!.text, 'Ya-Sin');
    });
  });
}
