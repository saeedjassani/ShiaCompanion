import json, re, os
WT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..') + os.sep
ROOT = WT + 'assets/zikr/'

def isar(s): return any('؀' <= c <= 'ۿ' for c in s[:35])

def ttype(s):
    if not s.strip(): return 'E'
    letters = [c for c in s if c.isalpha()]
    if not letters: return 'N'
    up = sum(c.isupper() for c in letters)
    return 'T' if up > 0.8 * len(letters) else 'N'

AYAH_RE = re.compile(r'\((\d+)\)\s*$')

def load_surah(s):
    d = json.load(open(f"{ROOT}A{s+4}"))
    return d

def ayah_lines(s):
    """yield (ayah_no, line_index, lines) for each arabic ayah line"""
    d = load_surah(s)
    L = d['data'].split('\n')
    out = []
    for i, l in enumerate(L):
        if isar(l):
            m = AYAH_RE.search(l)
            if m:
                out.append((int(m.group(1)), i))
    return L, out

def ground_truth():
    gt = {}
    for s in range(1, 115):
        L, al = ayah_lines(s)
        for a, i in al:
            if i + 1 < len(L) and ttype(L[i+1]) == 'T':
                gt[(s, a)] = L[i+1]
    return gt

def tanzil():
    t = {}
    for line in open(WT + 'assets/quran/tanzil-uthmani.txt', encoding='utf-8'):
        p = line.rstrip('\n').split('|')
        if len(p) == 3 and p[0].isdigit():
            s, a, txt = int(p[0]), int(p[1]), p[2]
            if a == 1 and s not in (1, 9):
                w = txt.split(' ')
                if w[0].startswith('بِسْم'):
                    txt = ' '.join(w[4:])
            t[(s, a)] = txt
    return t
