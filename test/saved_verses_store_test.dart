import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/services/saved_verses_sync_policy.dart';
import 'package:shia_companion/services/saved_verses_store.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

SavedVerse _verse(int surah, int ayah, {String name = 'Surah', String? text}) {
  return SavedVerse(
    surah: surah,
    ayah: ayah,
    surahName: name,
    excerpt: text ?? 'verse $surah:$ayah',
    savedAt: DateTime.utc(2026, 6, 7, 10, 30),
  );
}

SavedVersesState _saving(Iterable<SavedVerse> verses) {
  var state = SavedVersesState.empty;
  for (final verse in verses) {
    state = state.save(verse);
  }
  return state;
}

List<String> _keys(SavedVersesState state) =>
    state.inMushafOrder.map((v) => v.verse.toString()).toList();

void main() {
  group('SavedVersesState', () {
    test('a fresh state has nothing saved', () {
      expect(SavedVersesState.empty.verses, isEmpty);
    });

    test('keeps every verse saved, not just the last one', () {
      // The whole reason this is not a ZikrBookmark: that holds one record
      // per document, so saving a second verse of a surah would destroy the
      // first.
      final state = _saving([_verse(2, 255), _verse(2, 286)]);
      expect(_keys(state), ['2:255', '2:286']);
    });

    test('reads back in mushaf order however they were saved', () {
      final state = _saving(
          [_verse(114, 1), _verse(2, 255), _verse(2, 5), _verse(36, 9)]);
      expect(_keys(state), ['2:5', '2:255', '36:9', '114:1']);
    });

    test('saving the same verse twice does not duplicate it', () {
      final state = _saving([
        _verse(2, 255, text: 'first'),
        _verse(2, 255, text: 'second'),
      ]);
      expect(state.verses, hasLength(1));
      expect(state.inMushafOrder.single.excerpt, 'second',
          reason: 'the later save wins');
    });

    test('removing takes out only the verse asked for', () {
      final state = _saving([_verse(2, 255), _verse(2, 286)])
          .unsave(savedVerseKey(const VerseKey(2, 255)));
      expect(_keys(state), ['2:286']);
    });

    test('removing something never saved changes nothing', () {
      final state = _saving([_verse(2, 255)]);
      expect(
        state.unsave(savedVerseKey(const VerseKey(9, 1))),
        same(state),
      );
    });

    test('an invalid verse is not saved', () {
      expect(_saving([_verse(0, 0)]).verses, isEmpty);
    });

    test('survive the JSON round trip, name and excerpt included', () {
      final state = _saving([
        _verse(5, 81, name: 'Al-Maidah', text: 'وَلَوْ كَانُوْا'),
        _verse(1, 1, text: ''),
      ]);
      final restored = SavedVersesState.fromJson(state.toJson());

      expect(_keys(restored), ['1:1', '5:81']);
      final maidah = restored.inMushafOrder.last;
      expect(maidah.surahName, 'Al-Maidah');
      expect(maidah.excerpt, 'وَلَوْ كَانُوْا');
      expect(maidah.savedAt, DateTime.utc(2026, 6, 7, 10, 30));
    });

    test('nonsense rows are dropped rather than shown', () {
      final state = SavedVersesState.fromJson({
        'verses': [
          {'surah': 0, 'ayah': 0},
          'not a map',
          {'surah': 2, 'ayah': 255, 'savedAt': '2026-06-07T10:30:00.000Z'},
        ],
      });
      expect(_keys(state), ['2:255']);
    });

    test('plus unions saved verses, as the guest import needs', () {
      final account = _saving([_verse(2, 255)]);
      final guest = _saving([_verse(36, 9)]);
      expect(_keys(account.plus(guest)), ['2:255', '36:9']);
      expect(_keys(account.plus(guest).plus(guest)), ['2:255', '36:9']);
    });
  });

  group('saved verse operations', () {
    test('save and unsave round trip through JSON', () {
      final save = PendingSavedVerseOperation.save(_verse(2, 255));
      final restoredSave = PendingSavedVerseOperation.fromJson(save.toJson())!;
      expect(restoredSave.kind, SavedVerseOperationKind.save);
      expect(restoredSave.verse!.verse, const VerseKey(2, 255));

      final unsave = PendingSavedVerseOperation.unsave('2:255');
      final restoredUnsave =
          PendingSavedVerseOperation.fromJson(unsave.toJson())!;
      expect(restoredUnsave.kind, SavedVerseOperationKind.unsave);
      expect(restoredUnsave.verseKey, '2:255');
    });

    test('saving and unsaving a verse share an id, so the last one wins', () {
      // The pending queue keeps one operation per id; sharing it means a
      // save then an unsave made offline leaves only the unsave to replay.
      expect(
        PendingSavedVerseOperation.save(_verse(2, 255)).id,
        PendingSavedVerseOperation.unsave('2:255').id,
      );
    });

    test('both replay idempotently', () {
      final save = PendingSavedVerseOperation.save(_verse(2, 255));
      final saved = applyPendingSavedVerseOperations(
          SavedVersesState.empty, [save, save]);
      expect(_keys(saved), ['2:255']);

      final unsave = PendingSavedVerseOperation.unsave('2:255');
      final unsaved = applyPendingSavedVerseOperations(saved, [unsave, unsave]);
      expect(unsaved.verses, isEmpty);
    });

    test('malformed rows are rejected', () {
      expect(
        PendingSavedVerseOperation.fromJson(
            {'kind': 'save', 'verseKey': '2:255', 'verse': 'nope'}),
        isNull,
      );
      expect(
        PendingSavedVerseOperation.fromJson({'kind': 'unsave'}),
        isNull,
      );
    });
  });

  group('the device-only store verses are moved out of', () {
    final store = SavedVersesStore.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
    });

    test('reads what an older version saved', () async {
      await SP.prefs.setString(
        'quran_saved_verses_v1',
        '[{"surah":2,"ayah":255,"surahName":"Al-Baqarah",'
            '"savedAt":"2026-06-07T10:30:00.000Z"}]',
      );
      expect(store.readAll().single.surahName, 'Al-Baqarah');

      await store.clear();
      expect(store.readAll(), isEmpty);
    });

    test('nonsense records are dropped rather than moved', () async {
      await SP.prefs.setString(
        'quran_saved_verses_v1',
        '[{"surah":0,"ayah":0},{"surah":2,"ayah":255,"savedAt":"2026-06-07T10:30:00.000Z"}]',
      );
      expect(store.readAll(), hasLength(1));
    });

    test('unreadable storage reads as empty rather than throwing', () async {
      await SP.prefs.setString('quran_saved_verses_v1', 'not json');
      expect(store.readAll(), isEmpty);
    });

    test('decodes numeric fields defensively', () {
      final verse = SavedVerse.fromJson({
        'version': '1',
        'surah': '5',
        'ayah': '81',
        'surahName': 'Al-Maidah',
        'savedAt': '2026-06-07T10:30:00.000Z',
      });

      expect(verse.version, 1);
      expect(verse.verse, const VerseKey(5, 81));
      expect(verse.isValid, isTrue);
    });
  });
}
