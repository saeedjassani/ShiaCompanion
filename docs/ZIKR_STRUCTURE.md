# Zikr structure

How a zikr entry (everything under `assets/zikr/` except the Quran's `A<n>`
surahs) is laid out. Most of the corpus came from Divine Pearls, which copied
whole Mafatih al-Jinan chapters in paragraph mode and split them across
entries at arbitrary points. In this app every entry is opened on its own -
from Today's Recitation, a favorite, a search, a shared link - so it has to
make sense without the pages around it in a book.

`scripts/zikr_structure/lint.py` checks every rule below that a script can
check. The `zikr-structure` skill (`.claude/skills/zikr-structure/SKILL.md`)
is the working procedure for applying them batch by batch.

## The file

```json
{ "title": "...", "data": "...", "tabs": ["...", "..."], "merits": "..." }
```

- `data` is the first part, `tabs` the rest. Each part is lines of text:
  an Arabic line, then (optionally) its transliteration, then its
  translation; any other line stands on its own and is drawn as a note
  (an instruction, a heading, a citation).
- With more than one part, the **first line of each part is its tab label**
  and is not shown in the body.
- `merits` opens in a sheet from the Merits button above the first part. It
  is never in the way of someone who recites the zikr every day.
- Markdown links `[text](uid)` work in the body and in merits.
- A standalone line starting `## ` is a section heading (see "Headings"
  below).

## The rules

### 1. Every entry stands on its own

- No numbering carried over from a book: `First:`, `Twenty-Seventh:`,
  `(d)`, `(iii)` go. If the order of steps matters, the instruction says
  so ("Then...", "After that...").
- No pointers to text that is not in this entry: "as mentioned above",
  "the aforementioned", "later on we will mention", "see the previous
  section". Either bring the text in, link to the entry that has it
  (`[Dua Simaat](E..)`), or drop the pointer.
- Book-structure titles go too: `(a) First Night of Rajab` is titled
  `First Night of Rajab`.

### 2. The body is for doing; merits are for reading once

- The body holds what to recite or do, in order, and the short
  instructions needed to do it.
- Merits hold everything a daily reciter does not need every time: the
  reward, the narration and its chain, who recorded it in which book,
  historical background, scholars' remarks.
