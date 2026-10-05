"""Word-by-word diff of a restored zikr's Arabic against its assets/items history.

Restoring a uid means re-typing or re-splitting its historic Arabic, and it is
easy to drift from it without noticing: an idgham shadda (وَّ, مِّنْ) or madd
mark the history never had, a dropped word, a letter changed. This lists every
word of assets/zikr/<uid> that is not spelled exactly as in history:

    NEW <word>          no history word has this consonant skeleton
    <history> -> <new>  same skeleton, different marks
    UNUSED: ...         history words whose skeleton appears nowhere now

Combining-mark order, tatweel, waqf signs and verse numbers are ignored, and a
detached وَ is glued to the next word on both sides. Fill-ins for history's
"so-and-so" gaps (فُلَان) and deliberate fixes will show up too - the point is
that every line of the output is a change you meant to make.

    python3 scripts/zikr_arabic/histdiff.py I42 I50
"""
import json
import re
import subprocess
import sys
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MARK = re.compile('[ً-ٰٟۖ-ۭ]')
AR = re.compile('[؀-ۿ]')


def _canon(w):
    out, marks = [], []
    for ch in w:
        if MARK.match(ch):
            marks.append(ch)
        else:
            out.append(''.join(sorted(marks)))
            marks = []
            out.append(ch)
    out.append(''.join(sorted(marks)))
    return ''.join(out)


def clean(w):
    w = re.sub('[‌‍‏﻿ـ۔،,.()0-9:ۖ-ۜ]', '', w)
    w = w.replace('ٱ', 'ا').replace('ۤ', '').replace('ٓ', '').replace('آ', 'ا')
    return _canon(w)


def skel(w):
    w = MARK.sub('', clean(w))
    for a, b in ('یي', 'ىي', 'کك', 'ہه', 'ۃة', 'ئء', 'ؤء', 'آا'):
        w = w.replace(a, b)
    return w


def words(text):
    ws = [clean(w) for w in text.split() if AR.search(w)]
    ws = [w for w in ws if w]
    out, i = [], 0
    while i < len(ws):
        if skel(ws[i]) == 'و' and i + 1 < len(ws):
            out.append(ws[i] + ws[i + 1])
            i += 2
        else:
            out.append(ws[i])
            i += 1
    return out


def history(uid):
    c = subprocess.check_output(['git', 'log', '--all', '--diff-filter=D', '--format=%H', '--',
                                 'assets/items/' + uid], text=True, cwd=ROOT).split()
    if not c:
        sys.exit(f'{uid}: no assets/items history (is the clone shallow?)')
    item = json.loads(subprocess.check_output(['git', 'show', c[-1] + '^:assets/items/' + uid],
                                              text=True, cwd=ROOT))
    return words(' '.join(b for b in item['content'].split('--') if AR.search(b)))


def main(uids):
    for uid in uids:
        hw = history(uid)
        forms = {}
        for w in hw:
            forms.setdefault(skel(w), set()).add(w)
        d = json.load(open(os.path.join(ROOT, 'assets/zikr', uid), encoding='utf-8'))
        text = '\n'.join([d.get('data') or '', d.get('merits') or ''] + list(d.get('tabs') or []))
        new = words('\n'.join(l for l in text.split('\n') if AR.search(l)))
        report = []
        for w in new:
            s = skel(w)
            line = f'NEW {w}' if s not in forms else (None if w in forms[s] else f'{"/".join(sorted(forms[s]))} -> {w}')
            if line and line not in report:
                report.append(line)
        used = {skel(w) for w in new}
        unused = list(dict.fromkeys(w for w in hw if skel(w) not in used))
        print(f'== {uid}: {len(report)} changed, {len(unused)} history words unused')
        for r in report:
            print('   ', r)
        if unused:
            print('    UNUSED:', ' '.join(unused))


if __name__ == '__main__':
    main(sys.argv[1:])
