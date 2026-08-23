#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Source normalization: bring stored zikr text to the canonical inventory.

Emits a patch (JSON) rather than editing anything, because assets/zikr/* is
generated from Firestore by scripts/build_zikr_release.js -- editing the assets
directly would be overwritten on the next build. Apply the patch with
scripts/zikr_arabic/apply.py.

Usage:
  python3 scripts/zikr_arabic/normalize.py                 # whole corpus, summary
  python3 scripts/zikr_arabic/normalize.py G13 E34         # named zikr
  python3 scripts/zikr_arabic/normalize.py --out patch.json
  python3 scripts/zikr_arabic/normalize.py --show G13      # print changed lines
"""
import sys, json, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import RULES, arabic_strings, normalize_source, AR

def _clean(d):
    return {k: v for k, v in d.items() if not k.startswith('_')}

def build(uids=None):
    patch = collections.defaultdict(list)
    counts = collections.Counter()
    review = collections.Counter()
    rq = set(_clean(RULES['source_normalization']['review_required']))
    for uid, path, s in arabic_strings(uids):
        new, changes = normalize_source(s)
        if new != s:
            patch[uid].append({'path': list(path), 'before': s, 'after': new})
            for a, b in changes:
                counts[(a, b)] += s.count(a)
        for ch in rq:
            if ch in new:
                review[(uid, ch)] += new.count(ch)
    return dict(patch), counts, review

def main(argv):
    out = None
    show = False
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == '--out':
            out = argv[i + 1]; i += 2
        elif argv[i] == '--show':
            show = True; i += 1
        else:
            args.append(argv[i]); i += 1
    uids = set(args) or None

    patch, counts, review = build(uids)
    total = sum(counts.values())
    print(f'{total} substitutions in {len(patch)} zikr\n')
    for (a, b), n in counts.most_common():
        print(f'   {a!r} -> {b!r:<8} x{n}')

    if review:
        print(f'\nneeds a human decision ({sum(review.values())} occurrences, '
              f'{len({u for u, _ in review})} zikr) -- not in the patch:')
        rq = _clean(RULES['source_normalization']['review_required'])
        by_ch = collections.Counter()
        for (uid, ch), n in review.items():
            by_ch[ch] += n
        for ch, n in by_ch.most_common():
            zs = sorted({u for u, c in review if c == ch})
            print(f'   {ch!r} x{n} in {len(zs)} zikr: {", ".join(zs[:12])}'
                  f'{" ..." if len(zs) > 12 else ""}')
            print(f'        {rq[ch]}')

    if show:
        for uid, edits in patch.items():
            for e in edits:
                for lb, la in zip(e['before'].split('\n'), e['after'].split('\n')):
                    if lb != la and AR.search(lb):
                        print(f'\n{uid}  - {lb.strip()[:100]}\n{" " * len(uid)}  + {la.strip()[:100]}')

    if out:
        json.dump(patch, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'\npatch -> {out}')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
