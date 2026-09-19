# Restoring missing zikrs from history

Context: 501 zikr UIDs once had real titles (some had real content) in this
app's history and no longer exist in `assets/zikr.json`. They were purged in
commit `8c5f825` ("fix bugs, normalize data, regen offline zikr") when the
corpus was rebuilt from a flat 943-entry placeholder-title index down to
~339 real entries. Old favorites can still reference these UIDs, which
produces "Unable to open this dua." — see the `fav-migration-missing-zikrs`
memory note for the bug-report side of this.

This doc is the restoration process for bringing an individual UID back with
real, correctly-formatted content — not just a title.

## Step 0: regenerate the missing-UID list (if you don't already have it)

`scripts/query_favorited_missing_zikrs.js` does this as its first step (union
every historical `assets/zikr.json` version's keys via `git log --follow`,
subtract the current file's keys), then cross-references against Firestore
favorites — see the Prioritizing section below. 483 UIDs missing as of
2026-09-08 (501 at the original 2026-09-05 count, minus UIDs restored since).
Don't confuse this with `scripts/missing_zikrs.json` (545 entries) — that
file is `populate_missing_zikrs.js`'s diff of the old `legacy_items_index.json`
against current `zikr.json`, a different project (finding content to backfill
from duas.org from scratch).

## Step 1: check `assets/items/<uid>` in git history FIRST

Before assuming a UID needs sourcing from scratch: this app used to store each
zikr's real content in a separate file, `assets/items/<uid>` (dropped in
commit `83594d0`, "Drop orphaned assets/items/..."). Many "missing" UIDs
still have their full old content sitting in that file's git history, even
though `assets/zikr.json` only ever had a bare title for them at the end.

```bash
git log --all --diff-filter=D --format=%H -- "assets/items/<UID>" | tail -1
# then, using the commit that deleted it:
git show <that-commit>^:"assets/items/<UID>"
```

The old shape is `{ content, audio, transliteration, english }` where
`content` mixes an English intro/attribution with the Arabic (often wrapped
in `--...--`), and `english` mixes the same intro with the English
translation. `transliteration` is very often empty — that's the one field
you'll usually have to fill in yourself (Step 3).

**Do this for every UID before searching the web.** A live web search for a
"Dua for X" style placeholder title mostly turns up unrelated collection
pages; the real text was already sitting in your own git history the whole
time.

## Step 1.5: check whether it's already covered by another UID's `tabs`

Some "missing" UIDs actually already have full content shipping today — not
under their own UID, but as one of another live UID's `tabs[]` entries. e.g.
`AA6`/`AA7` ("Dua after every obligatory Prayers (2)/(3)") are `AA5`'s
`tabs[0]`/`tabs[1]` verbatim. For these, **don't create a standalone
`assets/zikr/<uid>` entry** — instead add it to
[lib/data/retired_zikr_redirects.dart](../lib/data/retired_zikr_redirects.dart),
which `ZikrPage` already consults so the UID opens the right tab of its
owner. That map currently covers 10 UIDs (`D11`→`D12` full duplicate, plus 9
tab-covered ones); check it — and check for new candidates — before doing any
restoration work on a UID.

The tempting shortcut — compare a chunk of the UID's own historic Arabic
against every live `tabs[]` entry's Arabic, look for a substring match — is
**unreliable on its own** and produces real false positives: many
completely different narrations quote the exact same short classical
formula (e.g. "Laa hawla wa laa quwwata..." or "Ya Fattah" recited 70x)
as their punchline, so an Arabic-substring match only proves two entries
share a common quoted phrase, not that they're the same entry. Concretely,
this false-flagged `E152` (the Sultanabadi dream story) against `I17`'s
tab about a totally different beggar-and-the-Prophet story, `E47` against
an unrelated `I14` tab, and half a dozen others — all because both texts
happened to end with the same well-worn hadith formula. It also missed a
real match (`AA7`) that a looser/different anchor length would have
caught. **Always eyeball the candidate's full old content against the
tab's full content side by side** (first ~200 chars of each is normally
enough to tell) before trusting an automated match — don't skip a UID on
substring-match evidence alone.

## Step 2: split into today's three-line `data` format

Today's format (see any file in `assets/zikr/`) is a single `data` string:
one verse/phrase per **three** `\n`-joined lines — Arabic, transliteration,
translation, repeated. Narrative/attribution text that isn't being recited
goes in a separate `merits` field instead (see `assets/zikr/E2` for the
pattern of narrative-in-merits + recitation-only in data).

Segment the old `content`/`english` prose into phrase-sized chunks. Natural
break points: sentence-ending punctuation in the English, and matching
particle boundaries in the Arabic (وَ .../يَا ... clauses are usually one
phrase each). If the dua quotes a Qur'an surah verbatim (common — e.g. an
embedded Surah al-Ikhlas), grep the existing corpus for that surah's own
`assets/zikr/<uid>` file and reuse its Arabic + transliteration verbatim
instead of re-transcribing — cheaper and guarantees consistency.

## Step 3: sourcing a missing transliteration

If `transliteration` was empty in the old item (the common case):

