#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Work the corpus batch by batch.

  python3 scripts/zikr_arabic/batch.py status
  python3 scripts/zikr_arabic/batch.py next [n]     propose the next batch
  python3 scripts/zikr_arabic/batch.py plan <uid…>  full report + patch for named zikr

Anywhere a uid list is taken, a range works too: `E1-E50` (or `E1-50`) expands
to every existing E1…E50. That is the normal way to run a batch — a contiguous
stretch of one prefix, in order.
  python3 scripts/zikr_arabic/batch.py done <uid…>  mark applied in the ledger

`next` walks the corpus in natural uid order, so batches are sequential
stretches rather than a scattered worst-first list. Quran surah zikr (every
`A<n>` uid) are excluded from every editing pass — that text is mushaf
orthography from a different source. They are still checked by `audit.py`,
because they still ship and still have to render.
"""
import sys, os, json, re, collections, datetime
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import ROOT, load_corpus, arabic_strings, normalize_source, uid_key
import silah as silah_mod
import vowelgap as vowel_mod

LEDGER = os.path.join(ROOT, 'scripts/zikr_arabic/ledger.json')

def load_ledger():
    if os.path.exists(LEDGER):
        return json.load(open(LEDGER, encoding='utf-8'))
    return {}

def save_ledger(l):
    json.dump(l, open(LEDGER, 'w', encoding='utf-8'), ensure_ascii=False, indent=1, sort_keys=True)

RANGE = re.compile(r'^([A-Za-z]+)(\d+)\s*-\s*(?:[A-Za-z]+)?(\d+)$')

def expand(args):
    """Expand range tokens like E1-E50 into the uids that actually exist.

    Alias uids (`alias|target`) are deliberately NOT pulled in. The app resolves
    them with UidTitleData.getFirstUId(), which is `uid.split("|").last`, so an
    alias always reads the target's content, and build_zikr_release.js emits no
    asset file for one. A few alias docs still carry a stale `data` field in
    Firestore; nothing reads it."""
    have = {u for u, _ in load_corpus(include_quran=True)}
    out = []
    for a in args:
        m = RANGE.match(a)
        if m:
            pre, lo, hi = m.group(1), int(m.group(2)), int(m.group(3))
            out += [u for u in (f'{pre}{i}' for i in range(lo, hi + 1)) if u in have]
        else:
            out.append(a)
    return out

def titles():
    return {uid: str(doc.get('title', uid)) for uid, doc in load_corpus()}

def pending(uids=None):
    """{uid: {'norm': n, 'silah': n, 'review': n}} for zikr with work outstanding."""
    out = collections.defaultdict(lambda: collections.Counter())
    for uid, path, s in arabic_strings(uids):
        new, changes = normalize_source(s)
        if new != s:
            out[uid]['norm'] += sum(s.count(a) for a, _ in changes)
        for ch in 'أإٴ':
            if ch in new:
                out[uid]['review'] += new.count(ch)
    for r in silah_mod.fixes(uids):
        out[r['uid']]['silah'] += 1
    return {u: c for u, c in out.items() if sum(c.values())}

def cmd_status():
    led, t = load_ledger(), titles()
    p = pending()
    done = {u for u, v in led.items() if v.get('state') == 'applied'}
    print(f'editable zikr     {len(t)}   (Quran surahs excluded entirely)')
    print(f'applied           {len(done)}')
    print(f'outstanding       {len(p)} zikr, {sum(sum(c.values()) for c in p.values())} changes')
    tot = collections.Counter()
    for c in p.values():
        tot.update(c)
    print(f'\nby kind: normalize {tot["norm"]}   silah {tot["silah"]}   needs-review {tot["review"]}')

def cmd_next(n=10):
    """Next n zikr with work outstanding, in natural uid order — batches run
    sequentially through the corpus (AA1…, then AC1…, … E1…) so a batch is a
    contiguous stretch someone can actually read end to end."""
    led, t = load_ledger(), titles()
    p = pending()
    cand = [(u, c) for u, c in sorted(p.items(), key=lambda x: uid_key(x[0]))
            if led.get(u, {}).get('state') != 'applied']
    batch = cand[:n]
    if not batch:
        print('nothing outstanding')
        return
    print(f'next batch: {batch[0][0]} → {batch[-1][0]}  '
          f'({len(batch)} zikr, {sum(sum(c.values()) for _, c in batch)} changes)\n')
    print(f'{"uid":<7} {"norm":>5} {"silah":>6} {"rev":>4}  title')
    for u, c in batch:
        print(f'{u:<7} {c["norm"]:>5} {c["silah"]:>6} {c["review"]:>4}  {t.get(u, "")[:52]}')
    print(f'\n  python3 scripts/zikr_arabic/batch.py plan {" ".join(u for u, _ in batch)}')

def cmd_range(uids):
    """Report on an explicit range, whether or not the zikr need work."""
    t, p = titles(), pending(set(uids))
    todo = [u for u in uids if u in p]
    print(f'{uids[0]} → {uids[-1]}: {len(uids)} zikr exist, {len(todo)} need work, '
          f'{sum(sum(p[u].values()) for u in todo)} changes\n')
    print(f'{"uid":<7} {"norm":>5} {"silah":>6} {"rev":>4}  title')
    for u in todo:
        c = p[u]
        print(f'{u:<7} {c["norm"]:>5} {c["silah"]:>6} {c["review"]:>4}  {t.get(u, "")[:52]}')
    print(f'\n  python3 scripts/zikr_arabic/batch.py plan {uids[0]}-{uids[-1]}')

def cmd_plan(uids):
    t = titles()
    patch = collections.defaultdict(list)
    for uid, path, s in arabic_strings(set(uids)):
        new, _ = normalize_source(s)
        if new != s:
            patch[uid].append({'path': list(path), 'before': s, 'after': new})
    # silah runs ON the normalized text, never alongside it -- see
    # silah.apply_to_text for why the order matters.
    for uid, path, s in arabic_strings(set(uids)):
        entry = next((e for e in patch.get(uid, []) if tuple(e['path']) == tuple(path)), None)
        base = entry['after'] if entry else s
        after = silah_mod.apply_to_text(base)
        if after == base:
            continue
        if entry:
            entry['after'] = after
        else:
            patch[uid].append({'path': list(path), 'before': s, 'after': after})

    # vowel fills last: they act on word-initial alif, which normalization
    # has already settled. Only the buckets cleared for action are applied --
    # leave-wasl-vowel and no-precedent never are.
    fills = collections.defaultdict(list)
    for r in vowel_mod.proposals(set(uids)):
        if r['state'] in vowel_mod.ACTIONABLE and r['after']:
            fills[r['uid']].append((r['word'], r['after']))
    def replace_words(text, pairs):
        """Whole-token replacement. A plain str.replace would also rewrite any
        longer word the token is a prefix of -- fixing ازَلِ would silently
        change ازَلِيٌّ, which is in a bucket nobody approved. Tokenise on all
        whitespace, not just spaces: these fields carry newlines between the
        Arabic and its translation, so a space-only split leaves the first and
        last word of every line glued to a newline and unmatchable.
        """
        table = dict(pairs)
        return re.sub(r'\S+', lambda m: table.get(m.group(0), m.group(0)), text)

    for uid, pairs in fills.items():
        for uid2, path, raw in arabic_strings({uid}):
            entry = next((e for e in patch.get(uid, []) if tuple(e['path']) == tuple(path)), None)
            base = entry['after'] if entry else raw
            after = replace_words(base, pairs)
            if after == base:
                continue
            if entry:
                entry['after'] = after
            else:
                patch.setdefault(uid, []).append(
                    {'path': list(path), 'before': raw, 'after': after})

    patch = {u: v for u, v in patch.items() if v}
    out = os.path.join(ROOT, 'scripts/zikr_arabic/.patch.json')
    json.dump(patch, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    for uid in uids:
        if uid in patch:
            print(f'{uid:<9} {len(patch[uid]):>2} field(s)  {t.get(uid, "")[:50]}')
    print(f'\npatch -> {out}')
    print('  node scripts/zikr_arabic/backup.js')
    print(f'  node scripts/zikr_arabic/apply_patch.js {out} --dry-run')

def cmd_done(uids):
    led = load_ledger()
    today = datetime.date.today().isoformat()
    for u in uids:
        led[u] = {'state': 'applied', 'date': today}
    save_ledger(led)
    print(f'{len(uids)} marked applied in {LEDGER}')

def main(argv):
    if not argv or argv[0] == 'status':
        return cmd_status()
    cmd, rest = argv[0], argv[1:]
    if cmd == 'next':
        if rest and RANGE.match(rest[0]):
            return cmd_range(expand(rest))
        return cmd_next(int(rest[0]) if rest and rest[0].isdigit() else 10)
    if cmd == 'plan':
        return cmd_plan(expand(rest))
    if cmd == 'done':
        return cmd_done(expand(rest))
    print(__doc__)
    return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]) or 0)
