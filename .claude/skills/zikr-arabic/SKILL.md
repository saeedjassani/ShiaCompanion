---
name: zikr-arabic
description: Proofread and correct the Arabic text of the zikr corpus, batch by batch — normalizing orthography so it renders identically in Qalam and Scheherazade New, and applying the ṣilah al-hā' (ulta pesh / khaṛi zer) rule. Use when asked to fix, proof, normalize, or audit zikr Arabic, when a character renders wrong in one font, or when continuing the batch-by-batch pass.
---

# Zikr Arabic

Corrects the Arabic in the `zikr` corpus so that every zikr uses one consistent
orthography and renders from the selected font alone — no fallback glyphs, no
stray marks, no codepoint that only one of the two bundled fonts can draw.

Everything here is deterministic and lives in `scripts/zikr_arabic/`. Run the
scripts; do not re-derive the rules by reading the corpus.

## Where the text actually lives

Firestore `zikr` collection is the source of truth. `scripts/build_zikr_release.js`
reads it, runs `scripts/zikr_text_normalization.js`, and writes `assets/zikr/*`,
which is what ships. Non-admin users only ever read the bundled assets
(`lib/pages/zikr/zikr_page.dart` `_fetchZikrData()`).

So: **a fix must land in Firestore, then the assets get rebuilt, then it ships in
a release.** Editing `assets/zikr/*` by hand is pointless — the next build wipes it.

`scripts/zikr/*`, `scripts/all_zikr.json`, `scripts/zikr.json`, `scripts/zikr.csv`
are stale legacy scrape dumps. Ignore them.

## Three lineages, three different jobs

| Lineage | Count | What it is |
|---|---|---|
| Authored | ~168 | Written by the app's other admin. Indo-Pak notation, `ي`/`ه`/`ك` dominant, ulta pesh and khaṛi zer used deliberately. This is the house style. |
| Quran surahs | 115 | Every `A<n>` uid. Mushaf text, full of `ؕ` waqf marks and `ٮ`. **Excluded from every editing pass** — `corpus.load_corpus()` skips them unless asked by name. Still audited, since they ship and still have to render. Detect by uid, not by title: `A4` is Ayat al-Kursi and has no `2:` prefix. |
| Imported du'a | 47 | duas.org imports — **confirmed by the repo owner**, not inferred. Standard-Arabic notation: `ٱ`, `أ`, `إ`, no ṣilah marks. These are what the normalization pass is mostly for. |

Nothing in Firestore records provenance — none of the 936 documents carries a
source field, and `scripts/import_dua_from_url.js` does not write one. The
lineage above is recoverable only from notation: measure `ٱ أ إ ﭐ` against
`ی ہ ھ ۃ ک ٮ ؕ`, normalised per 1,000 Arabic characters. The authored files
have zero `ٱ` and 20 `أ` across 833k characters; the imports have thousands.

There is **no single house letterform** to restyle toward: within the authored
files, 73 use only `ي` and 27 only `ی`. Do not "unify" `ي`/`ی`, `ه`/`ہ`,
`ك`/`ک`, `ة`/`ۃ` — the runtime font map already handles them, and the imports
already match the dominant form.

## The rules

All of them live in `scripts/zikr_arabic/rules.json`. Two layers:

**Source normalization** — applied once, permanently, in Firestore. Brings the
stored text into the canonical inventory: `ٱ→ا`, `أَ→اَ` (and `أُ أِ أْ أً`,
`إِ`…), presentation forms (`ﭐ ﺎ ﷲ ﴿﴾`) to their plain equivalents, Extended
Arabic-Indic digits to Arabic ones, and outright junk deleted — stray `ؔ`
takhallus marks attached to no letter, one `ؚ` no font can draw.

**Runtime font map** — `ZikrContentParser.formatArabicText`, mirroring
`font_runtime` in rules.json. There is no longer a per-font letterform table.
MeQuran and Uthmani were retired in favour of **Scheherazade New**, which draws
every Indo-Pak letterform (`ڪ ٮ ی ک ہ ھ ؕ`) natively, so the corpus renders as
authored in both shipped fonts. What remains applies to every font: typographic
spaces collapsed, and Al Qalam's private `U+E003`/`U+E004` rewritten to the real
`U+0656`/`U+0657` (Qalam maps both pairs to the same glyphs). Scheherazade
additionally gets a trailing `(N)` turned into a `U+06DD` ayah medallion, which
it composes with the digits inside; Qalam draws its own medallion from the
parentheses and must keep them.