1. Search for the dua by its distinctive Arabic incipit or by its narrator
   (e.g. "Kaf'ami", "Baladul Ameen") plus "transliteration" or "duas.org".
2. **Don't trust a found page's Arabic without checking it against your own
   historic Arabic first.** Old Islamic sites built from legacy
   font-to-Unicode conversions (Word "Save as Web Page" exports especially)
   routinely drop word-initial hamzas (أ) or mangle Latin macron characters
   into mojibake (`ï¿½`). Pull the raw HTML (`curl`, decode with the page's
   declared charset — check `<meta charset=...>`, often `windows-1252`) and
   extract the actual triplet table cells (`class="a"` / `class="Trans"` /
   plain English cell was the pattern on one duas.org page from 2001-era
   Word export) rather than relying on a summarized fetch, which can silently
   smooth over exactly these defects.
3. Cross-check every suspect word against the historic Arabic you already
   have from Step 1 — it's usually correct where the web source is defective,
   since it predates the encoding-loss problem.
4. If nothing usable turns up, write the transliteration yourself from the
   verified-correct Arabic, matching house style (ALL CAPS, doubled vowels
   for long vowels — `aa`/`ee`/`oo`, apostrophe for hamza/ayn, no macrons).
   Spot-check your style against a same-uid-family file already in
   `assets/zikr/` (e.g. `F2`, `A116`) rather than inventing conventions.
   Flag to whoever reviews it that this line is your own reconstruction, not
   sourced verbatim, so a native-speaker pass is worth it before it ships.

## Step 4: writing the result

`assets/zikr.json` and `assets/zikr/<uid>` are the source of truth now —
edited directly in git, committed like any other file. (This used to run
through Firestore, with a build script regenerating these two files from it
on every release; that indirection is retired — see the top of this repo's
`scripts/` history around the "remove Firestore as the zikr source of truth"
commit if you want the old process.)

Write both files by hand:

- **`assets/zikr.json`** — add `{title, slug}` under the uid. Keys are kept
  in strict lexicographic string order, so find the alphabetical insertion
  point.
- **`assets/zikr/<uid>`** — the full content file: `{title, code, data,
  merits}`. `code` is almost always `"012"`; `merits` is optional.

Then validate (Step 5) and commit.

## Step 5: validate before moving on

```bash
node -e "JSON.parse(require('fs').readFileSync('assets/zikr.json','utf8'))"
node -e "const d=JSON.parse(require('fs').readFileSync('assets/zikr/<UID>','utf8')); console.log(d.data.split('\n').length)"
```
Line count should be a multiple of 3 (plus however many trailing plain-text
lines you appended, e.g. a closing "you may then mention your needs" note).

## Prioritizing: which missing UIDs are actually favorited by users

Not all missing UIDs are equally worth the effort. Cross-referencing against
real favorites needs live Firestore admin access (`scripts/serviceAccountKey.json`),
which a remote/cloud session usually doesn't have — so the list below is a
**committed, static snapshot** generated locally, not something you need to
re-query Firestore for. Regenerate it with:

```bash
node scripts/query_favorited_missing_zikrs.js
```

which also writes the full machine-readable version (all 274 favorited UIDs,
including the 10 already retired via `retiredZikrRedirects` — see Step 1.5)
to [scripts/favorited_missing_zikrs.json](favorited_missing_zikrs.json).

**Progress:** the top 20 rows by distinct users (E92 through AA29, i.e. down
through and including the two 7-user rows) were restored on 2026-09-09 - all
19 as standalone `assets/zikr/<uid>` entries except E53, which turned out to
duplicate the already-live E38 (see `retiredZikrRedirects`) and was retired
there instead per Step 1.5.

A second batch of 20 (E113 through I72, i.e. down through and including the
6-user rows and twelve of the fourteen 5-user rows - all but Z10 and Z15,
picked up below) was restored the same day, all as standalone
`assets/zikr/<uid>` entries - no further duplicates found in this batch.
AA19 was the largest item so far (a ten-part/hundred-phrase tasbih litany
plus several salawat and duas for every day of Ramadan); its captured
record opens mid-list at "Second" with no "First" surviving in history, the
same situation as AA15 and AA34, so the orphaned ordinal labels were dropped
per that precedent.

After that, rather than continuing strictly by rank, a "low hanging fruit"
pass picked off three self-contained, uniform clusters scattered through
the remaining rows (all restored 2026-09-09):
- **Z6, Z9-Z31** (24 UIDs, including the previously-skipped Z10 and Z15):
  the rest of the daily Ramadan duas. These already carried complete
  transliteration/english in history (matching the convention the live
  Z1/Z7/Z8 use, not the house style used elsewhere), so almost no authoring
  was needed.
