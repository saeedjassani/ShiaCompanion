"""Transliterate vocalised Indo-Pak-style dua text (اَ اِ اُ for hamza,
يْ / وْ for long vowels, ٗ / ٖ for the pronoun silah) in the same house style
as the Quran transliterations (see README.md).

The Quran engine needs Tanzil spelling and corpus morphology. Duas have
neither, so this module respells each word the Tanzil way and splits off the
wa-/fa-/bi-/li-/ka-/la- prefixes by rule, with PREFIX for the exceptions.

    python3 dua.py "اَللّٰهُمَّ اَنْتَ ثِقَتِيْ ..."
"""
import re, sys
from translit import (FATHA, KASRA, DAMMA, FATHATAN, KASRATAN, DAMMATAN, SHADDA,
                      SUKUN, DAGGER, MADDAH, IQLAB_HI, SMALL_WAW, SMALL_YEH, WASLA,
                      TATWEEL, MARKS, clusters)
from render import render_utterance, MUQ_LETTERS

MUQ = '\x00'  # marks a token of disjoined letters

VOWELS = {FATHA, KASRA, DAMMA}
TANWEEN = {FATHATAN, KASRATAN, DAMMATAN}
INV_DAMMA, SUB_ALIF = 'ٗ', 'ٖ'
ALT_SUKUN = 'ۡ'
SMALL_MADDA = 'ۤ'
ALIF_MADDA = 'آ'

# Punctuation that ends a breath: (pausal form?, text written after it)
PUNCT = [('...', '...'), ('…', '...'), ('.', '.'), ('،', ','), (',', ','),
         ('؛', ';'), (':', ':'), ('!', '!'), ('؟', '?')]

# Stems that glue onto a consonant prefix without a hyphen (BEKA, FAMAA, LAHUM).
FUNCTION = set('''ما من لا لم لن قد لو لما هل هو هي هم هما هن ك كم كما ه ها
نا ي ني ذلك ذا هذا هذه هؤلاء في ذي مهما'''.split())

# Words whose first letter looks like a prefix but is part of the root, or
# that need a split the rules can't see: skeleton -> number of prefixes.
PREFIX = {
    'ولي': 0, 'وليا': 0, 'ولد': 0, 'ولدا': 0, 'واحد': 0, 'وكلني': 0, 'واسع': 0, 'وجه': 0, 'وجهي': 0, 'وجهك': 0,
    'وحده': 0, 'وراء': 0, 'وسعت': 0, 'وقت': 0,
    'فوق': 0, 'فيه': 0, 'فيها': 0, 'فيما': 0, 'فاضلا': 0, 'فضل': 0, 'فضله': 0,
    'فقدت': 0, 'فرج': 0,
    'بين': 0, 'بعد': 0, 'بعض': 0,
    'لك': 1, 'لكم': 1, 'له': 1, 'لها': 1, 'لهم': 1, 'لنا': 1, 'لي': 1,
    'لطفا': 0, 'لطفك': 0, 'لعل': 0, 'لكن': 0, 'ليس': 0, 'ليلة': 0, 'لقاء': 0,
}


# Words starting with a root و / ف / ب / ل, by skeleton: whole words ...
ROOT_EXACT = set('''بسم بئس وسع وسعت وسعني وسعه وسعتني فوق فوقه فوقها فوقهم وقب لين
فقر فرح فرحا فخر فخرك فناء فجر وقرا وحي وحيك وحيه فرض فرضه فرضك وقت وقتا'''.split())
# ... and word beginnings (لِسَانِيْ, وَعَدْتَنِيْ, فَرَائِضِكَ)
ROOT_STARTS = ('لسان', 'لباس', 'فسق', 'فقير', 'فرائض', 'فريض', 'فاقة', 'فاقت', 'فزع', 'فضل',
               'وفاء', 'وجل', 'وداع', 'ودائع', 'ودايع', 'وكيل', 'وسيل', 'وحد', 'ولائج', 'وصي',
               'وهن', 'وعظ', 'ولد', 'واحد', 'وجه', 'وراء',
               'فاجر', 'فاحشة', 'واجد', 'وزير', 'فرائد', 'والين', 'والى',
               'ورث', 'واصب', 'فاطر', 'فاتح', 'واسع', 'فاخر', 'فاضل', 'فاز')


