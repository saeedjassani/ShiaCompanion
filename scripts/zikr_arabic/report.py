#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the reviewer's sheet: every change grouped by rule, rendered in each font.

One row per rule, not per occurrence — 8,000 changes come from ~25 rules, and a
reviewer signs off on the rule, not on each instance. Items that genuinely need
a per-case decision get their own rows at the end.

  python3 scripts/zikr_arabic/report.py [--fonts Qalam,Uthmani] [-o out.html] [uid …]
"""
import sys, os, json, base64, collections, html, datetime
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import ROOT, RULES, arabic_strings, normalize_source, render_for_font, AR
import silah as S
import vowelgap as V
from batch import expand as _expand

def _clean(d):
    return {k: v for k, v in d.items() if not k.startswith('_')}

def font_face(name):
    path = os.path.join(ROOT, RULES['fonts'][name])
    ext = os.path.splitext(path)[1]
    fmt = {'.otf': 'opentype', '.ttf': 'truetype'}.get(ext, 'truetype')
    b64 = base64.b64encode(open(path, 'rb').read()).decode()
    return (f"@font-face{{font-family:'{name}';src:url(data:font/{fmt};base64,{b64}) "
            f"format('{fmt}');font-display:block}}")

def collect(uids=None):
    """{rule_label: {'n': count, 'ex': [(before, after), …]}} plus per-case lists."""
    rules = collections.defaultdict(lambda: {'n': 0, 'ex': []})
    sn = RULES['source_normalization']
    label = {}
    for a, b in list(_clean(sn['sequence']).items()) + list(_clean(sn['single']).items()):
        label[a] = f'{a} → {b or "(removed)"}'

    for uid, path, s in arabic_strings(uids):
        new, _ = normalize_source(s)
        if new == s:
            continue
        for lb, la in zip(s.split('\n'), new.split('\n')):
            if lb == la or not AR.search(lb):
                continue
            wb, wa = lb.split(), la.split()
            if len(wb) != len(wa):
                continue
            for x, y in zip(wb, wa):
                if x == y:
                    continue
                hit = next((a for a in label if a in x and a not in y), None)
                if hit is None:
                    continue
                r = rules[label[hit]]
                r['n'] += 1
                if len(r['ex']) < 2 and (x, y) not in r['ex']:
                    r['ex'].append((x, y))

    sil = list(S.fixes(uids))
    r = rules['ه ُ → ه ٗ   (ṣilah on the pronoun hā)']
    r['n'] = len(sil)
    seen = set()
    for f in sil:
        if f['before'] not in seen and len(r['ex']) < 4:
            seen.add(f['before']); r['ex'].append((f['before'], f['after']))

    review = []
    rq = _clean(sn['review_required'])
    for uid, path, s in arabic_strings(uids):
        new, _ = normalize_source(s)
        for line in new.split('\n'):
            for w in line.split():
                if any(c in w for c in rq):
                    review.append((uid, w, line.strip()))
    bad = [(r['uid'], r['word'], r['line'].strip()) for r in S.impossible_vowel(uids)]
    return rules, review, bad

DO = {'confident', 'qat-imperfect', 'qat-double-hamza', 'ambiguous'}

BUCKETS = [
    ('confident', 'Fill it — the same word is spelled with this vowel elsewhere in the corpus'),
    ('qat-imperfect', 'Fill with zabar — 1st-person imperfect, so the hamza is qat`'),
    ('qat-double-hamza', 'Fill BOTH with zabar — interrogative hamza + verb (أَأَدْخُلُ, "may I enter?")'),
    ('ambiguous', 'Your call — the corpus spells this word both ways'),
    ('wasl-imperative', 'Form-I imperative at the start of a line — hamzat al-wasl, so it IS pronounced here and takes kasra (or damma)'),
    ('leave-wasl-vowel', 'LEAVE — mid-phrase form-I imperative that already has its vowel. A pause before the word restores the hamza and pauses are not marked in the text, so these are not removable'),
    ('no-precedent', 'Needs a decision — nothing in the corpus to copy from'),
]

def vowel_sheet(fonts, out, uids=None):
    rows = V.proposals(uids)
    css = ''.join(font_face(f) for f in fonts) + """
    *{box-sizing:border-box}
    body{font:13px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
         color:#111;background:#fff;margin:0;padding:24px}
    h1{font-size:17px;margin:0 0 2px}.sub{color:#666;margin:0 0 18px}
    h2{font-size:13px;margin:24px 0 4px;padding-top:12px;border-top:2px solid #111}
    .hint{color:#666;margin:0 0 8px;font-size:12px}
    table{border-collapse:collapse;width:100%}
    th{text-align:left;font-size:10px;letter-spacing:.06em;text-transform:uppercase;
       color:#888;border-bottom:1px solid #ccc;padding:0 8px 5px;font-weight:600}
    td{border-bottom:1px solid #eee;padding:4px 8px;vertical-align:middle}
    tr{break-inside:avoid}
    .n{text-align:right;color:#666;font-variant-numeric:tabular-nums;width:44px}
    .ar{font-size:1.6em;line-height:1.8}
    .old .ar{color:#a11}.new .ar{color:#161}
    .ctx{color:#555}.ctx .ar{font-size:1.35em;color:#444}
    @media print{body{padding:0}@page{margin:12mm 10mm}}
    """
    def cell(t, f, cls='ar'):
        return f'<span class="{cls}" style="font-family:\'{f}\'">{html.escape(render_for_font(t, f))}</span>'
    def context(line, word, span=34):
        """Window the line around the word. Some zikr are stored as one
        unbroken line thousands of characters long, so a head-truncated
        excerpt usually does not contain the word it is meant to show."""
        i = line.find(word)
        if i < 0:
            return line[:span * 2]
        a, b = max(0, i - span), min(len(line), i + len(word) + span)
        return ('... ' if a else '') + line[a:b] + (' ...' if b < len(line) else '')

    p = [f'<title>Zikr Arabic — missing vowels</title><style>{css}</style>',
         '<h1 style="margin-bottom:2px">Zikr Arabic — word-initial alif vowels</h1>',
         f'<p class="sub">{sum(r["n"] for r in rows)} occurrences, {len(rows)} distinct words '
         f'· the definite article and other hamzat al-wasl stems are excluded, they are correctly bare</p>']
    section = None
    for name, hint in BUCKETS:
        rs = [r for r in rows if r['state'] == name]
        if not rs:
            continue
        want = 'DOING' if name in DO else 'NEEDS CONFIRMATION'
        if want != section:
            section = want
            n = sum(x['n'] for x in rows if (x['state'] in DO) == (want == 'DOING'))
            p.append(f'<h1 style="margin-top:26px">{want}'
                     f' <span style="font-weight:400;color:#777;font-size:13px">— {n} occurrences</span></h1>')
        p.append(f'<h2>{name} <span style="font-weight:400;color:#777">— {len(rs)} words, '
                 f'{sum(r["n"] for r in rs)} occurrences</span></h2><p class="hint">{hint}</p>')
        p.append('<table><tr><th>Now</th><th>Proposed</th><th class="n">Count</th>'
                 '<th>Zikr</th><th>Example line</th></tr>')
        for r in rs:
            after = cell(r['after'], fonts[0]) if r['after'] else '<span style="color:#999">leave as is</span>'
            p.append(f'<tr><td class="old">{cell(r["word"], fonts[0])}</td>'
                     f'<td class="new">{after}</td>'
                     f'<td class="n">{r["n"]}</td><td>{r["uid"]}</td>'
                     f'<td class="ctx">{cell(context(r["line"], r["word"]), fonts[0])}</td></tr>')
        p.append('</table>')
    open(out, 'w', encoding='utf-8').write(
        '<!doctype html><html><head><meta charset="utf-8">' + p[0] +
        '</head><body>' + ''.join(p[1:]) + '</body></html>')
    print(f'{sum(r["n"] for r in rows)} occurrences / {len(rows)} words -> {out}')

def main(argv):
    fonts = ['Qalam', 'Uthmani']
    out = os.path.join(ROOT, 'scripts/zikr_arabic/review.html')
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == '--fonts':
            fonts = argv[i + 1].split(','); i += 2
        elif argv[i] in ('-o', '--out'):
            out = argv[i + 1]; i += 2
        else:
            args.append(argv[i]); i += 1
    if '--vowels' in args:
        args = [a for a in args if a != '--vowels']
        return vowel_sheet(fonts, out, set(_expand(args)) or None)
    uids = set(args) or None

    rules, review, bad = collect(uids)
    rows = sorted(rules.items(), key=lambda x: -x[1]['n'])
    total = sum(v['n'] for v in rules.values())

    def rule_label(name, font):
        # glyph parts of a rule name get the real Arabic font; prose stays UI
        out = []
        for tok in name.split(' '):
            if tok and AR.search(tok):
                out.append(f'<span class="g" style="font-family:\'{font}\'">'
                           f'{html.escape(tok)}</span>')
            elif tok.startswith('('):
                out.append(f'<span class="lbl">{html.escape(tok)}</span>')
            else:
                out.append(html.escape(tok))
        return ' '.join(out)

    def cell(text, font):
        return (f'<span class="ar" style="font-family:\'{font}\'">'
                f'{html.escape(render_for_font(text, font))}</span>')

    css = ''.join(font_face(f) for f in fonts) + """
    *{box-sizing:border-box}
    body{font:13px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
         color:#111;background:#fff;margin:0;padding:24px}
    h1{font-size:17px;margin:0 0 2px}
    .sub{color:#666;margin:0 0 18px}
    table{border-collapse:collapse;width:100%;margin-bottom:26px}
    th{text-align:left;font-size:10px;letter-spacing:.06em;text-transform:uppercase;
       color:#888;border-bottom:1px solid #ccc;padding:0 8px 5px;font-weight:600}
    td{border-bottom:1px solid #eee;padding:5px 8px;vertical-align:middle}
    tr{break-inside:avoid}
    .rule{font-size:12px;white-space:nowrap;color:#333}
    .rule .g{font-size:1.5em;vertical-align:-.15em;padding:0 2px}
    .rule .lbl{color:#777}
    .n{text-align:right;color:#666;font-variant-numeric:tabular-nums;width:52px}
    .ar{font-size:1.7em;line-height:1.85}
    .to{color:#bbb;padding:0 5px}
    .old .ar{color:#a11}
    .new .ar{color:#161}
    .ctx{color:#555;font-size:12px}
    h2{font-size:13px;margin:26px 0 8px;padding-top:14px;border-top:2px solid #111}
    h2 span{font-weight:400;color:#777}
    @media print{body{padding:0}@page{margin:12mm 10mm}}
    """

    parts = [f'<title>Zikr Arabic — changes for review</title><style>{css}</style>',
             '<h1>Zikr Arabic — changes for review</h1>',
             f'<p class="sub">{total} changes, grouped by rule · rendered in '
             f'{" and ".join(fonts)} · {datetime.date.today().isoformat()}</p>']

    head = '<tr><th>Rule</th><th class="n">Count</th>' + ''.join(
        f'<th colspan="3">{f}</th>' for f in fonts) + '</tr>'
    parts.append('<table>' + head)
    for name, v in rows:
        span = max(1, len(v['ex']))
        for k, (b, a) in enumerate(v['ex'] or [('', '')]):
            tds = []
            if k == 0:
                tds.append(f'<td class="rule" rowspan="{span}">{rule_label(name, fonts[0])}</td>')
                tds.append(f'<td class="n" rowspan="{span}">{v["n"]}</td>')
            for f in fonts:
                tds.append(f'<td class="old">{cell(b, f)}</td>'
                           f'<td class="to">→</td><td class="new">{cell(a, f)}</td>')
            parts.append('<tr>' + ''.join(tds) + '</tr>')
    parts.append('</table>')

    if bad:
        parts.append(f'<h2>Wrong vowel, not just the mark <span>— {len(bad)}, '
                     f'each needs a decision</span></h2><table>'
                     '<tr><th>Zikr</th><th>Word</th><th>Line</th></tr>')
        for uid, w, line in bad:
            parts.append(f'<tr><td>{uid}</td><td class="old">{cell(w, fonts[0])}</td>'
                         f'<td class="ctx">{cell(line[:80], fonts[0])}</td></tr>')
        parts.append('</table>')

    if review:
        parts.append(f'<h2>Bare hamza — no vowel to copy <span>— {len(review)}, '
                     f'left unchanged</span></h2><table>'
                     '<tr><th>Zikr</th><th>Word</th><th>Line</th></tr>')
        for uid, w, line in review:
            parts.append(f'<tr><td>{uid}</td><td class="old">{cell(w, fonts[0])}</td>'
                         f'<td class="ctx">{cell(line[:80], fonts[0])}</td></tr>')
        parts.append('</table>')

    open(out, 'w', encoding='utf-8').write(
        '<!doctype html><html><head><meta charset="utf-8">'
        + ''.join(parts[:1]) + '</head><body>' + ''.join(parts[1:]) + '</body></html>')
    print(f'{total} changes / {len(rows)} rules / {len(review) + len(bad)} case-by-case')
    print(f'-> {out}')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
