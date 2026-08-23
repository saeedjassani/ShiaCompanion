---
name: zikr-arabic
description: Proofread and correct the Arabic text of the zikr corpus, batch by batch — normalizing orthography so it renders identically in Qalam, Uthmani and MeQuran, and applying the ṣilah al-hā' (ulta pesh / khaṛi zer) rule. Use when asked to fix, proof, normalize, or audit zikr Arabic, when a character renders wrong in one font, or when continuing the batch-by-batch pass.
---

# Zikr Arabic

Corrects the Arabic in the `zikr` corpus so that every zikr uses one consistent
orthography and renders from the selected font alone — no fallback glyphs, no
stray marks, no codepoint that only one of the three bundled fonts can draw.

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
`font_runtime` in rules.json. Qalam is the authoring font and gets nothing.
Uthmani gets the Indo-Pak letterforms mapped for style. MeQuran additionally
needs `ؕ` dropped and `ٮ→ى`, because its font file has no glyph for either.

**`ٗ` (ulta pesh) and `ٖ` (khaṛi zer): keep in the source, flatten at render.**
They are correct, distinct marks — the content's author confirmed this, and
source normalization must never strip them. But **Uthmani draws `ٗ` as a slanted
stroke indistinguishable from a fatha**, so `عِلْمَهٗ` reads as `عِلْمَهَ`, and
MeQuran collides the mark with the letter. The runtime map therefore converts
`ٗ→ُ` and `ٖ→ِ` for both non-Qalam fonts.

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

**Private Use Area characters (1,385, in ~120 zikr).** Nine codepoints in
U+E003–U+E022. Qalam defines glyphs for all nine; Uthmani and MeQuran define
none. They are almost certainly waqf/sajdah symbols carried over from whatever
Indo-Pak source the text was copied from. Until each is identified and mapped to
its standard Unicode equivalent (U+06D6–U+06ED, which every font carries), these
are Qalam-only content that silently disappears in the other fonts. `audit.py`
reports them as INV-3. Identifying them means rendering Qalam's glyphs and
looking at them.

**Combining-mark order is inconsistent.** Shadda-before-vowel (`U+0651 U+064E`)
appears 29,356 times; vowel-before-shadda 299 times, and `U+0650 U+0651` 2,738
times. Normalize toward the dominant shadda-first order — roughly 3,000 words.
**Do not use `unicodedata.normalize('NFC')` for this.** Unicode's canonical
combining classes put shadda *after* the vowel, so NFC rewrites 40,521 words
into the minority order. Verified, not assumed.

**Stacked marks Uthmani cannot shape.** `U+0670 U+0653` (superscript alef +
maddah, as in `اُولٰٓئِكَ`, `عَلٰٓى`) — 604 occurrences — renders with a dotted
circle in Uthmani. This is a shaping failure, not a missing glyph, so INV-2 does
not catch it; detecting it needs HarfBuzz (`uharfbuzz`, not currently installed)
or rasterising and looking for U+25CC.

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
  following word with no space? Recommended yes (standard orthography, Uthmani
  mushaf convention, and by far the largest source of diff noise), but it must
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