def root_initial(sk, cl):
    if sk in ROOT_EXACT or sk.startswith(ROOT_STARTS):
        return True
    if sk.startswith('وعد') and not sk.startswith('وعدو'):
        return True  # وَعَدْتَنِيْ, but وَعَدُوِّيْ is wa + 'aduwwi
    # وَلِيُّ, وَلِيِّكَ (waliyy) but وَلِيْ (wa + li)
    return sk.startswith('ولي') and len(cl) > 2 and SHADDA in cl[2][1]


PREP_PRON = set('''لك لكم له لها لهم لهما لنا لي بك بكم به بها بهم بنا بي'''.split())


def skel(w):
    return ''.join(c for c in w if c not in MARKS and c not in (
        INV_DAMMA, SUB_ALIF, ALT_SUKUN, SMALL_MADDA, TATWEEL, SMALL_WAW, SMALL_YEH))


def respell(tok):
    """Indo-Pak spelling -> the Tanzil-like spelling translit.parse_word reads."""
    t = tok.replace(ALT_SUKUN, SUKUN).replace(SMALL_MADDA, MADDAH).replace(TATWEEL, '')
    # آ before a hamza is a drawn-out alif (اِسْرَآءِيْلَ); elsewhere a hamza + long a (آلِ)
    t = re.sub(ALIF_MADDA + '(?=[ءأإؤئ]|$)', 'ا' + MADDAH, t)
    t = t.replace(ALIF_MADDA, 'ءَا' + MADDAH)
    t = t.replace('ی', 'ي')
    # اٰ is a hamza and a long a: اٰمَنُوْا, بِاٰيٰتِنَا, الْقُرْاٰنَ
    t = re.sub('ا(' + DAGGER + MADDAH + '?)', 'ءَا' + MADDAH, t)
    # pronoun silah / long vowel signs: هٗ -> هُۥ, هٖ -> هِۦ
    # (only at the end of a word; inside one they are plain long vowels: اِبْرٰهٖمَ)
    t = re.sub(INV_DAMMA + '(?=' + MADDAH + '?$)', DAMMA + SMALL_WAW, t)
    t = re.sub(SUB_ALIF + '(?=' + MADDAH + '?$)', KASRA + SMALL_YEH, t)
    t = t.replace(INV_DAMMA, DAMMA + 'و').replace(SUB_ALIF, KASRA + 'ي')
    cl = clusters(t)
    out = []
    for i, (b, ms, _) in enumerate(cl):
        ms = list(ms)
        prev = cl[i - 1] if i else None
        # إٍ: the seat already says kasra, the tanween says it again (مَلَإٍ)
        if b == 'إ' and any(m in TANWEEN for m in ms):
            b = 'ء'
        if b == 'ا' and any(m in VOWELS for m in ms):
            v = [m for m in ms if m in VOWELS][0]
            b = {FATHA: 'أ', KASRA: 'إ', DAMMA: 'أ'}[v]
        # a bare alif before a vowelless consonant is hamzat al-wasl: فَاجْعَلْهُ, كَالَّذِيْ
        if b == 'ا' and not ms and i and prev[0] in 'وفبكلت' and i + 1 < len(cl) and (
                SUKUN in cl[i + 1][1] or (cl[i + 1][0] == 'ل' and SHADDA in cl[i + 1][1]) or
                (not cl[i + 1][1] and i + 2 < len(cl) and SHADDA in cl[i + 2][1])):
            b = WASLA
        # long vowel letters carry a sukun in Indo-Pak: فِيْ, يَقُوْلُ, الَّذِىْ
        if b == 'ى' and prev and KASRA in prev[1]:
            b = 'ي'
        if b in 'يو' and SUKUN in ms and prev and \
                ((b == 'ي' and KASRA in prev[1]) or (b == 'و' and DAMMA in prev[1])):
            ms.remove(SUKUN)
        # و / ي with a standing fatha are consonants: السَّمٰوٰتِ, يٰۤاَيُّهَا, الْقِيٰمَةِ
        if b in 'يو' and DAGGER in ms and not any(m in VOWELS for m in ms):
            ms.insert(0, FATHA)
        # a bare و after a standing fatha is only a spelling: الصَّلٰوةَ, الْحَيٰوةِ
        if b == 'و' and not ms and prev and DAGGER in prev[1]:
            continue
        # iqlab inside a word: اَنْبِيَاء
        if b == 'ن' and i + 1 < len(cl) and cl[i + 1][0] == 'ب' and not any(m in VOWELS for m in ms):
            ms = [m for m in ms if m != SUKUN] + [IQLAB_HI]
        # final ي after a fatha is an alif maqsura: صَلَّي
        if b == 'ي' and not ms and i == len(cl) - 1 and prev and (FATHA in prev[1] or DAGGER in prev[1]):
            b = 'ى'
        out.append([b, ms])
    # a long vowel followed by a hamza in the same word is drawn out (SAMAAA-E)
    for i in range(1, len(out) - 1):
        b, ms = out[i]
        nb = out[i + 1][0]
        if nb in 'ءأإؤئ' and not ms and (
                (b == 'ا' and FATHA in out[i - 1][1]) or
                (b == 'ي' and KASRA in out[i - 1][1]) or
                (b == 'و' and DAMMA in out[i - 1][1])):
            ms.append(MADDAH)
    return out


