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

Two places, and they are NOT the same source of truth:

- **Firestore `zikr/{uid}`** — the actual source of truth. Fields: `title`,
  `code` (almost always `"012"`), `data`, `merits` (optional), `slug`
  (optional, kebab-case of the title).
- **`assets/zikr.json`** (adds `{title, slug}` under the uid — keys are kept
  in strict lexicographic string order, so find the alphabetical insertion
  point) and **`assets/zikr/<uid>`** (the full `{title, code, data, merits}`
  content file) — these are a **generated build artifact**.
  `scripts/build_zikr_release.js` regenerates both from Firestore. If you
  only edit the local files and someone runs that script before Firestore
  is updated, your restoration is silently wiped.

So: write Firestore first, then either run
`node scripts/build_zikr_release.js` or hand-edit the two local files to
match (matching by hand is fine for a one-off if Firestore write access
isn't available in the moment, but treat it as provisional until Firestore
actually has the doc).

Use `scripts/restore_zikr_to_firestore.js <uid> <draft.json> [--regenerate]`
for the Firestore write — point it at a draft JSON shaped
`{title, code, data, merits, slug}`. Draft JSONs for UIDs already restored
this way live in `scripts/zikr_restore_drafts/`.

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
