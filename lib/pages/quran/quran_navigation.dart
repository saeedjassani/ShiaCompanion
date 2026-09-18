import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../services/analytics_service.dart';
import '../../utils/quran_index.dart';
import '../../utils/quran_portion.dart';
import '../zikr/zikr_page.dart';

/// Opens a surah, at a verse when one is named.
///
/// Every Quran entry point goes through here - the surah list, the juz list,
/// the go-to-verse box, a recitation label's resume card and the
/// `/quran/...` links - so they all open the same reader the same way, and a
/// surah with no document yet fails in one place rather than several.
///
/// [recitationLabel] names the recitation track this read belongs to (e.g.
/// "Family", "Personal") — set only when opened by tapping that label's
/// resume card. Left null for every other entry point, which is what routes
/// ordinary browsing into the reserved "Unlabeled" bucket instead of
/// silently picking a label for the reader.
Future<void> openQuranVerse(
  BuildContext context,
  VerseKey verse, {
  String source = ZikrOpenSource.quran,
  String? recitationLabel,
}) async {
  final info = surahInfoFor(verse.surah);
  if (info == null) return;

  await pushPageRoute(
    context,
    ZikrPage(
      UidTitleData(info.uid, items[info.uid]?.toString() ?? info.fullTitle),
      source: source,
      initialVerse: verse,
      recitationLabel: recitationLabel,
    ),
  );
}

/// Opens a juz as one continuous reading, optionally at a verse inside it.
///
/// A juz is not a document in the corpus - 28 of the 30 run across two or more
/// surahs - so it is assembled first and then handed to the reader whole. That
/// is why this is async where [openQuranVerse] is not.
Future<void> openQuranJuz(
  BuildContext context,
  int juz, {
  VerseKey? at,
  String source = ZikrOpenSource.quran,
  String? recitationLabel,
}) async {
  final portion = await loadJuzPortion(juz, DefaultAssetBundle.of(context));
  if (portion == null || portion.isEmpty || !context.mounted) return;

  await pushPageRoute(
    context,
    ZikrPage(
      UidTitleData(quranJuzUid(juz), portion.title),
      source: source,
      portion: portion,
      initialVerse: at,
      recitationLabel: recitationLabel,
    ),
  );
}
