import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/home/hadith_card.dart';
import 'package:shia_companion/utils/hadith_loader.dart';

void main() {
  const manifest = HadithManifest(
    shardSize: 128,
    totalQuotes: 2302,
    muharramStart: 2267,
  );

  test('maps quote indexes to fixed-size shard assets', () {
    expect(locateHadithAsset(0, 128).path, 'assets/hadith/000.json');
    expect(locateHadithAsset(127, 128).itemIndex, 127);
    expect(locateHadithAsset(128, 128).path, 'assets/hadith/001.json');
    expect(locateHadithAsset(128, 128).itemIndex, 0);
    expect(locateHadithAsset(2301, 128).path, 'assets/hadith/017.json');
    expect(locateHadithAsset(2301, 128).itemIndex, 125);
  });

  test('selects general and Muharram quotes from their own ranges', () {
    for (var day = 20000; day < 20400; day++) {
      expect(
        selectHadithIndex(manifest, useMuharramQuotes: false, day: day),
        inInclusiveRange(0, 2266),
      );
      expect(
        selectHadithIndex(manifest, useMuharramQuotes: true, day: day),
        inInclusiveRange(2267, 2301),
      );
    }
  });

  test('a hadith does not repeat until the whole range has been shown', () {
    for (final muharram in [false, true]) {
      final count = muharram
          ? manifest.totalQuotes - manifest.muharramStart
          : manifest.muharramStart;
      final seen = {
        for (var day = 20000; day < 20000 + count; day++)
          selectHadithIndex(manifest, useMuharramQuotes: muharram, day: day),
      };
      expect(seen, hasLength(count));
    }
  });

  test('consecutive days do not show neighbouring rows', () {
    final today =
        selectHadithIndex(manifest, useMuharramQuotes: false, day: 20000);
    final tomorrow =
        selectHadithIndex(manifest, useMuharramQuotes: false, day: 20001);
    expect((today - tomorrow).abs(), greaterThan(100));
  });

  testWidgets('loads a quote from the generated asset shards', (_) async {
    final quote = await loadDailyHadith(
      rootBundle,
      useMuharramQuotes: false,
      day: hadithDayNumber(DateTime.utc(2026, 8, 22)),
    );

    expect(quote, isNotEmpty);
  });

  test('day number is stable across the same UTC day and moves on by one', () {
    final morning = DateTime.utc(2026, 8, 22, 0, 30);
    final night = DateTime.utc(2026, 8, 22, 23, 59);
    final nextDay = DateTime.utc(2026, 8, 23, 0, 30);

    expect(hadithDayNumber(morning), hadithDayNumber(night));
    expect(hadithDayNumber(nextDay), hadithDayNumber(morning) + 1);
  });

  test('the bundled manifest matches its shards, and each hadith has a source',
      () {
    final dir = Directory('assets/hadith');
    final bundled = HadithManifest.fromJson(
      jsonDecode(File('${dir.path}/manifest.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final quotes = <String>[
      for (final file
          in dir.listSync().whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        if (RegExp(r'\d{3}\.json$').hasMatch(file.path))
          ...(jsonDecode(file.readAsStringSync()) as List).cast<String>(),
    ];

    expect(quotes, hasLength(bundled.totalQuotes));
    expect(bundled.totalQuotes - bundled.muharramStart, 35);
    final unsourced =
        quotes.where((quote) => splitHadith(quote).source == null).toList();
    // Three sayings were bundled without any reference.
    expect(unsourced, hasLength(3));
    // The hadith of the day is hadith only, not Qur'an verses.
    expect(quotes.where((quote) => quote.endsWith('[Holy Qur’an]')), isEmpty);
    expect(
      quotes.where((quote) => quote.contains('\n[Holy Qur’an ')),
      isEmpty,
    );
  });
}
