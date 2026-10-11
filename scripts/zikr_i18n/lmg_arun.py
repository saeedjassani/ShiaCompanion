"""Decoder for Gujarati typed in the legacy LMG-Arun font, as in duas.org's
Dua Kumayl (Dua_Kumayl_5languages.pptx) and Ziyarat Jamia Kabira
(Ziyarat-jamia-kabira-eng-urdu-hindi-guj.pptx) decks.

LMG-Arun maps Gujarati glyphs onto ASCII keys. Most keys are a whole
consonant or a vowel sign, and a few are half forms (consonant + virama);
a half form followed by the aa-stem F is the full consonant.
Three need reordering into Unicode's logical order:
  l   the i-sign, typed before the consonant it follows;
  "   the repha (ર્), typed after the syllable it sits on;
  | = the subscript ra (્ર), typed after its consonant.
The decks often type a vowel sign twice ("]\\]\\" for ું). The font draws
the copies on top of each other, so repeated runs of signs are collapsed.

    python3 scripts/zikr_i18n/lmg_arun.py text 'VI V<,FC ¦'   # -> અય અલ્લાહ!
    # rows for deck_source.py align, as deck_source.py rows writes them
    python3 scripts/zikr_i18n/lmg_arun.py rows deck.pptx rows.json
"""
import re
import sys

CONSONANT = {
    'S': 'ક', 'B': 'ખ', 'U': 'ગ', '3': 'ઘ', 'R': 'ચ', 'K': 'છ', 'H': 'જ',
    'h': 'ઝ', '8': 'ટ', '9': 'ઠ', '0': 'ડ', '-': 'ઢ', '6': 'ણ', 'T': 'ત',
    'Y': 'થ', 'N': 'દ', 'W': 'ધ', 'G': 'ન', '5': 'પ', 'O': 'ફ', 'A': 'બ',
    'E': 'ભ', 'D': 'મ', 'I': 'ય', 'Z': 'ર', ',': 'લ', 'J': 'વ', 'X': 'શ',
    ';': 'સ', 'C': 'હ', '/': 'ળ',
    # conjuncts with a glyph of their own
    '7': 'જ્ઞ', '+': 'ત્ર', 'z': 'શ્ર',
    'â': 'દ્વ', 'ã': 'દ્ર', '~': 'રૂ',
}
HALF = {
    'b': 'ખ', 'u': 'ગ', 't': 'ત', 'g': 'ન', 'a': 'બ', 'd': 'મ', 'i': 'ય',
    '<': 'લ', 'j': 'વ', 'x': 'શ', '`': 'શ', ':': 'સ', '%': 'પ', 'Q': 'ષ',
    '1': 'ક્ષ',
}
VOWEL = {'V': 'અ', 'p': 'ઉ', '.': 'ઇ', 'r': 'ઇ'}
SIGN = {
    'F': 'ા', 'L': 'ી', ']': 'ુ', '}': 'ૂ', '[': 'ે', '{': 'ૈ', 'M': 'ો',
    '\\': 'ં', 'o': 'ઃ',
}
PUNCT = {
    '4': ',', 'P': '.', '·': '.', 's': '(', 'f': ')', 'm': '?', '¦': '!',
    'c': '"', 'v': '-',
}
DROP = {'˜', 'Ò'}
MARK_KEYS = set(SIGN) | {'|', '=', '"'}
VIRAMA = '્'
SIGNS = set(SIGN.values()) | {'ૌ', 'ૉ'}


def _collapse_repeats(text):
    marks = re.escape(''.join(sorted(MARK_KEYS)))
    return re.sub(f'((?:[{marks}]){{1,3}})\\1+', r'\1', text)


def _cluster_start(out):
    """Index in out where the syllable ending at out[-1] starts: back over
    vowel signs, then the consonant, then any half forms before it."""
    i = len(out)
    while i > 0 and out[i - 1] in SIGNS:
        i -= 1
    if i == 0:
        return 0
    i -= 1  # the consonant (or a whole conjunct glyph)
    while i >= 2 and out[i - 1] == VIRAMA:
        i -= 2
    return i


