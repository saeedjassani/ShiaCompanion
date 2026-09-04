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

  test('reading before preferences are ready is not an error', () {
    // The Quran screen reads this in initState, which can run before
    // SharedPreferences has been initialised in a cold start.
    expect(QuranProgressStore.instance.read(), isNull);
  });
}
