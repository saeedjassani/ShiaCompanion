#!/usr/bin/env python3
"""Check zikr entries against docs/ZIKR_STRUCTURE.md.

    python3 scripts/zikr_structure/lint.py                 # whole corpus, summary
    python3 scripts/zikr_structure/lint.py J8 J6 AA5       # those uids, every finding
    python3 scripts/zikr_structure/lint.py --code ORDINAL  # who breaks one rule
    python3 scripts/zikr_structure/lint.py --review        # the owner's review list
    python3 scripts/zikr_structure/lint.py --json out.json

Severities:
  error   breaks a rule; a restructured entry must have none
  review  for the repo owner to decide (LONG_PROSE, NOTHING_TO_DO) - not
          something a batch fixes on its own
Exit status is 1 when any listed uid has an error.
"""
import argparse
import collections
import json
import re
import sys

import corpus

ORDINAL_WORD = (
    r'(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|'
    r'eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|'
    r'seventeenth|eighteenth|nineteenth|twentieth|thirtieth|fortieth|fiftieth|'
    r'(twenty|thirty|forty|fifty)[\s-]+(first|second|third|fourth|fifth|'
    r'sixth|seventh|eighth|ninth))'
)
# "Twenty-Seventh:", "First -", "(d) ", "(iii) ", "(1) " at a line start.
# A plain "1." / "a." list is left alone - it numbers steps within the entry.
ORDINAL = re.compile(
    r'^\s*(' + ORDINAL_WORD + r'\s*[:\-–—]'
    r'|\((?:[a-z]|[ivx]{1,4}|\d{1,2})\)\s*)',
    re.I,
)
OCCASION = re.compile(
    r'\b(was born|were born|birth|martyr|passed away|demise|died|death|'
    r'anniversary|was revealed|took place|occurred|happened)\b',
    re.I,
)
BACKREF = re.compile(
    r'\b(as (?:was |has been |we have |I have )?(?:mentioned|said|stated|cited|'
    r'noted|explained|discussed|indicated) (?:above|before|earlier|previously)'
    r'|aforementioned|above-?mentioned|the previous (?:section|chapter|item|one|night|day|part)'
    r'|(?:mentioned|cited|discussed) (?:above|earlier|before|previously)'
    r'|see (?:above|below)'
    r'|already (?:been )?(?:mentioned|cited|discussed)'
    r'|(?:later on|hereinafter),? we (?:will|shall) (?:mention|cite|discuss)'
    r'|will be (?:mentioned|cited|discussed) (?:later|below|in (?:the|its) (?:place|section|chapter))'
    r'|we will mention'
    r'|in the (?:previous|coming|next|following) (?:section|chapter))\b',
    re.I,
)
ACT = re.compile(
    r'\b(recite|recit|recommended|pray|prayer|namaz|salat|fast|bathe|ghusl|'
    r'ziyar|visit|say|repeat|rak|unit|dua|supplicat|invocation|tasbeeh|'
    r'istighfar|istikhar|istekh|invoke|write|read|perform|offer|zikr|dhikr|seek|'
    r'give alms|sadaqah)',
    re.I,
)
LINK = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')
BAD_LABEL = re.compile(
    r'^(\(?\d+\)?\.?|\d+(st|nd|rd|th)|dua \d+|part \d+|tab \d+|'
    r'misc\.?|miscellaneous|more|more .*|other|others|another .*|additional .*|'
    r'various .*)$',
    re.I,
)

MAX_NOTE = 400        # one standalone line in the body
MAX_INTRO = 600       # standalone text before the first Arabic line of part 1
MAX_RUN = 1500        # consecutive standalone text anywhere in the body
MAX_LABEL = 40

Finding = collections.namedtuple('Finding', 'uid severity code where detail')


