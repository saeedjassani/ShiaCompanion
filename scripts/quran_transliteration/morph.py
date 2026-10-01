"""Per-word prefix segmentation from the Quranic Arabic Corpus morphology.

The data file is not committed (GPL, 6 MB); it is downloaded on first use
into this directory and git-ignored.
"""
import collections, os, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
MORPH_URL = 'https://raw.githubusercontent.com/mustafa0x/quran-morphology/master/quran-morphology.txt'


def _ensure():
    path = os.path.join(HERE, 'morph.txt')
    if not os.path.exists(path):
        urllib.request.urlretrieve(MORPH_URL, path)
    return path

PREFIX_TAGS = {'CONJ', 'REM', 'P', 'EMPH', 'INTG', 'RSLT', 'CIRC', 'SUP', 'PRP',
               'VOC', 'FUT', 'CAUS', 'IMPV', 'PRO', 'EQ', 'RES', 'SUB', 'ATT', 'COND',
               'DET', 'INC', 'EXP', 'EXL', 'INT', 'NEG', 'ANS', 'AMD', 'RET', 'EXH',
               'SUR', 'PREV', 'INL', 'T'}

_cache = None

def load():
    """{(s,a,w): [(seg_text, tag, kind)]} where kind in PREF/STEM/SUFF"""
    global _cache
    if _cache is not None: return _cache
    d = collections.defaultdict(list)
    for l in open(_ensure(), encoding='utf-8'):
        p = l.rstrip('\n').split('\t')
        if len(p) < 4 or ':' not in p[0]: continue
        s, a, w, g = map(int, p[0].split(':'))
        feats = p[3].split('|')
        kind = 'PREF' if 'PREF' in feats else ('SUFF' if 'SUFF' in feats else 'STEM')
        d[(s, a, w)].append((p[1], feats[0], kind, p[2], feats))
    _cache = d
    return d
