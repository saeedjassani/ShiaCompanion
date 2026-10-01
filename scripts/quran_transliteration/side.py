import sys
from common import ground_truth, tanzil
import render
from harness import toks
gt = ground_truth()
s = int(sys.argv[1])
rng = range(int(sys.argv[2]), int(sys.argv[3]) + 1) if len(sys.argv) > 3 else range(1, 300)
for a in rng:
    if (s, a) not in gt: continue
    e = render.transliterate(s, a)
    mark = '  ' if toks(e) == toks(gt[(s, a)]) else '!!'
    print(mark, a, 'ENG', e)
    if mark == '!!':
        print('     GT ', gt[(s, a)])
