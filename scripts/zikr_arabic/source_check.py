"""source_check.py - check restored zikr entries against their source.

Usage:
  python3 -I scripts/zikr_arabic/source_check.py . E146 E112   # report
  python3 -I scripts/zikr_arabic/source_check.py . baseline    # accept flags
  python3 -I scripts/zikr_arabic/source_check.py . snapshot    # needs history

For each uid: every Arabic line shipped must appear in the source (old item +
pre-purge zikr file + any entry it links), and every source Arabic block
must appear in the entry or in an entry it links to.

The source of a restored uid lives only in git history (`001aa3ad`'s
`assets/items/<uid>` and `8c5f8258^`'s `assets/zikr/<uid>`), which shallow
clones and CI don't have. So:

- `snapshot` (needs `git fetch --unshallow`) writes every restored uid's
  source, normalized, to `source_snapshot.json`. A uid is "restored" when it
  existed before the purge (`8c5f8258`), was gone after it, and is in
  `assets/zikr/` now. History doesn't change, so only rerun this after
  restoring more uids.
- The report reads that snapshot, so it works without history too; a uid not
  in it falls back to git.
- `baseline` records what the check flags today in `source_baseline.json`:
  lines whose source is elsewhere (duas.org, Wikisource, Iqbal), cited typo
  fixes, gaps not yet filled. `test/zikr_source_check_test.dart` fails on any
  flag not in it, and on any entry in it that no longer fires. After a
  deliberate edit to a restored entry: run the report on it, read what it
  flags, then run `baseline` and commit both.

`norm`, `cov` and the per-entry check are ported to
`test/zikr_source_check_test.dart`; keep the two in step.
"""
import hashlib, html, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOT = os.path.join(HERE, 'source_snapshot.json')
BASELINE = os.path.join(HERE, 'source_baseline.json')
PURGE = '8c5f8258'
OLD_ITEMS = '001aa3ad'
MIN_LEN = 12      # normalized letters; shorter lines/blocks aren't checked
THRESHOLD = 0.85  # share of a line's 8-letter shingles that must be found


def norm(s):
    s = html.unescape(html.unescape(s)).replace('ﷲ', 'الله')
    s = re.sub(r'[ً-ٰٟۖ-ۭـؐ-ؚ‌‍‏۔۔]', '', s)
    for a, b in [('ٱ', 'ا'), ('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ى', 'ي'), ('ة', 'ه'), ('ہ', 'ه'),
                 ('ھ', 'ه'), ('ی', 'ي'), ('ې', 'ي'), ('ک', 'ك'), ('ؤ', 'و'), ('ئ', 'ي'), ('ء', '')]:
        s = s.replace(a, b)
    return re.sub(r'[^ء-ي]', '', s)


def hay(*texts):
    """Normalized texts to search, kept apart so no shingle spans two.

    Lines inside one text are joined, since a source block is often split
    over several lines of the entry."""
    return '|'.join(norm(t) for t in texts)


def cov(n, hay, k=8, st=3):
    sh = [n[j:j + k] for j in range(0, max(1, len(n) - k + 1), st)]
    return sum(x in hay for x in sh) / len(sh)


def key(n):
    """Baseline id of a normalized line or block."""
    return hashlib.sha1(n.encode()).hexdigest()[:12]


def git(root, *args):
    try:
        return subprocess.check_output(['git', '-C', root, *args], stderr=subprocess.DEVNULL).decode()
    except subprocess.CalledProcessError:
        return ''


def entry_text(d):
    return '\n'.join([d.get('data', '')] + list(d.get('tabs', []) or []))


def links(t):
    return re.findall(r'\]\(([A-Z]+\d+)\)', t)


def load_json(path):
    return json.load(open(path)) if os.path.exists(path) else {}


def source_blocks(src):
    """The `--`-delimited Arabic blocks of an old item, normalized."""
    parts = re.split(r'--', src)
    blocks = parts[1::2]
    # an unterminated final block counts too
    if len(parts) % 2 == 0:
        blocks.append(parts[-1])
    return [n for n in map(norm, blocks) if len(n) >= MIN_LEN]


def source_from_git(root, uid):
    old_raw = git(root, 'show', f'{OLD_ITEMS}:assets/items/{uid}')
    src = html.unescape(html.unescape(json.loads(old_raw)['content'])) if old_raw else ''
    pre = git(root, 'show', f'{PURGE}^:assets/zikr/{uid}')
    return {'source': hay(src, pre), 'blocks': source_blocks(src)}