def decode_word(word):
    word = _collapse_repeats(word)
    out = []
    pending_i = False
    k = 0
    while k < len(word):
        ch = word[k]
        if ch in DROP:
            pass
        elif ch == 'l':
            pending_i = True
        elif ch in HALF and word[k + 1:k + 2] == 'F':
            # a half form plus the aa-stem is the full consonant
            out.append(HALF[ch])
            if pending_i:
                out.append('િ')
                pending_i = False
            k += 1
        elif ch in HALF:
            out += [HALF[ch], VIRAMA]
        elif ch in CONSONANT:
            out.append(CONSONANT[ch])
            if word[k + 1:k + 2] in ('|', '='):
                out += [VIRAMA, 'ર']
                k += 1
            if pending_i:
                out.append('િ')
                pending_i = False
        elif ch in ('|', '='):
            out += [VIRAMA, 'ર']
        elif ch == '"':
            out.insert(_cluster_start(out), 'ર' + VIRAMA)
        elif ch in VOWEL:
            out.append(VOWEL[ch])
        elif ch in SIGN:
            sign = SIGN[ch]
            prev = out[-1] if out else ''
            if prev == 'અ' and sign in 'ાેૈો':
                out[-1] = {'ા': 'આ', 'ે': 'એ', 'ૈ': 'ઐ', 'ો': 'ઓ'}[sign]
            elif prev == 'આ' and sign in 'ેૈ':
                out[-1] = {'ે': 'ઓ', 'ૈ': 'ઔ'}[sign]
            elif prev == 'ઉ' and sign == 'ૂ':
                out[-1] = 'ઊ'
            elif prev == 'ા' and sign in 'ેૈ':
                out[-1] = {'ે': 'ો', 'ૈ': 'ૌ'}[sign]
            else:
                out.append(sign)
        elif ch in PUNCT:
            out.append(PUNCT[ch])
        else:
            out.append(ch)
        k += 1
    text = ''.join(out)
    # A sign typed before the subscript ra belongs after it, and a sign
    # typed again around the anusvara is the same sign.
    text = re.sub('([ાિીુૂેૈોૌ]+)્ર', r'્ર\1', text)
    text = re.sub('ં([ાિીુૂેૈોૌ])', r'\1ં', text)
    text = re.sub('ં+', 'ં', text)
    text = re.sub('([ાિીુૂેૈોૌ])(ં?)\\1', r'\1\2', text)
    return text


def decode(text):
    words = []
    for word in text.split():
        if word == '/':
            continue
        words.append(decode_word(word))
    text = ' '.join(w for w in words if w)
    text = re.sub(r'"+', '"', text)
    text = re.sub(r'\s+([,.!?)])', r'\1', text)
    text = re.sub(r'[!?]{2,}', lambda m: '?' if '?' in m.group() else '!', text)
    return text.strip()




def deck_rows(path):
    """deck_source.py-style rows from a deck whose translation is LMG-Arun
    Gujarati: per slide, its Arabic and its decoded Gujarati."""
    import html
    import zipfile
    sys.path.insert(0, __import__('os').path.dirname(__file__))
    from deck_source import _script
    deck = zipfile.ZipFile(path)
    names = sorted(
        (n for n in deck.namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)),
        key=lambda n: int(re.search(r'(\d+)\.xml$', n).group(1)))
    rows = []
    for number, name in enumerate(names, 1):
        xml = deck.read(name).decode('utf-8')
        ar, gu = [], []
        for p in re.findall(r'<a:p>.*?</a:p>|<a:p .*?</a:p>', xml, re.S):
            p_ar, p_gu = '', ''
            for run in re.findall(r'<a:r>.*?</a:r>', p, re.S):
                face = re.search(r'<a:latin typeface="([^"]*)"', run)
                text = re.search(r'<a:t>(.*?)</a:t>', run, re.S)
                if not text:
                    continue
                text = html.unescape(text.group(1))
                if face and 'LMG' in face.group(1):
                    p_gu += text
                elif _script(text) == 'ar' or (p_ar and not text.strip()):
                    p_ar += text
            if p_ar.strip():
                ar.append(' '.join(p_ar.split()))
            if p_gu.strip():
                gu.append(decode(p_gu))
        if ar or gu:
            rows.append({'slide': number, 'ar': ' '.join(ar),
                         'translation': ' '.join(gu), 'other': ''})
    return rows


if __name__ == '__main__':
    if sys.argv[1] == 'rows':
        import json
        rows = deck_rows(sys.argv[2])
        with open(sys.argv[3], 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=1)
        print(f'{len(rows)} rows -> {sys.argv[3]}')
    else:
        for arg in sys.argv[2:]:
            print(decode(arg))
