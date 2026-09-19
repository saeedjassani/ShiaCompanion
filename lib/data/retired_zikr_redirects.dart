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

  /// Found in a full-corpus duplicate sweep (2026-09-17), unrelated to the
  /// missing-zikr restoration project - these are old, previously-live
  /// entries that turned out to duplicate other old, previously-live
  /// entries.
  ///
  /// AH10's entire content ("Entrance Permission & Farewell - Kazimayn") is
  /// verbatim the entrance/Izn-Dukhool preamble already embedded at the top
  /// of AH5's main data ("Ziyarah of Imam Muhammad al-Jawad - Kazimayn").
  /// AH10 also never actually delivers on its own title: it has zero
  /// farewell/wida content despite promising it.
  'AH10': RetiredZikrRedirect('AH5'),

  /// I12 ("Merits of reciting Ayah Kursi, Ayah Al Shahadah, Ayah Al Mulk
  /// after every Namaz") is a reworded/retranslated duplicate of I9's
  /// second tab, which carries the identical Imam al-Sadiq hadith and the
  /// same four-verse list (al-Faatehah, Ayat al-Kursi, Ayah al-Shahadah,
  /// Ayah al-Mulk) under its own "Eighth:" numbered section - the same
  /// reworded-duplicate shape as the already-retired I10/I9 pair. Restored
  /// standalone in "batch 3 of top-20" (commit d72bc84) without the
  /// duplicate being caught.
  'I12': RetiredZikrRedirect('I9', tabIndex: 1),

  /// E49 ("Dua for Pardoning of sins") is the bare "Ya man laa
  /// yashghaluhu sam'un..." supplication with none of its narrative frame.
  /// I14's second tab carries the same dua in full context (Imam Ali's
  /// encounter with Prophet Khizr at the Ka'bah, per Muhammad ibn
  /// al-Hanafiyyah, also reported by al-Kaf'ami in al-Balad al-Ameen).
  'E49': RetiredZikrRedirect('I14', tabIndex: 1),

  /// E47 ("Dua for Longevity") is the bare "Allaahumma salli ala
  /// Muhammadin..." supplication with no narrative. I14's second tab
  /// carries the same dua under its own "Twenty-first:" numbered section,
  /// with the full frame it's missing: an old, lonely man asking Imam
  /// al-Sadiq for a way to live longer (Jameel ibn Darraaj, via Sayyid Ibn
  /// Tawus) - matching E47's own title exactly.
  'E47': RetiredZikrRedirect('I14', tabIndex: 1),

  /// E50 ("Dua for Protection of the house from damage & theft") is
  /// verbatim I24's tabs[2] ("Fear of House Collapse") *and* tabs[3]
  /// ("Fear of Thieves") concatenated - the sibling entries I24 tabs[0] and
  /// tabs[1] were already retired above as I25/I26; E50 is the same
  /// pattern for the other two tabs, just missed at the time. This map only
  /// supports one target tab, so this redirect lands on tabs[2]; tabs[3]
  /// ("Fear of Thieves") is one swipe away from there in the reader.
  'E50': RetiredZikrRedirect('I24', tabIndex: 2),

  /// G20 was restored standalone ("Restore a third low-hanging-fruit
  /// batch...", commit cd2b3c6) without noticing that 'G20|N3' already
  /// existed as a proper alias to N3's identical "Ziyarat on Tuesday"
  /// content - the corpus ended up with both a stale plain 'G20' entry
  /// (its own rougher, non-transliterated text) and the correct alias,
  /// double-listing the same ziyarah in the general Ziyarat list. The
  /// 'G20|N3' alias stays; this retires the leftover plain 'G20'.
  'G20': RetiredZikrRedirect('N3'),

  /// R10 ("Ziyarah of Condolence to Holy Prophet (s) and His Immaculate
  /// progeny") is a word-for-word duplicate of G10 ("Ziyarat e Taziyah
  /// Condolence to Holy Prophet (s) and His Immaculate progeny").
  'R10': RetiredZikrRedirect('G10'),

  /// Y8 ("Thirteenth Night Of Shaban") contains only a cross-reference
  /// pointing back to the Rajab White Nights prayers (X11).
  'Y8': RetiredZikrRedirect('X11'),

  /// Y12 ("Last Night of Shaban") contains only an introductory sentence
  /// pointing to the last night of Shaban / first night of Ramadan dua (AA20).
  'Y12': RetiredZikrRedirect('AA20'),

  /// G24 ("Story of Sayyid Al Rashti") is the narrative regarding the virtues
  /// and recitation of the comprehensive form of Ziyarah (G30).
  'G24': RetiredZikrRedirect('G30'),

  /// I86 ("Ten duas for fufillment of petitions (requests)") contains only
  /// the introductory hadith narrative without the 10 duas.
  'I86': RetiredZikrRedirect('I83'),

  /// R11 ("Ziyarah on the day of Ashura") is an alias to the famous Ziyarat
  /// Ashura (G4).
  'R11': RetiredZikrRedirect('G4'),

  /// R14 ("More Confirmations") is the narrative of Sayyid Ahmad al-Rashti
  /// regarding the Comprehensive Ziyarah (G30).
  'R14': RetiredZikrRedirect('G30'),

  /// F1 ("Merits of Namaz e Shab") is the merits/preamble to Namaz e Shab (F2).
  'F1': RetiredZikrRedirect('F2'),

  /// AA28 ("Aamal of Shab Qadr") points to the Common Aamal of Qadr Nights (AA29).
  'AA28': RetiredZikrRedirect('AA29'),

  /// P6 ("The Namaaz of Ameer al-Momineen (a.s.)") points to Namaz of Imam Ali (F15).
  'P6': RetiredZikrRedirect('F15'),

  /// I96 ("Merits of Surah Zilzal") points to Surah al-Zalzalah (A99).
  'I96': RetiredZikrRedirect('A99'),

  /// X8 ("(c) First Day of Rajab") points to the First Night/Day of Rajab rites (X7).
  'X8': RetiredZikrRedirect('X7'),
};
