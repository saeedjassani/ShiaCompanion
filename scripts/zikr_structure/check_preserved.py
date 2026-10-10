#!/usr/bin/env python3
"""Check a restructuring against the base branch, and build the review page.

    python3 scripts/zikr_structure/check_preserved.py                 # vs master
    python3 scripts/zikr_structure/check_preserved.py --base origin/master J8 J6
    python3 scripts/zikr_structure/check_preserved.py --html review.html

For every changed `assets/zikr/<uid>` (Quran surahs excluded):
  * every Arabic line of the base version must still be in the entry
    (body, any tab, or merits) - otherwise it is an error;
  * every transliteration/translation line must survive verbatim too;
  * every English sentence of the notes and merits that disappeared, and
    every one that is new, is listed - that is what the reviewer reads.
Removed entries are listed with where they redirect.
Exit status is 1 on any lost Arabic/transliteration/translation line.
"""
import argparse
import collections
import html
import json
import re
import subprocess
import sys

import corpus
from lint import ORDINAL

SENT = re.compile(r'(?<=[.!?:;])\s+(?=[A-Z“"\'(\[])')


def git(*args):
    return subprocess.run(['git', '-C', corpus.ROOT, *args], check=True,
                          capture_output=True, text=True).stdout


def norm(s):
    return re.sub(r'\s+', ' ', s).strip()


def norm_en(s):
    s = ORDINAL.sub('', s)
    s = re.sub(r'[’‘]', "'", s)
    s = re.sub(r'[^\w\s\']', ' ', s.lower())
    return re.sub(r'\s+', ' ', s).strip()


def classify(entry):
    """(verse lines Counter, note/merit sentences list) of an entry."""
    verse = collections.Counter()
    notes = []
    for part in corpus.parse_parts(entry):
        for kind, line in zip(part.kind, part.lines):
            if kind in ('arabic', 'translit', 'translation'):
                verse[(kind, norm(line))] += 1
            elif kind == 'note':
                notes.append(line)
        if part.label and not corpus.is_arabic(part.label):
            notes.append(part.label)
        elif part.label:
            verse[('arabic', norm(part.label))] += 0  # label text, see below
    for line in (entry.get('merits') or '').split('\n'):
        if line.strip():
            if corpus.is_arabic(line):
                verse[('arabic', norm(line))] += 1
            else:
                notes.append(line.strip())
    sentences = [s for n in notes for s in SENT.split(n) if s.strip()]
    return verse, sentences


def all_text(entry):
    chunks = corpus.parts_of(entry) + [entry.get('merits') or '']
    return '\n'.join(chunks)


def compare(uid, old, new):
    report = {'uid': uid, 'title': (new or old)['title'], 'lost': [], 'dropped': [], 'added': []}
    o_verse, o_sent = classify(old)
    if new is None:
        return report
    n_verse, n_sent = classify(new)
    new_text = norm(all_text(new))
    for (kind, line), count in o_verse.items():
        if count == 0:
            continue
        if n_verse[(kind, line)] < count and line not in new_text:
            report['lost'].append(f'{kind}: {line}')
    new_en = norm_en(all_text(new))
    old_en = norm_en(all_text(old))
    for s in o_sent:
        k = norm_en(s)
        if k and k not in new_en:
            report['dropped'].append(s)
    for s in n_sent:
        k = norm_en(s)
        if k and k not in old_en:
            report['added'].append(s)
    return report


def changed_uids(base, only):
    out = git('diff', '--name-status', base, '--', 'assets/zikr/')
    rows = []
    for line in out.splitlines():
        status, path = line.split('\t')[0], line.split('\t')[-1]
        uid = path.rsplit('/', 1)[-1]
        if corpus.QURAN_UID.match(uid) or (only and uid not in only):
            continue
        rows.append((status[0], uid))
    return rows


def render_part_html(part):
    out = []
    for kind, line in zip(part.kind, part.lines):
        if kind == 'blank':
            continue
        out.append(f'<p class="{kind}">{html.escape(line)}</p>')
    return '\n'.join(out)


def entry_html(entry):
    parts = corpus.parse_parts(entry)
    out = []
    if (entry.get('merits') or '').strip():
        paras = ''.join(f'<p>{html.escape(p)}</p>' for p in entry['merits'].split('\n') if p.strip())
        out.append(f'<details class="merits"><summary>Merits</summary>{paras}</details>')
    for i, part in enumerate(parts):
        label = f'<div class="tab">Tab {i + 1}: {html.escape(part.label or "")}</div>' if len(parts) > 1 else ''
        out.append(f'<section>{label}{render_part_html(part)}</section>')
    return '\n'.join(out)


