import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/hadith_loader.dart';

void main() {
  const manifest = HadithManifest(
    shardSize: 128,
    totalQuotes: 2376,
    muharramStart: 2341,
  );

  test('maps quote indexes to fixed-size shard assets', () {
    expect(locateHadithAsset(0, 128).path, 'assets/hadith/000.json');
    expect(locateHadithAsset(127, 128).itemIndex, 127);
    expect(locateHadithAsset(128, 128).path, 'assets/hadith/001.json');
    expect(locateHadithAsset(128, 128).itemIndex, 0);
    expect(locateHadithAsset(2375, 128).path, 'assets/hadith/018.json');
    expect(locateHadithAsset(2375, 128).itemIndex, 71);
  });

  test('selects general and Muharram quotes from their original ranges', () {
    final general = selectHadithIndex(
      manifest,
      useMuharramQuotes: false,
      random: Random(1),
    );
    final muharram = selectHadithIndex(
      manifest,
      useMuharramQuotes: true,
      random: Random(1),
    );

    expect(general, inInclusiveRange(0, 2340));
    expect(muharram, inInclusiveRange(2341, 2375));
  });

  testWidgets('loads a quote from the generated asset shards', (_) async {
    final quote = await loadRandomHadith(
      rootBundle,
      useMuharramQuotes: false,
      random: Random(1),
    );

    expect(quote, isNotEmpty);
  });

  test('daily seed is stable across the same UTC day and changes on the next',
      () {
    final morning = DateTime.utc(2026, 8, 22, 0, 30);
    final night = DateTime.utc(2026, 8, 22, 23, 59);
    final nextDay = DateTime.utc(2026, 8, 23, 0, 30);

    expect(dailyHadithSeed(morning), dailyHadithSeed(night));
    expect(dailyHadithSeed(morning), isNot(dailyHadithSeed(nextDay)));
  });

  test('same daily seed selects the same hadith index every time', () {
    final seed = dailyHadithSeed(DateTime.utc(2026, 8, 22));

    final first = selectHadithIndex(
      manifest,
      useMuharramQuotes: false,
      random: Random(seed),
    );
    final second = selectHadithIndex(
      manifest,
      useMuharramQuotes: false,
      random: Random(seed),
    );

    expect(first, second);
  });
}
