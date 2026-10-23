"""Fill the empty right-hand (transliteration) column of a Word file of duas:
one table per dua, Arabic in the left cell. Used for Dad's dua file.

    python3 dua_docx.py in.docx out.docx 0 8      # tables 0-7

FIXES corrects typos in the source Arabic before transliterating (the Arabic
column is left as it is); the corrected words are highlighted yellow in the
transliteration so they can be checked against the book.
"""
import re, sys, docx
from docx.enum.text import WD_COLOR_INDEX
import dua

# table -> [(old Arabic, new Arabic, note, transliteration to highlight)]
FIXES = {
    0: [
        ('اَنْزَلَتُهٗ', 'اَنْزَلْتُهٗ',
         'انزلتُه: sukun on the lam (anzaltuhu), as in dua 4', 'ANZALTOHU'),
    ],
    2: [
        ('اَسْتَوْجَبَ', 'اسْتَوْجَبَ',
         'استوجب is istawjaba (hamzat al-wasl), so LAZIS TAWJABA', 'LAZIS TAWJABASH'),
        ('اِعْطِنِيْ', 'اَعْطِنِيْ',
         'اعطني is a‘ṭinī with a fatha (give me)', 'A-A’TENEE'),
    ],
    3: [
        ('اِتِكَالِيْ', 'اِتِّكَالِيْ',
         'اتّكالي needs a shadda on the ta (ittikālī)', 'ITTEKAALEE'),
    ],
    4: [
        ('الشَّرِ ', 'الشَّرِّ ',
         'الشرّ needs a shadda on the ra (ash-sharri)', 'SHARRE'),
    ],
    6: [
        ('فِرْعَوْنَ اِكْفِنِيْ', 'فِرْعَوْنَ، اِكْفِنِيْ',
         'pause added after فرعون, since the Arabic starts اِكْفِنِيْ fresh', 'FIR-A’WN,'),
        ('مَا اَنَا فِيْهِ اَللّٰهُ', 'مَا اَنَا فِيْهِ، اَللّٰهُ',
         'pause added before اَللّٰهُ اَللّٰهُ رَبِّيْ', 'FEEH,'),
        ('الْمرْبُوْبِيْنَ', 'الْمَرْبُوْبِيْنَ',
         'المربوبين: fatha on the meem was missing', 'MARBOOBEENA'),
        ('حَبْسِيْ', 'حَسْبِيْ',
         'حبسي is a typo for حسبي (hasbī)', 'HASBEE MAL'),
    ],
    7: [
        ('تَخْفٰىٍ', 'تَخْفٰى',
         'تخفى: stray tanween removed', 'TAKHFAA'),
        ('تَشْتَبِهٗ', 'تَشْتَبِهُ',
         'تشتبه: the ha is part of the verb (tashtabihu), not the pronoun', 'TASHTABEHO'),
        ('اكْنِفْنِيْ', 'اكْنُفْنِيْ',
         'اكنفني: damma on the nun (uknufnī), as in dua 7', 'NUFNEE BE-RUKNEKAL LAZEE LAA YOZAAM'),
        ('اِلْتِمَاسَ', 'الْتِمَاسَ',
         'التماس begins with hamzat al-wasl (wal-timāsa)', 'WAL TEMAASA'),
        ('لِاَوَاءٍ', 'لَاْوَاءٍ',
         'لأواء (la’wā’, hardship), not li-awā’', 'LAAWAAA-INW'),
        ('خَلصْتَهٗ', 'خَلَّصْتَهٗ',
         'خلصته had no vowels on lam; read as khallaṣtahu. Please check against the book', 'KHALLASTAHU'),
    ],
}


def canon(t):
    # one order for stacked marks (shadda + vowel) so the fixes match
    return re.sub('[ً-ٰٗ]+', lambda m: ''.join(sorted(m.group(0))), t)


def fixed(i, ar):
    ar = canon(ar)
    for old, new, _, _ in FIXES.get(i, []):
        old, new = canon(old), canon(new)
        assert ar.count(old) == 1, (i, old)
        ar = ar.replace(old, new)
    return ar


def main(src, out, lo, hi):
    d = docx.Document(src)
    for i in range(lo, hi):
        t = d.tables[i]
        text = dua.transliterate(fixed(i, t.rows[0].cells[0].text))
        hl = [h for _, _, _, h in FIXES.get(i, [])]
        for h in hl:
            assert text.count(h) == 1, (i, h)
        p = t.rows[0].cells[1].paragraphs[0]
        parts = re.split('(' + '|'.join(map(re.escape, hl)) + ')', text) if hl else [text]
        for part in filter(None, parts):
            r = p.add_run(part)
            if part in hl:
                r.font.highlight_color = WD_COLOR_INDEX.YELLOW
    d.save(out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]))