def join(cl):
    return ''.join(b + ''.join(ms) for b, ms in cl)


ALLAH_RE = re.compile(r'^(و|ف|ب|ت)?(ا|أ)?للا?ه(م)?$')


def analyse(tok, initial=False, prev=''):
    """-> word dict for engine.build_stream. `prev` is the word before."""
    cl = respell(tok)
    sk = skel(tok)
    # a sentence-initial اَلْ / اَلَّذِيْ is the article's hamzat al-wasl (AL-HAMDO, LAZEE)
    if initial and len(cl) > 2 and cl[0][0] == 'أ' and cl[1][0] == 'ل' and \
            (SUKUN in cl[1][1] or (not cl[1][1] and SHADDA in cl[2][1]) or
             (SHADDA in cl[1][1] and sk[:3] in ('الذ', 'الت'))):
        cl[0] = [WASLA, []]
    is_allah = bool(ALLAH_RE.match(sk.replace('ٱ', 'ا'))) or sk in ('لله', 'للهم')
    if is_allah:
        # يَا اَللّٰهُ keeps its hamza (YAA ALLAAHO)
        keep = skel(prev) == 'يا' and cl[0][0] == 'أ'
        cl = respell_allah(cl, sk)
        if keep:
            cl[0] = ['أ', [FATHA]]
    # split prefixes
    npre = PREFIX.get(sk)
    if npre is None and root_initial(sk, cl):
        npre = 0
    # after a separate وَ / فَ a leading و is the word's own: وَ وَفَاءً
    if npre is None and skel(prev) in ('و', 'ف') and sk[:1] == 'و':
        npre = 0
    pre = []
    k = 0
    while True:
        if k >= len(cl) - 1:
            break
        b, ms = cl[k]
        if npre is not None and len(pre) >= npre:
            break
        tag = None
        conj = not pre
        prep = not any(t in ('P', 'EMPH') for _, t in pre)
        # لَكَ, بِهٖ: a preposition with a pronoun stays one word (FALAKA, WA BEHI)
        if npre is None and pre and skel(join(cl[k:])) in PREP_PRON:
            break
        # (a وَّ glued to its word is still wa: the shadda is the idgham)
        if b == 'و' and FATHA in ms and conj:
            tag = 'CONJ'
        elif b == 'ف' and FATHA in ms and conj:
            tag = 'REM'
        elif not prep:
            pass
        elif b == 'ب' and KASRA in ms:
            tag = 'P'
        elif b == 'ل' and KASRA in ms:
            tag = 'P'
        elif b == 'ل' and FATHA in ms and (npre is not None or cl[k + 1][0] == WASLA):
            tag = 'EMPH'
        elif b == 'ك' and FATHA in ms and (npre is not None or cl[k + 1][0] == WASLA):
            tag = 'P'
        if tag is None:
            break
        rest = cl[k + 1:]
        # bi-/li-/fa-/wa- need a stem after them: not the whole word (بِكَ is bi + ka)
        if npre is None and not plausible_prefix(b, rest, is_allah):
            break
        if tag == 'CONJ' and SHADDA in ms:  # (a separate وَّ is handled in link())
            cl[k] = [b, [m for m in ms if m != SHADDA]]
        pre.append((join([cl[k]]), tag))
        k += 1
    stem = cl[k:]
    # a bare alif at the start of a word (or right after its prefixes) is hamzat al-wasl
    if stem and stem[0][0] == 'ا' and not stem[0][1]:
        stem[0][0] = WASLA
    stem_s = skel(join(stem))
    # (a written vowel on the alif makes it a real hamza: يَوْمَ اَلْقَاكَ, حِيْلَةٍ اَلْجَاُ)
    has_al = len(stem) > 1 and stem[0][0] in (WASLA, 'ا') and stem[1][0] == 'ل' and not is_allah \
        and (SUKUN in stem[1][1] or not stem[1][1] or (len(stem) > 2 and SHADDA in stem[2][1]))
    if not has_al and pre and stem and stem[0][0] == 'ل' and SUKUN in stem[0][1] and pre[-1][1] == 'P':
        has_al = True  # لِلْمُؤْمِنِيْنَ
    if stem_s.lstrip('اٱ') in ('لذي', 'لذين', 'لتي', 'لذان', 'لتان', 'لاتي', 'لائي'):
        has_al = False  # الَّذِيْ is a pronoun: LILLAZEE
    func = stem_s in FUNCTION or stem_s in PREP_PRON or stem_s.lstrip('اٱ') in ('لذي', 'لذين', 'لتي') or (pre and len(stem_s) <= 2 and stem_s in ('ك', 'كم', 'ه', 'ها', 'هم', 'هما', 'نا', 'ي', 'ني', 'هن', 'كما'))
    segs = [(join(stem), '', 'STEM', 'N', ['PRON' if func else 'ROOT:x'])]
    ar = join(pre and [] or []) + ''.join(p for p, _ in pre) + join(stem)
    return {'ar': ar, 'idx': 0, 'prefixes': pre, 'stem': join(stem), 'has_al': has_al,
            'pause_after': None, 'is_allah': is_allah, 'segs': segs, 'src': tok}


