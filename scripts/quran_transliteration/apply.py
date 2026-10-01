"""Fill the empty transliteration slot of every ayah in the given surahs.

    python3 scripts/quran_transliteration/apply.py 4 [5 6 ...]
    python3 scripts/quran_transliteration/apply.py all

Only a blank (or placeholder) line directly under an ayah's Arabic line is
filled; existing hand-made transliterations are never touched. Files laid
out as Arabic + translation only (no slot) get a slot inserted under every
Arabic line, which switches them to the three-line layout.
"""
import json, sys
from common import ROOT, ayah_lines, ttype, isar
import render

BISMILLAH = 'BISMIL LAAHIR RAHMAANIR RAHEEM'
PLACEHOLDERS = {'???', '38:'}
# Hand-made lines that were cut off mid-ayah; regenerated whole.
TRUNCATED = {(41, 37)}
# Hand-made but mis-cased; normalised to the house style.
OVERRIDES = {(26, 1): 'TAA SIM MEEM.'}


def is_slot(line):
    return ttype(line) == 'E' or line.strip() in PLACEHOLDERS


def apply(s):
    path = f'{ROOT}A{s+4}'
    d = json.load(open(path, encoding='utf-8'))
    L, al = ayah_lines(s)
    ayah_at = {i: a for a, i in al}
    arabic = [i for i, l in enumerate(L) if isar(l)]
    gaps = [b - a for a, b in zip(arabic, arabic[1:])]
    two_line = gaps and max(set(gaps), key=gaps.count) == 2
    n = 0
    if two_line:
        out = []
        for i, l in enumerate(L):
            out.append(l)
            if isar(l):
                out.append(render.transliterate(s, ayah_at[i]) if i in ayah_at else BISMILLAH)
                n += 1
        L = out
    else:
        for a, i in al:
            if (s, a) in OVERRIDES:
                L[i + 1] = OVERRIDES[(s, a)]
                n += 1
            elif i + 1 < len(L) and (is_slot(L[i + 1]) or (s, a) in TRUNCATED):
                L[i + 1] = render.transliterate(s, a)
                n += 1
    d['data'] = '\n'.join(L)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(f'surah {s}: filled {n} lines{" (converted to 3-line)" if two_line else ""}')


if __name__ == '__main__':
    args = sys.argv[1:]
    surahs = range(1, 115) if args == ['all'] else [int(x) for x in args]
    for s in surahs:
        apply(s)