def check(root, uid, source):
    """(entry, flagged lines, missing blocks) - each flag (coverage, key, preview)."""
    d = json.load(open(os.path.join(root, 'assets/zikr', uid)))
    t = entry_text(d)
    linked = links(t) + links(d.get('merits', ''))
    linked_texts = []
    for l in sorted(set(linked)):
        p = os.path.join(root, 'assets/zikr', l)
        if os.path.exists(p):
            linked_texts.append(entry_text(json.load(open(p))))
    hay_src = '|'.join([source['source'], hay(*linked_texts)])
    hay_new = hay(t, *linked_texts)
    bad, seen = [], set()
    for l in t.split('\n'):
        n = norm(l)
        if len(n) < MIN_LEN or key(n) in seen:
            continue
        seen.add(key(n))
        c = cov(n, hay_src)
        if c < THRESHOLD:
            bad.append((round(c, 2), key(n), l.strip()[:70]))
    missing, seen = [], set()
    for n in source['blocks']:
        if key(n) in seen:
            continue
        seen.add(key(n))
        c = cov(n, hay_new)
        if c < THRESHOLD:
            missing.append((round(c, 2), key(n), n[:70]))
    return d, sorted(set(linked)), bad, missing


def restored_uids(root):
    def ls(tree, d):
        out = git(root, 'ls-tree', '--name-only', f'{tree}:{d}')
        if not out:
            sys.exit(f'{tree} is not in this clone: run git fetch --unshallow')
        return set(out.split())
    now = set(os.listdir(os.path.join(root, 'assets/zikr')))
    before = ls(OLD_ITEMS, 'assets/items') | ls(f'{PURGE}^', 'assets/zikr')
    return sorted((now & before) - ls(PURGE, 'assets/zikr'))


def write_json(path, obj):
    with open(path, 'w') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write('\n')


def snapshot(root):
    uids = restored_uids(root)
    write_json(SNAPSHOT, {uid: source_from_git(root, uid) for uid in uids})
    print(f'{len(uids)} restored uids -> {os.path.relpath(SNAPSHOT, root)}')


def baseline(root):
    snap = load_json(SNAPSHOT)
    out = {}
    for uid in sorted(snap):
        if not os.path.exists(os.path.join(root, 'assets/zikr', uid)):
            continue
        _, _, bad, missing = check(root, uid, snap[uid])
        flags = {}
        if bad:
            flags['not_in_source'] = sorted(k for _, k, _ in bad)
        if missing:
            flags['missing'] = sorted(k for _, k, _ in missing)
        if flags:
            out[uid] = flags
    old = load_json(BASELINE)
    write_json(BASELINE, out)
    count = lambda b: sum(len(v) for f in b.values() for v in f.values())
    print(f'{len(out)} uids, {count(out)} accepted flags (was {count(old)}) -> '
          f'{os.path.relpath(BASELINE, root)}')


def report(root, uids):
    snap, base = load_json(SNAPSHOT), load_json(BASELINE)
    for uid in uids:
        source = snap.get(uid) or source_from_git(root, uid)
        d, linked, bad, missing = check(root, uid, source)
        accepted = base.get(uid, {})
        ar = sum(len(norm(l)) >= MIN_LEN for l in entry_text(d).split('\n'))
        print(f'== {uid}: tabs={len(d.get("tabs", []))} arabic_lines={ar} not_in_source={len(bad)} '
              f'source_blocks={len(source["blocks"])} missing={len(missing)} links={linked}'
              + ('' if uid in snap else ' (not in snapshot)'))
        for c, k, l in bad:
            mark = ' ' if k in accepted.get('not_in_source', ()) else '+'
            print(f'  {mark}NOT IN SOURCE', (c, l))
        for c, k, n in missing:
            mark = ' ' if k in accepted.get('missing', ()) else '+'
            print(f'  {mark}MISSING      ', (c, n))
    print('(+ = not in source_baseline.json yet; the test fails on it)')


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    root = os.path.abspath(sys.argv[1])
    if sys.argv[2] == 'snapshot':
        snapshot(root)
    elif sys.argv[2] == 'baseline':
        baseline(root)
    else:
        report(root, sys.argv[2:])


if __name__ == '__main__':
    main()
