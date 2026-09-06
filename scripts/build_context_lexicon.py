#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build a context-aware transliteration lexicon from the already-hand-verified
Quran surah files (everything under assets/zikr/A* that 915235c did NOT
touch).

full_quran_lexicon.json stores one transliteration per Arabic word, but many
high-frequency words legitimately change form depending on what immediately
follows them:

  - Liaison with the definite article (wasl): a word ending a phrase reads
    straight into a following 'ال' word, e.g. huwa + al-... -> "HOWAL",
    inna + al-... -> "INNAL", rabbika + al-... -> "RABBEKAL".
  - Noon-sakin/tanween assimilation (idgham/iqlab): min/an/inna-with-sukun
    etc. change their final consonant to match the first letter of the next
    word, e.g. "MIN" -> "MIM" before ب, "MIR" before ر, "MIL" before ل.

Rather than hand-encode tajweed assimilation tables (risking new, unverified
errors), this mines the *actual* established house-style pairs directly from
the 57 surahs a human already transliterated: for every (word, next-word
context-bucket) pair seen with enough support and a clear majority, record
the majority transliteration. populate_transliterations.py consults this
before falling back to the context-free lexicon or the rule engine.

Read-only against assets/zikr — writes only scripts/context_lexicon.json.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIKR_DIR = os.path.join(ROOT, 'assets', 'zikr')
OUT_PATH = os.path.join(ROOT, 'scripts', 'context_lexicon.json')

sys.path.insert(0, os.path.join(ROOT, 'scripts'))
import populate_transliterations as pt

# The 58 surahs 915235c auto-populated - excluded as training data since
# they're the untrusted output we're trying to correct, not ground truth.
POPULATED = set('''A7 A8 A9 A10 A11 A12 A13 A14 A15 A16 A17 A18 A19 A20 A21 A22 A23
A24 A25 A26 A27 A28 A29 A30 A35 A36 A38 A39 A41 A42 A43 A44 A46 A47 A49 A50
A51 A53 A54 A55 A56 A57 A58 A61 A62 A64 A65 A68 A70 A72 A73 A74 A75 A76 A78
A79 A81 A83'''.split())

MIN_SUPPORT = 2      # need to see a (word, bucket) pair at least this often
MIN_MAJORITY = 0.75  # and agree on the majority value at least this often


def is_upper_translit(l):
    letters = [c for c in l if c.isalpha()]
    if not letters:
        return False
    return sum(1 for c in letters if c.isupper()) / len(letters) > 0.8


def main():
    all_files = [f for f in os.listdir(ZIKR_DIR) if re.match(r'^A\d+$', f)]
    good_files = [f for f in all_files if f not in POPULATED]

    # (word, bucket) -> {observed_value: count}
    observations = {}
    lines_used = 0
    lines_skipped_len_mismatch = 0

    for fid in good_files:
        doc = json.load(open(os.path.join(ZIKR_DIR, fid), encoding='utf-8'))
        lines = doc.get('data', '').split('\n')
        for i in range(len(lines) - 1):
            ar, tr = lines[i], lines[i + 1]
            if not (pt.is_arabic(ar) and tr.strip() and not pt.is_arabic(tr) and is_upper_translit(tr)):
                continue
            ar_cleaned = pt.clean_arabic_verse(ar)
            ar_raw_toks = ar_cleaned.split()
            ar_norm_toks = [pt.normalize_token(t) for t in ar_raw_toks]
            tr_toks = tr.strip().rstrip('.').split()
            if len(ar_norm_toks) != len(tr_toks):
                lines_skipped_len_mismatch += 1
                continue
            lines_used += 1
            for j, (norm, tr_word) in enumerate(zip(ar_norm_toks, tr_toks)):
                if not norm:
                    continue
                nxt = ar_norm_toks[j + 1] if j + 1 < len(ar_norm_toks) else None
                bucket = pt.context_bucket(nxt)
                key = f"{norm}{pt.CONTEXT_SEP}{bucket}"
                val = tr_word.rstrip('.,')
                observations.setdefault(key, {}).setdefault(val, 0)
                observations[key][val] += 1

    # Words the harvest found *some* repeated support for, but that a manual
    # read-through showed to be wrong - almost always the "exact word count
    # match" alignment check coincidentally lining up two different words
    # rather than really pairing the token with its own translation (e.g.
    # 'عَنِ' -> 'A’NIN' when the plain lexicon, and every other liaison
    # entry's own pattern, says 'A’NIL'). Keep this list short; anything
    # dropped for a *general*, checkable reason belongs in a heuristic
    # below instead, not here.
    MANUAL_DENYLIST = {
        f"عَنِ{pt.CONTEXT_SEP}AL",  # disagrees with the plain lexicon's own value ('A’NIL') for no clear reason
    }

    context_lexicon = {}
    ambiguous_dropped = 0
    redundant_dropped = 0
    implausible_dropped = 0
    for key, counts in observations.items():
        total = sum(counts.values())
        if total < MIN_SUPPORT:
            continue
        best_val, best_count = max(counts.items(), key=lambda kv: kv[1])
        if best_count / total < MIN_MAJORITY:
            ambiguous_dropped += 1
            continue
        norm, _bucket = key.split(pt.CONTEXT_SEP, 1)

        # Liaison/assimilation only ever modifies or extends a word's own
        # tail - it never lops off a leading component or swaps the word
        # for an unrelated one. Both failure modes are symptoms of the same
        # alignment risk noted in MANUAL_DENYLIST above, and are common
        # enough (multi-word bases like 'WA MAA', 'WA LAQAD') to catch
        # generically instead of one at a time.
        base = pt.LEXICON.get(norm) or pt.rule_based_word(norm)
        if base:
            truncated = len(best_val) < len(base) - 2
            word_swapped = best_val[0].upper() != base[0].upper()
            if key in MANUAL_DENYLIST or truncated or word_swapped:
                implausible_dropped += 1
                continue
        elif key in MANUAL_DENYLIST:
            implausible_dropped += 1
            continue

        # Only keep entries that add real information beyond the plain
        # lexicon: skip if it's identical to what the context-free lookup
        # would already produce for this word (no liaison/assimilation for
        # this particular bucket, so the override is a no-op).
        if norm in pt.LEXICON and pt.LEXICON[norm] == best_val:
            redundant_dropped += 1
            continue
        context_lexicon[key] = best_val

    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(context_lexicon, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')

    print(f"Hand-verified files scanned: {len(good_files)}")
    print(f"Triplet lines used (exact word-count match): {lines_used}")
    print(f"Triplet lines skipped (ambiguous alignment): {lines_skipped_len_mismatch}")
    print(f"(word, context) pairs observed: {len(observations)}")
    print(f"Pairs dropped for low support (<{MIN_SUPPORT}) or no majority (<{MIN_MAJORITY:.0%}): {ambiguous_dropped}")
    print(f"Pairs dropped as implausible (truncated/word-swapped/denylisted): {implausible_dropped}")
    print(f"Pairs dropped as redundant with the plain lexicon: {redundant_dropped}")
    print(f"Context-lexicon entries written: {len(context_lexicon)}")


if __name__ == '__main__':
    main()
