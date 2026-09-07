/// Uids retired from the live corpus - almost always because they turned
/// out to duplicate another entry word-for-word - but still reachable
/// through a favorite or a shared/deep-linked URL saved before the
/// retirement. A favorite's uid is never rewritten once saved (see
/// [UidTitleData.getFirstUId]), so simply dropping a uid from the corpus
/// reproduces the "Unable to open this dua." bug documented for the 2026-04
/// zikr.json purge: the content load is a literal asset lookup by uid, with
/// nothing to fall back to.
///
/// Retiring a uid safely means adding it here instead of just deleting its
/// content: [ZikrPage] consults this map when the direct uid lookup would
/// otherwise fail, and opens [targetUid] - landing on tab index [tabIndex]
/// of it (into its `tabs` array, not counting the main `data` slot) when
/// the retired uid's content now lives in one tab specifically rather than
/// covering the whole entry.
class RetiredZikrRedirect {
  const RetiredZikrRedirect(this.targetUid, {this.tabIndex});

  /// The uid whose content now covers what this retired uid used to.
  final String targetUid;

  /// Index into the target's `tabs` array to land on, or null to land on
  /// the target's main `data` (tab index 0 in the reader's own numbering).
  final int? tabIndex;
}

/// D11 duplicated D12 word-for-word (D12 now carries the fuller ending).
/// The other nine were identified during the 2026-09 missing-zikr recovery
/// as already covered by an existing tab and deliberately never restored as
/// standalone entries - see fav-migration-missing-zikrs in project memory.
const Map<String, RetiredZikrRedirect> retiredZikrRedirects = {
  'D11': RetiredZikrRedirect('D12'),
  'AA6': RetiredZikrRedirect('AA5', tabIndex: 0),
  'AA7': RetiredZikrRedirect('AA5', tabIndex: 1),
  'I26': RetiredZikrRedirect('I24', tabIndex: 1),
  'E48': RetiredZikrRedirect('I20', tabIndex: 0),
  'I25': RetiredZikrRedirect('I24', tabIndex: 0),
  'E56': RetiredZikrRedirect('I17', tabIndex: 2),
  'E106': RetiredZikrRedirect('I9', tabIndex: 2),
  'E151': RetiredZikrRedirect('I21', tabIndex: 1),
  'I16': RetiredZikrRedirect('I14', tabIndex: 0),
};
