# Quran transliteration generator

A rule-based transliterator for the 58 surahs whose transliteration slot is
empty. It copies the house style of the hand-made transliterations already in
`assets/zikr/A*` (surahs 1, 2, 27-30, 33, 36, 41, 44, 48, 55-57, 59, 62-63,
65, 67, 73, 76, 78, 80-114, plus the partial lines in others), and is scored
against them.

Input:
- `assets/quran/tanzil-uthmani.txt`: fully vocalised Hafs text, used for the
  pronunciation.
- The Indo-Pak Arabic line in each `assets/zikr/A*` file, used only for its
  waqf marks, which decide where commas and pauses go (the hand-made
  transliterations follow those marks).
- Quranic Arabic Corpus morphology (downloaded to `morph.txt` on first run,
  git-ignored), used to split off the wa-/fa-/bi-/li-/ka-/la-/sa- prefixes.

## Conventions (taken from the hand-made transliterations)

- Short vowels: fatha `A`. Kasra `I` in a closed syllable, `E` in an open one
  (BISMIL, MIN / MAALEKE, ELAYKA). Damma `U` in a closed syllable, `O` in an
  open one (TUQSETOO, QUL / AYMAANOKUM, NA’BODO). A syllable is closed when a
  consonant and then another consonant (or a doubled one) follow. Before a
  sukun'd ه ح ع ء the syllable counts as open (MOHTADEEN, YOAMENOON).
- Long vowels `AA` `EE` `OO`. Alif + hamza in the same word `AAA`
  (SAMAAA-E). Pronoun silah `HU` / `HI`.
- ع is `’` after its vowel (A’LAA, YA’LAMO, JA-A’LNAA). Hamza between vowels
  is a hyphen (SHAY-IN). Hamza with sukun is written as `A` (YOAMENOON).
- ث س ص → S, ذ ز ض ظ → Z, ت ط → T, ح ه → H.
- Across words: sun letters and idgham are written doubled across the space
  (INNAL LAZEENA, MIR RABBEHIM). Iqlab is `M` (MIM BA’DE), and idgham into
  و / ي is `NW WA` / `N-Y YA`. A long vowel before hamzat al-wasl is
  shortened (FIL ARZE, AATUN NESAAA).
- Pause (end of ayah, and at the ؕ ۚ ۖ ۘ-type marks): the final short vowel
  and -un/-in are dropped. -an becomes `AA`, and ة becomes `H`. ۙ (laa) only
  gets a comma.
- Prefixes: wa is its own word (WA). A prefix before a vowel takes a hyphen
  (FA-IN). bi/li/fa before a noun or verb take a hyphen (BE-RABBEHIM). Before
  pronouns and particles they are glued on (BEHIM, FAMAA, LAHUM). LILLAAHE.

- Disjoined letters are spelled by name (ALIF LAAAM MEEM, TAA SIM MEEM,
  HAA MEEM, KAAAF HAA YAA A’YN SAAAD).

The hand-made text itself varies (e.g. MAN-Y / MANY). Where it does, the
majority form is used.

## Usage

```
cd scripts/quran_transliteration
python3 harness.py 40      # agreement with the hand-made surahs (+ top diffs)
python3 harness.py 40 p    # same, ignoring hyphen/space-only differences
python3 side.py 67         # side-by-side for one surah
python3 apply.py 4         # fill the empty slots of surah 4
python3 apply.py all       # every surah (only blank slots are touched)
```
