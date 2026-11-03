"""source_check.py <repo-root> <uid>... - check restored zikr entries against their source.

Usage: python3 -I scripts/zikr_arabic/source_check.py . E146 E112

For each uid: every Arabic line shipped must appear in the source (old item +
pre-purge zikr file + any Quran file it links), and every source Arabic block
must appear in the entry or in an entry it links to.
"""
import html, json, os, re, subprocess, sys

REPO = os.path.abspath(sys.argv[1])


def norm(s):
    s = html.unescape(html.unescape(s)).replace('ﷲ', 'الله')
    s = re.sub(r'[ً-ٰٟۖ-ۭـؐ-ؚ‌‍‏۔۔]', '', s)
    for a, b in [('ٱ', 'ا'), ('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ى', 'ي'), ('ة', 'ه'), ('ہ', 'ه'),
                 ('ھ', 'ه'), ('ی', 'ي'), ('ې', 'ي'), ('ک', 'ك'), ('ؤ', 'و'), ('ئ', 'ي'), ('ء', '')]:
        s = s.replace(a, b)
    return re.sub(r'[^ء-ي]', '', s)


def cov(n, hay, k=8, st=3):
    sh = [n[j:j + k] for j in range(0, max(1, len(n) - k + 1), st)]
    return sum(x in hay for x in sh) / len(sh)


def git_show(path):
    try:
        return subprocess.check_output(['git', '-C', REPO, 'show', path], stderr=subprocess.DEVNULL).decode()
    except subprocess.CalledProcessError:
        return ''


def entry_text(d):
    return '\n'.join([d.get('data', '')] + list(d.get('tabs', []) or []))


def links(t):
    return re.findall(r'\]\(([A-Z]+\d+)\)', t)


root = sys.argv[1]
for uid in sys.argv[2:]:
    d = json.load(open(os.path.join(root, 'assets/zikr', uid)))
    t = entry_text(d)
    old_raw = git_show(f'001aa3ad:assets/items/{uid}')
    src = html.unescape(html.unescape(json.loads(old_raw)['content'])) if old_raw else ''
    pre = git_show(f'8c5f8258^:assets/zikr/{uid}')
    linked = links(t) + links(d.get('merits', ''))
    linked_text = ''
    for l in set(linked):
        p = os.path.join(root, 'assets/zikr', l)
        if os.path.exists(p):
            linked_text += entry_text(json.load(open(p)))
    hay_src = norm(src + pre + linked_text)
    hay_new = norm(t + linked_text)
    ar = [l for l in t.split('\n') if len(norm(l)) >= 12]
    bad = [(round(cov(norm(l), hay_src), 2), l.strip()[:70]) for l in ar if cov(norm(l), hay_src) < 0.85]
    blocks = [b for b in re.split(r'--', src)[1::2] if len(norm(b)) >= 12]
    # an unterminated final block counts too
    parts = re.split(r'--', src)
    if len(parts) % 2 == 0 and len(norm(parts[-1])) >= 12:
        blocks.append(parts[-1])
    missing = [(round(cov(norm(b), hay_new), 2), b.strip()[:70]) for b in blocks if cov(norm(b), hay_new) < 0.85]
    print(f'== {uid}: tabs={len(d.get("tabs", []))} arabic_lines={len(ar)} not_in_source={len(bad)} '
          f'source_blocks={len(blocks)} missing={len(missing)} links={sorted(set(linked))}')
    for b in bad:
        print('   NOT IN SOURCE', b)
    for m in missing:
        print('   MISSING      ', m)