def plausible_prefix(letter, rest, is_allah):
    if not rest:
        return False
    if is_allah:
        return True
    rs = ''.join(b for b, _ in rest)
    # no word starts with a doubled letter: فَرِّغْنِيْ, بِرٍّ are one word
    if SHADDA in rest[0][1]:
        return False
    # بِ / لِ + one letter only as a pronoun: بِكَ, لِيْ, بِهٖ
    if len(rs) == 1 and rs not in 'كهي':
        return False
    if letter in 'وف':
        # وَ / فَ + a word of at least two letters; the root cases are in PREFIX
        return len(rs) >= 2
    # بِ / لِ + pronoun suffix (بِكَ, لِيْ) or + a word
    return len(rs) >= 1


def respell_allah(cl, sk):
    """Allah-words in Tanzil spelling: ٱللَّهِ, لِلَّهِ, ٱللَّهُمَّ."""
    out = []
    i = 0
    # prefix letter (وَ فَ بِ تَ) stays as written
    if cl and cl[0][0] in 'وفبت' and (sk[0] in 'وفبت'):
        out.append(cl[0]); i = 1
    rest = cl[i:]
    letters = ''.join(b for b, _ in rest)
    end = rest[-1][1] if rest else []
    if letters.startswith('لل'):          # لِلهِ (li-llah)
        li = rest[0]
        out.append(li)
        h = [c for c in rest if c[0] == 'ه'][0]
        out.append(['ل', [SHADDA, FATHA]])
        out.append(['ه', [m for m in h[1] if m in VOWELS]])
        if letters.endswith('م'):
            out.append(['م', [SHADDA, FATHA]])
        return out
    out.append([WASLA, []])
    out.append(['ل', []])
    out.append(['ل', [SHADDA, FATHA]])
    h = [c for c in rest if c[0] == 'ه'][0]
    out.append(['ه', [m for m in h[1] if m in VOWELS]])
    if letters.endswith('م'):
        out.append(['م', [SHADDA, FATHA]])
    return out


