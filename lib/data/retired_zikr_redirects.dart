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
  'E56': RetiredZikrRedirect('I17', tabIndex: 1),
  'E106': RetiredZikrRedirect('I9', tabIndex: 7),
  'E151': RetiredZikrRedirect('I21', tabIndex: 1),
  'I16': RetiredZikrRedirect('I14', tabIndex: 6),

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

  /// Found during the 2026-09-14 restoration pass: I15's old content (the
  /// ten-times tahlil statement, Prophet Joseph's dua, the "Your forgiveness
  /// is more hopeful than my deeds" dua, etc.) is word-for-word already live
  /// inside I14 ("General Ta'qeebaat-2"), where it opened under the inline
  /// heading "Virtues of the 'Effective Veneration'" - I15's exact title.
  /// Restoring it standalone would just duplicate those tabs; the redirect
  /// lands on I14's "Tahleel x10 (Effective Veneration)" tab, where that
  /// run of duas begins.
  'I15': RetiredZikrRedirect('I14', tabIndex: 1),

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
  /// "Tasbih & La Hawla" tab (the Bismillah+la-hawla doxology; the Sayyid
  /// Ibn Tawus / Imam al-Rida narration is in I17's merits).
  'I18': RetiredZikrRedirect('I17', tabIndex: 0),

  /// E99's entire content ("Dua of Covenant with Almighty Allah") is
  /// word-for-word already live inside I17: the Prophet's morning/evening
  /// covenant is I17's "Dua of the Covenant" tab, and the post-fajr
  /// salutation formula is the next tab, "Salawat after Fajr".
  'E99': RetiredZikrRedirect('I17', tabIndex: 2),

  /// E40's entire content ("Dua for delaying death (Ajal)") is the same
  /// Prophetic hadith and the same "Subhaanallaahi mil'al meezaan..."
  /// glorification as in I17's "Tasbih & La Hawla" tab - I17 additionally
  /// carries a "wa sa'atal kursiyy" tail and a follow-on Alhamdulillah
  /// variant that E40 lacks, but it's the same narration and the same core
  /// dhikr.
  'E40': RetiredZikrRedirect('I17', tabIndex: 0),

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
  /// "Fatihah, Kursi, Shahadah & Mulk" tab, which carries the identical Imam
  /// al-Sadiq hadith (in its merits) and the same four-verse list
  /// (al-Faatehah, Ayat al-Kursi, Ayah al-Shahadah, Ayah al-Mulk) - the same
  /// reworded-duplicate shape as the already-retired I10/I9 pair. Restored
  /// standalone in "batch 3 of top-20" (commit d72bc84) without the
  /// duplicate being caught.
  'I12': RetiredZikrRedirect('I9', tabIndex: 6),

  /// E49 ("Dua for Pardoning of sins") is the bare "Ya man laa
  /// yashghaluhu sam'un..." supplication with none of its narrative frame.
  /// I14's "Dua Ya Man La Yashghaluhu" tab carries the same dua, with the
  /// full context in its merits (Imam Ali's encounter with Prophet Khizr at
  /// the Ka'bah, per Muhammad ibn al-Hanafiyyah, also reported by al-Kaf'ami
  /// in al-Balad al-Ameen).
  'E49': RetiredZikrRedirect('I14', tabIndex: 8),

  /// E47 ("Dua for Longevity") is the bare "Allaahumma salli ala
  /// Muhammadin..." supplication with no narrative. I14's "Dua for a Long
  /// Life" tab carries the same dua, with the full frame it's missing in its
  /// merits: an old, lonely man asking Imam al-Sadiq for a way to live longer
  /// (Jameel ibn Darraaj, via Sayyid Ibn Tawus) - matching E47's own title
  /// exactly.
  'E47': RetiredZikrRedirect('I14', tabIndex: 10),

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

  /// I96 ("Merits of Surah Zilzal") points to Surah al-Zalzalah (A103 -
  /// surah n is uid A(n+4); this used to say A99, which is At-Tin).
  'I96': RetiredZikrRedirect('A103'),

  /// X8 ("(c) First Day of Rajab") points to the First Night/Day of Rajab rites (X7).
  'X8': RetiredZikrRedirect('X7'),

  /// E127 ("Salawat upon The Holy Infallibles") is only the isnad introducing
  /// Imam al-Hasan al-'Askari's salawat; its source content stops at "Write
  /// down the following:". The salawat itself ships as E128 (upon the Holy
  /// Prophet), E129 (upon the Commander of the Faithful), and onward.
  'E127': RetiredZikrRedirect('E128'),

  /// Found in the 2026-10-03 sweep of the *unfavorited* missing uids (see
  /// scripts/unfavorited_missing_zikrs.json). Each was checked side by side
  /// against its target, not just matched by script. Most are the old
  /// one-form-per-uid ziyarat pages that were later folded into a live
  /// "All Forms" compilation (AG8, AK5, AI3) or a weekday entry's tab.
  ///
  /// R2/R3 ("The First Night/Day Of Muharram") are R1's main data and first
  /// tab. R8 ("Forgeries of the Enemies of Imam Husayn") is R7's first tab;
  /// its trailing "Day of Ashura" section is R7's second tab, one swipe on.
  /// R13 (Safwan's discourse on the merit of Ziyarat Ashura) is in G4's
  /// merits.
  'R2': RetiredZikrRedirect('R1'),
  'R3': RetiredZikrRedirect('R1', tabIndex: 0),
  'R8': RetiredZikrRedirect('R7', tabIndex: 0),
  'R13': RetiredZikrRedirect('G4'),

  /// AC9 ("The 8th Day Of Zilhajj" - the Tarwiyah Day) is a paragraph of
  /// AC5's merits ("First Ten Days of Dhul Hijjah").
  'AC9': RetiredZikrRedirect('AC5'),

  /// I27 ("Etiquettes of applying Kohl") is I24's "Applying Kohl" tab.
  'I27': RetiredZikrRedirect('I24', tabIndex: 4),

  /// The weekday ziyarat of Lady Fatimah (Sunday) and Imam Husayn (Monday)
  /// were each stored twice, once under the general Ziyarat list (G17,
  /// G19) and once under the weekday (L4, M4). Both now live as the second
  /// ziyarah of L3 ("Ziyarat on Sunday") and M3 ("Ziyarat on Monday").
  'G17': RetiredZikrRedirect('L3', tabIndex: 0),
  'L4': RetiredZikrRedirect('L3', tabIndex: 0),
  'G19': RetiredZikrRedirect('M3', tabIndex: 0),
  'M4': RetiredZikrRedirect('M3', tabIndex: 0),

  /// Second through Sixth forms of the general Ziyarat of Imam Husayn,
  /// now AG8's tabs. AG4 (salawat on Imam Husayn, "Fourteenth:") is
  /// AG5's second tab ("Salawat on Imam Husayn (a.s.)").
  'AG9': RetiredZikrRedirect('AG8', tabIndex: 0),
  'AG10': RetiredZikrRedirect('AG8', tabIndex: 1),
  'AG11': RetiredZikrRedirect('AG8', tabIndex: 2),
  'AG12': RetiredZikrRedirect('AG8', tabIndex: 3),
  'AG13': RetiredZikrRedirect('AG8', tabIndex: 4),
  'AG4': RetiredZikrRedirect('AG5', tabIndex: 1),

  /// Third through Sixth forms of the Ziyarat of Imam Ali, plus AK14 (Imam
  /// Zayn al-Abidin's visitation, from Farhat al-Ghari), now AK5's tabs. AK14
  /// is AK5's last tab, "Imam Zayn al-Abidin's Visit", split out of the
  /// Seventh Ziyarat's tab.
  'AK9': RetiredZikrRedirect('AK5', tabIndex: 1),
  'AK10': RetiredZikrRedirect('AK5', tabIndex: 2),
  'AK11': RetiredZikrRedirect('AK5', tabIndex: 3),
  'AK12': RetiredZikrRedirect('AK5', tabIndex: 4),
  'AK14': RetiredZikrRedirect('AK5', tabIndex: 6),

  /// The Masjid al-Kufah column/station acts, now AI3's tabs. AI8 (the
  /// third column / seat of Imam Zayn al-Abidin) runs on into AI3's next
  /// tab, "Acts in the Courtyard".
  'AI6': RetiredZikrRedirect('AI3', tabIndex: 1),
  'AI7': RetiredZikrRedirect('AI3', tabIndex: 2),
  'AI8': RetiredZikrRedirect('AI3', tabIndex: 3),
  'AI9': RetiredZikrRedirect('AI3', tabIndex: 5),

  /// AL13 ("Another form of Ziyarah (1)" at the Sardab) is AL11's second
  /// ziyarah tab.
  'AL13': RetiredZikrRedirect('AL11', tabIndex: 0),

  /// AH6/AH8 (two "Another Ziyarah of Imam al-Jawad" forms, from Ibn
  /// Tawus's al-Mazar and al-Saduq's al-Faqih) are both inside AH5's main
  /// data.
  'AH6': RetiredZikrRedirect('AH5'),
  'AH8': RetiredZikrRedirect('AH5'),

  /// Friday salawat (Misbah al-Mutahajjid, from Imam al-'Askari) upon
  /// Imams al-Jawad, al-Hadi and al-'Askari - already the salawat sections
  /// of their own shrine entries.
  'E137': RetiredZikrRedirect('AH7'),
  'E138': RetiredZikrRedirect('AL5', tabIndex: 0),
  'E139': RetiredZikrRedirect('AL6', tabIndex: 1),

  /// The Thursday-night (Shab-e-Jumu'ah) rites of Mafatih al-Jinan used to be
  /// fifteen separate uids, P2-P16 - one numbered item each ("First:",
  /// "Second:", ... "Twelfth:", plus Imam al-Mahdi's prayer). They now live
  /// as one tabbed entry, P1, rebuilt on 2026-10-03 from duas.org's copy of
  /// the al-islam.org Mafatih text (see scripts/RESTORING_MISSING_ZIKRS.md).
  /// P13 and P15 had been restored standalone and are folded in too (their
  /// slugs are P1's slugAliases). P6 used to point at F15, but its history
  /// also carried items Third-Fifth; P14 was byte-identical to P15.
  /// P12 ("Tenth", eating a pomegranate) is a single prose line, so it sits
  /// in the "Prayers and Other Acts of the Night" tab rather than a tab of
  /// its own.
  'P2': RetiredZikrRedirect('P1'),
  'P3': RetiredZikrRedirect('P1'),
  'P4': RetiredZikrRedirect('P1'),
  'P5': RetiredZikrRedirect('P1', tabIndex: 0),
  'P6': RetiredZikrRedirect('P1', tabIndex: 1),
  'P7': RetiredZikrRedirect('P1', tabIndex: 2),
  'P8': RetiredZikrRedirect('P1', tabIndex: 3),
  'P9': RetiredZikrRedirect('P1', tabIndex: 4),
  'P10': RetiredZikrRedirect('P1', tabIndex: 5),
  'P11': RetiredZikrRedirect('P1', tabIndex: 6),
  'P12': RetiredZikrRedirect('P1', tabIndex: 1),
  'P13': RetiredZikrRedirect('P1', tabIndex: 7),
  'P14': RetiredZikrRedirect('P1', tabIndex: 8),
  'P15': RetiredZikrRedirect('P1', tabIndex: 8),
  'P16': RetiredZikrRedirect('P1', tabIndex: 9),

  /// AC16 only reported Imam al-Hadi's (a.s.) birth on 15 Dhul Hijjah, with
  /// nothing to recite or do (docs/ZIKR_STRUCTURE.md rule 6).
  'AC16': RetiredZikrRedirect('AC5'),

  /// AB4 only recounted Imam al-Jawad's (a.s.) martyrdom on the last day of
  /// Dhul Qa'dah, with nothing to recite or do (rule 6).
  'AB4': RetiredZikrRedirect('AB1'),

  /// R5 only narrated the siege of Imam Husayn (a.s.) on 9 Muharram (Tasua),
  /// with nothing to recite or do (rule 6).
  'R5': RetiredZikrRedirect('R6'),

  /// R15 carried Ziyarat Ashura Ghair Maroofa (the lesser-known second form of
  /// ziyarat on the day of Ashura) in the old paragraph mode, with its Arabic
  /// run together in a few long lines - G83 is the same ziyarat line by line.
  /// The 'R15|G83' alias keeps it listed under Muharram.
  'R15': RetiredZikrRedirect('G83'),

  /// AC19 (Namaz on the Day of Ghadir) repeated AC18's tabs 2-6 almost word for
  /// word; AC18 carries the full aamal of the day.
  'AC19': RetiredZikrRedirect('AC18', tabIndex: 0),

  /// I30 (Dedication to the Dead) had no Arabic and nothing to recite of its
  /// own; its narrations on gifting deeds to the dead are now in F9's (Namaz-e-
  /// Wahshat) merits.
  'I30': RetiredZikrRedirect('F9'),

  /// I106 (Istikhara on Behalf of Others) was a scholarly discussion with
  /// nothing to recite; it is now in I33's (Istikhara) merits.
  'I106': RetiredZikrRedirect('I33'),

  /// B4 was the last of the etiquettes of ziyarat (giving way at crowded tombs,
  /// women's ziyarah); it is now part of B3's 'Ziyarah Prayer & Conduct' tab
  /// and merits.
  'B4': RetiredZikrRedirect('B3', tabIndex: 2),

  /// I108 (Prohibition on Shaving Beard) was a ruling, not a zikr; trimming the
  /// mustache is in J6's 'Ghusl & Grooming' tab.
  'I108': RetiredZikrRedirect('J6', tabIndex: 0),
};
