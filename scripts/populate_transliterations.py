#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Quran Transliteration Generator for ShiaCompanion.
Populates missing transliterations locally in assets/zikr/ for all remaining Surahs,
matching the South Asian ShiaCompanion transliteration style and incorporating user feedback.
"""

import json
import os
import re

# Load cleaned lexicon
LEXICON_PATH = os.path.join(os.path.dirname(__file__), 'full_quran_lexicon.json')
LEXICON = {}
if os.path.exists(LEXICON_PATH):
    with open(LEXICON_PATH, 'r', encoding='utf-8') as f:
        LEXICON = json.load(f)

# Context-aware overrides for words whose transliteration legitimately changes
# with what follows (definite-article liaison, noon-sakin/tanween assimilation
# - e.g. min/mim/mir, inna/innal). Mined from the hand-verified surahs by
# scripts/build_context_lexicon.py; see that script for how a key is formed.
CONTEXT_LEXICON_PATH = os.path.join(os.path.dirname(__file__), 'context_lexicon.json')
CONTEXT_LEXICON = {}
if os.path.exists(CONTEXT_LEXICON_PATH):
    with open(CONTEXT_LEXICON_PATH, 'r', encoding='utf-8') as f:
        CONTEXT_LEXICON = json.load(f)

# Unicode constants
FATHATAN = '\u064B'
DAMMATAN = '\u064C'
KASRATAN = '\u064D'
FATHA    = '\u064E'
DAMMA    = '\u064F'
KASRA    = '\u0650'
SHADDA   = '\u0651'
SUKUN    = '\u0652'
MADDAH   = '\u0653'
DAGGER_ALIF = '\u0670'

ALIF = '\u0627'
ALIF_MAQSOORA = '\u0649'

SUN_LETTERS = {'ت', 'ث', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ل', 'ن'}

CONSONANTS = {
    'ب': 'B', 'ت': 'T', 'ث': 'S', 'ج': 'J', 'ح': 'H', 'خ': 'KH',
    'د': 'D', 'ذ': 'Z', 'ر': 'R', 'ز': 'Z', 'س': 'S', 'ش': 'SH',
    'ص': 'S', 'ض': 'Z', 'ط': 'T', 'ظ': 'Z', 'ع': 'A’', 'غ': 'GH',
    'ف': 'F', 'ق': 'Q', 'ك': 'K', 'ل': 'L', 'م': 'M', 'ن': 'N',
    'ه': 'H', 'و': 'W', 'ي': 'Y', 'ء': '', 'ئ': '', 'ؤ': '',
    'ى': 'AA', 'ة': 'T', 'آ': 'AA', 'أ': 'A', 'إ': 'E', 'ا': 'A'
}

# Urdu/Farsi letterforms that appear in this corpus but aren't in CONSONANTS.
# Left unmapped, the rule-based engine silently drops them instead of erroring
# (e.g. 'عَلَیْکُمْ' -> 'A’ALAM' instead of 'A’LAYKUM') rather than transliterating
# them. Normalize to their standard-Arabic equivalents up front so both the
# lexicon lookup and the rule engine see a letter they recognize.
URDU_FARSI_LETTERFORMS = {
    'ی': 'ي',  # FARSI YEH -> ARABIC YEH
    'ک': 'ك',  # KEHEH -> ARABIC KAF
    'ڪ': 'ك',  # SWASH KAF -> ARABIC KAF
    'ھ': 'ه',  # HEH DOACHASHMEE -> ARABIC HEH
    'ہ': 'ه',  # HEH GOAL -> ARABIC HEH
    'ے': 'ي',  # YEH BARREE -> ARABIC YEH
    'ٴ': 'ء',  # HIGH HAMZA -> ARABIC HAMZA (already maps to '')
    'ﺎ': 'ا',  # ARABIC PRESENTATION FORM ALEF -> ARABIC ALEF
}

def normalize_letterforms(s):
    """Map Urdu/Farsi letterform variants to their standard-Arabic equivalents."""
    for src, dst in URDU_FARSI_LETTERFORMS.items():
        s = s.replace(src, dst)
    return s

def clean_arabic_verse(ar_line):
    """Normalize typography, merge broken words, and strip pause marks."""
    s = ar_line.strip()
    s = normalize_letterforms(s)
    # Strip trailing verse number annotations: (1), [1], ۝۱, etc.
    s = re.sub(r'[\(\[\{]\s*\d+\s*[\)\]\}]\s*$', '', s).strip()
    s = re.sub(r'[\u06DD\u06DE\u06DF\u06E0-\u06ED\u0600-\u0605\uFD3E\uFD3F]+', '', s).strip()
    s = re.sub(r'[\u0660-\u0669\u06F0-\u06F9]+$', '', s).strip()
    s = re.sub(r'[\u06D6-\u06DC\u06DF-\u06ED\u200B-\u200F\uFEFFۣۙۚۖۗۛۜۥۦ۪ۭۧۨ‏\uE000-\uF8FF]', '', s).strip()
    s = s.replace('\u06E1', '\u0652')

    # Merge broken typography
    # A stray space after word-initial alef-fatha splits many words in two
    # (e.g. 'اَ لِيْمٍ' for 'اَلِيْمٍ' aleem, 'اَ ذًى' for 'اَذًى' adha).
    # Left alone it tokenizes as a bare 'اَ', which also happens to collide
    # with a bad full_quran_lexicon.json entry ('اَ' -> 'A’ZAABAN'), so glue
    # it back onto whatever follows before tokenizing.
    s = re.sub(r'\bاَ\s+', 'اَ', s)
    s = re.sub(r'\bذٰ\s+لِكَ\b', 'ذٰلِكَ', s)
    s = re.sub(r'\bهٰ\s+ذَا\b', 'هٰذَا', s)
    s = re.sub(r'\bهٰ\s+ذِهِ\b', 'هٰذِهِ', s)
    s = re.sub(r'\bهٰ\s+ؤُلَآءِ\b', 'هٰٓؤُلَآءِ', s)
    s = re.sub(r'\bيٰۤ?\s+اَيُّهَا\b', 'يٰۤاَيُّهَا', s)

    return s.strip()

def normalize_token(s):
    """Clean token for lexicon matching."""
    s = normalize_letterforms(s)
    s = re.sub(r'[\u06D6-\u06DC\u06DF-\u06ED\u200B-\u200F\uFEFFۣۙۚۖۗۛۜۥۦ۪ۭۧۨ‏\uE000-\uF8FF]', '', s).strip()
    s = s.replace('\u06E1', '\u0652')
    return s.strip()

def rule_based_word(word):
    """Fallback phonetic rule engine for words not in the lexicon."""
    prefix = ""
    rest = word

    # Al- / Sun letters
    if rest.startswith('الْ') or rest.startswith('الۡ') or rest.startswith('الْـ'):
        prefix = 'AL-'
        rest = rest[3:]
    elif rest.startswith('ال') and len(rest) > 2 and (rest[2] in SUN_LETTERS or (len(rest) > 3 and rest[3] == SHADDA)):
        c = rest[2]
        c_tr = CONSONANTS.get(c, 'L')
        prefix = f"A{c_tr}-"
        rest = rest[2:]
        if rest.startswith(c) and len(rest) > 1 and rest[1] == SHADDA:
            rest = rest[0] + rest[2:]
    elif rest.startswith('وَالْ') or rest.startswith('وَالۡ'):
        prefix = 'WAL '
        rest = rest[4:]
    elif rest.startswith('بِالْ') or rest.startswith('بِالۡ'):
        prefix = 'BIL-'
        rest = rest[4:]
    elif rest.startswith('فَالْ') or rest.startswith('فَالۡ'):
        prefix = 'FAL '
        rest = rest[4:]
    elif rest.startswith('لِلْ') or rest.startswith('لِلۡ'):
        prefix = 'LIL-'
        rest = rest[3:]

    chars = list(rest)
    out = []
    i = 0
    n = len(chars)

    while i < n:
        ch = chars[i]
        nxt = chars[i+1] if i + 1 < n else ''
        nxt2 = chars[i+2] if i + 2 < n else ''

        if ch in '\u06D6\u06D7\u06D8\u06D9\u06DA\u06DB\u06DC\u06DF\u06E0\u06E1\u06E2\u06E3\u06E4\u06E5\u06E6\u06E7\u06E8\u06EA\u06EB\u06EC\u06ED\u200C\u200D\u200E\u200F':
            i += 1
            continue

        has_shadda = False
        if nxt == SHADDA:
            has_shadda = True
            nxt = nxt2
            skip_shadda = 1
        else:
            skip_shadda = 0

        if ch in CONSONANTS:
            cons = CONSONANTS[ch]

            if ch == 'ع':
                if nxt == FATHA:
                    cons = "A’"
                elif nxt == KASRA:
                    cons = "E’"
                elif nxt == DAMMA:
                    cons = "U’"
                else:
                    cons = "A’"

            vowel = ""
            advance = 1 + skip_shadda

            idx = i + advance
            curr_vowel = ""
            while idx < n and chars[idx] in (FATHA, DAMMA, KASRA, FATHATAN, DAMMATAN, KASRATAN, SUKUN, MADDAH, DAGGER_ALIF):
                curr_vowel += chars[idx]
                idx += 1

            if DAGGER_ALIF in curr_vowel or (FATHA in curr_vowel and idx < n and chars[idx] in (ALIF, ALIF_MAQSOORA)):
                vowel = "AA"
                if idx < n and chars[idx] in (ALIF, ALIF_MAQSOORA):
                    idx += 1
            elif KASRA in curr_vowel and idx < n and chars[idx] == 'ي':
                vowel = "EE"
                idx += 1
            elif DAMMA in curr_vowel and idx < n and chars[idx] == 'و':
                vowel = "OO"
                idx += 1
            elif FATHATAN in curr_vowel:
                vowel = "AN"
                if idx < n and chars[idx] in (ALIF, ALIF_MAQSOORA):
                    idx += 1
            elif DAMMATAN in curr_vowel:
                vowel = "UN"
            elif KASRATAN in curr_vowel:
                vowel = "IN"
            elif FATHA in curr_vowel:
                if idx < n and chars[idx] == 'ي' and (idx + 1 >= n or chars[idx+1] == SUKUN or chars[idx+1] not in (FATHA, DAMMA, KASRA)):
                    vowel = "AY"
                    idx += 1
                elif idx < n and chars[idx] == 'و' and (idx + 1 >= n or chars[idx+1] == SUKUN or chars[idx+1] not in (FATHA, DAMMA, KASRA)):
                    vowel = "AW"
                    idx += 1
                else:
                    vowel = "A"
            elif KASRA in curr_vowel:
                vowel = "E"
            elif DAMMA in curr_vowel:
                vowel = "U"
            elif SUKUN in curr_vowel:
                vowel = ""

            if MADDAH in curr_vowel:
                if vowel.endswith('AA'):
                    vowel += "A"
                elif vowel.endswith('EE'):
                    vowel += "E"
                elif vowel.endswith('OO'):
                    vowel += "O"
                else:
                    vowel += "AA"

            if has_shadda and cons:
                sh_char = cons[0]
                out.append(sh_char + cons + vowel)
            else:
                out.append(cons + vowel)

            i = idx
            continue

        i += 1

    word_result = prefix + ''.join(out)
    return word_result

CONTEXT_SEP = '␟'  # unit separator - matches scripts/build_context_lexicon.py

def context_bucket(next_norm_token):
    """Classify what follows a word, for CONTEXT_LEXICON lookups.

    Must stay in sync with the same function in build_context_lexicon.py -
    the key format is shared between the file that mines this table and the
    file that reads it.
    """
    if not next_norm_token:
        return 'END'
    if next_norm_token.startswith('ال') or next_norm_token.startswith('اَل'):
        return 'AL'
    return next_norm_token[0]

def transliterate_word(raw_token, next_norm_token=None):
    """Lookup context-lexicon first, then plain lexicon (with common prefix
    stripping), fallback to rules."""
    norm = normalize_token(raw_token)
    if not norm:
        return ""

    ctx_key = f"{norm}{CONTEXT_SEP}{context_bucket(next_norm_token)}"
    if ctx_key in CONTEXT_LEXICON:
        return CONTEXT_LEXICON[ctx_key]

    if norm in LEXICON:
        return LEXICON[norm]

    prefixes = [
        ('وَ', 'WA '), ('فَ', 'FA '), ('بِ', 'BE-'), ('لِ', 'LE-'),
        ('كَ', 'KA-'), ('سَ', 'SA-'), ('يٰ', 'YAA '), ('يٰۤ', 'YAA ')
    ]
    for p_ar, p_en in prefixes:
        if norm.startswith(p_ar):
            stem = norm[len(p_ar):]
            if stem in LEXICON:
                return p_en + LEXICON[stem]

    return rule_based_word(norm)

def transliterate_verse(ar_text):
    """Full verse transliteration adhering to ShiaCompanion phonetics and user feedback."""
    cleaned = clean_arabic_verse(ar_text)
    if not cleaned:
        return ""

    if cleaned in ('بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ', 'بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ', 'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ'):
        return "BISMIL LAAHIR RAHMAANIR RAHEEM"

    tokens = cleaned.split()
    norm_tokens = [normalize_token(t) for t in tokens]
    tr_tokens = []

    for idx, token in enumerate(tokens):
        nxt = norm_tokens[idx + 1] if idx + 1 < len(norm_tokens) else None
        tr = transliterate_word(token, nxt)
        if tr:
            tr_tokens.append(tr)

    line = ' '.join(tr_tokens).strip()

    # User feedback and stylistic consistency rules
    line = re.sub(r'\s+', ' ', line)
    line = re.sub(r'\bMINHOB\b', 'MINHUB', line)
    line = re.sub(r'\bOLUL\b', 'ULUL', line)
    line = re.sub(r'\bOOLIL\b', 'ULIL', line)
    line = re.sub(r'\bAL-LAZEENA\b', 'LAZEENA', line)
    line = re.sub(r'\bWAL-LAZEENA\b', 'WAL LAZEENA', line)
    line = re.sub(r'\bFAL-LAZEENA\b', 'FAL LAZEENA', line)
    line = re.sub(r'\bALLAAHO\b', 'ALLAAHO', line)
    line = re.sub(r'\bAL LAAH\b', 'ALLAAH', line)
    line = re.sub(r'A’A’', 'A’', line)
    
    if line and not line.endswith(('.', '!', '?', ',')):
        line += '.'

    return line

def is_arabic(s):
    if not s: return False
    scanned = 0
    for ch in s:
        if scanned >= 35: break
        r = ord(ch)
        if ((0x0600 <= r <= 0x06FF) or (0x0750 <= r <= 0x077F) or 
            (0x08A0 <= r <= 0x08FF) or (0xFB50 <= r <= 0xFDFF) or (0xFE70 <= r <= 0xFEFF)):
            return True
        scanned += 1
    return False

def populate_all_missing(zikr_dir):
    """Populate all missing transliterations across all 58 Surahs in zikr_dir."""
    missing_surahs = [
        3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        21, 22, 23, 24, 25, 26, 31, 32, 34, 35, 37, 38, 39, 40, 42, 43,
        45, 46, 47, 49, 50, 51, 52, 53, 54, 57, 58, 60, 61, 64, 66, 68,
        69, 70, 71, 72, 74, 75, 77, 79
    ]

    total_populated = 0
    stats = {}

    for s in missing_surahs:
        fid = f"A{s+4}"
        fpath = os.path.join(zikr_dir, fid)
        if not os.path.exists(fpath):
            print(f"Warning: {fpath} does not exist!")
            continue

        with open(fpath, 'r', encoding='utf-8') as f:
            doc = json.load(f)

        code = doc.get('code')
        lines = doc.get('data', '').split('\n')
        populated_count = 0

        if code == '012':
            # Code 012: lines have empty transliterations between Arabic and Translation
            new_lines = list(lines)
            for i in range(len(lines)):
                if is_arabic(lines[i]):
                    # Check if i + 1 is the transliteration slot
                    if i + 1 < len(lines):
                        if lines[i+1].strip() == '':
                            # It's an empty line waiting for transliteration!
                            tr = transliterate_verse(lines[i])
                            new_lines[i+1] = tr
                            populated_count += 1
                        elif is_arabic(lines[i+1]):
                            # Another Arabic line follows directly (missing line entirely)
                            tr = transliterate_verse(lines[i])
                            new_lines.insert(i+1, tr)
                            populated_count += 1
            doc['data'] = '\n'.join(new_lines)

        elif code == '02':
            # Code 02 (Surah 57, 68): Convert to 012 and interleave transliterations
            new_lines = []
            for i in range(len(lines)):
                line = lines[i]
                new_lines.append(line)
                if is_arabic(line):
                    # Check if next line is translation or already transliteration
                    tr = transliterate_verse(line)
                    new_lines.append(tr)
                    populated_count += 1
            doc['code'] = '012'
            doc['data'] = '\n'.join(new_lines)

        # Write back to file with proper formatting
        with open(fpath, 'w', encoding='utf-8') as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
            f.write('\n')

        stats[s] = (fid, doc.get('title'), populated_count)
        total_populated += populated_count

    print("\n" + "=" * 70)
    print(f"POPULATION COMPLETE: {total_populated} verses populated across {len(stats)} Surahs.")
    print("=" * 70)
    for s, (fid, title, count) in stats.items():
        print(f"Surah {s:3d} ({fid}): {count:3d} verses populated - {title}")

    return total_populated

if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_dir = os.path.dirname(script_dir)
    zikr_path = os.path.join(workspace_dir, 'assets', 'zikr')
    populate_all_missing(zikr_path)
