"""Fill the empty right-hand (transliteration) column of a Word file of duas:
one table per dua, Arabic in the left cell. Used for Dad's dua file.

    python3 dua_docx.py in.docx out.docx [first last]   # tables first..last-1

dua_fixes.json lists corrections to the source Arabic ("fixes": table, old,
new, note) and to the transliteration where the program gets a correct
Arabic word wrong ("translit": table, got, want). Corrected Arabic is
written into the Arabic column, and the changed words are highlighted yellow
in both columns so they can be checked against the book.
"""
import copy, difflib, json, os, re, sys
import docx
from docx.enum.text import WD_COLOR_INDEX
import dua

HERE = os.path.dirname(os.path.abspath(__file__))
FIXES = json.load(open(os.path.join(HERE, 'dua_fixes.json'), encoding='utf-8'))


def canon(t):
    # one order for stacked marks (shadda + vowel) so the fixes match
    return re.sub('[ً-ٰٗ]+', lambda m: ''.join(sorted(m.group(0))), t)


def fixed(i, ar):
    ar = canon(ar)
    for f in FIXES['fixes']:
        if f['table'] == i:
            old, new = canon(f['old']), canon(f['new'])
            assert ar.count(old) == 1, (i, f['old'], ar.count(old))
            ar = ar.replace(old, new)
    return ar


def translit(i, ar):
    text = dua.transliterate(ar)
    for f in FIXES['translit']:
        if f['table'] == i:
            assert text.count(f['got']) == 1, (i, f['got'], text.count(f['got']))
            text = text.replace(f['got'], f['want'])
    return text


def changed(before, after):
    """-> [(chunk, is_changed)] covering `after`, by words."""
    a, b = before.split(), after.split()
    out = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(a=a, b=b, autojunk=False).get_opcodes():
        if j2 > j1:
            out.append((' '.join(b[j1:j2]), op != 'equal'))
    return out


def fill(p, chunks, rpr=None):
    for r in list(p.runs):
        r._r.getparent().remove(r._r)
    for k, (txt, hl) in enumerate(chunks):
        r = p.add_run(txt + (' ' if k + 1 < len(chunks) else ''))
        if rpr is not None:
            r._r.insert(0, copy.deepcopy(rpr))
        if hl:
            r.font.highlight_color = WD_COLOR_INDEX.YELLOW


def main(src, out, lo=0, hi=None):
    d = docx.Document(src)
    hi = len(d.tables) if hi is None else hi
    for i in range(lo, hi):
        ar_cell, tr_cell = d.tables[i].rows[0].cells
        orig = ar_cell.text
        new = fixed(i, orig)
        if new != canon(orig):
            # unchanged words keep their original spelling
            o, n = orig.split(), new.split()
            chunks = []
            sm = difflib.SequenceMatcher(a=[canon(w) for w in o], b=n, autojunk=False)
            for op, i1, i2, j1, j2 in sm.get_opcodes():
                if op == 'equal':
                    chunks.append((' '.join(o[i1:i2]), False))
                elif j2 > j1:
                    chunks.append((' '.join(n[j1:j2]), True))
            p = ar_cell.paragraphs[0]
            rpr = p.runs[0]._r.rPr if p.runs and p.runs[0]._r.rPr is not None else None
            fill(p, chunks, rpr)
        text = translit(i, new)
        fill(tr_cell.paragraphs[0], changed(translit(i, canon(orig)), text))
    d.save(out)


if __name__ == '__main__':
    a = sys.argv[1:]
    main(a[0], a[1], *map(int, a[2:4]))
