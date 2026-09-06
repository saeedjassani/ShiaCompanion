#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Apply S.V. Mir Ahmed Ali's English translation to all 114 Surahs in assets/zikr/.
Preserves:
- Indo-Pak Arabic script with Ayah numerals (n)
- Phonetically matched Latin transliterations
- Surah titles, intro descriptions, and merits
- '012' code structure (Arabic, Transliteration, Translation)
"""

import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKSPACE_DIR = os.path.dirname(SCRIPT_DIR)
ZIKR_DIR = os.path.join(WORKSPACE_DIR, 'assets', 'zikr')
TRANSLATIONS_PATH = os.path.join(SCRIPT_DIR, 'mir_ahmed_ali_quran.json')

BISMILLAH_EN = "In the Name of Allah, the All-beneficent, the All-merciful"
QUOTE_CHARS = '\u201c\u201d\u2018\u2019"\'\u0027\u0022'

SURAH_VERSE_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6
]

def is_arabic(s):
    if not s:
        return False
    scanned = 0
    for ch in s:
        if scanned >= 35:
            break
        r = ord(ch)
        if ((0x0600 <= r <= 0x06FF) or (0x0750 <= r <= 0x077F) or 
            (0x08A0 <= r <= 0x08FF) or (0xFB50 <= r <= 0xFDFF) or (0xFE70 <= r <= 0xFEFF)):
            return True
        scanned += 1
    return False

def clean_translation(t):
    t = t.strip()
    while t and t[0] in QUOTE_CHARS:
        t = t[1:].strip()
    while t and t[-1] in QUOTE_CHARS:
        t = t[:-1].strip()
    t = re.sub(r'\s+([.,;:!?])', r'\1', t)
    t = re.sub(r'\s+', ' ', t)
    return t.strip()

def update_surah(surah_num, translations):
    fid = f"A{surah_num + 4}"
    fpath = os.path.join(ZIKR_DIR, fid)
    if not os.path.exists(fpath):
        print(f"Warning: {fpath} does not exist!")
        return False

    with open(fpath, 'r', encoding='utf-8') as f:
        doc = json.load(f)

    lines = doc.get('data', '').split('\n')
    expected_verses = SURAH_VERSE_COUNTS[surah_num - 1]

    # Find intro lines before first Arabic
    first_ar_idx = -1
    for i, line in enumerate(lines):
        if is_arabic(line.strip()):
            first_ar_idx = i
            break

    if first_ar_idx == -1:
        print(f"Error: No Arabic found in {fid}")
        return False

    intro_lines = lines[:first_ar_idx]
    
    # Rebuild triplets accurately
    new_lines = list(intro_lines)
    
    # Identify Arabic lines
    ar_indices = [i for i in range(first_ar_idx, len(lines)) if is_arabic(lines[i].strip())]
    
    # Special fix for Surah 13 (A17) which had an extra trailing Bismillah in original file
    if surah_num == 13 and len(ar_indices) == 45:
        ar_indices = ar_indices[:44]

    has_header_bismillah = (surah_num != 1 and surah_num != 9)
    
    verse_idx = 1
    for k, ar_idx in enumerate(ar_indices):
        ar_line = lines[ar_idx].strip()
        
        # Determine transliteration line
        tr_line = ""
        if ar_idx + 1 < len(lines) and not is_arabic(lines[ar_idx + 1].strip()):
            tr_line = lines[ar_idx + 1].strip()

        # Handle header Bismillah
        if has_header_bismillah and k == 0:
            en_line = BISMILLAH_EN
            new_lines.append(ar_line)
            new_lines.append(tr_line if tr_line else "BISMIL LAAHIR RAHMAANIR RAHEEM")
            new_lines.append(en_line)
            continue

        # Regular verse
        ref = f"{surah_num}:{verse_idx}"
        en_trans = translations.get(ref)
        if not en_trans:
            print(f"  Warning: Missing translation for {ref} in {fid}")
            if ar_idx + 2 < len(lines) and not is_arabic(lines[ar_idx + 2].strip()):
                en_trans = lines[ar_idx + 2].strip()
            else:
                en_trans = ""

        en_line = clean_translation(en_trans) if en_trans else ""
        
        new_lines.append(ar_line)
        new_lines.append(tr_line)
        new_lines.append(en_line)
        verse_idx += 1

    doc['code'] = '012'
    doc['data'] = '\n'.join(new_lines)

    # Save
    with open(fpath, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write('\n')

    return True

def main():
    if not os.path.exists(TRANSLATIONS_PATH):
        print(f"Error: {TRANSLATIONS_PATH} does not exist! Run extract_mir_ahmed_ali.py first.")
        sys.exit(1)

    with open(TRANSLATIONS_PATH, 'r', encoding='utf-8') as f:
        translations = json.load(f)

    print(f"Loaded {len(translations)} verses from {TRANSLATIONS_PATH}")

    updated_count = 0
    for s in range(1, 115):
        if update_surah(s, translations):
            updated_count += 1

    print("\n" + "=" * 60)
    print(f"SUCCESS: Updated {updated_count}/114 Surahs with S.V. Mir Ahmed Ali's translation!")
    print("=" * 60)

if __name__ == '__main__':
    main()
