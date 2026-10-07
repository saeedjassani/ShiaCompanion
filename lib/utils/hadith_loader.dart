import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class HadithManifest {
  const HadithManifest({
    required this.shardSize,
    required this.totalQuotes,
    required this.muharramStart,
  });

  factory HadithManifest.fromJson(Map<String, dynamic> json) {
    return HadithManifest(
      shardSize: json['shardSize'] as int,
      totalQuotes: json['totalQuotes'] as int,
      muharramStart: json['muharramStart'] as int,
    );
  }

  final int shardSize;
  final int totalQuotes;
  final int muharramStart;
}

class HadithAssetLocation {
  const HadithAssetLocation({
    required this.path,
    required this.itemIndex,
  });

  final String path;
  final int itemIndex;
}

/// The day number, counted in whole UTC days since 1970, that picks the
/// "hadith of the day": it is the same for everyone all day and moves on by
/// one at midnight UTC. Pass [now] in tests to control which day is used.
int hadithDayNumber([DateTime? now]) {
  final utcNow = (now ?? DateTime.now()).toUtc();
  final dayStart = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
  return dayStart.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

HadithAssetLocation locateHadithAsset(int quoteIndex, int shardSize) {
  final shardIndex = quoteIndex ~/ shardSize;
  return HadithAssetLocation(
    path: 'assets/hadith/${shardIndex.toString().padLeft(3, '0')}.json',
    itemIndex: quoteIndex % shardSize,
  );
}

/// Picks the hadith for [day] (see [hadithDayNumber]) from the general or the
/// Muharram range.
///
/// Each day steps a fixed stride through the range rather than moving to the
/// next row, because the CSV is grouped by topic and consecutive rows would
/// show the same subject for weeks. The stride shares no factor with the
/// range's size, so no hadith comes back until every other one in the range
/// has been shown - more than six years for the general range.
int selectHadithIndex(
  HadithManifest manifest, {
  required bool useMuharramQuotes,
  required int day,
}) {
  final start = useMuharramQuotes ? manifest.muharramStart : 0;
  final end = useMuharramQuotes ? manifest.totalQuotes : manifest.muharramStart;
  final count = end - start;
  return start + (day * _hadithStride(count)) % count;
}

/// The first number from about 0.618 of [count] up that is coprime with it.
int _hadithStride(int count) {
  var stride = max(1, (count * 0.618).round());
  while (_gcd(stride, count) != 1) {
    stride++;
  }
  return stride;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

Future<String> loadDailyHadith(
  AssetBundle bundle, {
  required bool useMuharramQuotes,
  required int day,
}) async {
  final manifestJson = jsonDecode(
    await bundle.loadString('assets/hadith/manifest.json'),
  ) as Map<String, dynamic>;
  final manifest = HadithManifest.fromJson(manifestJson);
  final quoteIndex = selectHadithIndex(
    manifest,
    useMuharramQuotes: useMuharramQuotes,
    day: day,
  );
  final location = locateHadithAsset(quoteIndex, manifest.shardSize);
  final shard = jsonDecode(await bundle.loadString(location.path)) as List;
  return shard[location.itemIndex] as String;
}