**`ٗ` (ulta pesh) and `ٖ` (khaṛi zer): keep them, and render them.**
They are correct, distinct marks — the content's author confirmed this, and
source normalization must never strip them. They used to be flattened to a plain
damma and kasra at render time, because **Uthmani drew `ٗ` as a slanted stroke
indistinguishable from a fatha**, turning `عِلْمَهٗ` into `عِلْمَهَ`, and MeQuran
collided the mark with the letter. Both fonts are gone. Qalam and Scheherazade
each draw both marks correctly, so nothing is flattened any more.

**A codepoint being in a font's cmap does not mean the font draws it.** This was
assumed once and was wrong — INV-2 only proves a glyph exists. Anything about
how a mark *looks* must be checked by rendering it and looking at the image:
build a small HTML page with the fonts embedded, screenshot it headless, read it.

`assets/items/*` is a good cross-check for *structural* problems (word splits,
dropped letters) and a bad one for *diacritic style* — those transcripts are
simply less precise.

### ṣilah al-hā'

The pronoun suffix `ه` ("his/its") takes `هٗ`/`هٖ` when the letter before it
carries a short vowel. Blocked by: sukūn before (`مِنْهُ`), a long vowel before
(`اِيَّاهُ`), or hamzat al-waṣl after (`لَهُ الْمُلْكُ`, `نَفْسَهُ ابْتِغَآءَ`).

The waṣl test is **orthographic, not grammatical**: the next word opens with a
bare `ا` carrying no diacritic. It works because the corpus writes the zabar on
the alif exactly when it is pronounced, so `اَللّٰهُمَّ` and `اِلَيْكَ` read as qaṭʿ
and keep the ṣilah. The next word may sit on the following line — check across
the line break. Corpus compliance with this rule is 579 vs 12.

`silah.py` also reports hā whose *own vowel* is wrong rather than just its mark
(kasra after a fatha/damma is impossible in Arabic). Those are real content
errors and need a human.

**Alias documents are pointers — skip them.** A uid containing `|` is
`alias|target`. `UidTitleData.getFirstUId()` returns `uid.split("|").last`, so
the app always reads the target, and `build_zikr_release.js` emits no asset for
an alias. Eight alias docs still carry a vestigial `data` field in Firestore;
nothing reads it, so do not spend a batch on them.

