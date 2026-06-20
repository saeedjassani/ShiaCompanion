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

HadithAssetLocation locateHadithAsset(int quoteIndex, int shardSize) {
  final shardIndex = quoteIndex ~/ shardSize;
  return HadithAssetLocation(
    path: 'assets/hadith/${shardIndex.toString().padLeft(3, '0')}.json',
    itemIndex: quoteIndex % shardSize,
  );
}

int selectHadithIndex(
  HadithManifest manifest, {
  required bool useMuharramQuotes,
  Random? random,
}) {
  final min = useMuharramQuotes ? manifest.muharramStart : 0;
  final max = useMuharramQuotes ? manifest.totalQuotes : manifest.muharramStart;
  return min + (random ?? Random()).nextInt(max - min);
}

Future<String> loadRandomHadith(
  AssetBundle bundle, {
  required bool useMuharramQuotes,
  Random? random,
}) async {
  final manifestJson = jsonDecode(
    await bundle.loadString('assets/hadith/manifest.json'),
  ) as Map<String, dynamic>;
  final manifest = HadithManifest.fromJson(manifestJson);
  final quoteIndex = selectHadithIndex(
    manifest,
    useMuharramQuotes: useMuharramQuotes,
    random: random,
  );
  final location = locateHadithAsset(quoteIndex, manifest.shardSize);
  final shard = jsonDecode(await bundle.loadString(location.path)) as List;
  return shard[location.itemIndex] as String;
}
