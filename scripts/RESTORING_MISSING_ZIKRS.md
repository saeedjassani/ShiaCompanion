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

```js
// Union every historical assets/zikr.json version's keys (git log --follow),
// subtract the current file's keys.
```
501 UIDs as of 2026-09-05. Don't confuse this with `scripts/missing_zikrs.json`
(545 entries) — that file is `populate_missing_zikrs.js`'s diff of the old
`legacy_items_index.json` against current `zikr.json`, a different project
(finding content to backfill from duas.org from scratch).

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
`assets/zikr/<uid>` entry** — the app will eventually get backward-compat
routing so the UID opens the right tab of its owner. Check for this before
doing any restoration work on a UID.

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

## Prioritizing which of the 501 to do first

Not all 501 are equally worth the effort — cross-reference against real
favorites before picking (see `favorites-firestore-path` memory note for the
collection-group-query technique). As of 2026-09-05, 292 of the 501 are
favorited by at least one real user across 1,150 favorite-entries and 146
distinct users; the top offenders by users-affected are worth doing first.