# Quranic stop signs: these pause, like a full stop in a dua ...
PAUSE_SIGNS = {'\u06d6', '\u06d7', '\u06da', '\u06d8', '\u0615'}
# ... these only get a comma (laa, the paired dots, saktah)
COMMA_SIGNS = {'\u06d9', '\u06db', '\u06dc'}
AYAH_END = '\u06dd'
LETTERS = {'\u06c1': 'ه', '\u06be': 'ه', '\u06c3': 'ة', '\u06cc': 'ي', '\u06a9': 'ك'}
# (the iqlab meems ۢ ۭ too: link() and respell() put iqlab where a ب follows)
DROP = re.compile('[\u06e2\u06ed\u200c\u200e\u200f\u06ea\u06eb\u06e3\u061a\u06f0-\u06f9\u0660-\u0669«»‘’“”]')


def normalise(text):
    for a, b in LETTERS.items():
        text = text.replace(a, b)
    # the small noon ۨ (nun qutni) is the tanween's n before a wasl: شَكُوْرُۨ الَّذِيْ
    text = re.sub('([\u064e\u064f\u0650])\u06e8', lambda m: {'\u064e': '\u064b', '\u064f': '\u064c', '\u0650': '\u064d'}[m.group(1)], text)
    text = text.replace('\u06e8', '')
    text = DROP.sub('', text)
    # an alif with a sukun is a hamza with a sukun: وَاْتُوْنِيْ, يَاْوِيْ
    text = re.sub('ا\u0652', 'أ\u0652', text)
    # a hamza sign over / under a seat: اٴ -> أ, إ -> إ
    text = re.sub('ا([\u064b-\u0652\u0670]*)\u0654', 'أ\\1', text)
    text = re.sub('ا([\u064b-\u0652\u0670]*)\u0655', 'إ\\1', text)
    text = re.sub('ي([\u064b-\u0652\u0670]*)\u0654', 'ئ\\1', text)
    text = re.sub('و([\u064b-\u0652\u0670]*)\u0654', 'ؤ\\1', text)
    text = re.sub('ى([\u064b-\u0652\u0670]*)[\u0654\u0655]', 'ئ\\1', text)
    text = text.replace('\u0654', '').replace('\u0655', '')
    # ۗ inside a word is a madd sign, not a stop: تَشَاۗءُ, الْمَلٰۗىِٕكَةُ
    text = re.sub('\u06d7(?=[\u0621-\u0670])', MADDAH, text)
    # ص with a small seen is read as س: بَصْۜطَةً
    text = re.sub('ص([\u064b-\u0652]*)\u06dc', 'س\\1', text)
    signs = PAUSE_SIGNS | COMMA_SIGNS | {AYAH_END}
    # marks typed after an ayah sign (۝۰ۥ) belong to nothing
    allmarks = ''.join(MARKS | {SMALL_WAW, SMALL_YEH, INV_DAMMA, SUB_ALIF, ALT_SUKUN, SMALL_MADDA})
    text = re.sub(AYAH_END + '[' + re.escape(allmarks) + ']+', AYAH_END, text)
    text = ''.join(' ' + c + ' ' if c in signs else c for c in text)
    # a mark cut off from its word by a space (رَحِيْمٍ ۭ, لَهٗ ۥ) goes back on it
    marks = ''.join(MARKS | {SMALL_WAW, SMALL_YEH, INV_DAMMA, SUB_ALIF, ALT_SUKUN, SMALL_MADDA})
    text = re.sub('\\s+([' + re.escape(marks) + ']+)(?=[\\s.,،]|$)', '\\1', text)
    # ... also when it got glued onto the front of the next word (ۡوَ)
    text = re.sub('(\\S)\\s+([' + re.escape(marks) + ']+)(?=[\u0621-\u064a])', '\\1\\2 ', text)
    # the vocative يٰ written onto its noun (يٰنَارُ) is its own word, YAA NAARO
    text = re.sub('(^|\\s)يٰ(?=[\u0621-\u064a])', '\\1يَا ', text)
    return text


