import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../utils/deep_links.dart';
import '../utils/quran_index.dart';

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

  static CollectionReference<Map<String, dynamic>> get _zikrCollection =>
      FirebaseFirestore.instance.collection('zikr');

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

    if (!isUserAdmin) {
      return null;
    }

    return _fetchFromFirestore(primarySegment);
  }

  /// What a `/quran/...` target actually points at, or null when it names no
  /// verse in the Quran.
  ///
  /// This is where range is decided - the link parser only checks shape - so
  /// `2/300` clamps to al-Baqarah's last verse and `115/1` resolves to nothing.
  static QuranDeepLinkDestination? resolveQuranDestination(
    DeepLinkTarget target,
  ) {
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

  static Future<UidTitleData?> _fetchFromFirestore(String segment) async {
    final directUidSnapshot = await _zikrCollection.doc(segment).get();
    final directUidItem = _buildItemFromSnapshot(directUidSnapshot);
    if (directUidItem != null) {
      return directUidItem;
    }

    final slugSnapshot =
        await _zikrCollection.where('slug', isEqualTo: segment).limit(1).get();
    if (slugSnapshot.docs.isNotEmpty) {
      final slugItem = _buildItemFromSnapshot(slugSnapshot.docs.first);
      if (slugItem != null) {
        return slugItem;
      }
    }

    final aliasSnapshot = await _zikrCollection
        .where('slugAliases', arrayContains: segment)
        .limit(1)
        .get();
    if (aliasSnapshot.docs.isEmpty) return null;

    return _buildItemFromSnapshot(aliasSnapshot.docs.first);
  }

  static UidTitleData? _buildItemFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    final title = data['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;

    final hasPrimaryData = data['data']?.toString().trim().isNotEmpty == true;
    final rawTabs = data['tabs'];
    final hasTabData = rawTabs is List &&
        rawTabs.any((tab) => tab?.toString().trim().isNotEmpty == true);
    if (!isUserAdmin && !hasPrimaryData && !hasTabData) {
      return null;
    }

    final uid = snapshot.id;
    items[uid] = title;
    final order = data['order'];
    if (order is num) {
      itemOrder[uid] = order.toDouble();
    }
    setLocalSlugData(
      uid,
      slug: data['slug']?.toString(),
      aliases: data['slugAliases'] is Iterable ? data['slugAliases'] : null,
    );
    return UidTitleData(uid, title);
  }
}
