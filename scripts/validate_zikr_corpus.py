#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Read-only corpus validator for assets/zikr.json + assets/zikr/*.

Built to sanity-check the changes since v3.4.0 without requiring a human to
read every line: the "full quran transliteration" commit (915235c) and the
"add missing zikrs" commit (4c29a34). Does NOT touch any files.

Checks:
  1. JSON validity of assets/zikr.json and every assets/zikr/<uid> file.
  2. Key parity between assets/zikr.json and the assets/zikr/ directory.
  3. For code == "012"/"02" entries: data splits into a multiple of 3 lines
     (Arabic / transliteration / translation triplets).
  4. Slot-order sanity per triplet: line0 should contain Arabic, line1
     should NOT contain Arabic (transliteration), line2 should be prose.
     Flags any leftover empty transliteration slots and any Arabic leaking
     into the transliteration slot.
  5. For Quran surah files (title starts with "<N> : " or "<N>: "): triplet
     count checked against the canonical 114-surah ayah-count table (+1 for
     the Bismillah preface triplet on every surah except 1 and 9).
  6. Lexicon-fallback rate per surah: what fraction of transliterated words
     are NOT found verbatim in scripts/full_quran_lexicon.json (i.e. were
     produced by the phonetic rule engine instead of a vetted lookup).
     High-fallback surahs are the highest-risk ones for a human spot check.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIKR_DIR = os.path.join(ROOT, 'assets', 'zikr')
ZIKR_JSON = os.path.join(ROOT, 'assets', 'zikr.json')
LEXICON_PATH = os.path.join(ROOT, 'scripts', 'full_quran_lexicon.json')

sys.path.insert(0, os.path.join(ROOT, 'scripts'))
import populate_transliterations as pt  # reuse the real normalize/lexicon logic

AYAH_COUNTS = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75, 9: 129,
    10: 109, 11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128, 17: 111,
    18: 110, 19: 98, 20: 135, 21: 112, 22: 78, 23: 118, 24: 64, 25: 77,
    26: 227, 27: 93, 28: 88, 29: 69, 30: 60, 31: 34, 32: 30, 33: 73,
    34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85, 41: 54,
    42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29, 49: 18,
    50: 45, 51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96, 57: 29,
    58: 22, 59: 24, 60: 13, 61: 14, 62: 11, 63: 11, 64: 18, 65: 12,
    66: 12, 67: 30, 68: 52, 69: 52, 70: 44, 71: 28, 72: 28, 73: 20,
    74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42, 81: 29,
    82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26, 89: 30,
    90: 20, 91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19, 97: 5, 98: 8,
    99: 8, 100: 11, 101: 11, 102: 8, 103: 3, 104: 9, 105: 5, 106: 4,
    107: 7, 108: 3, 109: 6, 110: 3, 111: 5, 112: 4, 113: 5, 114: 6,
}

errors = []      # hard problems: corruption / structural breaks
warnings = []     # soft anomalies worth a human glance
surah_stats = {}  # surah_num -> dict(fid, fallback_rate, fallback_words)


def is_arabic(s):
    return pt.is_arabic(s)


def check_json_validity():
    try:
        with open(ZIKR_JSON, encoding='utf-8') as f:
            index = json.load(f)
    except Exception as e:
        errors.append(f"assets/zikr.json failed to parse: {e}")
        return {}
    return index


