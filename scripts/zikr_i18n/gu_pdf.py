"""Text out of the Gujarati dua PDFs on jafrilibrary.com (Haji Naji Trust and
hadilibrary.org booklets), whose Gujarati can't be copied out as Unicode.

Two kinds of PDF, two decoders:

- `arialunicode`: booklets typeset by Maulana Rizwanali Palsaniya (footer
  "palsani76@gmail.com"), e.g. Ziarat E Warisa (book 6684) and Munajaat E Ali
  (book 6678). The Gujarati is a subset of Arial Unicode MS with no ToUnicode
  map, so the text is glyph ids. Their numbering is the full font's, so the
  system's Arial Unicode MS turns them back into characters: its cmap for
  single glyphs, its gujr GSUB ligatures for conjuncts. The below-base ra
  (blwf) is written back as ્ર after its consonant, and the reph (rphf),
  drawn after its syllable, is moved in front of it, as is the i-sign, drawn
  before its consonant. Arabic and anything set in plain Arial (e.g. the
  verse numbers of Munajaat E Ali's Quran citations) are left out.

- `legacy`: booklets set in LMG-Arun / InvGuj (same key layout), e.g. Hadees
  E Kisa (book 6666) and Ziarat E Ashura Arabic Gujarati (book 6685). Their
  keys decode with lmg_arun.py, plus a few keys these PDFs use that the
  duas.org decks did not (PDF_KEYS, worked out from words in context:
  ખોજાવાડ, હાજી, નક્કર, પૃથ્વી, આવૃત્તિ, સભ્યો, ધ્યાન, વચ્ચે, સાંભળ્યું).
  Each line is tagged with its font, because in these booklets one font
  holds the Arabic spelled out in Gujarati letters and the other the
  translation - which is which differs per book, so read a page first.
  The font's digits (!=1, Z=2, #=3 ... _=0) are left as keys.

Shree-Lipi booklets (SHREE-GUJ fonts, e.g. Dua E Sanam E Quraish, book
118431) are not decoded: E37 was transcribed from page images.

Needs pypdf and fontTools (pip install pypdf fonttools); `arialunicode`
needs macOS's /System/Library/Fonts/Supplemental/Arial Unicode.ttf.

    python3 scripts/zikr_i18n/gu_pdf.py arialunicode book.pdf > book.txt
    python3 scripts/zikr_i18n/gu_pdf.py legacy book.pdf > book.txt

Either way, check the output against the page images before using it.
"""
import collections
import os
import re
import sys

import pypdf

sys.path.insert(0, os.path.dirname(__file__))
import lmg_arun  # noqa: E402

ARIAL_UNICODE = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
CONS = '\u0a95-\u0ab9'
REPH = '\ue000'


def _glyph_map():
    from fontTools.ttLib import TTFont
    font = TTFont(ARIAL_UNICODE)
    gid = {name: i for i, name in enumerate(font.getGlyphOrder())}
    rev = {}
    for cp, name in sorted(font.getBestCmap().items()):
        rev.setdefault(gid[name], chr(cp))
    rev[gid['glyph07672']] = '\u0acd\u0ab0'  # blwf: below-base ra
    rev[gid['glyph07671']] = REPH  # rphf: reph
    lookups = font['GSUB'].table.LookupList.Lookup
    changed = True
    while changed:  # ligatures of ligatures
        changed = False
        for lookup in lookups:
            for st in lookup.SubTable:
                if st.LookupType == 7:
                    st = st.ExtSubTable
                if st.LookupType == 4:
                    for first, ligs in st.ligatures.items():
                        for lig in ligs:
                            parts = [rev.get(gid[g]) for g in [first, *lig.Component]]
                            if None not in parts and gid[lig.LigGlyph] not in rev:
                                rev[gid[lig.LigGlyph]] = ''.join(parts)
                                changed = True
                elif st.LookupType == 1:
                    for src, dst in st.mapping.items():
                        if rev.get(gid[src]) is not None and gid[dst] not in rev:
                            rev[gid[dst]] = rev[gid[src]]
                            changed = True
    return rev


def _logical(s):
    s = re.sub('\u0abf((?:[%s]\u0acd)*[%s]\u0abc?)' % (CONS, CONS), '\\1\u0abf', s)
    s = re.sub('((?:[%s]\u0acd)*[%s][\u0abc\u0abe-\u0acc\u0a81-\u0a83]*)%s'
               % (CONS, CONS, REPH), REPH + '\\1', s)
    return s.replace(REPH, '\u0ab0\u0acd')


