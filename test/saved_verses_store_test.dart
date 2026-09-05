import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

void main() {
  final store = SavedVersesStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await store.clear();
  });

  test('a fresh install has nothing saved', () {
    expect(store.readAll(), isEmpty);
    expect(store.contains(const VerseKey(2, 255)), isFalse);
  });

  test('keeps every verse saved, not just the last one', () async {
    // The whole reason this is not a ZikrBookmark: that holds one record per
    // document, so saving a second verse of a surah would destroy the first.
    await store.add(_verse(2, 255));
    await store.add(_verse(2, 286));

    expect(store.readAll(), hasLength(2));
    expect(store.contains(const VerseKey(2, 255)), isTrue);
    expect(store.contains(const VerseKey(2, 286)), isTrue);
  });

  test('reads back in mushaf order however they were saved', () async {
    await store.add(_verse(114, 1));
    await store.add(_verse(2, 255));
    await store.add(_verse(2, 5));
    await store.add(_verse(36, 9));

    expect(
      store.readAll().map((v) => v.verse.toString()),
      ['2:5', '2:255', '36:9', '114:1'],
    );
  });

  test('saving the same verse twice does not duplicate it', () async {
    await store.add(_verse(2, 255, text: 'first'));
    await store.add(_verse(2, 255, text: 'second'));

    final saved = store.readAll();
    expect(saved, hasLength(1));
    expect(saved.single.excerpt, 'second', reason: 'the later save wins');
  });

  test('removing takes out only the verse asked for', () async {
    await store.add(_verse(2, 255));
    await store.add(_verse(2, 286));

    await store.remove(const VerseKey(2, 255));

    expect(store.readAll().map((v) => v.verse.toString()), ['2:286']);
  });

  test('removing something never saved is harmless', () async {
    await store.add(_verse(2, 255));
    await store.remove(const VerseKey(9, 1));

    expect(store.readAll(), hasLength(1));
  });

  test('the surah name and excerpt survive the round trip', () async {
    await store.add(_verse(5, 81, name: 'Al-Maidah', text: 'وَلَوْ كَانُوْا'));

    final saved = store.readAll().single;
    expect(saved.surahName, 'Al-Maidah');
    expect(saved.excerpt, 'وَلَوْ كَانُوْا');
    expect(saved.savedAt, DateTime.utc(2026, 6, 7, 10, 30));
  });

  test('a verse with no excerpt is still saved', () async {
    await store.add(_verse(1, 1, text: ''));

    final saved = store.readAll().single;
    expect(saved.excerpt, isEmpty);
    expect(saved.toJson().containsKey('excerpt'), isFalse);
  });

  test('nonsense records are dropped rather than shown', () async {
    // Guards the list against a corrupted entry taking the whole screen down.
    await store.add(_verse(2, 255));
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
}