CSS = """
:root{--bg:#fbfaf7;--fg:#1d1b16;--muted:#6b665c;--line:#e4e0d6;--accent:#0f6e56;--bad:#b42318;--good:#1a7f37;--card:#fff}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15140f;--fg:#ece8df;--muted:#a39e92;--line:#34312a;--accent:#5cc7a8;--bad:#ff8a80;--good:#7ee2a0;--card:#1d1c16}}
:root[data-theme="dark"]{--bg:#15140f;--fg:#ece8df;--muted:#a39e92;--line:#34312a;--accent:#5cc7a8;--bad:#ff8a80;--good:#7ee2a0;--card:#1d1c16}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif}
main{max-width:1200px;margin:0 auto;padding:24px 16px}h1{font-size:22px}h2{font-size:18px;margin:0}
.entry{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:16px;margin:20px 0}
.cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}@media(max-width:800px){.cols{grid-template-columns:1fr}}
.col{max-height:70vh;overflow:auto;border:1px solid var(--line);border-radius:8px;padding:10px;min-width:0}
.col h3{margin:0 0 8px;font-size:13px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
.arabic{direction:rtl;font-size:20px;text-align:right;margin:8px 0 2px}.translit{color:var(--muted);font-size:12px;margin:0}
.translation{margin:0 0 6px}.note{border-left:3px solid var(--accent);padding-left:8px;font-style:italic}
.tab{font-weight:600;color:var(--accent);margin:14px 0 4px;border-top:1px dashed var(--line);padding-top:8px}
.merits{background:color-mix(in srgb,var(--accent) 8%,transparent);border-radius:8px;padding:8px 12px;margin-bottom:8px}
.diff li{margin:4px 0}.dropped{color:var(--bad)}.added{color:var(--good)}.lost{color:var(--bad);font-weight:600}
.meta{color:var(--muted);font-size:13px}
"""


def main():
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('uids', nargs='*')
    ap.add_argument('--base', default='master')
    ap.add_argument('--html', metavar='PATH')
    ap.add_argument('--title', default='Zikr restructuring review')
    args = ap.parse_args()

    redirects = corpus.load_redirects()
    reports, pages = [], []
    for status, uid in changed_uids(args.base, set(args.uids)):
        old = corpus.load_entry(uid, git('show', f'{args.base}:assets/zikr/{uid}')) if status != 'A' else None
        new = corpus.load_entry(uid) if status != 'D' else None
        if old is None:
            reports.append({'uid': uid, 'title': new['title'], 'lost': [], 'dropped': [], 'added': [], 'status': 'new'})
            pages.append((reports[-1], None, new))
            continue
        rep = compare(uid, old, new)
        rep['status'] = 'removed' if new is None else 'changed'
        if new is None:
            rep['redirect'] = redirects.get(uid)
        reports.append(rep)
        pages.append((rep, old, new))

    bad = False
    for r in reports:
        line = f"{r['uid']:8} {r['status']:8} lost {len(r['lost'])}  dropped {len(r['dropped'])}  added {len(r['added'])}"
        if r['status'] == 'removed':
            line += f"  -> {r.get('redirect') or 'NO REDIRECT'}"
            bad |= not r.get('redirect')
        print(line)
        for l in r['lost']:
            print('    LOST', l[:100])
        bad |= bool(r['lost'])

    if args.html:
        body = [f'<h1>{html.escape(args.title)}</h1>',
                f'<p class="meta">{len(reports)} entries vs <code>{html.escape(args.base)}</code>. '
                'Red: English that is gone. Green: English that is new. '
                'Arabic, transliteration and translation lines are checked by script and must all survive.</p>']
        for rep, old, new in pages:
            diff = []
            if rep.get('lost'):
                diff += [f'<li class="lost">LOST {html.escape(x)}</li>' for x in rep['lost']]
            diff += [f'<li class="dropped">− {html.escape(x)}</li>' for x in rep['dropped']]
            diff += [f'<li class="added">+ {html.escape(x)}</li>' for x in rep['added']]
            head = f"<h2>{html.escape(rep['uid'])} · {html.escape(rep['title'])}</h2>"
            if rep['status'] == 'removed':
                head += f"<p class='meta'>Removed - redirects to {html.escape(str(rep.get('redirect')))}</p>"
            cols = ''
            if old is not None:
                cols += f'<div class="col"><h3>Before</h3>{entry_html(old)}</div>'
            if new is not None:
                cols += f'<div class="col"><h3>After</h3>{entry_html(new)}</div>'
            body.append(f'<div class="entry">{head}<ul class="diff">{"".join(diff)}</ul><div class="cols">{cols}</div></div>')
        page = (f'<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
                f'<title>Zikr Structure Review</title><style>{CSS}</style></head><body><main>{"".join(body)}</main></body></html>')
        with open(args.html, 'w', encoding='utf-8') as f:
            f.write(page)
        print(f'wrote {args.html}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
