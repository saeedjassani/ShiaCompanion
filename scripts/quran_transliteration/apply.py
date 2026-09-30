"""Fill the empty transliteration slot of every ayah in the given surahs.

    python3 scripts/quran_transliteration/apply.py 4 [5 6 ...]

Only a blank line directly under an ayah's Arabic line is filled; existing
(hand-made) transliterations are never touched.
"""
import json, sys
from common import ROOT, ayah_lines, ttype
import render


def apply(s):
    path = f'{ROOT}A{s+4}'
    d = json.load(open(path, encoding='utf-8'))
    L, al = ayah_lines(s)
    n = 0
    for a, i in al:
        if i + 1 < len(L) and ttype(L[i + 1]) == 'E':
            L[i + 1] = render.transliterate(s, a)
            n += 1
    d['data'] = '\n'.join(L)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(f'surah {s}: filled {n} ayat')


if __name__ == '__main__':
    for arg in sys.argv[1:]:
        apply(int(arg))