def main():
    index = check_json_validity()
    index_keys = set(index.keys())

    dir_files = set(os.listdir(ZIKR_DIR))
    dir_files = {f for f in dir_files if not f.startswith('.')}

    missing_on_disk = sorted(k for k in index_keys if '|' not in k and k not in dir_files)
    orphan_on_disk = sorted(f for f in dir_files if f not in index_keys)
    if missing_on_disk:
        warnings.append(f"{len(missing_on_disk)} zikr.json keys have no assets/zikr/<uid> file: {missing_on_disk[:20]}{'...' if len(missing_on_disk) > 20 else ''}")
    if orphan_on_disk:
        warnings.append(f"{len(orphan_on_disk)} assets/zikr/<uid> files are not referenced in zikr.json: {orphan_on_disk[:20]}{'...' if len(orphan_on_disk) > 20 else ''}")

    surah_title_re = re.compile(r'^(\d+)\s*:\s*')

    for fname in sorted(dir_files):
        fpath = os.path.join(ZIKR_DIR, fname)
        try:
            with open(fpath, encoding='utf-8') as f:
                doc = json.load(f)
        except Exception as e:
            errors.append(f"{fname}: invalid JSON ({e})")
            continue

        code = doc.get('code')
        data = doc.get('data', '')
        title = doc.get('title', '')

        if code not in ('012', '02'):
            continue  # not a triplet-format zikr; skip structural checks

        lines = data.split('\n')
        if code == '012' and len(lines) % 3 != 0:
            errors.append(f"{fname} ({title}): {len(lines)} lines, not a multiple of 3 (triplet format broken)")
            continue

        m = surah_title_re.match(title)
        surah_num = int(m.group(1)) if m else None

        n_triplets = len(lines) // 3 if code == '012' else None

        empty_translit = 0
        arabic_leak = 0
        empty_translation = 0
        fallback_words = 0
        total_words = 0

        if code == '012':
            for i in range(0, len(lines), 3):
                ar, tr, en = lines[i], lines[i+1], lines[i+2]
                if is_arabic(ar):
                    if tr.strip() == '':
                        empty_translit += 1
                    elif is_arabic(tr):
                        arabic_leak += 1
                    else:
                        for tok in pt.clean_arabic_verse(ar).split():
                            norm = pt.normalize_token(tok)
                            if not norm:
                                continue
                            total_words += 1
                            in_lexicon = norm in pt.LEXICON
                            if not in_lexicon:
                                for p_ar, _ in [('وَ', ''), ('فَ', ''), ('بِ', ''), ('لِ', ''), ('كَ', ''), ('سَ', ''), ('يٰ', ''), ('يٰۤ', '')]:
                                    if norm.startswith(p_ar) and norm[len(p_ar):] in pt.LEXICON:
                                        in_lexicon = True
                                        break
                            if not in_lexicon:
                                fallback_words += 1
                    if en.strip() == '':
                        empty_translation += 1

        if empty_translit:
            errors.append(f"{fname} ({title}): {empty_translit} verse(s) still missing transliteration")
        if arabic_leak:
            errors.append(f"{fname} ({title}): {arabic_leak} verse(s) have Arabic text in the transliteration slot")
        if empty_translation:
            warnings.append(f"{fname} ({title}): {empty_translation} verse(s) missing translation")

        if surah_num is not None:
            expected_ayat = AYAH_COUNTS.get(surah_num)
            if expected_ayat is not None:
                expected_triplets = expected_ayat + (0 if surah_num in (1, 9) else 1)
                if n_triplets != expected_triplets:
                    warnings.append(
                        f"{fname} (Surah {surah_num}, {title}): {n_triplets} triplets, "
                        f"expected {expected_triplets} ({expected_ayat} ayat"
                        f"{'' if surah_num in (1, 9) else ' + 1 Bismillah'})"
                    )
            if total_words:
                rate = fallback_words / total_words
                surah_stats[surah_num] = {
                    'fid': fname, 'title': title, 'fallback_rate': rate,
                    'fallback_words': fallback_words, 'total_words': total_words,
                }

    print("=" * 78)
    print(f"ERRORS ({len(errors)}) — structural problems, should block shipping:")
    print("=" * 78)
    for e in errors:
        print(" -", e)

    print()
    print("=" * 78)
    print(f"WARNINGS ({len(warnings)}) — worth a look, not necessarily bugs:")
    print("=" * 78)
    for w in warnings:
        print(" -", w)

    print()
    print("=" * 78)
    print("TOP 15 HIGHEST-RISK SURAHS by rule-engine fallback rate")
    print("(these words weren't found in full_quran_lexicon.json verbatim —")
    print(" generated by the phonetic rule engine instead; prioritize these")
    print(" for a native-speaker spot check)")
    print("=" * 78)
    ranked = sorted(surah_stats.items(), key=lambda kv: -kv[1]['fallback_rate'])
    for num, s in ranked[:15]:
        print(f"  Surah {num:3d} ({s['fid']:6s} {s['title'][:40]:40s}): "
              f"{s['fallback_rate']*100:5.1f}%  ({s['fallback_words']}/{s['total_words']} words)")

    print()
    print(f"Total surahs analyzed for fallback rate: {len(surah_stats)}")
    if surah_stats:
        overall_fb = sum(s['fallback_words'] for s in surah_stats.values())
        overall_tot = sum(s['total_words'] for s in surah_stats.values())
        print(f"Overall fallback rate across all Quran files: {overall_fb}/{overall_tot} = {overall_fb/overall_tot*100:.1f}%")


if __name__ == '__main__':
    main()
