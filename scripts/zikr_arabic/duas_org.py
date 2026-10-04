"""Pull a du'a from duas.org's v2 data store and draft house-style triplets.

duas.org's current pages are a JavaScript shell; the content lives in
https://www.duas.org/data_v2/<page-id>.json as a list of blocks, each dua
block holding `segments` of {arabic, transliteration, translation}. Its
transliteration is a different (lowercase) style, and its Arabic has lost
most hamza vowels (the old site's private-use hamza glyph was dropped), so
this script:

  1. fetches the page (or searches data_v2/search_index.json for one),
  2. reconciles each Arabic word against our own historic text for that uid
     (assets/items/<uid> in git history) - where the consonant skeleton
     matches and history carries more vowel marks, history wins,
  3. prints Arabic / house-style transliteration (translit.py) / English.

The output is a draft. Bare alifs that history could not fix still need a
human pass (see "Friday-night rites" in scripts/RESTORING_MISSING_ZIKRS.md
for how to tell hamzat al-wasl from a lost hamza), and every line must be
read against the Arabic before it ships.

    python3 scripts/zikr_arabic/duas_org.py search "ya shahida"
    python3 scripts/zikr_arabic/duas_org.py blocks dua-man-taaba-tahiaya
    python3 scripts/zikr_arabic/duas_org.py draft dua-man-taaba-tahiaya 0 --history P9
"""
import difflib
import html
import json
import os
import re
import subprocess
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from translit import transliterate  # noqa: E402

BASE = 'https://www.duas.org/data_v2/'


def fetch(name):
    # duas.org answers 403 to Python's default User-Agent
    req = urllib.request.Request(BASE + name, headers={'User-Agent': 'curl/8'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode('utf-8'))


def clean(s):
    return ' '.join(html.unescape(re.sub(r'<[^>]+>', ' ', s or '')).replace('`', "'").split())


def history_words(uid):
    """Arabic words of assets/items/<uid> as it was just before deletion."""
    c = subprocess.check_output(['git', 'log', '--all', '--diff-filter=D', '--format=%H', '--',
                                 'assets/items/' + uid], text=True).split()
    if not c:
        return []
    t = json.loads(subprocess.check_output(['git', 'show', c[0] + '^:assets/items/' + uid], text=True))['content']
    t = re.sub(r'\[[^\]]*\]', ' ', t)            # bracketed alternate readings
    return [w for b in t.split('--') if re.search('[؀-ۿ]', b)
            for w in b.split() if re.search('[ء-ي]', w)]


def skeleton(w):
    w = re.sub('[أإآٱ]', 'ا', w).replace('ى', 'ي').replace('ؤ', 'و').replace('ئ', 'ي').replace('ء', '')
    return re.sub(r'[^ء-ي]', '', w)


def marks(w):
    return len(re.findall('[ً-ْٰ]', w))


def reconcile(lines, hist):
    """Take the historic spelling of each aligned word when it is better vowelled."""
    flat = [(li, wi, w) for li, l in enumerate(lines) for wi, w in enumerate(l.split())]
    words = [l.split() for l in lines]
    sm = difflib.SequenceMatcher(None, [skeleton(w) for _, _, w in flat], [skeleton(w) for w in hist], autojunk=False)
    taken = 0
    for tag, i1, i2, j1, _ in sm.get_opcodes():
        if tag != 'equal':
            continue
        for k in range(i2 - i1):
            li, wi, w = flat[i1 + k]
            h = hist[j1 + k]
            # keep the Indo-Pak waṣl-after-tanween spelling (۟اِلْ) out: it turns waṣl into hamza
            if '۟' in h or re.match('^[ء-ي]?[َِ]?اِ?ل', h):
                continue
            if marks(h) > marks(w):
                words[li][wi] = re.sub('[ٖٗ]', lambda m: 'ِ' if m.group(0) == 'ٖ' else 'ُ', h)
                taken += 1
    return [' '.join(w) for w in words], taken


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    cmd = argv[0]
    if cmd == 'search':
        q = ' '.join(argv[1:]).lower()
        for e in fetch('search_index.json'):
            if q in (e['id'] + ' ' + e.get('title', '') + ' ' + e.get('description', '')).lower():
                print(f"{e['indexType']:5} {e['id']:55} {e.get('title', '')}")
        return 0
    page = fetch(argv[1] + '.json')
    blocks = page.get('duas', [])
    if cmd == 'blocks':
        for i, b in enumerate(blocks):
            print(f"[{i}] {b.get('type')} | {b.get('title') or ''} | {len(b.get('segments') or [])} segments")
            for f in ('description', 'content'):
                if b.get(f):
                    print('     ' + clean(b[f])[:300])
        return 0
    if cmd == 'draft':
        idx = [int(x) for x in argv[2].split(',')]
        hist = history_words(argv[argv.index('--history') + 1]) if '--history' in argv else []
        segs = [s for i in idx for s in blocks[i].get('segments') or []]
        arabic = [' '.join(s['arabic'].replace('ٱ', 'ا').split()) for s in segs]
        if hist:
            arabic, n = reconcile(arabic, hist)
            print(f'# {n} words taken from history', file=sys.stderr)
        for a, s in zip(arabic, segs):
            print(a)
            print(transliterate(a))
            print(clean(s.get('translation')) or '<<NO ENGLISH>>')
        return 0
    print(__doc__)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
