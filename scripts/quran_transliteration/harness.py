import sys, re, collections, difflib
from common import ground_truth, tanzil
import render

COMMAS = False
PHON = False

def norm(s):
    s = s.upper()
    s = s.replace('‘', '’').replace("'", '’').replace('`', '’').replace('‛', '’')
    s = re.sub(r'\s*,', ' ,', s) if COMMAS else s
    s = re.sub(r'[.;:!?"“”()\[\]]' if COMMAS else r'[.,;:!?"“”()\[\]]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s

def toks(s):
    return norm(s).split()

def main(show=40, only=None):
    gt = ground_truth()
    tot = 0; ok = 0; exact = 0; n = 0
    pairs = collections.Counter()
    ex = {}
    for k in sorted(gt):
        if only and k[0] not in only: continue
        if (k[0], k[1]) in render.MUQATTAAT: continue
        try:
            out = render.transliterate(*k)
        except Exception as e:
            print('ERR', k, e); raise
        a, b = toks(out), toks(gt[k])
        n += 1
        if a == b: exact += 1
        sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op == 'equal':
                ok += i2 - i1
            else:
                if PHON and ''.join(a[i1:i2]).replace('-', '') == ''.join(b[j1:j2]).replace('-', ''):
                    ok += j2 - j1
                    continue
                key = (' '.join(a[i1:i2]), ' '.join(b[j1:j2]))
                pairs[key] += 1
                ex.setdefault(key, k)
        tot += len(b)
    print(f'ayat {n} exact {exact} ({exact/n:.1%})  tokens {ok}/{tot} ({ok/tot:.1%})')
    for (x, y), c in pairs.most_common(show):
        print(c, repr(x), '=>', repr(y), ex[(x, y)])

if __name__ == '__main__':
    show = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    if len(sys.argv) > 2 and 'c' in sys.argv[2]:
        COMMAS = True
    if len(sys.argv) > 2 and 'p' in sys.argv[2]:
        PHON = True
    main(show)
