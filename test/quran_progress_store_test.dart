import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/quran_progress_store.dart';

void main() {
  test('quran progress encodes versioned position data', () {
    final progress = QuranProgress(
      surah: 2,
      ayah: 156,
      surahTitle: '2 : Al-Baqarah البقرة',
      updatedAt: DateTime.utc(2026, 6, 7, 10, 30),
    );

    expect(progress.toJson(), {
      'version': 1,
      'surah': 2,
      'ayah': 156,
      'surahTitle': '2 : Al-Baqarah البقرة',
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });
  });

  test('quran progress decodes numeric fields defensively', () {
    final progress = QuranProgress.fromJson({
      'version': '1',
      'surah': '2',
      'ayah': '156',
      'surahTitle': '2 : Al-Baqarah',
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });

    expect(progress.version, 1);
    expect(progress.surah, 2);
    expect(progress.ayah, 156);
    expect(progress.updatedAt, DateTime.utc(2026, 6, 7, 10, 30));
  });

  test('quran progress survives a record with fields missing', () {
    final progress = QuranProgress.fromJson({});

    expect(progress.surah, 0);
    expect(progress.ayah, 0);
    expect(progress.surahTitle, isEmpty);
  });

  test('progress reached inside a juz remembers the juz', () {
    final progress = QuranProgress(
      surah: 5,
      ayah: 12,
      surahTitle: '5: Al-Maidah',
      juz: 6,
      updatedAt: DateTime.utc(2026, 6, 7, 10, 30),
    );

    expect(progress.toJson()['juz'], 6);
    expect(QuranProgress.fromJson(progress.toJson()).juz, 6);
  });

  test('progress from reading a surah alone carries no juz', () {
    final progress = QuranProgress(
      surah: 5,
      ayah: 12,
      surahTitle: '5: Al-Maidah',
      updatedAt: DateTime.utc(2026, 6, 7, 10, 30),
    );

    expect(progress.toJson().containsKey('juz'), isFalse);
    expect(QuranProgress.fromJson(progress.toJson()).juz, isNull);
  });

  test('a record written before juz existed still reads back', () {
    final progress = QuranProgress.fromJson({
      'version': 1,
      'surah': 2,
      'ayah': 156,
      'surahTitle': '2: Al-Baqarah',
      'updatedAt': '2026-06-07T10:30:00.000Z',
    });

    expect(progress.juz, isNull);
    expect(progress.surah, 2);
    expect(progress.ayah, 156);
  });

  test('reading before preferences are ready is not an error', () {
    // The Quran screen reads this in initState, which can run before
    // SharedPreferences has been initialised in a cold start.
    expect(QuranProgressStore.instance.read(), isNull);
  });
}
