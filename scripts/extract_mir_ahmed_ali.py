#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extract S.V. Mir Ahmed Ali's English translation of the Holy Quran from Al-Islam.org.
Source: 'The Holy Qur’an - The Final Testament' by Mirza Mahdi Pooya & S.V. Mir Ahmad Ali.
Compiles all 114 Surahs (6,236 verses) into scripts/mir_ahmed_ali_quran.json.
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(SCRIPT_DIR, 'mir_ahmed_ali_quran.json')
CACHE_DIR = os.path.join(SCRIPT_DIR, 'juz_cache')

# Canonical Quran verse counts for Surahs 1 to 114
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

JUZ_SURAHS = {
    1: [1, 2],
    2: [2],
    3: [2, 3],
    4: [3, 4],
    5: [4],
    6: [4, 5],
    7: [5, 6],
    8: [6, 7],
    9: [7, 8],
    10: [8, 9],
    11: [9, 10, 11],
    12: [11, 12],
    13: [12, 13, 14],
    14: [15, 16],
    15: [17, 18],
    16: [18, 19, 20],
    17: [21, 22],
    18: [23, 24, 25],
    19: [25, 26, 27],
    20: [27, 28, 29],
    21: [29, 30, 31, 32, 33],
    22: [33, 34, 35, 36],
    23: [36, 37, 38, 39],
    24: [39, 40, 41],
    25: [41, 42, 43, 44, 45],
    26: [46, 47, 48, 49, 50, 51],
    27: [51, 52, 53, 54, 55, 56, 57],
    28: list(range(58, 67)),
    29: list(range(67, 78)),
    30: list(range(78, 115))
}

QUOTE_CHARS = '\u201c\u201d\u2018\u2019"\'\u0027\u0022'

def fetch_url(url, retries=3, delay=2):
    req = urllib.request.Request(url, headers=HEADERS)
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.read().decode('utf-8', errors='ignore')
        except urllib.error.HTTPError as e:
            print(f"  [HTTP {e.code}] {url} (attempt {attempt+1}/{retries})")
            if e.code == 404:
                return None
            time.sleep(delay * (attempt + 1))
        except Exception as e:
            print(f"  [Error: {e}] {url} (attempt {attempt+1}/{retries})")
            time.sleep(delay * (attempt + 1))
    return None

def clean_verse_text(text):
    """Normalize whitespace, strip HTML tags, remove hanging quotes, and fix punctuation spacing."""
    s = re.sub(r'<[^>]+>', ' ', text)
    s = s.replace('&quot;', '"').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    s = s.replace('&#039;', "'").replace('&#39;', "'").replace('&nbsp;', ' ')
    s = s.strip()

    # Iteratively strip leading and trailing quotation marks
    while s and s[0] in QUOTE_CHARS:
        s = s[1:].strip()
    while s and s[-1] in QUOTE_CHARS:
        s = s[:-1].strip()

    # Remove extraneous space before punctuation (often left by stripped footnote tags)
    s = re.sub(r'\s+([.,;:!?])', r'\1', s)

    # Normalize internal spaces
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

