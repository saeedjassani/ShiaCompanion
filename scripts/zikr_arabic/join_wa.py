#!/usr/bin/env python3
"""Glue the conjunction وَ to the word after it, and pull a line-final وَ
down onto the next Arabic line.

    python3 scripts/zikr_arabic/join_wa.py [--out patch.json] [uid ...]

The corpus writes the conjunction as its own word ~10,000 times (`وَ اَنْتَ`).
Arabic never does: و is a one-letter prefix. Qalam's tight spacing hid the gap;
Scheherazade and the QuranWBW font both show it.

Only the conjunction's own spellings are joined - bare و, وَ, وَّ, وّ. A و with
sukun, damma, kasra or tanween is the tail of a split word, not the
conjunction, and is reported instead of touched.

A وَ that ends an Arabic line (39 of them, all in `012`-layout documents -
Arabic, transliteration, translation) is moved to the start of the next Arabic
line, three lines down. The transliteration's trailing WA/WAL and the
translation's trailing "and" move with it, unless the next line already opens
with one.
"""
import argparse, json, re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import corpus

AR = 'ء-يٮ-ۓۺ-ۿ'
MARKS = 'ً-ٰٟۖ-ۭ-'
SEP = '[  ‌]*[  ][  ‌]*'
# The conjunction's spellings: bare, fatha, shadda with or without fatha.
CONJ = 'و(?:َّ?|َّ?)?'
NOT_AFTER_LETTER = f'(?<![{AR}{MARKS}])'

JOIN = re.compile(f'{NOT_AFTER_LETTER}({CONJ}){SEP}(?=[{AR}])')
# `و َمَنَحَ`: the fatha split off the waw by a space.
DETACHED_FATHA = re.compile(f'{NOT_AFTER_LETTER}و{SEP}(َ)(?=[{AR}])')
SPLIT_TAIL = re.compile(f'{NOT_AFTER_LETTER}و[{MARKS}]+{SEP}(?=[{AR}])')
LINE_FINAL = re.compile(f'{NOT_AFTER_LETTER}({CONJ})\\s*$')
# Reviewed by hand: a damma typed for the conjunction's fatha. The
# transliteration of both reads WA.
TYPOS = {
    'AC12': [('فَبِحِلْمِكَ وُ جُوْدِكَ', 'فَبِحِلْمِكَ وَ جُوْدِكَ')],
    'G13': [('وُ نُوْرِهٖ وَ بُرْهَانِهٖ', 'وَ نُوْرِهٖ وَ بُرْهَانِهٖ')],
}
TL_FINAL = re.compile(r'\s+(WAL|WA|wal|wa)\s*$')
TR_FINAL = re.compile(r'\s+and\s*$')


def move_line_final(text, uid, log):
    lines = text.split('\n')
    for i, line in enumerate(lines):
        if not corpus.AR.search(line[:40]):
            continue
        m = LINE_FINAL.search(line)
        if not m:
            continue
        nxt = i + 3
        if nxt >= len(lines) or not corpus.AR.search(lines[nxt][:40]):
            log.append(f'{uid} L{i}: line-final وَ with no Arabic line 3 below - left alone')
            continue
        lines[i] = line[:m.start()].rstrip() + ' '
        lines[nxt] = m.group(1) + lines[nxt].lstrip()
        tl, tr = i + 1, i + 2
        t = TL_FINAL.search(lines[tl])
        if t and not re.match(r'\s*wa', lines[tl + 3], re.I):
            lines[tl] = lines[tl][:t.start()]
            lines[tl + 3] = f'{t.group(1)} ' + lines[tl + 3].lstrip()
        t = TR_FINAL.search(lines[tr])
        if t and not re.match(r'\s*and\b', lines[tr + 3], re.I):
            lines[tr] = lines[tr][:t.start()] + ' '
            lines[tr + 3] = 'and ' + lines[tr + 3].lstrip()
        log.append(f'{uid} L{i}: moved وَ to L{nxt}')
    return '\n'.join(lines)


def fix(text, uid, log):
    for before, after in TYPOS.get(uid, []):
        text = text.replace(before, after)
    text = move_line_final(text, uid, log)
    text = DETACHED_FATHA.sub('و\\1', text)
    for m in SPLIT_TAIL.finditer(text):
        if not JOIN.match(text, m.start()):
            log.append(f'{uid}: not a conjunction, left alone: {text[max(0, m.start()-15):m.end()+15]!r}')
    return JOIN.sub(r'\1', text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('uids', nargs='*')
    ap.add_argument('--out', default=os.path.join(os.path.dirname(__file__), '.patch.json'))
    args = ap.parse_args()
    patch, log, joins = {}, [], 0
    for uid, doc in corpus.load_corpus(set(args.uids) or None):
        for path, s in corpus.iter_strings(doc):
            if not corpus.AR.search(s):
                continue
            after = fix(s, uid, log)
            if after != s:
                joins += len(JOIN.findall(s))
                patch.setdefault(uid, []).append({'path': list(path), 'before': s, 'after': after})
    json.dump(patch, open(args.out, 'w'), ensure_ascii=False, indent=1)
    print('\n'.join(log))
    print(f'\n{joins} joins, {sum(len(v) for v in patch.values())} strings in {len(patch)} documents -> {args.out}')


if __name__ == '__main__':
    main()
