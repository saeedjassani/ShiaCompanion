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

  /// Found during the top-20 favorited-missing-zikr restoration pass: E53's
  /// old content ("Ya 'Imada man la 'Imada lahu...", from al-Khisal, taught
  /// to Imam Ali by the Prophet) is the same nineteen-phrase supplication
  /// E38 already carries in full (from Kaf'ami's al-Balad al-Ameen, plus a
  /// bonus dua from Imam al-Jawad) - restoring it standalone would just
  /// duplicate E38. Several other live entries (E27 Dua Mashlool, E29
  /// Jawshan al-Kabeer, E96 Dua for Solving Difficulties, R1) quote the same
  /// "Ya 'imada man la 'imada lahu..." opening formula as part of otherwise
  /// distinct content - checked side by side and kept standalone, per the
  /// false-positive warning in RESTORING_MISSING_ZIKRS.md Step 1.5.
  'E53': RetiredZikrRedirect('E38'),

  /// Found while restoring the per-Imam supplication set: E118's old content
  /// ("Ya man azharal jameela wa sataral qabeeha...") is word-for-word the
  /// dua F11 ("Namaz of Jafar-e-Tayyaar") already carries in its first tab
  /// ("Special Namaz") - taught there by Imam al-Sadiq for a request to be
  /// granted, rather than as one of the Imams' own supplications. Restoring
  /// it standalone would just duplicate that tab.
  'E118': RetiredZikrRedirect('F11', tabIndex: 0),

  /// Found in a "low hanging fruit" restoration pass: E148's old content
  /// ("Thanksgiving Prostration - Sajdah al Shukr") is already fully
  /// covered live - the "shukran shukran"/"afwan afwan" (100x) formula is
  /// in I20 ("Supplicatory Utterances of the Thanksgiving Prostration")
  /// and the "shukran lillah" (3x) formula is in I19's own merits field,
  /// both under the same Imam al-Rida narrations E148 quotes. I19 is the
  /// closer title match and carries the exact phrase E148 leads with.
  'E148': RetiredZikrRedirect('I19'),

  /// Found during the 2026-09-14 restoration pass: I15's old content ("Twelfth"
  /// through "Sixteenth" - the ten-times tahlil statement, Prophet Joseph's
  /// dua, the "Your forgiveness is more hopeful than my deeds" dua, etc.) is
  /// word-for-word already live inside I14 ("General Ta'qeebaat-2"), under
  /// its own inline heading "Virtues of the 'Effective Veneration'" - I15's
  /// exact title. Restoring it standalone would just duplicate that section
  /// of I14's main data.
  'I15': RetiredZikrRedirect('I14'),

  /// Caught in review of the 2026-09-14 sixth restoration pass: I10's title
  /// ("General Ta'qeebaat - 1") is the same entry as the already-live I9's
  /// ("General Ta'qeebaat-1"), and I10's content is the same Tasbih
  /// al-Zahra' method-and-merits text as I9's main `data` field, just
  /// reworded/retranslated - restoring it standalone would just duplicate
  /// I9.
  'I10': RetiredZikrRedirect('I9'),

  /// Caught in the same review sweep: I18's entire content ("Merit of
  /// reciting Bismillah along with La Haula Wa La Quwwata") is word-for-word
  /// already live inside I17 ("Ta'qeebaat of the Dawn (Fajr) Prayers")'s
  /// second tab, under I17's own "Seventh:" numbered section (Sayyid Ibn
  /// Tawus / Imam al-Rida narration on the Bismillah+la-hawla doxology).
  'I18': RetiredZikrRedirect('I17', tabIndex: 1),

  /// E99's entire content ("Dua of Covenant with Almighty Allah") is
  /// word-for-word already live inside I17's fourth tab, spanning I17's own
  /// "Eleventh:" and "Twelfth:" numbered sections (the Prophet's morning/
  /// evening covenant and the post-fajr salutation formula).
  'E99': RetiredZikrRedirect('I17', tabIndex: 3),

  /// E40's entire content ("Dua for delaying death (Ajal)") is the same
  /// Prophetic hadith and the same "Subhaanallaahi mil'al meezaan..."
  /// glorification as I17's second tab, under I17's own "Sixth:" numbered
  /// section - I17 additionally carries a "wa sa'atal kursiyy" tail and a
  /// follow-on Alhamdulillah variant that E40 lacks, but it's the same
  /// narration and the same core dhikr, just under a different numbering
  /// scheme.
  'E40': RetiredZikrRedirect('I17', tabIndex: 1),
};
