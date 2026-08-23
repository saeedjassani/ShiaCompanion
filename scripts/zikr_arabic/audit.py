#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Corpus invariants for zikr Arabic. Exit 0 = clean, 1 = violations found.

INV-1  every Arabic codepoint stored in the corpus is canonical, i.e. it is not
       something source normalization is supposed to have removed.
INV-2  for each bundled font, the text that font actually renders (after
       formatArabicText) uses only codepoints that font has a glyph for, so no
       Arabic falls back to a system font.
INV-3  no Private Use Area codepoints. Qalam defines glyphs in the PUA and the
       corpus uses them; nothing else can draw them, so they are Qalam-only
       content masquerading as text.

Usage:  python3 scripts/zikr_arabic/audit.py [uid ...]
"""
import sys, collections, unicodedata
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import (RULES, arabic_strings, font_cmaps, render_for_font, is_arabic)

def _clean(d):
    return {k: v for k, v in d.items() if not k.startswith('_')}

def main(uids=None):
    sn = RULES['source_normalization']
    removed = set(''.join(_clean(sn['single'])) ) | {k[0] for k in _clean(sn['sequence'])}
    review = set(_clean(sn['review_required']))
    cmaps = font_cmaps()

    stored = collections.Counter()
    per_font = {f: collections.Counter() for f in cmaps}
    where = collections.defaultdict(set)

    for uid, _path, s in arabic_strings(uids, include_quran=True, source='assets'):
        for ch in s:
            if is_arabic(ch):
                stored[ch] += 1
                where[ch].add(uid)
        for font in cmaps:
            for ch in render_for_font(s, font):
                if is_arabic(ch) and ord(ch) not in cmaps[font]:
                    per_font[font][ch] += 1
                    where[ch].add(uid)

    fail = False

    inv1 = {ch: n for ch, n in stored.items() if ch in removed or ch in review}
    print('INV-1  non-canonical codepoints stored in the corpus')
    if inv1:
        fail = True
        for ch, n in sorted(inv1.items(), key=lambda x: -x[1]):
            tag = 'REVIEW' if ch in review else 'normalize'
            print(f'   U+{ord(ch):04X} {ch!r:<5} x{n:<6} {len(where[ch]):>3} zikr  [{tag}]  {name(ch)}')
    else:
        print('   ok')

    print('\nINV-2  codepoints with no glyph in the font that renders them')
    for font in ('Qalam', 'Uthmani', 'MeQuran'):
        miss = per_font[font]
        if miss:
            fail = True
            print(f'   {font}:')
            for ch, n in sorted(miss.items(), key=lambda x: -x[1]):
                print(f'      U+{ord(ch):04X} {ch!r:<5} x{n:<6} {len(where[ch]):>3} zikr   {name(ch)}')
        else:
            print(f'   {font}: ok')

    pua = collections.Counter()
    for uid, _path, s2 in arabic_strings(uids, include_quran=True, source='assets'):
        for ch in s2:
            if 0xE000 <= ord(ch) <= 0xF8FF:
                pua[ch] += 1
                where[ch].add(uid)
    print('\nINV-3  Private Use Area codepoints')
    if pua:
        fail = True
        for ch, n in pua.most_common():
            drawn = [f for f in cmaps if ord(ch) in cmaps[f]] or ['none']
            print(f'   U+{ord(ch):04X} x{n:<6} {len(where[ch]):>3} zikr   '
                  f'drawn only by: {", ".join(drawn)}')
    else:
        print('   ok')

    if not fail:
        inv = sorted(stored, key=lambda c: ord(c))
        print(f'\ncanonical inventory: {len(inv)} codepoints')
        print('   ' + ' '.join(f'U+{ord(c):04X}' for c in inv))
    return 1 if fail else 0

def name(ch):
    try:
        return unicodedata.name(ch)
    except ValueError:
        return '?'

if __name__ == '__main__':
    sys.exit(main(set(sys.argv[1:]) or None))