def parse_verses_from_juz(juz_num, html):
    """
    Extracts verses for a given Juz HTML file.
    Restricts parsing to the Surahs that belong to this Juz,
    concatenating multi-paragraph verse spans between blockquotes,
    and handling known typographical edge cases in Al-Islam's HTML.
    """
    found = {}
    
    # Strip footnotes so they don't break textual flow
    html_clean = re.sub(r'<a\s+class=\"see-footnote\"[^>]*>.*?</a>', '', html, flags=re.DOTALL)
    
    # Handle known Al-Islam typographical edge cases:
    if juz_num == 14:
        # Typo 17:71 in place of 15:71
        html_clean = html_clean.replace('>17:71<', '>15:71<').replace('(17:71)', '(15:71)')
    elif juz_num == 19:
        # Typo 45:47 in place of 25:47
        html_clean = html_clean.replace('(45:47)', '(25:47)').replace('>45:47<', '>25:47<')
    elif juz_num == 21:
        # Typo 33:6 in place of 30:6 in Surah Ar-Rum
        target_30_6 = 'Faileth not God His promise, but most people know not (this).'
        html_clean = re.sub(re.escape(target_30_6) + r'.*?33:6.*?</strong>', target_30_6 + '” (30:6)</strong>', html_clean)
        # Missing reference tag for 31:26
        html_clean = html_clean.replace('the Most Praised.</strong>', 'the Most Praised.” (31:26)</strong>')
    elif juz_num == 23:
        # 37:29 mislabeled as duplicate 37:28
        html_clean = re.sub(r'(They shall say:.*?were not the believers:[^)]*?)\(\s*<a[^>]*>37:28</a>\s*\)', r'\1(37:29)', html_clean)
    elif juz_num == 27:
        # 53:61 and 53:62 mislabeled as 53:60
        html_clean = html_clean.replace(
            '“And yet sport ye (negligently)” (<a href="#quran_ref_373307" id="quran_ref_373307" class="regexed quran_ref" data-id="373307">53:60</a>)',
            '“And yet sport ye (negligently)” (53:61)'
        )
        html_clean = html_clean.replace(
            '“Therefore, prostrate ye in obeisance unto God and worship Him (alone)” (<a href="#quran_ref_373307" id="quran_ref_373307" class="regexed quran_ref" data-id="373307">53:60</a>)',
            '“Therefore, prostrate ye in obeisance unto God and worship Him (alone)” (53:62)'
        )
    elif juz_num == 30:
        # Typo 84:61 in place of 84:16
        html_clean = html_clean.replace('(84:61)', '(84:16)').replace('>84:61<', '>84:16<')
        # Surah At-Tin: 95:3 mislabeled as 95:1, and 95:4 mislabeled as 95:3
        html_clean = re.sub(r'(And by this City \(declared\) Inviolate!?[^)]*?)\(\s*<a[^>]*>95:1</a>\s*\)', r'\1(95:3)', html_clean)
        html_clean = re.sub(r'(Indeed, We created man in the best structure[^)]*?)\(\s*<a[^>]*>95:3</a>\s*\)', r'\1(95:4)', html_clean)

    # Normalize split reference tags like (<a ...>3</a><a ...>2:1</a>) -> (32:1)
    def clean_ref_parens(m):
        inner = re.sub(r'<[^>]+>', '', m.group(1)).strip()
        return f'({inner})'
    html_clean = re.sub(r'\(([^\)]*?\d+:\d+[^\)]*?)\)', clean_ref_parens, html_clean)
    
    valid_surahs = JUZ_SURAHS.get(juz_num, [])
    
    # Match blockquotes containing Arabic verses and extract following translation chunks
    bq_matches = list(re.finditer(r'<blockquote\s+class=\"rtl\">\s*<p>(.*?)</p>\s*</blockquote>', html_clean, re.DOTALL | re.IGNORECASE))
    for i, bq in enumerate(bq_matches):
        start_pos = bq.end()
        end_pos = bq_matches[i+1].start() if (i+1 < len(bq_matches)) else len(html_clean)
        h2_match = re.search(r'<h[12][^>]*>', html_clean[start_pos:end_pos], re.IGNORECASE)
        if h2_match:
            end_pos = start_pos + h2_match.start()
            
        chunk = html_clean[start_pos:end_pos]
        ref_matches = list(re.finditer(r'\(\s*(\d+:\d+)\s*\)', chunk))
        last_idx = 0
        for m_ref in ref_matches:
            ref = m_ref.group(1)
            surah_num = int(ref.split(':')[0])
            if surah_num in valid_surahs:
                raw_text = chunk[last_idx:m_ref.start()]
                last_idx = m_ref.end()
                cleaned = clean_verse_text(raw_text)
                if cleaned and ref not in found:
                    found[ref] = cleaned

    return found

def get_juz_html(juz_num):
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_file = os.path.join(CACHE_DIR, f'juz_{juz_num}.html')
    if os.path.exists(cache_file):
        with open(cache_file, 'r', encoding='utf-8') as f:
            return f.read()

    juz_url = f'https://al-islam.org/holy-quran-final-testament-juz-{juz_num}-mirza-mahdi-pooya-sv-mir-ahmad-ali'
    print(f"Fetching Juz {juz_num} landing page...")
    page_html = fetch_url(juz_url)
    
    export_url = None
    if page_html:
        m = re.search(r'href=\"(/book/export/html/\d+)\"', page_html)
        if not m:
            m = re.search(r'href=\"(/printpdf/book/export/html/(\d+))\"', page_html)
            if m:
                export_url = f"https://al-islam.org/book/export/html/{m.group(2)}"
        else:
            export_url = f"https://al-islam.org{m.group(1)}"

    if not export_url:
        print(f"  Warning: Could not find export URL for Juz {juz_num} on {juz_url}")
        return None

    print(f"  Downloading export HTML for Juz {juz_num} from {export_url}...")
    export_html = fetch_url(export_url)
    if export_html:
        with open(cache_file, 'w', encoding='utf-8') as f:
            f.write(export_html)
        return export_html
    return None

def main():
    all_verses = {}
    total_expected = sum(SURAH_VERSE_COUNTS)
    
    for juz in range(1, 31):
        print(f"Processing Juz {juz}/30...")
        html = get_juz_html(juz)
        if not html:
            print(f"  Failed to retrieve HTML for Juz {juz}")
            continue

        juz_verses = parse_verses_from_juz(juz, html)
        print(f"  Parsed {len(juz_verses)} verses from Juz {juz}")
        
        for ref, trans in juz_verses.items():
            if ref not in all_verses:
                all_verses[ref] = trans
            
    # Fix typo in 1:2 if present
    if '1:2' in all_verses and 'the of the worlds' in all_verses['1:2']:
        all_verses['1:2'] = all_verses['1:2'].replace('the of the worlds', 'the Lord of the worlds')

    # Save to JSON
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(all_verses, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 60)
    print(f"EXTRACTION COMPLETE: {len(all_verses)}/{total_expected} verses saved to {OUTPUT_PATH}")
    print("=" * 60)

    # Validate against expected counts
    missing = []
    for s_idx, count in enumerate(SURAH_VERSE_COUNTS):
        surah_num = s_idx + 1
        for a_num in range(1, count + 1):
            ref = f"{surah_num}:{a_num}"
            if ref not in all_verses:
                missing.append(ref)

    if missing:
        print(f"WARNING: {len(missing)} verses missing:")
        print(missing[:50])
    else:
        print("ALL 6,236 VERSES ACROSS 114 SURAHS SUCCESSFULLY EXTRACTED!")

if __name__ == '__main__':
    main()