def lint_entry(uid, entry, index, redirects, live):
    out = []

    def add(sev, code, where, detail):
        out.append(Finding(uid, sev, code, where, detail))

    if index.get(uid, {}).get('title') not in (None, entry.get('title')):
        add('error', 'TITLE_MISMATCH', 'title',
            f"zikr.json {index[uid]['title']!r} != file {entry.get('title')!r}")
    if ORDINAL.match(entry.get('title', '')):
        add('error', 'ORDINAL', 'title', entry['title'])

    parts = corpus.parse_parts(entry)
    multi = len(parts) > 1
    any_arabic = False
    body_text = []
    for p_i, part in enumerate(parts):
        where = f'tab {p_i + 1}' if multi else 'body'
        if multi:
            label = part.label or ''
            if part.header_blank:
                add('error', 'TAB_LABEL', where, 'part opens with a blank line - label shows twice')
            if not label:
                add('error', 'TAB_LABEL', where, 'empty label')
            elif corpus.is_arabic(label):
                add('error', 'TAB_LABEL', where, f'Arabic label: {label[:40]}')
            elif BAD_LABEL.match(label) or ORDINAL.match(label):
                add('error', 'TAB_LABEL', where, f'non-descriptive label: {label!r}')
            elif len(label) > MAX_LABEL:
                add('error', 'TAB_LABEL', where, f'{len(label)} chars: {label!r}')
            if re.match(r'^(merits|virtues|importance|excellence)\b', label, re.I):
                add('error', 'MERITS_TAB', where, label)
        if 'arabic' in part.kind:
            any_arabic = True
        for i, line in part.notes():
            body_text.append(line)
            if ORDINAL.match(line):
                add('error', 'ORDINAL', f'{where} line {i + 1}', line[:90])
            if len(line) > MAX_NOTE:
                add('error', 'LONG_LINE', f'{where} line {i + 1}',
                    f'{len(line)} chars: {line[:70]}...')
        for line in part.lines:
            m = BACKREF.search(line)
            if m:
                add('error', 'BACKREF', where, f'"{m.group(0)}" in: {line[:90]}')
        if p_i == 0 and not (entry.get('merits') or '').strip():
            intro = []
            for k, line in zip(part.kind, part.lines):
                if k == 'arabic':
                    break
                if k == 'note':
                    intro.append(line)
            n = sum(map(len, intro))
            if 'arabic' in part.kind and n > MAX_INTRO:
                add('error', 'INTRO_IN_BODY', where,
                    f'{n} chars of prose before the first Arabic and no merits')
        for run in part.note_runs():
            n = sum(map(len, run))
            if n > MAX_RUN:
                add('review', 'LONG_PROSE', where,
                    f'{n} chars of standalone prose: {run[0][:70]}...')

    merits = entry.get('merits') or ''
    for line in merits.split('\n'):
        if ORDINAL.match(line):
            add('error', 'ORDINAL', 'merits', line[:90])
        m = BACKREF.search(line)
        if m:
            add('error', 'BACKREF', 'merits', f'"{m.group(0)}" in: {line[:90]}')

    if not any_arabic:
        prose = '\n'.join(body_text)
        if not ACT.search(prose):
            add('review', 'NOTHING_TO_DO', 'body',
                'no Arabic and no act to perform - removal candidate (rule 6)')
        elif OCCASION.search(prose):
            add('review', 'OCCASION_NOTE', 'body',
                f'no Arabic, reports an occasion ({len(prose)} chars) - check rule 6: '
                + prose[:80].replace('\n', ' / '))

    for text in [p for p in corpus.parts_of(entry)] + [merits]:
        for _, target in LINK.findall(text):
            target = target.strip().split("#")[0]
            if target.startswith(('http://', 'https://', 'mailto:')):
                continue
            if target not in live and target not in redirects:
                add('error', 'BROKEN_LINK', 'link', target)
    return out


def lint_index(index, redirects, live):
    out = []
    for key, meta in index.items():
        if '|' in key:
            alias, target = key.split('|', 1)
            tmeta = index.get(target)
            if tmeta is None:
                out.append(Finding(alias, 'error', 'ALIAS_TARGET', 'zikr.json', f'{key}: no {target}'))
            elif tmeta['title'] == meta['title'] and tmeta.get('slug') != meta.get('slug'):
                out.append(Finding(alias, 'error', 'ALIAS_SLUG', 'zikr.json',
                                   f"same title as {target} but slug {meta.get('slug')!r} != {tmeta.get('slug')!r}"))
    bases = collections.Counter(k.split('|')[0] for k in index)
    for base, n in bases.items():
        # Two aliases sharing a listing number only tie in sort order; a
        # plain uid that is also an alias's listing uid is a real duplicate.
        if n > 1 and base in index:
            out.append(Finding(base, 'error', 'DUP_UID', 'zikr.json',
                               f'{base} is the listing uid of {n} keys: '
                               + ', '.join(k for k in index if k.split('|')[0] == base)))
    for uid, (target, tab) in corpus.load_redirects_full().items():
        if tab is not None and target in live and not target.startswith('A'):
            try:
                n_tabs = len([t for t in (corpus.load_entry(target).get('tabs') or []) if t.strip()])
            except FileNotFoundError:
                n_tabs = 0
            if tab >= n_tabs:
                out.append(Finding(uid, 'error', 'REDIRECT_TAB', 'retired_zikr_redirects.dart',
                                   f'{uid} -> {target} tabIndex {tab}, but {target} has {n_tabs} tabs'))
    for uid, target in redirects.items():
        if target not in live:
            out.append(Finding(uid, 'error', 'REDIRECT_TARGET', 'retired_zikr_redirects.dart',
                               f'{uid} -> {target}, which is not live'))
        # 'G20|N3' alongside G20 -> N3 is fine: the redirect catches favorites
        # saved under the bare uid, the alias lists the same target.
        if uid in live and f'{uid}|{target}' not in index:
            out.append(Finding(uid, 'error', 'REDIRECT_LIVE', 'retired_zikr_redirects.dart',
                               f'{uid} is retired but still has a live entry'))
    return out