**Internal cross-references use `[label](uid)`, resolved at runtime.**
`ZikrPage._handleZikrLinkTap` / `_lookupInternalItemUid` treat a markdown-style
link in `data`/`merits` as in-app navigation when its target is a known uid or
slug, falling back to an external URL otherwise. Plain-text mentions of
another zikr by name — "recite Surah al-Tawheed", "the third comprehensive
Ziyarah (Ziyaarah al-Jaame'ah)", a bare list of other things to visit at a
shrine — are candidates for this treatment, and most of the corpus has never
had this pass run over it: it was applied only to Quran surah names, a
handful of well-known named duas/ziyarat, and the one shrine-complex list
found in `AG14`, all as one-off content sessions (not a `scripts/zikr_arabic/`
script). **Never invent a target.** Only link a mention when the exact
personality/surah/dua it names has its own uid in the corpus and the mention
isn't the entry's own self-description (a repeated header, or a comment
naming what the reader is already looking at) — an ambiguous name with more
than one plausible target (e.g. more than one "Dua Faraj", more than one
"Ziyarat Warith") needs the content author's call on which uid wins by
default, the way `E19` and `G6` were confirmed as defaults here. This is the
same judgement call as the truncation fix above: link what's real and
findable, remove what isn't.

### Vowel on a word-initial alif

Two hamzas, different behaviour, and the corpus conflates them
(`scripts/zikr_arabic/vowelgap.py`).

**Hamzat al-qaṭʿ** — `أَشْهَدُ`, `أَكْبَر`, `أَبَا`, `أَيُّهَا`, form-IV verbs
(`أَصْلِحْ`, `أَظْهِرْ`). Always pronounced, so it always carries its vowel,
at any position. Measured: 86% vowelled line-initial, 84% mid-line — position
makes no difference, as it shouldn't.

**Hamzat al-waṣl** — the article, form-**I** imperatives (`اِغْفِرْ`,
`اُدْخُلْ`), forms VII/VIII/X, and `ابن`/`اسم`/`امرأة`. Pronounced **only when
it opens the utterance**. Mid-phrase it elides: `اَللّٰهُمَّ اغْفِرْ` is read
*allāhumma-ghfir*, so the alif stays bare and writing a kasra on it is wrong.
Measured: 70% vowelled line-initial but 599/619 mid-line — a coin flip, i.e.
no settled practice, which is why this is worth fixing rather than copying.

**What is not mechanically decidable.** A form-I imperative (`اِغْفِرْ`, waṣl,
kasra) and a form-IV imperative (`أَصْلِحْ`, qaṭʿ, fatha) have the same
skeleton — alif + three root letters with sukun on the first. Nothing in an
unvowelled spelling separates them; it needs the verb's form. The one reliable
asymmetry: **a fatha proves qaṭʿ**, because waṣl never takes fatha. A damma
proves nothing (`أُحْصِي` is qaṭʿ). So filter on fatha, then hand the residue
to a human.

**Do not strip the corpus and re-diacritise it.** Case endings depend on
syntax; the best Arabic diacritisers reach ~90-95% on modern standard Arabic
and worse on classical du'a vocabulary. Over ~400k letters that is thousands of
silent errors in text people recite, replacing a hand-authored corpus that is
already ~94% complete. Fill the enumerated gaps instead — there are only a few
hundred distinct words, which fits on a review sheet.

## Known gaps, not yet resolved

**Private Use Area characters (~1,360, in ~120 zikr).** Nine codepoints in
U+E003–U+E022, of which two are resolved: `U+E003`/`U+E004` are the ṣilah al-hā'
marks and are rewritten at render time to `U+0656`/`U+0657`.

The other seven were rendered from Qalam and identified by eye: `U+E01B` ص,
`U+E01C` ق, `U+E01D` صل, `U+E01E` قف, `U+E01F` وقفة, `U+E020` ك, `U+E022` the
rukūʿ ع — plus `U+E01A`, which has **not** been identified with confidence.
These are Indo-Pak pause signs, and unlike `U+06D6`–`U+06DC` they have **no
Unicode codepoint at all**, so there is nothing to map them to. The reader
therefore sets `fontFamilyFallback: ['Qalam']` on the Arabic style, which draws
the correct sign for each. Substituting a plain letter per mark was considered
and rejected: `U+E01A` alone is 244 occurrences, and printing the wrong pause
sign is a worse failure than a face change on an isolated glyph.

`audit.py` still reports them as INV-3, deliberately — they remain font-private
content, and dropping Qalam would break them. Do not "fix" INV-3 by stripping
the marks.

**Combining-mark order is inconsistent.** Shadda-before-vowel (`U+0651 U+064E`)
appears 29,356 times; vowel-before-shadda 299 times, and `U+0650 U+0651` 2,738
times. Normalize toward the dominant shadda-first order — roughly 3,000 words.
**Do not use `unicodedata.normalize('NFC')` for this.** Unicode's canonical
combining classes put shadda *after* the vowel, so NFC rewrites 40,521 words
into the minority order. Verified, not assumed.

**Stacked marks.** `U+0670 U+0653` (superscript alef + maddah, as in
`اُولٰٓئِكَ`, `عَلٰٓى`) — 604 occurrences — used to render with a dotted circle in
Uthmani, which is now retired. Re-check it in Scheherazade before assuming it is
gone: this is a shaping failure, not a missing glyph, so INV-2 does not catch
it. Detecting it needs HarfBuzz or rasterising and looking for U+25CC.

**Import truncation and scrape artifacts (English side, imports only).** The
47 duas.org imports carry a second kind of defect that has nothing to do with
Arabic orthography: the scrape sometimes cut a page short or dragged in text
that was never part of the dua. Two shapes, both English/structural rather
than diacritic, so `normalize.py`/`silah.py` never see them:

- **Dangling promise.** The prose says "...you may say the following words:",
  "...composed the following poetic verses:", "Another Salwaat Imam
  Mahdi(ajtfs) Friday" — and then either nothing follows, or what follows is
  unrelated junk (`AG18` had "the following verses:" run straight into
  "Mesuseum in the shrine"). Grep every import for `the following[^.:\n]*:`
  and check what comes right after: if it's Arabic/transliteration/an actual
  quoted line, it's fine (this is the overwhelmingly common case — most
  "following:" mentions in the 47 are genuinely fulfilled); if it's empty, a
  short unrelated fragment, or another unfulfilled "following:", the promise
  and everything after it back to the last complete sentence is dead weight.