def cons(w):
    """Consonant skeleton, the same for Indo-Pak and Uthmani spelling."""
    w = skel(w.replace('ٱ', 'ا'))
    return re.sub('[اأإآىيوؤئءة]', '', w.replace('ة', 'ه'))


_AYAH_ENDS = None


def ayah_ends():
    """{(last words..., first word of next ayah)} for every ayah, by skeleton."""
    global _AYAH_ENDS
    if _AYAH_ENDS is None:
        from common import tanzil
        t = tanzil()
        _AYAH_ENDS = set()
        for (su, a), txt in t.items():
            nxt = t.get((su, a + 1))
            if not nxt:
                continue
            w = [cons(x) for x in txt.split() if cons(x)]
            n = [cons(x) for x in nxt.split() if cons(x)]
            if len(w) >= 2 and n:
                _AYAH_ENDS.add(tuple(w[-2:]) + (n[0],))
    return _AYAH_ENDS


_ENDS3 = None


def ends_long():
    """The last five words of every ayah (all of a four-word one), the
    Bismillah aside: enough to know a verse has ended whatever follows."""
    global _ENDS3
    if _ENDS3 is None:
        from common import tanzil
        _ENDS3 = set()
        for (su, a), txt in tanzil().items():
            w = [cons(x) for x in txt.split() if cons(x)]
            if len(w) >= 4 and (su, a) != (1, 1):
                _ENDS3.add(tuple(w[-5:]))
    return _ENDS3


def mark_ayah_ends(toks):
    """Pause at the end of a quoted verse whose ayah sign was left out."""
    ends = ayah_ends()
    sk = [cons(t) for t in toks]
    # word positions that have letters (a separate وَ has no skeleton left)
    real = [j for j, x in enumerate(sk) if x]
    seq = [sk[j] for j in real]
    after = set()
    for n, j in enumerate(real):
        if n + 1 >= len(real):
            break
        t = toks[j]
        if any(t.endswith(p) for p, _ in PUNCT) or \
                any(x in PAUSE_SIGNS | COMMA_SIGNS | {AYAH_END} for x in toks[j + 1:real[n + 1]]):
            continue
        if any(n >= k - 1 and tuple(seq[n - k + 1:n + 1]) in ends_long() for k in (5, 4)) or \
                (n >= 1 and len(seq[n + 1]) >= 2 and tuple(seq[n - 1:n + 2]) in ends):
            after.add(j)
    # a Bismillah that opens a quoted surah stands on its own: ... AL-HAKEEM.
    # BISMIL LAAHIR RAHMAANIR RAHEEM. QUL ...
    bism = tuple(cons(x) for x in 'بسم الله الرحمن الرحيم'.split())
    for n in range(3, len(real) - 1):
        if tuple(seq[n - 3:n + 1]) == bism and seq[n + 1] in surah_openings():
            after.add(real[n])
            if n >= 4:
                after.add(real[n - 4])
    out = []
    for j, t in enumerate(toks):
        out.append(t)
        if j in after and not any(t.endswith(p) for p, _ in PUNCT) and \
                not (j + 1 < len(toks) and toks[j + 1] in PAUSE_SIGNS | COMMA_SIGNS | {AYAH_END}):
            out.append(AYAH_END)
    return out


_OPENINGS = None


def surah_openings():
    global _OPENINGS
    if _OPENINGS is None:
        from common import tanzil
        _OPENINGS = {w[0] for (su, a), txt in tanzil().items() if a == 1 and su != 1
                     for w in [[cons(x) for x in txt.split() if cons(x)]] if w and len(w[0]) >= 2}
    return _OPENINGS