REVIEW_HEADINGS = {
    'NOTHING_TO_DO': ('Nothing to recite or do',
                      'No Arabic and no act. Rule 6 says remove; confirm.'),
    'OCCASION_NOTE': ('Prose that reports an occasion',
                      'No Arabic. Some carry an act (fast, give alms, a prayer) and stay; '
                      'the ones that only recount history go (rule 6).'),
    'LONG_PROSE': ('Long instructions that may not belong in the app',
                   'Long runs of standalone English in the body - rulings, histories, '
                   'long how-tos. Keep, trim, or drop?'),
}


def write_review_markdown(path, findings, index):
    lines = ['# Zikr entries for the owner to review', '',
             'Generated by `python3 scripts/zikr_structure/lint.py --markdown <path>`. '
             'These are judgement calls the structure pass does not make on its own '
             '(docs/ZIKR_STRUCTURE.md rules 3 and 6).', '']
    for code, (heading, blurb) in REVIEW_HEADINGS.items():
        rows = [f for f in findings if f.code == code]
        if not rows:
            continue
        lines += [f'## {heading} ({len({f.uid for f in rows})})', '', blurb, '',
                  '| uid | title | where | detail |', '|---|---|---|---|']
        for f in rows:
            title = index.get(f.uid, {}).get('title', '')
            detail = f.detail.replace('|', '\\|')
            lines.append(f'| {f.uid} | {title} | {f.where} | {detail} |')
        lines.append('')
    with open(path, 'w', encoding='utf-8') as out:
        out.write('\n'.join(lines))


def main():
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('uids', nargs='*')
    ap.add_argument('--code', action='append', help='only these finding codes')
    ap.add_argument('--review', action='store_true', help='only owner-review findings')
    ap.add_argument('--json', metavar='PATH')
    ap.add_argument('--markdown', metavar='PATH', help='write the owner review list (review findings) as Markdown')
    ap.add_argument('--summary', action='store_true', help='counts only, even with uids')
    args = ap.parse_args()

    index = corpus.load_index()
    redirects = corpus.load_redirects()
    live = set()
    for key in index:
        live.update(key.split('|'))
    live.update(corpus.entry_uids())

    uids = args.uids or corpus.entry_uids()
    findings = []
    for uid in uids:
        findings += lint_entry(uid, corpus.load_entry(uid), index, redirects, live)
    if not args.uids:
        findings += lint_index(index, redirects, live)
    if args.code:
        findings = [f for f in findings if f.code in args.code]
    if args.review:
        findings = [f for f in findings if f.severity == 'review']

    if args.json:
        with open(args.json, 'w', encoding='utf-8') as f:
            json.dump([f._asdict() for f in findings], f, ensure_ascii=False, indent=1)

    if args.markdown:
        write_review_markdown(args.markdown, [f for f in findings if f.severity == 'review'], index)

    by_code = collections.Counter(f.code for f in findings)
    uids_with = collections.defaultdict(set)
    for f in findings:
        uids_with[f.code].add(f.uid)
    show_all = (args.uids or args.code or args.review) and not args.summary
    if show_all:
        for f in findings:
            print(f'{f.uid:8} {f.severity:6} {f.code:14} {f.where:12} {f.detail}')
        print()
    print(f'{len(uids)} entries checked')
    for code, n in by_code.most_common():
        print(f'  {code:15} {n:5} findings in {len(uids_with[code]):4} entries')
    clean = [u for u in uids if not any(f.uid == u and f.severity == 'error' for f in findings)]
    print(f'  {len(clean)} entries without errors')
    sys.exit(1 if any(f.severity == 'error' for f in findings) else 0)


if __name__ == '__main__':
    main()