- **Stray site chrome.** Fragments of the source website leaking into the
  content: a view-toggle label (`ARABIC ONLY`, mid-paragraph in `AL11`), nav
  text and a stranger's personal dedication note glued to the end of the
  ziyarah (`AN1`: "Previous Translation / Special visit / --> Al-Fatiha
  <names>... Arabic only"), a dead footnote reference to the print source
  that lost its target (`AI16`: "...following statement: \"...\" See dua4").
  These read as obviously not-dua the moment you see them — no ambiguity, no
  judgement call about content.

**The fix is the same shape as internal cross-references (see below): if
the dangling text names a real, findable person/ziyarah/dua, that's not
actually a truncation — check the corpus for a matching uid and link it
(`[label](uid)`) instead of deleting it.** Genuinely dead text — a promise
with nothing behind it, or site chrome — gets deleted back to the last
complete sentence, not just blanked to whitespace. `AG14`'s "Other Ziarat
inside shrine complex" list was exactly this ambiguity resolved the right
way: three of its four bare names had nothing to link to and one (Habib ibn
Mazahir) matched `G58` and got linked instead of removed.

Fixed so far by this method: `AG18` (two unfulfilled verse-promises),
`AH10` (a "2 Common Ziarats" section that was 100% unfulfilled setup, zero
payoff), `AI16` ("See dua4"), `AL11` ("ARABIC ONLY"), `AL15` ("Another
Salwaat Imam Mahdi(ajtfs) Friday"), `AN1` (the trailing site-chrome block).
**Not a completed audit** — these were found by sweeping the
Karbala/Kazimayn/Kufa/Najaf/Samarra/Balad shrine-guide batch
(`AG`/`AH`/`AI`/`AJ`/`AK`/`AL`/`AN` prefixes) plus a handful of other
high-confidence imports, using the `ٱ أ إ ﭐ` notation measure above to find
them (41 files scored clean-import at >5 marks per 1,000 Arabic characters,
plus `AK5`/`AN1`/`AL17` which mix in a little authored-style noise). That
list is short of the confirmed 47 by a few — the exact roster still needs
pinning down — and the remaining imports (the `E`/`H`/`AA` one-offs: `E155`,
`AA9`, `AA11`, `AA13`, `G78`, `H20`-`H27`) have not been swept for this
issue at all. Do that before assuming the imports are clean.

## Working a batch

Batches run **sequentially through the corpus in natural uid order** (AA1…,
AC1…, … E1…), not worst-first, so each batch is a contiguous stretch a reviewer
can read end to end.

```
python3 scripts/zikr_arabic/audit.py            # invariants; exit 1 = violations
python3 scripts/zikr_arabic/batch.py status     # how much is left
python3 scripts/zikr_arabic/batch.py next 10    # next 10 in uid order
python3 scripts/zikr_arabic/batch.py plan <uid…>  # report + write .patch.json
node    scripts/zikr_arabic/backup.js           # REQUIRED before any write
node    scripts/zikr_arabic/apply_patch.js scripts/zikr_arabic/.patch.json --dry-run
node    scripts/zikr_arabic/apply_patch.js scripts/zikr_arabic/.patch.json
node    scripts/build_zikr_release.js           # regenerate assets/zikr/*
flutter test test/zikr_content_parser_test.dart
python3 scripts/zikr_arabic/batch.py done <uid…>
```

`normalize.py` and `silah.py` can be run standalone on named zikr for a closer
look; both take `--out`/`--json` to dump a patch.

## Guardrails

- **Firestore has no revision history for this collection.** `apply_patch.js`
  refuses to write without a snapshot in `.zikr-backups/`. Never bypass that.
- Every patch entry carries the exact `before` text. `apply_patch.js` re-reads
  the document and skips anything that has drifted rather than overwriting it.
- These transforms are 1:1 or shrink-only. Character count is a cheap assertion.
- `audit.py` must exit 0 before shipping. INV-1 = nothing non-canonical stored;
  INV-2 = nothing rendered from a font that lacks the glyph.
- Run `flutter test test/zikr_content_parser_test.dart` after any change to the
  runtime map or the corpus.

## What needs a human

Auto-applicable: source normalization, the ṣilah mark, junk removal. These do
not change how a word is read.

Needs the content author's sign-off:

- **Bare `أ`/`إ` with no vowel mark** (~95) and `ٴ` high hamza (13). The correct
  Indo-Pak vowel cannot be inferred; `normalize.py` lists them under
  "needs a human decision" and leaves them out of the patch.
- **Any hā flagged by `impossible_vowel`** — the reading itself is wrong.
- **Restyling a whole document.** The 47 imports are a restyle, not bug-fixing.
  Keep that decision separate and explicit.
- **Open question, unanswered twice:** should `وَ` always be glued to the
  following word with no space? Recommended yes (standard orthography, mushaf
  convention, and by far the largest source of diff noise), but it must
  run *after* word-split fixes so that a standalone `وَ` is unambiguously the
  conjunction.

Review happens as a published Artifact or a PDF, never raw diffs — the reviewer
is non-technical. Headless Chrome renders this corpus's Arabic correctly:
`chrome --headless --disable-gpu --no-pdf-header-footer --print-to-pdf=out.pdf
--virtual-time-budget=20000 page.html`, with Qalam embedded as a base64
`@font-face`. Always rasterise a page with `pdftoppm` and look at it before
sending. In `@media print`, re-declare the light palette (token colours
otherwise print dark-on-dark) and give any hairline-gap grid real borders
(`background:none;gap:0`) or it paints a grey slab across page breaks.

Attachments cannot be sent from here — the Gmail and Drive tools take file
content as inline base64 only, which is not viable for a real PDF. Generate the
file, then hand it to the user to attach.
