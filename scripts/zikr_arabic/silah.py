#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""صلة هاء الضمير -- the ulta pesh / khari zer rule on the 3rd-person pronoun ه.

The suffix ه meaning "his/its" is read long, and that long reading is written
with ulta pesh (هٗ) or khari zer (هٖ), when the letter BEFORE it carries a short
vowel.  Three things block it:

  sukun before it        مِنْهُ  عَلَيْهِ
  long vowel before it   اِيَّاهُ  جَعَلْنٰهُ
  hamzat al-wasl after   لَهُ الْمُلْكُ   نَفْسَهُ ابْتِغَآءَ

The wasl test is ORTHOGRAPHIC, not grammatical: the next word opens with a bare
alif carrying no diacritic.  This works because the corpus writes the zabar on
the alif exactly when it is actually pronounced, so اَللّٰهُمَّ / اِلَيْكَ read as
qat` and keep the silah.  The next word may sit on the following line.

Usage:  python3 scripts/zikr_arabic/silah.py [--json out.json] [uid ...]
"""
import sys, re, json, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import (HA, ULTA, KHARI, DAMMA, KASRA, FATHA, SUKUN, SHADDA,
                    TANWEEN, DAGGER, SHORT, MARKS, PUNCT, AR, skeleton,
                    load_corpus, iter_strings)

PAT = re.compile('([' + HA + '])([' + ULTA + KHARI + DAMMA + KASRA + '])'
                 r'(?=$|[\s،؟.,:;!?۔‏])')
SWAP = {DAMMA: ULTA, KASRA: KHARI}

# Words whose final ه is root-final, a demonstrative, or the name Allah, i.e.
# not a pronoun suffix at all.  A naive scan has a ~7% false-positive rate
# without this; the list is hand-classified from the residual of a stem-exists
# test (strip the ه, check the remainder is a real corpus word, normalising
# hamza/alef variants and mapping final ت -> ة).
EXCLUDE_SKELETON = {
    'اتوجه', 'واتوجه', 'اوجه', 'وجه', 'الوجه', 'توجه', 'نتوجه', 'يتوجه', 'تتوجه',
    'تشتبه', 'المتشابه', 'والمتشابه', 'المكاره', 'مكاره', 'الشبه', 'شبه',
    'فواكه', 'تكره', 'اكره', 'يكره', 'المنزه', 'منزه', 'المتنزه', 'سفه',
    'اتفوه', 'نفقه', 'تنته', 'ينته', 'تفقه',
    'هذه', 'هذهي', 'هذهه',
    'تولاه', 'استكلاه', 'استولاه',
    'يرضه',
}

def is_pronoun_suffix(sk):
    s = sk.strip('“”"‏‎,.').replace('ٱ', 'ا').replace('ہ', 'ه').replace('ھ', 'ه')
    if s.endswith('لله') or s.endswith('اله'):
        return False
    for p in ('وال', 'فال', 'بال', 'ولل', 'لل', 'ال', 'و', 'ف', 'ب', 'ل', 'ك'):
        if s.startswith(p) and len(s) > len(p) + 2 and s[len(p):] in EXCLUDE_SKELETON:
            return False
    return s not in EXCLUDE_SKELETON

def next_word(line, endpos, nextline=''):
    rest = line[endpos:].lstrip()
    while rest and rest[0] in PUNCT:
        rest = rest[1:].lstrip()
    if not rest:
        rest = nextline.lstrip()
        while rest and rest[0] in PUNCT:
            rest = rest[1:].lstrip()
    return rest.split(' ')[0] if rest else ''

def is_wasl(nxt):
    """True = hamzat al-wasl follows (no silah). None = no next word found."""
    if not nxt:
        return None
    w = nxt.lstrip(PUNCT)
    if not w:
        return None
    if w[0] == 'ٱ':
        return True
    if w[0] != 'ا':
        return False
    return not (len(w) > 1 and w[1] in MARKS)

def classify(line, m, nextline=''):
    mark = m.group(2)
    word = re.search(r'\S*$', line[:m.end(2)]).group(0)
    j, mk = m.start(1) - 1, ''
    while j >= 0 and line[j] in MARKS:
        mk = line[j] + mk; j -= 1
    if j < 0 or not AR.match(line[j]):
        return None
    base, mkset = line[j], set(mk)
    if DAGGER in mkset:
        prev = 'madd'
    elif base in 'اويیى' and not (mkset & set(SHORT)):
        prev = 'madd'
    elif SUKUN in mkset:
        prev = 'sukun'
    elif mkset & set(SHORT + ULTA + KHARI):
        prev = 'voweled'
    else:
        prev = 'bare'
    nxt = next_word(line, m.end(2), nextline)
    return dict(prev=prev, kind='silah' if mark in (ULTA + KHARI) else 'plain',
                wasl=is_wasl(nxt), word=word, nxt=nxt, mark=mark,
                pbase=base, pmk=mk)

def scan_text(text):
    """Yield every pronoun-suffix hā in one string."""
    lines = text.split('\n')
    for li, line in enumerate(lines):
        nl = next((lines[k] for k in range(li + 1, min(li + 4, len(lines)))
                   if AR.search(lines[k])), '')
        for m in PAT.finditer(line):
            c = classify(line, m, nl)
            if c and is_pronoun_suffix(skeleton(c['word'])):
                c.update(line=line)
                yield c

def scan(uids=None):
    for uid, doc in load_corpus(uids):
        for path, s in iter_strings(doc):
            if not AR.search(s):
                continue
            for c in scan_text(s):
                c.update(uid=uid, path=list(path))
                yield c

def _vowel_is_impossible(r):
    """The hā's own vowel contradicts the letter before it: kasra cannot follow
    a fatha/damma. The underlying vowel is wrong, so swapping the mark would
    only lock the error in — leave it for a human."""
    return (set(r['mark']) & set(KASRA + KHARI)
            and set(r['pmk']) & set(FATHA + DAMMA)
            and r['pbase'] not in 'يیى')

def apply_to_text(text):
    """Apply every silah fix to one string and return the result. Must run on
    text that source normalization has ALREADY been applied to: computing the
    fixes on raw text and replacing into normalized text loses every fix on a
    word both passes touch (إِحْسَانَهُ -> اِحْسَانَهُ no longer matches)."""
    for r in fixes_in_text(text):
        text = text.replace(r['before'], r['after'])
    return text

def fixes_in_text(text):
    for r in scan_text(text):
        if _vowel_is_impossible(r):
            continue
        if r['prev'] == 'voweled' and r['kind'] == 'plain' and r['wasl'] is False:
            w = r['word']
            i = w.rfind(r['mark'])
            yield dict(r, before=w, after=w[:i] + SWAP[r['mark']] + w[i + 1:])

def fixes(uids=None):
    """Pronoun hā that should carry the silah mark but does not."""
    for r in scan(uids):
        if _vowel_is_impossible(r):
            continue
        if r['prev'] == 'voweled' and r['kind'] == 'plain' and r['wasl'] is False:
            w = r['word']
            i = w.rfind(r['mark'])
            yield dict(r, before=w, after=w[:i] + SWAP[r['mark']] + w[i + 1:])

def impossible_vowel(uids=None):
    """The hā's own vowel disagrees with the letter before it -- the underlying
    vowel is wrong, not just the mark.  Kasra after fatha/damma cannot occur."""
    for r in scan(uids):
        if _vowel_is_impossible(r):
            yield r

def main(argv):
    out = None
    if '--json' in argv:
        i = argv.index('--json'); out = argv[i + 1]; argv = argv[:i] + argv[i + 2:]
    uids = set(argv) or None

    rows = list(scan(uids))
    c = collections.Counter((r['prev'], r['kind'], r['wasl']) for r in rows)
    ok_wasl = c[('voweled', 'plain', True)]
    bad_wasl = c[('voweled', 'silah', True)]
    print(f'{len(rows)} pronoun-suffix hā examined')
    print(f'  silah where required        {c[("voweled", "silah", False)]}')
    print(f'  plain after sukun/madd      {c[("sukun", "plain", False)] + c[("madd", "plain", False)]}')
    print(f'  plain before hamzat al-wasl {ok_wasl}   (violations: {bad_wasl})')

    f = list(fixes(uids))
    by = collections.Counter(r['uid'] for r in f)
    print(f'\n{len(f)} missing silah marks in {len(by)} zikr')
    for uid, n in by.most_common(20):
        print(f'   {uid:<7} {n}')
    if len(by) > 20:
        print(f'   ... {len(by) - 20} more')

    bad = list(impossible_vowel(uids))
    if bad:
        print(f'\n{len(bad)} hā whose own vowel is wrong (not just the mark):')
        for r in bad:
            print(f'   {r["uid"]:<7} {r["word"]}   {r["line"].strip()[:70]}')

    if out:
        json.dump(f, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'\nfixes -> {out}')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