def arialunicode(path):
    rev = _glyph_map()
    unknown = collections.Counter()
    out = []
    for number, page in enumerate(pypdf.PdfReader(path).pages, 1):
        fonts = {k: (v.get_object()['/BaseFont'], v.get_object()['/Subtype'])
                 for k, v in page['/Resources']['/Font'].items()}
        runs, font = [], [('', '')]

        def visit(op, operands, cm, tm):
            if op == b'Tf':
                font[0] = fonts.get(operands[0], ('', ''))
            elif op in (b'Tj', b"'", b'"', b'TJ'):
                name, subtype = font[0]
                items = operands[0] if op == b'TJ' else [operands[-1]]
                for item in items:
                    if isinstance(item, (int, float, pypdf.generic.NumberObject,
                                         pypdf.generic.FloatObject)):
                        continue
                    raw = item if isinstance(item, bytes) else item.original_bytes
                    if subtype != '/Type0':
                        # spaces and punctuation are set in a simple font
                        # between the Gujarati runs
                        text = raw.decode('latin-1')
                        if (runs and runs[-1][0] == 'gu'
                                and re.fullmatch(r'[\s\d,.!?;:()\-]*', text)):
                            runs[-1][2] += text
                    elif 'ArialUnicode' in name:
                        text = ''
                        for i in range(0, len(raw) - 1, 2):
                            g = raw[i] << 8 | raw[i + 1]
                            if g not in rev:
                                unknown[g] += 1
                            text += rev.get(g, '\ufffd')
                        y = round(tm[5])
                        if runs and runs[-1][0] == 'gu' and runs[-1][1] == y:
                            runs[-1][2] += text
                        else:
                            runs.append(['gu', y, text])
        page.extract_text(visitor_operand_before=visit)
        out.append(f'=== page {number}')
        out += [_logical(text).strip() for _, _, text in runs if text.strip()]
    if unknown:
        print('unknown glyph ids:', dict(unknown.most_common(20)), file=sys.stderr)
    return '\n'.join(out)


PDF_KEYS = {
    'Ô': 'HF', 'Ò': 'HL', 'Þ': 'S\u0acdS', 'y': 'Y\u0acd', 'e': 'E\u0acd',
    'w': 'W\u0acd', "'": '\u0ac3', 'Ÿ': '\u0acd', 'r': 'R\u0acd',
    '—': 'c', '˜': 'c', '\x7f': '', '\x80': '',
}
LEGACY_FONTS = {'InvGuj': 'INV', 'LMG ArunA': 'LMG', 'LMG-Arun,Bold': 'HEAD'}


def _legacy_line(raw):
    raw = re.sub(r'\?(?=\S)', '/\u0acd', raw)  # ? inside a word is half ળ
    text = lmg_arun.decode(''.join(PDF_KEYS.get(ch, ch) for ch in raw))
    text = re.sub(' +([\u0abe-\u0acd\u0a81-\u0a83])', r'\1', text)
    return text.replace('\u0acd\u0acd', '\u0acd').replace('પ ઢ', 'પઢ')


def legacy(path):
    lines, cur = [], None
    for number, page in enumerate(pypdf.PdfReader(path).pages, 1):
        def visit(text, cm, tm, font, size):
            nonlocal cur
            if not text or not font:
                return
            tag = LEGACY_FONTS.get(str(font.get('/BaseFont', '')).split('+')[-1])
            if tag is None:
                return
            y = tm[5] * cm[3] + cm[5]
            for i, part in enumerate(text.split('\n')):
                if (i or cur is None or cur[0] != number or cur[2] != tag
                        or abs(cur[1] - y) > 3):
                    if cur and cur[3].strip():
                        lines.append(cur)
                    cur = [number, y, tag, '']
                cur[3] += part
        page.extract_text(visitor_text=visit)
    if cur and cur[3].strip():
        lines.append(cur)
    return '\n'.join(f'p{n} {tag}: {_legacy_line(raw)}' for n, _, tag, raw in lines)


if __name__ == '__main__':
    mode, path = sys.argv[1], sys.argv[2]
    print({'arialunicode': arialunicode, 'legacy': legacy}[mode](path))
