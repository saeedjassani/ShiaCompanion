---
name: zikr-structure
description: Restructure zikr entries (assets/zikr/<uid>) so each one stands on its own - Mafatih numbering and "as mentioned above" pointers removed, narrations and rewards moved to merits, short instruction lines, descriptive tab labels, occasion-only entries removed. Use when asked to clean up, restructure, audit or lint the structure of zikr/dua/aamal entries, or to continue the batch-by-batch structure pass.
---

# Zikr structure

The rules are in `docs/ZIKR_STRUCTURE.md` - read it first, all of it. This
file is the procedure. Arabic orthography is a different job (the
`zikr-arabic` skill); never touch it here.

## Tools (`scripts/zikr_structure/`)

| Command | What for |
|---|---|
| `python3 scripts/zikr_structure/lint.py <uids>` | Every rule breach in those entries. A finished entry has **no `error`**. `review` findings (`LONG_PROSE`, `NOTHING_TO_DO`, `OCCASION_NOTE`) are for the owner - report them, don't act on them unless the rule is clear-cut. |
| `python3 scripts/zikr_structure/lint.py --summary` | Corpus-wide counts. |
| `python3 scripts/zikr_structure/dump.py <uid> [--short]` | The entry's lines, numbered per part and tagged `A`rabic / `t`ranslit / `T`ranslation / `N`ote. |
| `python3 scripts/zikr_structure/check_preserved.py <uids>` | Against `master`: every Arabic/translit/translation line still present (exit 1 if not), English sentences dropped/added. `--html out.html` builds the side-by-side review page. |

## Working one entry

1. `dump.py <uid> --short`, then read the long `N` lines in full (`dump.py
   <uid>` without `--short`, or `grep`) - those are what you restructure.
2. Decide the shape:
   - **One act** (one dua, one ziyarat): one part, no tabs. An instruction
     line above the Arabic, narrations and rewards to merits.
   - **Several separate acts on one occasion**: one tab per act, or group
     very short acts (one-line tasbeeh, "recite Surah X") into one tab as
     consecutive steps. Labels ≤ 40 chars, English, descriptive.
   - A **named dua that already has its own entry** (Dua Kumayl, Simat,
     Asharat, Nudba ...): link to it - `Recite [Dua Simat](E26).` - instead
     of copying it in. Look the uid up in `assets/zikr.json`.
3. Write the entry with a short Python script that **slices the original
   lines by index** for every Arabic/transliteration/translation run - never
   retype or paste verse text - and builds new note lines and merits
   around them. Write it with `corpus.write_entry(uid, title, parts,
   merits)` (keeps the file format: 2-space JSON, trailing newline). Put
   build scripts in your scratchpad, not the repo.
4. Merits: one paragraph per act or narration, separated by a blank line
   (`"\n\n".join(...)`). Start a paragraph with the act it belongs to when
   there are several (`"Istighfar: ..."`). Keep narration sentences as they
   are; only cut book scaffolding: the ordinal, "the following" → "this",
   "as mentioned above", "later we will mention", Mafatih chapter talk.
5. `lint.py <uid>` → no errors. `check_preserved.py <uid>` → lost 0; read
   the dropped list and make sure every dropped sentence is either
   scaffolding (ordinal, pointer, "it is recommended to recite the
   following") or restated in a new instruction line.
6. Don't change: uids, slugs, `assets/zikr.json` (except a title, kept in
   sync with the file - see CLAUDE.md "Zikr title conventions"), audio,
   Arabic. Don't remove, merge or alias entries yourself - list what you
   would do in your report (below), the owner decides.
7. If you changed the tab order or count, fix every redirect into the
   entry: `grep "RetiredZikrRedirect('<uid>'" lib/data/retired_zikr_redirects.dart`
   (the pilot moved four into I17, not one), and update their comments.

### Instruction lines

Short, imperative, count and timing first, end with `:` when Arabic
follows:

- `After the Asr prayer on Friday, recite 100 times:`
- `In each unit, after Surah al-Fatihah, recite [Surah al-Qadr](A101) 3 times.`
- `Recite [Dua Simat](E26).`
- `Al-Kafi records it in this form:` (introducing a variant)

Leave a line out when it would say nothing new: no bare `Recite:`, no
copy of the same line at the top of every tab (say the shared context once,
in the first part), no `Then` joining acts the source doesn't put in order
(owner feedback on the pilot).

A body line may keep a brief *why* when the reader needs it to act (the
time window, a condition) - not the reward.

### Worked example: J8 "Aamal of Asr on Friday"

Before: one part, opening `Twenty-Seventh: It has been narrated that the
best hours of Fridays are these coming after the Asr Prayer. Accordingly,
it is recommended to repeat...`, narrations between every recitation,
`Twenty-Eighth:` ... `Thirty-First:`, a `Later on, we will mention (within
the devotional rites on the 'Arafah Day)...` pointer, and Dua Asharat /
Simaat named without links.

After (`git show` the commit that introduced this skill for the full file):

| Tab | Label | Body |
|---|---|---|
| 1 | `Salawat ×100` | `After the Asr prayer on Friday, recite 100 times:` + salawat; `Shaykh al-Tusi also recommends reciting this 100 times at the same time:` + his form |
| 2 | `Salawat of the Awsiya` | `After the Asr prayer on Friday, recite 7 times (or 10):` + Ibn Idris's form; `Al-Kafi records it in this form:` + al-Kafi's |
| 3 | `Istighfar, al-Qadr & Asharat` | `After the Asr prayer, recite 70 times:` + istighfar; `Recite [Surah al-Qadr](A101) 100 times.`; `Recite [Dua Asharat](E10).` |
| 4 | `Last Hour before Sunset` | one line on the hour of answered prayer + `Recite this litany...:` + litany; `Recite [Dua Simat](E26).` |

Merits: the "best hours" line, then one paragraph each for the Awsiya
salawat (Ibn Idris/al-Bazanti narration, the 7-or-10 times narration,
al-Kafi's reward), Istighfar, Surah al-Qadr (Imam al-Kazim's thousand
gifts), the last hour (al-Tusi, the half-set sun, Lady Fatimah). The
Arafah pointer is dropped.

## Report back (subagents)

End with, per uid: the shape chosen (tabs + labels), anything you were
unsure of, the lint `review` findings, and any **proposals** - remove
(rule 6), merge into / alias to another uid, retitle, a named dua that
should be linked but has no entry. Keep it short; the reviewer reads the
diff through `check_preserved.py --html`.