- **E116, E117, E119-E125** (9 UIDs): the individual Imam-supplication set
  (Hasan through al-'Askari; Ali/Baqir/Mahdi were already covered). E118
  ("Zayn al-'Abidin's") turned out to duplicate F11's "Special Namaz" tab
  word-for-word and was retired there instead (`retiredZikrRedirects`).
- **E66-E75, E78** (11 UIDs): the twelve-hours-of-the-day tawassul duas
  (hours 1-9 and 12; hours 10-11 are missing but unfavorited, so stayed
  out of scope).

That's 44 more UIDs (43 standalone + 1 retired) beyond the first two
batches - the entire 5-user tier is now done.

A fourth pass (also 2026-09-09) restored 15 more short-to-moderate UIDs
from the 4-user tier - AA17, AA30, E65, E88, E105, E109, F8, F45, F48,
F56, I13, I31, I57, I61, I99 - plus one retirement: E148 ("Thanksgiving
Prostration") turned out to duplicate content already live across I19 and
I20 and was retired to I19. I57 linked to the already-restored I58 instead
of repeating Ayah al-Sakhkhara, and AA30's third item linked to AA19's
already-restored "Ya dhal-ladhi kana qabla kulli shay" dua rather than
repeating it - both per Step 1.5.

Across the four passes, 90 UIDs remain unrestored in the 2+-favorite
table (starting at **E114**, still in the 4-user tier - E67 and E117,
also 4-user, were already covered by the hours-of-the-day and per-Imam
clusters), plus the 72-UID single-favorite tail in
favorited_missing_zikrs.json untouched. What's left is more
heterogeneous and, in several cases (E102, E103, E112, E90, G10, G24, G30,
G74, the remaining AA-series Ramadan-night compilations), considerably
longer than anything above - pick up at E114 for the next pass.

A fifth pass (2026-09-14) restored the top five rows of what was left -
**E114, E40, F39, G14, I64** (the 7-user tier) - all as standalone
`assets/zikr/<uid>` entries, no duplicates of live `tabs[]` content found for
any of them (checked per Step 1.5, including the stock ziyarah-greeting
formula in G14 that also appears in the unrelated Day-of-Arafah ziyarat
G75/AC4 - a shared stock phrase, not a shared entry). All five had full old
content in `assets/items/<uid>` history; only G14 needed a `merits` field
(the multi-paragraph hadith preamble on the virtues of visiting Imam Husayn
at the Qadr Nights, ahead of the four ziyarah passages themselves in `data`).
None had a usable historic transliteration, so all of it was authored fresh
in this pass, matching the house style spot-checked against F45/G76/I60/E94
(not F2/A4's older Indo-Pak convention, which predates the house style and is
preserved as-is only where it already existed) - flagged here for a
native-speaker review pass rather than trusted as verbatim-sourced. Also ran
`scripts/zikr_arabic/normalize.py` and `silah.py` (see the `zikr-arabic`
skill) against the five new entries before finishing: normalize.py found no
non-canonical codepoints, and silah.py's first pass caught 18 missing
ṣilah al-hā' marks across four of the five entries (all fixed; a second pass
came back clean, and `zikr_arabic/audit.py`'s per-font check passed for all
five with no INV-2 glyph gaps).

AA18 (the 6-user-tier "Aamal & Duas for the days of Ramadhan") was skipped
this pass - its `assets/items/AA18` history is ~34KB, in the same
considerably-longer-than-usual bracket as the UIDs called out above.

85 UIDs now remain unrestored in the 2+-favorite table (88 rows still
missing from `assets/zikr.json`, of which 3 - E53, E118, E148 - are retired
via `retiredZikrRedirects` rather than needing standalone restoration), plus
the untouched single-favorite tail - pick up at **AA18** (or skip straight to
**E102**, the next short-to-moderate row) for the next pass.

A sixth pass (also 2026-09-14) restored 50 more UIDs in one go - rather than
working strictly by rank, this pass swept the **shortest remaining
`assets/items/<uid>` histories first** (roughly 300 bytes to 4.7KB), skipping
past the still-untouched 4-user tier's longer rows (E102, E103, E112, E90,
G10 among them) and AA18 in favor of tractable ones further down the table:
**F54, E51, I39, I94, E150, I110, F60, I88, E97, I56, E111, AA39, E83, F40,
AA25, F49, I58, I18, F58, X11, A2, I53, F47, I44, F44, I68, E147, AA26, E110,
I66, A3, Y1, E95, I78, AA35, E104, E100, E99, I111, E149, I10, Y10, F34,
I115, I30, F55, I65, AA33, I54, C16** - all restored as standalone
`assets/zikr/<uid>` entries, none of them (this time) needing a `merits`
field. I58 ("Ayah Al Sakharah") was a priority pickup regardless of size:
I57 (restored in the fourth pass) already carries a dangling
`[Ayah al-Sakhkhara](I58)` link waiting for this UID to exist. (A2, A3, I10,
I18, E99 and E40 were part of this original 50 - see the 2026-09-17
correction below for why they didn't make it into the final PR.)

Four originally-picked candidates from this size tier turned out to be
unrestorable or duplicates and were swapped out (per Step 1.5 and the
"dangling promise" pattern the `zikr-arabic` skill documents for imports -
the same defect turns out to also appear in a few of this native-authored
corpus's own historic entries): **Y12** and **Y8** had no dua text at all in
history (an attribution/cross-reference setup with nothing following it -
Y8 just points back at Rajab's already-covered White Nights prayers), **I86**
promised "ten supplicatory prayers" and delivered none, and **I15** turned
out to be a genuine Step-1.5 duplicate - its entire "Twelfth" through
"Sixteenth" content is already live word-for-word inside **I14**
("General Ta'qeebaat-2"), under I14's own inline heading "Virtues of the
'Effective Veneration'" (I15's exact title) - retired to I14 via
`retiredZikrRedirects` instead of restored standalone. They were replaced
with the next four rows by size: I65, AA33, I54, C16.

One further false-positive-shaped case was resolved without dropping the
UID: **F44**'s "Tawakkaltu 'alal hayyil lazee laa yamoot..." litany (taught
by the Prophet to a man complaining of debts) is the same wording **E54**
already carries in full (taught by al-Kaf'ami for poverty and ailment) -
per the false-positive warning in Step 1.5, this didn't disqualify F44 as a
whole (its other two duas are unrelated), so F44 keeps its own entry but
links to E54 for that one shared litany instead of re-transcribing it.

As in the fifth pass, none of the 50 had a usable historic transliteration
(a few - AA33, AA35, C16, F55 - did have full transliteration and/or English
already in history and needed only cross-checking), so the rest was authored
fresh matching each entry's own house style, and is flagged for a
native-speaker review pass. Quran citations (Surah al-Fatihah, al-Tawheed,
Yasin, al-Mulk, al-Qadr, al-Kawthar, al-Kafirun, al-Falaq, al-Nas, Ayat
al-Kursi, and a couple of single-verse citations from al-Fath and al-Nur)
were linked to their existing `A<n>` entries per Step 2 rather than
re-transcribed, and Dua al-Mujeer references were linked to the already-live
**E28**. Ran `zikr_arabic/normalize.py` and `silah.py` against all 50 before
finishing, same as the fifth pass: normalize.py found nothing to change,
and silah.py's first pass caught 38 missing marks across 20 entries (all
fixed, including a mid-fix slip on one line of E83 that briefly marked the
wrong of two `بِهِ` occurrences - caught and corrected by re-running
silah.py after applying the batch); a final pass came back clean, and
`audit.py`'s per-font check (INV-2) passed with no glyph gaps.

**Post-PR review correction (2026-09-17):** two more problems surfaced in
review of the sixth pass's PR before merge. **I10** turned out to be the
same Step-1.5 duplicate case as I15 but missed the first time round: its
title ("General Ta'qeebaat - 1") and content are the same Tasbih al-Zahra'
method-and-merits text as the already-live **I9**'s ("General
Ta'qeebaat-1"), just reworded - retired to I9 via `retiredZikrRedirects`
instead of restored standalone, dropped from the 50-count above. Separately,
**A2** ("Dua after reciting Holy Quran") and **A3** ("Dua Khatme Quran")
were pulled from this pass and deferred - not restored, not retired, still
missing - pending further review; no replacement candidates were picked up
in their place.

A follow-up sweep of the remaining 53 new entries (same day) caught three
more Step-1.5 misses: **I18** ("Merit of reciting Bismillah along with La
Haula Wa La Quwwata") is word-for-word I17's "Seventh:" numbered section,
**E99** ("Dua of Covenant with Almighty Allah") is word-for-word I17's
"Eleventh:"+"Twelfth:" sections, and **E40** ("Dua for delaying death
(Ajal)") is the same hadith and the same core "Subhaanallaahi mil'al
meezaan..." glorification as I17's "Sixth:" section (I17 carries a longer
tail E40 lacks, but it's the same narration under a different numbering
scheme) - all three retired to **I17** via `retiredZikrRedirects` (tab
index 1, 3, and 1 respectively) instead of restored standalone. Two entries
the sweep also flagged were checked and kept as-is: **I53**'s knee-pain dua
overlaps one paragraph of the already-live **E39** but, per the same
precedent already established for F44/E54, its other two components are
unrelated so it keeps its own standalone entry; **AA33** and **AA35** share
an extensive closing petition with each other, but each has its own
distinct night-specific opening invocation and the shared closing reads as
authentic traditional content (the same phenomenon documented for shared
stock formulas elsewhere in this doc), not a restoration artifact - no
action taken.

This pass's final standalone-restored count is therefore **44**, not 50,
and its retired count is **5** (I15, I10, I18, E99, E40), not 1.

A seventh pass (2026-09-19) restored all remaining **36 UIDs** from the 2+-favorite
table, plus revisited and restored the previously deferred **A2** and **A3**:
- **32 standalone entries**: A2, A3, AA18, AA22, AA31, AA32, AA40, AA43, AA47,
  AC6, E3, E90, E102, E103, E112, E146, F6, F7, F13, F14, F15, G10, G30, G74,
  G77, I43, X10, X14, X15, Y2, Y7, Y11.
- **5 retirements / redirects** to `retiredZikrRedirects`:
  - **R10 → G10** (word-for-word duplicate of G10's Ziyarat e Taziyah)
  - **Y8 → X11** (cross-reference to Rajab White Nights prayers)
  - **Y12 → AA20** (intro sentence pointing to the Ramadan 1st night dua)
  - **G24 → G30** (narrative regarding the recitation of Comprehensive Ziyarah G30)
  - **I86 → I83** (introductory hadith narrative without the ten promised duas)

All 32 new entries were formatted to the 3-line triplet standard, verified with
`scripts/zikr_arabic/normalize.py` (0 non-canonical codepoints), `silah.py` (all
pronoun-suffix hā checked clean with 0 missing marks), and `audit.py` (passing
INV-2 with 0 glyph gaps across bundled fonts).

The entire 2+-favorite tier (all rows with 2 to 11 users) is now **100% complete**.

An eighth pass (also 2026-09-19) completed the entire remaining **single-favorite tail**
(all 71 remaining UIDs):
- **64 standalone entries**: AA20, AA23, AA27, AA37, AA38, AA46, AC19, AD2, AD3,
  AG19, AG2, AI12, AK13, AP2, AP4, B3, B4, B6, E127, E129, E76, E77, F12, F17,
  F23, F35, F38, F41, F43, F51, F52, F53, F57, F64, G26, G29, I108, I109, I112,
  I119, I28, I29, I37, I38, I41, I51, I55, I62, I63, I67, I69, I70, I87, I97,
  P13, P15, R15, T2, W1, W2, W3, X13, Y5, Y6.
- **7 retirements / redirects** to `retiredZikrRedirects`:
  - **R11 → G4** (alias to Ziyarat Ashura)
  - **R14 → G30** (Sayyid Ahmad al-Rashti narrative on Comprehensive Ziyarah)
  - **F1 → F2** (merits/preamble to Namaz e Shab)
  - **AA28 → AA29** (points to Common Aamal of Qadr Nights)
  - **P6 → F15** (points to Namaz of Imam Ali)
  - **I96 → A99** (points to Surah al-Zalzalah)
  - **X8 → X7** (points to First Night/Day of Rajab)

All entries were verified with `normalize.py` (0 non-canonical codepoints),
`silah.py` (all pronoun-suffix hā checked clean with 0 missing marks), and
`audit.py` (passing INV-2 and INV-3 across bundled fonts).

Across all passes, **all 274 favorited missing zikrs** from
`scripts/favorited_missing_zikrs.json` are now **100% restored or redirected**!

## Full-corpus duplicate sweep (2026-09-17)

Separately from restoring missing UIDs, an Arabic-text shingle-overlap sweep
was run across all ~576 *already-live* entries in `assets/zikr/` to check
whether the old corpus (not just this restoration project's own additions)
carries duplicates too. It found six more, all retired via
`retiredZikrRedirects` or converted to a `|`-alias the same way `G20|N3`
already worked:

- **AH10 → AH5**, **I12 → I9** (tab 1), **E49 → I14** (tab 1), **E47 → I14**
  (tab 1), **E50 → I24** (tab 2, also covers tab 3 - see the code comment)
  are the same reworded/verbatim-contained pattern as I10/I18/E99/E40
  above, just found in older, previously-live content instead of this
  pass's new restorations. I12 and E47 in particular trace back to an
  earlier restoration pass ("batch 3 of top-20", commit `d72bc84`) that
  missed the duplicate at the time.
- **G20** turned out to be a stale leftover: it was restored standalone in
  an earlier pass ("Restore a third low-hanging-fruit batch...", commit
  `cd2b3c6`) without noticing `G20|N3` already existed as a correct alias
  to the identical `N3` ("Ziyarat on Tuesday") - so the corpus carried both
  the alias and a rougher plain duplicate, double-listing the same ziyarah
  in the general Ziyarat list. The plain `G20` is now retired to `N3`; the
  `G20|N3` alias is untouched.
- **G15 → `G15|K3`**, **S7 → `S7|G3`**, **AC4 → `AC4|G75`**: these three
  were confirmed byte-identical (G15/K3, AC4/G75) or near-identical
  (G3/S7, differing only in a one-line heading) full duplicates,
  deliberately cross-listed under two browsing categories (a general
  Ziyarat/topic list plus a weekday- or calendar-specific collection) - the
  exact shape the `|`-alias convention exists for (see `G16|L3`, `R11|G4`,
  etc.). Converted to aliases instead of retired, since both list entries
  are meant to stay reachable; only the duplicate content file was dropped.

A handful of other high-overlap pairs the sweep surfaced were checked and
left alone as intentional, not bugs: **AC4/G75 and G3/S7's shared text with
G6** (a stock ziyarah-greeting phrase, same false-positive shape already
documented above for G14), **AK5** (an explicit "(All Forms)" compilation
whose tabs[0] is verbatim **G2**'s "Ziyarat-e-Ameenullah" - a named ziyarah
intentionally nested in a larger compiled entry), **D3** (similarly nests
the "Ya Malik al-Riqaab" dua that **I83** is built from), and **E15**
(Dua-e-Hazeen, explicitly labeled "recite this after Namaz-e-Shab" inline
in both **F2** and **F3**). The rest of the sweep's matches were coincidental
shared Quranic verses (17:111, Dua Yunus 21:87-88) or universal stock
formulas (tasbeeh, "laa hawla wa laa quwwata") independently quoted by
otherwise-unrelated entries - the exact false-positive shape this doc's
Step 1.5 section already warns about.

**As of 2026-09-08:** 483 UIDs are missing from `assets/zikr.json`; of those,
274 are favorited by at least one real user, across 890 favorite-entries and
131 distinct users (out of 269 users who have any favorites at all). The
table below is every missing, not-yet-retired UID favorited by **2 or more**
users (202 total), ranked by distinct users affected — the single-favorite
tail (72 more UIDs) is in the JSON file only. Note the run of `Z*` (Muharram
"Nth Day") and `Y*`/`AA*` (Shaban/Ramadhan) series UIDs — these look like
whole calendar-day series that got purged together, so restoring one likely
means restoring several siblings by the same pattern.

| UID | Users | Entries | Title |
|---|---|---|---|
| E92 | 11 | 11 | Dua before leaving the house |
| E93 | 11 | 11 | Dua before reading a book |
| E101 | 10 | 10 | Dua of Imam Husayn (a) on the day of Ashura بِحَقِّ يٰسٓ وَالْقُرْاٰنِ الْحَكِيْمِ |
| E108 | 10 | 10 | Dua to rememeber the things that Satan makes you forget |
| E143 | 10 | 10 | Prayer for fulfillment of desires |
| E55 | 10 | 10 | Dua for repaying the Debts |
| E62 | 10 | 10 | Dua for safety from illness and ailments |
| E10 | 9 | 9 | Dua Asharat |
| E53 | 9 | 9 | Dua for Release from Grief |
| E64 | 9 | 9 | Dua for Sustenance |
| E86 | 9 | 9 | Dua for whoever wants to see his request in the dream |
| I12 | 9 | 9 | Merits of reciting Ayah Kursi (2: 255), Ayah Al Shahadah, Ayah Al Mulk after every Namaz |
| E25 | 8 | 8 | Another Dua Tawassul |
| E43 | 8 | 8 | Dua for getting Male Child |
| E47 | 8 | 8 | Dua for Longevity |
| E87 | 8 | 8 | Dua in the Mornings and Evenings |
| F10 | 8 | 8 | Namaz e Maghferat e Waaledain |
| G76 | 8 | 8 | Ziyarat After Namaz |
| AA15 | 7 | 7 | Aamal & Duas to be recited in every night of Ramadhan |
| AA29 | 7 | 7 | Common Aamal at each of the three Qadr Nights |
| E114 | 7 | 7 | Hirz Zayn al Abidin (a) |
| E40 | 7 | 7 | Dua for delaying death (Ajal) |
| F39 | 7 | 7 | Namaz for more Sustenance |
| G14 | 7 | 7 | Ziyarah of Imam Husayn (a) at the Qadr Nights |
| I64 | 7 | 7 | Repelling The Evils of Jinn & Horrifying Authorities |
| AA18 | 6 | 6 | Aamal & Duas for the days of Ramadhan |
| E113 | 6 | 6 | Everyday Supplications |
| E126 | 6 | 6 | Imam al-Mahdi's Supplication |
| E141 | 6 | 6 | Isteghfar e Maujiz e Aasaa |
| E142 | 6 | 6 | Merits of reciting the Dua اعددت لکل هول |
| E17 | 6 | 6 | Dua during the Occultation of Imam Mahdi (a) - LONG اَللّٰهُمَّ عَرِّفْنِيْ نَفْسَكَ |
| E57 | 6 | 6 | Dua for repayment of debts 1 |
| E59 | 6 | 6 | Dua for Restoration of Health |
| Y9 | 6 | 6 | Fifteenth Night of Shaban |
| AA19 | 5 | 5 | Tasbeehat & Salawat for every day in Ramadhan |
| AA34 | 5 | 5 | 23rd Night of Ramadhan |
| E115 | 5 | 5 | Imam Baqir's (a) dua |
| E128 | 5 | 5 | Salawat upon the Holy Prophet |
| E140 | 5 | 5 | Salawat upon The Awaited Imam |
| E23 | 5 | 5 | Dua e Hifz e Imaan (another) |
| E94 | 5 | 5 | Dua between Sunset and Bedtime |
| F4 | 5 | 5 | Namaz e Aayaat |
| F46 | 5 | 5 | Namaz for Gaining Intelligence and Good Memory |
| I52 | 5 | 5 | Taweez against Private Parts Pains |
| I60 | 5 | 5 | Taweez against Evil Eyes |
| I72 | 5 | 5 | Lightening fast Prayer (for worldly desires) |
| Z10 | 5 | 5 | 9th Day |
| Z15 | 5 | 5 | 14th Day |
| AA17 | 4 | 4 | Tasbeehat at the time of Sehar |
| AA30 | 4 | 4 | 19th Night of Ramadhan |
| E102 | 4 | 4 | Dua of Mother for her child who is ailing. |
| E103 | 4 | 4 | Dua of Prostration of thanksgiving |
| E105 | 4 | 4 | Dua of the Noon (Zuhr) |
| E109 | 4 | 4 | Dua when intending to leave the Mosque |
| E112 | 4 | 4 | Duas at Daybreak and Sunset |
| E117 | 4 | 4 | Imam al-Husayn's supplication |
| E146 | 4 | 4 | Supplications at Sunrise & Sunset |
| E148 | 4 | 4 | Thanksgiving Prostration - Sajdah al Shukr |
| E65 | 4 | 4 | Dua for the Deceased |
| E67 | 4 | 4 | Dua for the First Hour |
| E88 | 4 | 4 | Dua Maknoon and its merits |
| E90 | 4 | 4 | Dua Before and After Ritual Prayers |
| F45 | 4 | 4 | Namaz for Forgiveness |
| F48 | 4 | 4 | Namaz for Seeking Allah's help In the name of Lady Fatimah (S) |
| F56 | 4 | 4 | Namaz for the removal of difficulties. |
| F8 | 4 | 4 | Namaz e Nawafil |
| G10 | 4 | 4 | Ziyarat e Taziyah Condolence to Holy Prophet (s) and His Immaculate progeny |
| G20 | 4 | 4 | Tuesday - Ziyarah of Imam Zayn al Abidin, Imam Muhammad al Baqir & Imam Jafar al Sadiq (a) |
| I13 | 4 | 4 | Merits of reciting Ayah Kursi after every Namaz |
| I31 | 4 | 4 | Recitations for Fending Off Evil Self Inspirations |
| I57 | 4 | 4 | Taweez for Fending Off Devils and Sorcerers |
| I58 | 4 | 4 | Ayah Al Sakharah |
| I61 | 4 | 4 | Taweez against Satan's Evil Insinuations |
| I99 | 4 | 4 | Three devotional acts before going to sleep |
| Z11 | 4 | 4 | 10th Day |
| Z21 | 4 | 4 | 20th Day |
| Z22 | 4 | 4 | 21st Day |
| Z24 | 4 | 4 | 23rd Day |
| Z6 | 4 | 4 | 5th Day |
| A3 | 3 | 3 | Dua Khatme Quran |
| AA32 | 3 | 3 | Aamal of the last ten Nights of Ramadhan |
| AA47 | 3 | 3 | Farewell Prayer of Ramadhan |
| E100 | 3 | 3 | Dua of Exaltation |
| E104 | 3 | 3 | Dua of Takbir |
| E111 | 3 | 3 | Dua when you see a Diseased or Defected Person |
| E116 | 3 | 3 | Imam al-Hasan's supplication |
| E118 | 3 | 3 | Imam Zayn al-'Abidin's supplication |
| E120 | 3 | 3 | Imam al-Sadiq's supplication |
| E121 | 3 | 3 | Imam al-Kazim's supplication |
| E122 | 3 | 3 | Imam al-Reza's supplication |
| E123 | 3 | 3 | Imam al-Jawad's supplication |
| E124 | 3 | 3 | Imam al-Hadi's supplication |
| E125 | 3 | 3 | Imam al-'Askari's supplication |
| E147 | 3 | 3 | Supplicatory Prayers for Healing |
| E69 | 3 | 3 | Dua for the Third Hour |
| E95 | 3 | 3 | Dua Muqatil ibn Sulayman |
| F14 | 3 | 3 | Namaz of Lady Fatimah Zehra (s.a.) |
| F54 | 3 | 3 | Namaz for Solving Difficulties |
| F7 | 3 | 3 | Namaz e Mayyat |
| I10 | 3 | 3 | General Ta'qeebaat - 1 |
| I15 | 3 | 3 | Virtues of the "Effective Veneration" |
| I30 | 3 | 3 | Dedication To The Dead |
| I39 | 3 | 3 | Taweez against Migraine |
| I53 | 3 | 3 | Taweez against Knee Pains |
| I56 | 3 | 3 | Taweez for Neutralizing Sorcery |
| I65 | 3 | 3 | Emphasis on sending Gifts to the Dead |
| I68 | 3 | 3 | Evil-Repelling Prayers and Supplicatory Amulets |
| X15 | 3 | 3 | (h) Aamal of Laylat al Mab'as (27th Night) |
| Y1 | 3 | 3 | Importance of the Month of Shaban |
| Y2 | 3 | 3 | General Aamal in Shaban |
| Z12 | 3 | 3 | 11th Day |
| Z13 | 3 | 3 | 12th Day |
| Z14 | 3 | 3 | 13th Day |
| Z16 | 3 | 3 | 15th Day |
| Z17 | 3 | 3 | 16th Day |
| Z18 | 3 | 3 | 17th Day |
| Z19 | 3 | 3 | 18th Day |
| Z20 | 3 | 3 | 19th Day |
| Z23 | 3 | 3 | 22nd Day |
| Z25 | 3 | 3 | 24th Day |
| Z26 | 3 | 3 | 25th Day |
| Z27 | 3 | 3 | 26th Day |
| Z28 | 3 | 3 | 27th Day |
| Z29 | 3 | 3 | 28th Day |
| Z30 | 3 | 3 | 29th Day |
| Z31 | 3 | 3 | 30th Day |
| Z9 | 3 | 3 | 8th Day |
| A2 | 2 | 2 | Dua after reciting Holy Quran |
| AA22 | 2 | 2 | Other Aamal of The First Night |
| AA25 | 2 | 2 | The 13th Night of Ramadhan |
| AA26 | 2 | 2 | The 15th Night of Ramadhan |
| AA31 | 2 | 2 | Aamal of the 21st Night of Ramadhan |
| AA33 | 2 | 2 | Dua on the 22nd Night of Ramadhan |
| AA35 | 2 | 2 | Dua for the 23rd Night of Ramadhan |
| AA39 | 2 | 2 | 27th Night of Ramadan |
| AA40 | 2 | 2 | Dua for the 27th Night of Ramadhan |
| AA43 | 2 | 2 | Last Night of Ramadhan |
| AC6 | 2 | 2 | Salat of وَ وَاعَدْنَا |
| C16 | 2 | 2 | Aamal of the day of Navroz |
| E110 | 2 | 2 | Dua when someone Sees the Dead |
| E119 | 2 | 2 | Imam al-Baqir's supplication |
| E149 | 2 | 2 | The Holy Infallibles And The Days Of The Week |
| E150 | 2 | 2 | The Holy Prophet's (s) dua |
| E3 | 2 | 2 | Dua Aaliyah al Mazameen Dua to be recited after the Ziyarah of every Masoomeen (a) |
| E51 | 2 | 2 | Dua for protection of valubales and precious things (that are concealed) |
| E66 | 2 | 2 | Duas for each hour of the Day |
| E68 | 2 | 2 | Dua for the Second Hour |
| E70 | 2 | 2 | Dua for the Fourth Hour |
| E71 | 2 | 2 | Dua for the Fifth Hour |
| E72 | 2 | 2 | Dua for the Sixth Hour |
| E73 | 2 | 2 | Dua for the Seventh Hour |
| E74 | 2 | 2 | Dua for the Eighth Hour |
| E75 | 2 | 2 | Dua for the Nineth Hour |
| E78 | 2 | 2 | Dua for the Twelfth Hour |
| E83 | 2 | 2 | Another Dua for Ailing Diseases |
| E97 | 2 | 2 | Dua of Ailing Diseases |
| E99 | 2 | 2 | Dua of Covenant with Almighty Allah (s.w.t) |
| F13 | 2 | 2 | Namaz of Holy Prophet(s) |
| F15 | 2 | 2 | Namaz of Imam Ali (a.s.) |
| F34 | 2 | 2 | Namaz for fulfillment of needs (1) |
| F40 | 2 | 2 | Another Namaz for more Sustenance |
| F44 | 2 | 2 | Namaz for Fending Off Evil Self Inspirations |
| F47 | 2 | 2 | Namaz for Seeking (divine) help. |
| F49 | 2 | 2 | Namaz For Seeking Allah's help in The Name of The Prophet (s) and Imam Ali (a) |
| F55 | 2 | 2 | Namaz for Travel |
| F58 | 2 | 2 | Namaz of Imam Muhammad Taqi (a) to ward of evil |
| F6 | 2 | 2 | Namaz e Kamilah |
| F60 | 2 | 2 | Namaz of Pardon |
| G24 | 2 | 2 | Story of Sayyid Al Rashti |
| G30 | 2 | 2 | The comprehensive Ziyarat of the Imams (a) |
| G74 | 2 | 2 | Ziyarat e Imam Husain (a)  |
| G77 | 2 | 2 | Ziyarat of Imam Al Hujjah (a.t.f.s.)  |
| I110 | 2 | 2 | Importance of Writing Bismillah on the House Door |
| I111 | 2 | 2 | Importance of reciting of Qulho wallaho Ahad |
| I115 | 2 | 2 | Writing of Will before death |
| I18 | 2 | 2 | Merit of reciting Bismillah along with La Haula Wa La Quwwata |
| I43 | 2 | 2 | Taweez for Chest Pains |
| I44 | 2 | 2 | Taweez for Curing of Coughing & against Stomach Pains |
| I54 | 2 | 2 | Taweez against Eye aches |
| I66 | 2 | 2 | Acquiring lesson from the Dead |
| I78 | 2 | 2 | Pocket Taweez |
| I86 | 2 | 2 | Ten duas for fufillment of petitions (requests) |
| I88 | 2 | 2 | Special Features of Surah Qadr, Tawheed & Ayah Al Kursi |
| I94 | 2 | 2 | Verses to restore the lost things |
| X10 | 2 | 2 | (d) Fifteenth of Rajab (Namaz e Salman) |
| X11 | 2 | 2 | (e) Thirteenth of Rajab |
| X14 | 2 | 2 | (g) Aamal & Dua of Umme Dawood |
| Y10 | 2 | 2 | Fifteenth day of Shaban |
| Y11 | 2 | 2 | Ziyarah on the 15th of Shaban |
| Y12 | 2 | 2 | Last Night of Shaban |
| Y7 | 2 | 2 | Third of Shaban |
| Y8 | 2 | 2 | Thirteenth Night Of Shaban |

The single-favorite tail (72 more UIDs, plus the 10 already-retired ones with
their own redirect target) is in
[scripts/favorited_missing_zikrs.json](favorited_missing_zikrs.json) if you
work through this table and want more.