- If an instruction line carries both ("Imam al-Sadiq said whoever recites
  this after Asr will be forgiven; recite it seven times"), the narration
  moves to merits and the body keeps "Recite seven times:".
- A part may also open with one short line of context when the reader
  genuinely needs it to act (e.g. "Recite in the last hour of Friday,
  before sunset:").

### 3. Instruction lines are short

- One or two sentences, directly above the Arabic they introduce, with the
  count and timing up front: `Recite 100 times:`, `After the Asr prayer,
  recite 70 times:`.
- An instruction line has to add something the reader doesn't already
  know. No bare `Recite:` / `Say:` above the Arabic - the Arabic itself says
  "recite this".
- `Then` only where the source fixes the order - the steps of a namaz, the
  34-33-33 of the Tasbih of Lady Fatimah when written as one step. Separate
  recommended acts are not a sequence; don't join them with "Then".
- No paragraph over ~300 characters in the body. Split long ones at
  sentence boundaries; whatever is narration or merit moves to merits.
- Prose-only entries (how to pray a namaz, etiquettes) are written as one
  step per line, not one block.
- **Very long how-to prose that may not belong in the app at all** (legal
  rulings, historical accounts, long scholarly discussions) is not
  rewritten - the linter flags it (`LONG_PROSE`) and it goes on the owner's
  review list.

### 4. Tabs: separate acts of one occasion

Use tabs when one occasion has several distinct things to recite or do,
each complete in itself - the model is `AA5` (Duas after every obligatory
prayer in Ramazan).

- Label: short English (≤ 40 characters), naming what the tab is:
  `Salawat ×100`, `Istighfar ×70`, `Dua Ya Aliyyu Ya Azim`. Never Arabic,
  never just a number (`(1)`, `Dua 2`, `1st`), never `Miscellaneous` /
  `More` / `Other`, never empty.
- Name a dua the way people know it - `Dua Ya Malik al-Riqab`, `Dua
  Asbahtu Allahumma` - and anything without such a name by what it is -
  `Forgiveness for Believers ×25`, `Ghusl & Grooming`.
- **Changing tab order or count** (adding, removing, splitting, merging
  tabs) shifts every `RetiredZikrRedirect(uid, tabIndex: n)` or
  `tabs: [...]` into that entry - `grep "RetiredZikrRedirect('<uid>'"
  lib/data/retired_zikr_redirects.dart` and update each so it still lands
  on the same text - and every `"tabs"` of an alias of it
  (`grep '|<uid>"' assets/zikr.json`). Links shared as `?tab=N` move too;
  there is nothing to update for those.
- A tab opens with an instruction line only when it has something of its
  own to say (a count, a time, a condition). Context the title or the whole
  entry already gives - "after every obligatory prayer in Ramazan" - is
  said once, in the first part, not repeated at the top of every tab.
- Do not split one continuous dua into tabs; scrolling is fine. If it is
  long and has named sections, mark them as headings instead (below).
- **Merits are never a tab.** A tab called "Merits of ..." moves to
  `merits`.
- Short acts (a one-line tasbeeh, a surah link) can share one part as
  consecutive steps instead of each getting a tab.

### Headings

A long part with named sections - Jawshan Kabir's 100 sections, the 30
night prayers of Ramazan - marks each one with a heading line:

```
## Section 1: For Success in Difficult Works
```

- The reader draws it as a heading (centred, in the accent) and lists every
  heading of the open part in the Sections menu in its top bar, which
  scrolls to the one picked. The `## ` itself is never shown.
- Short: at most 60 characters (lint's `HEADING`), English, naming the
  section. It is translated like any other standalone line.
- Only for sections someone would jump between. A part with three steps
  needs no headings; separate acts are tabs (rule 4), not headings.

### 5. One text lives in one place

- A named dua/ziyarat that is famous on its own (Dua Kumayl, Dua Simaat,
  Ziyarat Ashura) has its own entry. A compilation that includes it links
  to it (`Recite [Dua Simaat](E..).`) rather than carrying a second copy.
- Every mention of a surah or of a named dua, ziyarat or namaz with its own
  entry is a link, in instructions and merits alike: `after [Surah
  al-Hamd](A5) recite [Surah al-Tawheed](A116)`. A surah's uid is
  `A<number + 4>`. `scripts/zikr_structure/link_mentions.py --write <uids>`
  adds them (any spelling - Hamd, al-Faatehah, Fatiha - and lists like
  "Surahs al-Falaq and al-Nas"); lint reports what it would link as
  `UNLINKED`. A translation of a linked line links the same names.
- To list the same entry in another category, add an alias key
  `"<uid>|<targetUid>"` in `assets/zikr.json` with the **same title and the
  same slug** as the target (CLAUDE.md, slug-collision note). Never copy
  the content file.
- A named dua that is also one tab (or a run of tabs) of a compilation can
  be an alias of just those tabs: give its `assets/zikr.json` entry
  `"tabs": [3]`, numbered from 1 as the reader shows them - the number a
  `?tab=3` link to that tab carries. It then shows only those tabs, under
  its own title, so it needs a **title and slug of its own**. Lint checks
  the numbers (`ALIAS_TABS`). A retired uid whose text is a run of tabs
  does the same with `RetiredZikrRedirect('<target>', tabs: [2, 3])`
  (`tabs[]` indexes, like `tabIndex`).
- A link to one tab of an entry is `/zikr/<slug>?tab=N`, N counted from 1
  as the reader shows the tabs; the reader's Share button and the web
  address bar write it for whichever tab is open.
- To merge or remove an entry, retire it (see 6) - never just delete the
  uid.
- Uids and slugs are never changed (favorites, bookmarks and shared links
  are keyed by them).

### 6. Entries with nothing to do are removed

An entry that only reports an occasion - "On the fifteenth of Dhul Hijjah,
Imam al-Hadi (a.s.) was born." - with nothing to recite, pray, fast or visit
is removed. The same goes for an entry that is nothing but a pointer to
another entry. When an entry mixes a historical note with an act, it stays:
the act is the body, the note goes to merits.

Removing uid `X`:

1. Delete `assets/zikr/X` and its `assets/zikr.json` key.
2. Add `'X': RetiredZikrRedirect('<target>')` to
   `lib/data/retired_zikr_redirects.dart`, pointing at the closest live
   entry (the month's general aamal, the entry it pointed to) so an old
   favorite still opens something.
3. Add `X`'s slug to the target's `slugAliases` so old links resolve.
4. Remove `X` from `assets/zikr_audio.json` if it has audio (move the audio
   to the target if it belongs there), and its `titles`/`audio` keys from
   every `assets/zikr_i18n/<code>/index.json`.

### 7. Text is preserved, not rewritten

- Arabic, transliteration and translation lines are never reworded here
  (Arabic has its own pass: the `zikr-arabic` skill).
- English notes can be moved (body ↔ merits ↔ another tab), split at
  sentence boundaries, and trimmed of book scaffolding (rule 1).
  New instruction lines may be written; they say what the source already
  says, shorter.
- `scripts/zikr_structure/check_preserved.py` compares against the base
  branch: every Arabic line must survive, and every English sentence that
  disappeared is listed for the reviewer.

## Titles

See "Zikr title conventions" in `CLAUDE.md`. Keep `assets/zikr.json`'s title
and the file's `title` identical.

## Side effects to know about

- Reading-position bookmarks are stored as tab index + line index, so a
  restructured entry can reopen a reader a little off from where they left
  it. Acceptable for this pass; not worth migrating.
- Content translations (`assets/zikr_i18n/<code>/<uid>`) currently cover
  only Quran surahs, so restructuring other entries needs no
  `zikr_i18n.py rebase`. If an entry ever gains one, rebase it after any
  structural change. Titles *are* translated for every entry
  (`index.json`'s `titles`), so a retitle needs its translations updated.