def tokenize(text):
    """-> list of sentences, each (words, closing punctuation, indices of
    words followed by a comma without a pause)."""
    toks = mark_ayah_ends(normalise(text).split())
    sents = []
    cur = []
    commas = set()
    for t in toks:
        punct = None
        if t in COMMA_SIGNS:
            if cur:
                commas.add(len(cur) - 1)
            continue
        if t in PAUSE_SIGNS:
            punct, t = ',', ''
        elif t == AYAH_END:
            punct, t = '.', ''
        for p, rep in PUNCT:
            if t.endswith(p):
                punct = rep
                t = t[:-len(p)]
                break
        sk = skel(t)
        if t and sk in MUQ_LETTERS and not any(m in t for m in VOWELS | TANWEEN):
            # الٓمّٓ is spelled by name (ALIF LAAAM MEEM), as its own sentence
            if cur:
                sents.append((cur, '', commas))
                cur, commas = [], set()
            sents.append(([MUQ + t], punct or '', set()))
            continue
        if t:
            cur.append(t)
        if punct and cur:
            sents.append((cur, punct, commas))
            cur, commas = [], set()
        elif punct and sents and punct == '.':
            sents[-1] = (sents[-1][0], '.', sents[-1][2])
    if cur:
        sents.append((cur, '', commas))
    return sents


def link(words):
    """Across-word assimilation the Indo-Pak spelling shows (or needs)."""
    # وَّ after a vowel (التَّقْوٰى وَّ) is a plain WA; after a tanween the engine
    # makes the idgham (KARBINW WA) without the shadda
    words = [re.sub('^و([\u064e\u0651]+)', 'وَ', w) if skel(w) == 'و' else w for w in words]
    for i in range(len(words) - 1):
        a, b = words[i], words[i + 1].replace(ALT_SUKUN, SUKUN)
        first = clusters(b)[0] if b else None
        # لَهُمْ مِّنْ, قُلْ رَّبِّ: the shadda on the next word swallows the sukun
        if first and SHADDA in first[1] and a.endswith((SUKUN, ALT_SUKUN)):
            words[i] = a[:-1]
        # iqlab: مِنْ بَعْدِ, عَلِيْمًا بِ
        if first and first[0] == 'ب':
            cl = clusters(words[i])
            for j in range(len(cl) - 1, -1, -1):
                ms = cl[j][1]
                if any(m in TANWEEN for m in ms) or (cl[j][0] == 'ن' and not any(m in VOWELS for m in ms)):
                    pos = cl[j][2] + 1 + len(ms)
                    w = words[i].replace(ALT_SUKUN, SUKUN)
                    if cl[j][0] == 'ن':
                        w = w[:cl[j][2] + 1] + ''.join(m for m in ms if m not in (SUKUN, ALT_SUKUN)) + w[pos:]
                        pos = cl[j][2] + 1 + len([m for m in ms if m not in (SUKUN, ALT_SUKUN)])
                    words[i] = w[:pos] + IQLAB_HI + w[pos:]
                    break
                if cl[j][0] not in 'اى':
                    break
    return words


def transliterate(text):
    out = []
    for words, punct, commas in tokenize(text):
        if words[0].startswith(MUQ):
            out.append(MUQ_LETTERS[skel(words[0][1:])] + (punct or '.'))
            continue
        lw = link(words)
        ws = [analyse(w, i == 0, lw[i - 1] if i else '') for i, w in enumerate(lw)]
        for i, w in enumerate(ws):
            w['idx'] = i + 1
        # no comma where the reading runs on into a hamzat al-wasl
        cw = {i for i in commas if i + 1 < len(ws) and not ws[i + 1]['ar'].startswith(WASLA)}
        txt, _ = render_utterance(ws, pause=True, comma_words=cw)
        out.append(txt + punct)
    return ' '.join(out)


if __name__ == '__main__':
    print(transliterate(' '.join(sys.argv[1:])))
