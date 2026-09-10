import '../constants.dart';
import '../data/uid_title_data.dart';
import '../utils/deep_links.dart';
import '../utils/quran_index.dart';

/// The verse a zikr link points at, once the zikr it names is known.
///
/// Only a surah has verses, so an ayah on any other zikr resolves to null and
/// the zikr simply opens at the top - the link is not treated as broken for
/// carrying a number that has nothing to point at. Out-of-range ayahs clamp
/// through [VerseKey.tryParse], so `/zikr/3-aal-e-imraan/999` opens at the
/// surah's last verse rather than nowhere.
VerseKey? zikrLinkVerse(DeepLinkTarget target, UidTitleData item) {
  final ayah = zikrDeepLinkAyah(target);
  if (ayah == null) return null;

  final surah = surahForUid(item.getFirstUId());
  if (surah == null) return null;

  return VerseKey.tryParse('$surah:$ayah');
}

/// Where a `/quran/...` link lands: the Quran screen, one juz, or one verse.
class QuranDeepLinkDestination {
  const QuranDeepLinkDestination.home()
      : verse = null,
        juz = null;
  const QuranDeepLinkDestination.verse(VerseKey this.verse) : juz = null;
  const QuranDeepLinkDestination.juz(int this.juz) : verse = null;

  /// The surah, and the ayah within it when the link named one.
  final VerseKey? verse;
  final int? juz;

  bool get isHome => verse == null && juz == null;
}

/// Turns a zikr deep-link target into the item it names.
///
/// Shared by two callers with different timing: the home page, which handles
/// links that arrive while the app is already running, and the web launch
/// route, which handles a link the app booted straight into. Both need the
/// zikr index loaded first — the slug-to-uid map lives there.
class DeepLinkResolver {
  const DeepLinkResolver._();

  static Future<UidTitleData?> resolveZikrItem(DeepLinkTarget target) async {
    if (target.segments.isEmpty) return null;

    final primarySegment = target.segments.first;
    if (items.containsKey(primarySegment)) {
      final title = items[primarySegment];
      if (title is String && title.isNotEmpty) {
        return UidTitleData(primarySegment, title);
      }
    }

    final cachedUid = slugToItemUid[primarySegment];
    if (cachedUid != null) {
      final title = items[cachedUid];
      if (title is String && title.isNotEmpty) {
        return UidTitleData(cachedUid, title);
      }
    }

    return null;
  }

  /// What a `/quran/...` target actually points at, or null when it names no
  /// verse in the Quran.
  ///
  /// This is where range is decided - the link parser only checks shape - so
  /// `2/300` clamps to al-Baqarah's last verse and `115/1` resolves to nothing.
  ///
  /// Dark-launch gate: the Quran screen, and juz reading in particular, only
  /// exist for admins right now (see home_menu.dart's visibleHomeMenuItems and
  /// ZikrPage._surahNumber), so a `/quran/...` link resolves to nothing for
  /// everyone else and lands on the same not-found page an unrecognised link
  /// would. Lift this once the feature is ready for every user.
  static QuranDeepLinkDestination? resolveQuranDestination(
    DeepLinkTarget target,
  ) {
    if (!isUserAdmin) return null;

    final segments = target.segments;
    if (segments.isEmpty) {
      return const QuranDeepLinkDestination.home();
    }

    if (segments.first.toLowerCase() == quranJuzSegment) {
      final juz = int.tryParse(segments.length > 1 ? segments[1] : '');
      if (juz == null || juz < 1 || juz > 30) return null;
      return QuranDeepLinkDestination.juz(juz);
    }

    final verse = VerseKey.tryParse(segments.join(':'));
    if (verse == null) return null;
    return QuranDeepLinkDestination.verse(verse);
  }
}
