"""Map Indo-Pak waqf marks from the zikr file's Arabic line onto Tanzil word indices."""
import re, difflib, collections, functools
from common import ayah_lines, tanzil

SKEL = set('بتثجحخدذرزسشصضطظعغفقكلمنهوي')
NORM = {'ک': 'ك', 'ڪ': 'ك', 'ی': 'ي', 'ى': 'ي', 'ۃ': 'ه', 'ة': 'ه', 'ہ': 'ه', 'ھ': 'ه', 'ٮ': 'ي', 'ۓ': 'ي', 'ے': 'ي'}
WAQF = {'ۚ': 'jeem', 'ؕ': 'toa', 'ۙ': 'laa', 'ۖ': 'salaa', 'ۗ': 'qalaa',
        'ۘ': 'meem', 'ۛ': 'muanaqa', 'ؗ': 'zay', 'ؔ': 'u614'}
for _c in (0xe022, 0xe01a, 0xe01b, 0xe01c, 0xe01e, 0xe021, 0xe01f, 0xe003, 0xe004):
    WAQF[chr(_c)] = 'p%x' % _c


def skel(s):
    out = []
    for ch in s:
        ch = NORM.get(ch, ch)
        if ch in SKEL:
            out.append(ch)
    return out


@functools.lru_cache(maxsize=None)
def file_arabic(s):
    L, al = ayah_lines(s)
    return {a: L[i] for a, i in al}


def indopak_marks(s, a, tan_words):
    """tan_words: list of tanzil word strings (no pause tokens).
    Returns {word_index(0-based): set(marks)} for marks after that word."""
    line = file_arabic(s).get(a)
    if line is None:
        return {}
    line = re.sub(r'\(\d+\)\s*$', '', line)
    # skeleton of indopak with mark positions
    isk = []
    marks = []
    for ch in line:
        if ch in WAQF:
            marks.append((len(isk), WAQF[ch]))
        else:
            c = NORM.get(ch, ch)
            if c in SKEL:
                isk.append(c)
    tsk = []
    wend = []
    for wi, w in enumerate(tan_words):
        tsk.extend(skel(w))
        wend.append(len(tsk))
    sm = difflib.SequenceMatcher(a=isk, b=tsk, autojunk=False)
    blocks = sm.get_matching_blocks()

    def map_pos(p):
        # map indopak position p (number of skeleton chars before) to tanzil count
        best = None
        for b in blocks:
            if b.a <= p <= b.a + b.size:
                return b.b + (p - b.a)
            if b.a + b.size <= p:
                best = b.b + b.size
        return best if best is not None else 0

    res = collections.defaultdict(set)
    for p, m in marks:
        tp = map_pos(p)
        # find word whose end is nearest to tp
        wi = min(range(len(wend)), key=lambda i: abs(wend[i] - tp))
        if abs(wend[wi] - tp) <= 1:
            res[wi].add(m)
    return res
