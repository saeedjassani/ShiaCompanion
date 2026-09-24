#!/usr/bin/env python3
"""One-off: the 24 words split mid-word outside the Quran, fixed as the repo
owner decided them on 2026-09-23 (after join_wa.py).

    python3 scripts/zikr_arabic/split_words.py [--out patch.json]

A - plain splits, joined. B - interrogative اَ written as its own word,
joined to the word it questions. C - the tanwin's nun written out as a
separate نِ (`مُحَمَّدِ نِ الْحَسَنِ`), restored to standard tanwin
(`مُحَمَّدٍ الْحَسَنِ`). D - AG8's truncated salutation, restored from its
transliteration.

Every edit states how many times it must match, and the patch is refused if
any count is off.
"""
import argparse, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import corpus

START = r'(?:(?<=\s)|^)'
MARK = 'ً-ٰٟۖ-ۭ'

def fuzzy(text):
    """A regex for [text] that ignores the order of stacked marks - the
    corpus writes both shadda-vowel and vowel-shadda."""
    out, i = '', 0
    while i < len(text):
        j = i
        while j < len(text) and re.match(f'[{MARK}]', text[j]):
            j += 1
        if j > i:
            out += f'[{re.escape(text[i:j])}]{{{j - i}}}'
            i = j
        else:
            out += re.escape(text[i])
            i += 1
    return out

def join(text):
    """Remove the first space in the matched text."""
    return (fuzzy(text), lambda m: m.group(0).replace(' ', '', 1))

def join_q(word):
    """Interrogative اَ + [word]: glue the اَ on."""
    return (START + fuzzy('اَ ') + f'(?={fuzzy(word)})', lambda m: m.group(0)[:-1])

def tanwin(word):
    """`مُحَمَّدِ نِ ` -> `مُحَمَّدٍ `: the last kasra becomes kasratan and
    the written-out nun goes. A word already carrying tanwin just loses the nun."""
    def repl(m):
        w = m.group(1)
        if not re.search('[ًٌٍ]', w):
            w = w[::-1].replace('ِ', 'ٍ', 1)[::-1]
        return w + ' '
    return (START + f'({fuzzy(word)}) ' + fuzzy('نِ '), repl)

def ag8(m, doc_text):
    # The same salutation appears intact elsewhere in AG8; reuse its exact
    # spelling rather than retyping it.
    intact = re.search(r'(?m)^' + fuzzy('صَلَّىٰ ٱللَّهُ عَلَيْكَ يَا أَبَا عَبْدِ ٱللَّهِ'), doc_text)
    return 'وَ' + intact.group(0)

FIXES = {
    # A
    'AA12': [(join('رَ اَیْتَنِیْ'), 2)],
    'AL11': [(join('لِبُنْيَا نِ'), 1),
             ((fuzzy('آثَاررِ ا لزَّيْغِ'),
               lambda m: m.group(0).replace('رر', 'ر', 1).replace('ا ل', 'ال', 1)), 1)],
    'F3': [(join('اَ لَمْ اَكُنِ'), 1)],
    'G11': [(join('اَ نَّكَ قَدْ'), 1)],
    'I20': [(join('ذُ نُوْبِىْ'), 1)],
    'I22': [(join('ذُ نُوْبِىْ'), 1)],
    'Y3': [(join('ذُ نُوْبِیْ'), 1)],
    'H17': [((fuzzy('يَا ذَ الْجُوْدِ'), lambda m: m.group(0).replace(' الْ', 'ا الْ', 1)), 1)],
    # B
    'E30': [(join_q('فَتَرُدَّنِيْ'), 1)],
    'E31': [(join_q('تُرَاكَ'), 1), (join_q('تُسَلِّطُ'), 1)],
    'H3': [(join_q('تَرَاكَ'), 1), (join_q('لِلشَّقَآءِ'), 1), (join_q('مِنْ اَهْلِ السَّعَادَةِ'), 1)],
    'H4': [(join_q('يَحْسُنُ'), 1)],
    # C
    'G56': [(tanwin('مُحَمَّدِ'), 1), (tanwin('عَلِیِّ'), 1)],
    'G73': [(tanwin('مُحَمَّدِ'), 1), (tanwin('عَلِیِّ'), 1)],
    'R9': [(tanwin('مُحَمَّدٍ'), 1)],
    'AA19': [(tanwin('مُحَمَّدًا'), 1)],
    # D
    'AG8': [((r'(?m)^' + fuzzy('ىٰ ٱللَّهُ عَلَيْكَ يَا أَبَا عَبْدِ') + r'(?=[ \t\r]*$)', ag8), 1)],
}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(os.path.dirname(__file__), '.patch.json'))
    args = ap.parse_args()
    patch, errors = {}, []
    for uid, doc in corpus.load_corpus(set(FIXES)):
        hits = [0] * len(FIXES[uid])
        for path, s in corpus.iter_strings(doc):
            after = s
            for i, ((pattern, repl), _) in enumerate(FIXES[uid]):
                fn = (lambda m, r=repl, t=s: r(m, t)) if repl is ag8 else repl
                after, n = re.subn(pattern, fn, after)
                hits[i] += n
            if after != s:
                patch.setdefault(uid, []).append({'path': list(path), 'before': s, 'after': after})
        for (fix, want), got in zip(FIXES[uid], hits):
            if got != want:
                errors.append(f'{uid}: {fix[0]!r} matched {got}, expected {want}')
    missing = set(FIXES) - set(patch)
    if errors or missing:
        sys.exit('\n'.join(errors + [f'{u}: no edits' for u in missing]))
    json.dump(patch, open(args.out, 'w'), ensure_ascii=False, indent=1)
    print(f'{sum(len(v) for v in FIXES.values())} fixes, {len(patch)} documents -> {args.out}')

if __name__ == '__main__':
    main()
