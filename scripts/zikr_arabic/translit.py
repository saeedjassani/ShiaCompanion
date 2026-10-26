"""House-style transliteration for vocalised du'a Arabic.

The house style is the one the app's Quran and most of its hand-made dua
transliteration use (see scripts/quran_transliteration/README.md, which
this follows for duas):

- Short vowels: fatha A; kasra I in a closed syllable, E in an open one
  (BISMIL, MIN / MENAL, ELAYKA); damma U closed, O open (KUNTO, QUWWATA /
  ASH-HADO, MOHAMMAD). Before an unvowelled ه ح ع ء the syllable counts as
  open (MOHTADEEN, NE’MATIN).
- Long vowels AA EE OO; alif + hamza in one word AAA (RAJAAA-EE, TASHAAA-O).
  The pronoun's silah is HU / HI (LAHU, BEHI), never HOO / HEE.
- 'ayn is ’ after its vowel (A’LAA, NE’MATEKA, YAZ-O’FO, AD-O’OKA); hamza
  between vowels is a hyphen (SHAY-IN, AS-ALOKA), with sukun an A (YAAWEE).
- ث س ص are S, ذ ز ض ظ are Z, ت ط T, ح ه H.
- Across words: sun letters and idgham are doubled across the space (INNAL
  LAZEENA, MIR RAHMATEKA, AHADAM MIN), into و / ي as NW WA / N-Y YA
  (MOHAMMADINW WA, GHAAYATUN-Y YAA); iqlab is M (MIM BAYNE). A long vowel
  before hamzat al-wasl is shortened (FIL ARZE), a final consonant takes a
  helping vowel (MENAL, MANIS TARHAMA), tanween a kasra (KHAYRANIL).
- Allah: ILLAL LAAHO, BISMIL LAAHE, WAL LAAHO; glued after bi / li
  (BILLAAHE, LILLAAHE).
- WA is its own word. bi / li take a hyphen before a noun or verb
  (BE-RAHMATEKA, LE-GHAYREKA, BIL-A’AFEYATE) and stay glued to pronouns and
  particles (BEKA, BEHIM, LEMAA); fa takes one before a hamza (FA-INNA).
- The reading pauses at the end of the line and at every full stop or comma:
  the last short vowel and -un / -in drop, -an is AA, ة is H (KHULFAA,
  RABBIL A’ALAMEEN, RAHMAH).

It is a drafting aid, not an oracle. Splitting off WA / BI / LI is a
heuristic (WAW_STEMS, ROOT_START list the words whose first letter is a root
letter), and Arabic that is under-vowelled or mistyped comes out wrong, so
read every line it produces against the Arabic before it ships.

    python3 scripts/zikr_arabic/translit.py "اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ"
    python3 scripts/zikr_arabic/translit.py --check [-v] [-d]   # vs the app's hand-made lines
"""
import json
import re
import sys

FATHA, DAMMA, KASRA, SUKUN, SHADDA = 'َ', 'ُ', 'ِ', 'ْ', 'ّ'
FATHATAN, DAMMATAN, KASRATAN = 'ً', 'ٌ', 'ٍ'
DAGGER = 'ٰ'
VOWELS = {FATHA: 'A', DAMMA: 'U', KASRA: 'I', 'ٗ': 'U', 'ٖ': 'I'}
SILAH_MARKS = {'ٗ': 'u', 'ٖ': 'i'}   # lower case: always U / I, never O / E
TANWEEN = {FATHATAN: 'AN', DAMMATAN: 'UN', KASRATAN: 'IN'}
TM = 'Ŧ'   # placeholder for ta marbuta: H at a pause, T otherwise
# Internal phoneme string: hamza is ', 'ayn is ` (AYN0 when it opens a word,
# written after its vowel there: A^LAA), silah vowels are u / i.
AYN0 = '^'
CONS = {'ب': 'B', 'ت': 'T', 'ث': 'TH', 'ج': 'J', 'ح': 'H', 'خ': 'KH', 'د': 'D', 'ذ': 'DH',
        'ر': 'R', 'ز': 'Z', 'س': 'S', 'ش': 'SH', 'ص': 'S', 'ض': 'Z', 'ط': 'T', 'ظ': 'Z',
        'ع': '`', 'غ': 'GH', 'ف': 'F', 'ق': 'Q', 'ك': 'K', 'ک': 'K', 'ل': 'L', 'م': 'M',
        'ن': 'N', 'ه': 'H', 'ہ': 'H', 'ھ': 'H', 'و': 'W', 'ي': 'Y', 'ی': 'Y', 'ء': "'",
        'أ': "'", 'إ': "'", 'ؤ': "'", 'ئ': "'", 'ة': TM, 'ۃ': TM}
HAMZA_SEATS = set('أإءؤئ')
SUN = set('تثدذرزسشصضطظلن')
MARKS = set(VOWELS) | set(TANWEEN) | {SUKUN, SHADDA, DAGGER}
# anything else that is not a base letter (Quranic annotation, tatweel, madda...)
def _ignorable(ch):
    return 'ؐ' <= ch <= 'ؚ' or 'ۖ' <= ch <= 'ۭ' or ch in 'ـٕٓٔ‌‍'
# stems whose leading و is a root letter, not the conjunction (consonant skeleton after the و)
WAW_STEMS = ('صو', 'لي', 'حي', 'صي', 'زي', 'قع', 'ضع', 'صف', 'رث', 'كي',
             'لد', 'قت', 'رق', 'زن', 'جل', 'هن', 'طن', 'ثق')


# Persian / Urdu letter forms the app's Arabic uses
_LETTER = {'ی': 'ي', 'ک': 'ك', 'ہ': 'ه', 'ھ': 'ه', 'ۃ': 'ة'}


def clusters(word):
    out = []
    for ch in word.replace('ٱ', 'ا').replace('ﭐ', 'ا'):
        if _ignorable(ch):
            continue
        if ch in MARKS:
            if out:
                out[-1][1].append(ch)
            continue
        if 'ء' <= ch <= 'ۿ':
            out.append([_LETTER.get(ch, ch), []])
    # ى after a kasra is a yaa (فِىْ); a bare final ی after a fatha is an alif maqsura (عَلٰی)
    for i in range(1, len(out)):
        if out[i][0] == 'ى' and KASRA in out[i - 1][1]:
            out[i][0] = 'ي'
        elif out[i][0] == 'ي' and not out[i][1] and DAGGER in out[i - 1][1]:
            out[i][0] = 'ى'                     # عَلٰي
        elif out[i][0] == 'ي' and i == len(out) - 1 and not out[i][1] and word.rstrip()[-1:] == 'ی' \
                and (FATHA in out[i - 1][1] or DAGGER in out[i - 1][1]):
            out[i][0] = 'ى'
    # a fatha written on the alif of لاَ belongs to the letter before it
    for i in range(1, len(out)):
        if out[i][0] == 'ا' and out[i][1] and set(out[i][1]) <= {FATHA, SHADDA} and FATHA in out[i][1] \
                and not vowel(out[i - 1][1]) and SUKUN not in out[i - 1][1]:
            out[i - 1][1] += out[i][1]          # اِلاَّ -> اِلَّا
            out[i][1] = []
    return out


def vowel(mk):
    return next((VOWELS[m] for m in mk if m in VOWELS), None)


def tanween(mk):
    return next((TANWEEN[m] for m in mk if m in TANWEEN), None)


def skeleton(cl):
    return ''.join(c for c, _ in cl)


def phonemes(cl):
    """Phoneme string for a list of clusters (no prefix/article handling)."""
    out = ''
    sk = skeleton(cl)
    silent_waw = re.match(r'^ا?ول(ي|و|ئ|ا|ٰ)', sk) is not None and len(cl) > 1 and SUKUN not in cl[1][1] \
        and vowel(cl[0][1]) in ('U', None)   # اُولِي، اُولُو، اُولٰئِكَ
    prev_bare = False
    for i, (ch, mk) in enumerate(cl):
        v, tan = vowel(mk), tanween(mk)
        last = i == len(cl) - 1
        if ch == 'و' and silent_waw and i == 1:
            if out.endswith('U'):
                out = out[:-1] + 'OO'           # اُولٰٓئِكَ: OOLAAA-EKA
            continue
        if ch == 'آ':
            out += 'A' if out.endswith('A') and not out.endswith('AA') else (("'" if out else '') + 'AA')
            prev_bare = False
            continue
        if ch in 'اى':
            if DAGGER in mk and ch == 'ا':
                out += ("'" if out else '') + 'AA'
            elif ch == 'ا' and SUKUN in mk:
                out += "'"
            elif ch == 'ا' and tan and not v and out:
                if not out.endswith('AN'):
                    out += 'AN'                        # ـاً : the alif only carries the tanween
            elif ch == 'ا' and (v or tan):
                out += ("'" if out else '') + (v or '') + (tan or '')
            elif out.endswith('AA') or out.endswith('OO') or out.endswith('EE'):
                pass
            elif out.endswith(AYN0) and len(out) == 2:
                out += 'A'                             # initial 'ayn + alif: A'ABID
            elif out.endswith('A'):
                out += 'A'
            elif out.endswith('AN') or (out.endswith('U') and last) or (out.endswith('AW') and last):
                pass                                   # -an + silent alif; waw al-jama'a
            elif prev_bare or (out and out[-1] not in 'AIU'):
                out += 'AA'                            # under-vowelled source: لا -> LAA
            prev_bare = False
            continue
        nxt = cl[i + 1] if i + 1 < len(cl) else None
        if ch == 'و' and nxt and nxt[0] == 'ا' and tanween(nxt[1]):
            out += 'WW' if SHADDA in mk else 'W'       # كُفُواً، عُلُوّاً
            continue
        if ch in 'وي' and not v and not tan and SHADDA not in mk and DAGGER not in mk:
            if re.fullmatch(r"[AIU]" + AYN0, out) and {'I': 'ي', 'U': 'و'}.get(out[0]) == ch:
                out += {'I': 'EE', 'U': 'OO'}[out[0]]       # initial 'ayn + long vowel: I'EESAA
                prev_bare = False
                continue
            if out.endswith('U') and ch == 'و':
                out = out[:-1] + 'OO'
                prev_bare = False
                continue
            if out.endswith('I') and ch == 'ي':
                out = out[:-1] + 'EE'
                prev_bare = False
                continue
            if prev_bare and ch == 'ي':
                out += 'EE'
                prev_bare = False
                continue
            if out.endswith('A') and SUKUN not in mk and last and ch == 'ي':
                out += 'A'                              # ى written as ي: عَلَي
                continue
        if ch == 'ي' and DAGGER in mk:
            out += 'A' if out.endswith('A') else 'AA'
            continue
        c = CONS.get(ch, '')
        if not out and (ch in HAMZA_SEATS or ch == 'ع'):
            # word-initial hamza is silent; word-initial 'ayn is written vowel-first (A'LAA)
            if not v and not tan:
                v = {'إ': 'I', 'أ': 'A'}.get(ch, '')
            out += (v or (tan or '')) + (('`' if not (v or tan) else AYN0) if ch == 'ع' else '')
            if DAGGER in mk:
                out += 'A'
            prev_bare = False
            continue
        if ch == 'ع' and SUKUN not in mk and (v or tan) and out and out[-1] not in "AIU'":
            pass
        if c == 'H' and i > 0 and cl[i - 1][0] in 'سشكدتغذثخطصض' and not vowel(cl[i - 1][1]):
            out += '-'                                 # ASH-HADU, not ASHHADU
        if SHADDA in mk:
            out += c
        out += c
        if v:
            out += v
        if tan:
            out += tan
        if DAGGER in mk:
            out += 'A' if v == 'A' or not v else ''
            if not v:
                out += 'A'
        prev_bare = not (v or tan or SUKUN in mk or SHADDA in mk or DAGGER in mk)
        if any(m in SILAH_MARKS for m in mk) and ch in 'هہ':
            out = out[:-1] + SILAH_MARKS[next(m for m in mk if m in SILAH_MARKS)]
    return out


# what bi- / li- stay glued to
GLUED = {'هم', 'هما', 'هن', 'كم', 'كما', 'كن', 'نا', 'ما', 'من', 'ذلك', 'ذا', 'هذا', 'هذه', 'ها', 'هو', 'هي',
         'ي', 'ك', 'ه', 'اي', 'ني'}
# words whose بِ / لِ is a root letter, not the preposition (by the letters after it)
ROOT_START = {'ب': ('لاد', 'حار', 'ساط', 'طان', 'ضاع', 'ئس', 'لى'),
              'ل': ('سان', 'باس', 'قاء', 'قا', 'واء', 'ين')}


class Word:
    """One space-separated Arabic word, split into prefix + body."""

    def __init__(self, raw):
        cl = clusters(raw)
        self.idgham = bool(cl) and SHADDA in cl[0][1] and cl[0][0] != 'ا' and not (len(cl) > 1 and cl[0][0] == 'ل' and cl[1][0] == 'ل')
        if self.idgham:
            cl[0][1] = [m for m in cl[0][1] if m != SHADDA]   # Indo-Pak idgham mark: مِّنْ, وَّ
        self.tanween_end = bool(cl) and any(m in TANWEEN for m in cl[-1][1]) or \
            (len(cl) > 1 and cl[-1][0] == 'ا' and any(m in TANWEEN for m in cl[-1][1] + cl[-2][1]))
        self.quta = bool(cl) and cl[0][0] == 'ا' and vowel(cl[0][1]) == 'A'
        self.prefix = ''        # WA / FA / BI / LI / KA
        self.kind = 'plain'     # plain | article | wasl | allah
        self.sep = ' '          # how the prefix attaches: ' ', '-', ''
        self.inner = ''         # BI-/LI-/FA- before a hamza, after any WA
        if not cl:
            self.cl = cl
            return
        sk = skeleton(cl)
        # Allah / Allahumma, possibly with a prefix
        m = re.match(r'^([وفبل]?)(ا?لل|لل)ه(م?)$', sk.replace('ٰ', ''))
        if m and (m.group(2) == 'الل' or m.group(1) == 'ل' or m.group(2) == 'لل'):
            self.kind = 'allah'
            self.prefix = {'و': 'WA', 'ف': 'FA', 'ب': 'BI', 'ل': 'LI'}.get(m.group(1), '')
            if not m.group(1) and m.group(2) == 'لل' and vowel(cl[0][1]) == 'I':
                self.prefix = 'LI'
            # suffix after the ه
            hi = max(i for i, (c, _) in enumerate(cl) if c in 'هہ')
            self.allah_tail = (vowel(cl[hi][1]) or '') + phonemes([['م', cl[hi + 1][1]]] + cl[hi + 2:])[0:] if hi + 1 < len(cl) else (vowel(cl[hi][1]) or '')
            if hi + 1 < len(cl):
                self.allah_tail = (vowel(cl[hi][1]) or '') + phonemes(cl[hi + 1:])
            self.cl = cl
            return
        # prefix + article: وَالْ بِالْ فَالْ كَالْ ; لِلْ
        if len(cl) > 3 and cl[0][0] in 'وفبك' and cl[1][0] == 'ا' and not vowel(cl[1][1]) and cl[2][0] == 'ل' \
                and (not vowel(cl[2][1]) or SHADDA in cl[2][1]):
            self.prefix = {'و': 'WA', 'ف': 'FA', 'ب': 'BI', 'ك': 'KA'}[cl[0][0]]
            cl = cl[1:]
        elif len(cl) > 2 and cl[0][0] == 'ل' and cl[1][0] == 'ل' and vowel(cl[0][1]) == 'I' \
                and (SUKUN in cl[1][1] or not cl[1][1] or SHADDA in cl[2][1]):
            self.prefix = 'LI'
            cl = [['ا', []]] + cl[1:]
        # prefix + hamzat al-wasl (فَاسْتَجَبْتَ / وَاغْفِرْ)
        elif len(cl) > 3 and cl[0][0] in 'وف' and vowel(cl[0][1]) == 'A' and cl[1][0] == 'ا' \
                and not vowel(cl[1][1]) and not tanween(cl[1][1]) and DAGGER not in cl[1][1] \
                and (SUKUN in cl[2][1] or (SHADDA in cl[2][1] and cl[2][0] != 'ل') or (len(cl) > 3 and cl[2][0] == 'ل' and SHADDA in cl[3][1])):
            self.prefix = {'و': 'WA', 'ف': 'FA'}[cl[0][0]]
            self.sep = ''
            cl = cl[1:]
        # wa + word (the word may itself start with bi-/li-/fa- + hamza)
        elif len(cl) > 2 and cl[0][0] == 'و' and vowel(cl[0][1]) == 'A' and SHADDA not in cl[0][1] \
                and (vowel(cl[1][1]) or tanween(cl[1][1]) or SHADDA in cl[1][1] or DAGGER in cl[1][1] or cl[1][0] in HAMZA_SEATS
                     or (cl[1][0] == 'ا' and (vowel(cl[1][1]) or DAGGER in cl[1][1])) or cl[1][0] == 'آ') \
                and not (cl[1][0] != 'ا' and skeleton(cl[1:3]) in WAW_STEMS) \
                and not skeleton(cl[1:4]) in ('فات', 'فاء', 'فاة', 'فاي') \
                and not (skeleton(cl[1:3]) == 'صل' and len(cl) > 2 and SHADDA not in cl[2][1]) \
                and not (skeleton(cl[1:3]) == 'دو' and vowel(cl[1][1]) == 'U') \
                and not (skeleton(cl[1:3]) == 'جد' and len(cl) > 2 and SHADDA not in cl[2][1]) \
                and not (skeleton(cl[1:3]) == 'هب' and len(cl) > 2 and vowel(cl[2][1])) \
                and not (skeleton(cl[1:3]) == 'فق' and SHADDA in cl[1][1]) \
                and not (skeleton(cl[1:3]) == 'في' and vowel(cl[1][1]) == 'A'):
            self.prefix = 'WA'
            cl = cl[1:]
        # (fa/bi/li/ka) + hamza or (bi/li) + 'ayn: فَاِنَّ بِاَنَّ لِاٰدَمَ بِعَظَمَةِ
        if len(cl) > 2 and cl[0][0] in 'فبلك' and vowel(cl[0][1]) in ('A', 'I') \
                and (cl[1][0] in HAMZA_SEATS or cl[1][0] == 'آ' or (cl[1][0] == 'ا' and (vowel(cl[1][1]) or DAGGER in cl[1][1]))
                     or (cl[1][0] == 'ع' and cl[0][0] in 'بل' and vowel(cl[0][1]) == 'I' and vowel(cl[1][1]))):
            self.inner = {'ف': 'FA', 'ب': 'BI', 'ل': 'LI', 'ك': 'KA'}[cl[0][0]] + '-'
            cl = cl[1:]
        # bi- / li- before a noun or verb take a hyphen (BE-RAHMATEKA, LE-GHAYREKA);
        # before a pronoun or particle they stay glued on (BEKA, BEHIM, LEMAA)
        elif len(cl) > 2 and cl[0][0] in 'بل' and vowel(cl[0][1]) == 'I' and SHADDA not in cl[0][1] \
                and (vowel(cl[1][1]) or SHADDA in cl[1][1] or tanween(cl[1][1])) \
                and skeleton(cl[1:]) not in GLUED and not skeleton(cl[1:]).startswith(ROOT_START[cl[0][0]]):
            self.inner = {'ب': 'BI', 'ل': 'LI'}[cl[0][0]] + '-'
            cl = cl[1:]
        if cl and SUKUN in cl[0][1] and not self.prefix and len(cl) > 1:
            self.kind = 'glue'                 # بْنِ / بْنَ: alif elided, reads on from the previous word
        # wa + (bi/fa/ka/li) + article: وَبِالْاِسْمِ / وَلِلْ
        if self.prefix == 'WA' and len(cl) > 3 and cl[0][0] in 'بفك' and cl[1][0] == 'ا' and not vowel(cl[1][1]) \
                and cl[2][0] == 'ل' and not vowel(cl[2][1]):
            self.prefix = 'WA ' + {'ب': 'BI', 'ف': 'FA', 'ك': 'KA'}[cl[0][0]]
            cl = cl[1:]
        if cl and cl[0][0] == 'ا' and vowel(cl[0][1]) == 'A' and not self.prefix and not self.inner and len(cl) > 2 \
                and cl[1][0] == 'ل' and not vowel(cl[1][1]) and (SUKUN in cl[1][1] or SHADDA in cl[2][1]):
            self.kind = 'article'              # utterance-initial اَلسَّلَامُ / اَلْحَمْدُ
            self.sun = SHADDA in cl[2][1] and cl[2][0] in SUN
            self.whole = cl                    # mid-line it is a word of its own: اَلْجَأْتُ
            cl = cl[2:]
        elif cl and cl[0][0] == 'ا' and not vowel(cl[0][1]) and not tanween(cl[0][1]) and DAGGER not in cl[0][1] and len(cl) > 1:
            if cl[1][0] == 'ل' and len(cl) > 2 and SHADDA in cl[1][1]:
                self.kind = 'article'          # الَّذِي / الَّتِي / اللَّيْل: the article's lam is assimilated
                self.sun = True
                cl = cl[1:]
            elif cl[1][0] == 'ل' and len(cl) > 2 and not vowel(cl[1][1]):
                self.kind = 'article'
                self.sun = cl[2][0] in SUN and (SHADDA in cl[2][1] or not cl[1][1])
                cl = cl[2:]
            else:
                self.kind = 'glue' if skeleton(cl) in ('ابن', 'ابنة') else 'wasl'
                cl = cl[1:]
        self.cl = cl

    def body(self):
        return self.inner + phonemes(self.cl)


def shorten(s):
    for a, b in (('AA', 'A'), ('EE', 'I'), ('OO', 'U')):
        if s.endswith(a):
            return s[:-2] + b
    return s


def head(s):
    m = re.match(r"(TH|DH|SH|KH|GH|[A-Z'`])", s)
    return m.group(1) if m else ''


def _pausal(s):
    if s.endswith(TM + 'AN') or re.search(TM + '(IN|UN|A|I|U)$', s):
        return re.sub(TM + '(AN|IN|UN|A|I|U)$', 'H', s)
    if s.endswith(TM):
        return s[:-1] + 'H'
    if s.endswith('AN') and not s.endswith('AAN'):
        return s[:-2] + 'AA'
    if re.search(r'[^AIU](IN|UN)$', s) or s.endswith("'IN") or s.endswith("'UN"):
        return s[:-2]
    if re.search(r'H[ui]$', s):
        return s[:-1]
    if re.search(r'[AIU]$', s) and not re.search(r'(AA|EE|OO)$', s):
        return s[:-1]
    return s


def pausal(s):
    s = _pausal(s)
    if re.search(r'([^AEIOUWY`\'])\1$', s):
        s = s[:-1]                      # a doubled letter is single at a pause: TOHIB, HAQ
    return s


# spelled as the Quran transliteration does (scripts/quran_transliteration/translit.py)
MUQATTAAT = {'عسق': 'A’YN SEEEN QAAAF', 'كهيعص': 'KAAAF HAA YAA A’YN SAAAD', 'يس': 'YAA SEEEN', 'طه': 'TAA HAA',
             'حم': 'HAA MEEM', 'الم': 'ALIF LAAAM MEEM', 'المص': 'ALIF LAAAM MEEM SAAAD', 'الر': 'ALIF LAAAM RAA',
             'طس': 'TAA SEEEN', 'طسم': 'TAA SIM MEEM', 'ص': 'SAAAD', 'ق': 'QAAAF', 'ن': 'NOOON'}


def _muqattaat(word):
    sk = re.sub('[^\u0621-\u064a]', '', word.replace('ٰ', ''))
    pre = ''
    if sk[:1] == 'و' and sk[1:] in MUQATTAAT and ('\u0653' in word or not re.search('[\u064b-\u0652]', word[2:])):
        pre, sk = 'WA ', sk[1:]
    rest = word[2:] if pre else word
    if sk in MUQATTAAT and ('\u0653' in word or 'ٰ' in word or not re.search('[\u064b-\u0652]', rest)):
        return '{' + pre + MUQATTAAT[sk] + '}'    # braces: copied through render() as is
    return None


def _internal(line, pause=True):
    special = {i: _muqattaat(t) for i, t in enumerate(line.split())}
    if any(special.values()):
        parts, buf = [], []
        for i, t in enumerate(line.split()):
            if special[i]:
                if buf:
                    parts.append(_internal(' '.join(buf), pause=False))
                    buf = []
                parts.append(special[i])
            else:
                buf.append(t)
        if buf:
            parts.append(_internal(' '.join(buf), pause))
        return ' '.join(parts)
    words = [Word(t) for t in line.split()]
    words = [w for w in words if w.cl]
    toks = []    # rendered tokens; a join rewrites the previous one
    tanw = []    # whether each token ends in tanween

    def run_on(extra):
        """Previous token flows into a hamzat al-wasl: shorten a long vowel, or
        give tanween its helping kasra (MUHAMMADINIS SAADIQ)."""
        prev = toks[-1]
        if tanw[-1]:
            prev += 'I'
        elif re.search(r"[^AEIOUiu' -]$", prev) and not prev.endswith(AYN0):
            # a final consonant takes a helping vowel: MENAL, ALAYKOMUS, MANIS
            prev += 'A' if prev.endswith('MIN') and len(prev.split()[-1]) == 3 else \
                'U' if re.search(r'(HUM|KUM|TUM)$', prev) else 'I'
        else:
            prev = shorten(prev)
        toks[-1] = prev + extra
        tanw[-1] = False

    for w in words:
        b = w.body() if w.kind != 'allah' else ''
        if w.kind == 'allah':
            body = 'LLAAH' + w.allah_tail
            if w.prefix in ('WA', 'FA'):
                toks.append(w.prefix + 'L ' + body[1:])     # WAL LAAHO
            elif w.prefix in ('BI', 'LI'):
                toks.append(w.prefix[0] + 'I' + body)        # BILLAAHE, LILLAAHE
            elif toks and not w.quta:
                run_on('L')                                  # ILLAL LAAHO, BISMIL LAAHE
                toks.append(body[1:])
                tanw.append(False)
                continue
            else:
                toks.append('A' + body)
            tanw.append(False)
            continue
        if w.kind == 'article' and toks and not w.prefix and hasattr(w, 'whole'):
            toks.append(phonemes(w.whole))
            tanw.append(w.tanween_end)
            continue
        if w.kind == 'article':
            c = head(b) if w.sun else 'L'
            rest = b[len(c):] if w.sun else b
            if w.prefix:
                sep = '-' if w.prefix.split()[-1] in ('BI', 'LI', 'KA') else ' '
                toks.append(w.prefix + c + sep + rest)     # WAL MULKO, BIL-A’AFEYATE
            elif toks:
                run_on(c)
                toks.append(rest)
            else:
                toks.append('A' + c + ('' if c == 'L' or not w.sun else '-') + rest if w.sun else 'AL-' + rest)
            tanw.append(w.tanween_end)
            continue
        if w.kind in ('wasl', 'glue'):
            if w.kind == 'glue':
                if w.prefix:
                    toks.append(w.prefix + b)
                    tanw.append(w.tanween_end)
                elif toks:
                    run_on(b)
                    tanw[-1] = w.tanween_end
                else:
                    toks.append('I' + b)
                    tanw.append(w.tanween_end)
                continue
            c = head(b)
            rest = b[len(c):]
            if re.match(r"`[AIU]", rest) and not w.prefix:
                rest = rest[1] + AYN0 + rest[2:]
            if w.prefix:
                toks.append(w.prefix + c + rest)
            elif toks:
                run_on(c)
                toks.append(rest)
            else:
                toks.append('I' + (AYN0 if c == '`' else c) + rest)     # E’TASAMTO
            tanw.append(w.tanween_end)
            continue
        # tanween assimilates into a following ر ل م ن (AHADIM MIN, GHAFOORUR RAHEEM)
        # (always, marked or not: the Arabic here often leaves the idgham shadda off)
        if toks and (tanw[-1] or re.search(r'[AIU]N$', toks[-1])) and not w.prefix and head(b) in ('R', 'L', 'M', 'N'):
            c = head(b)
            toks[-1] = toks[-1][:-1] + c
            if b.startswith(c + c):
                b = b[1:]
        # ... and runs nasalised into a following و / ي (MOHAMMADINW WA, RAJAAA-IN-Y YAAWEE)
        elif toks and (tanw[-1] or re.search(r'[AIU]N$', toks[-1])) \
                and (w.prefix[:2] == 'WA' or (not w.prefix and head(b) in ('W', 'Y'))):
            toks[-1] += 'W' if w.prefix == 'WA' or head(b) == 'W' else '-Y'
        if w.prefix:
            if w.sep == '':
                toks.append(w.prefix + b)
            else:
                toks.append(w.prefix)
                tanw.append(False)
                toks.append(b)
        else:
            toks.append(b)
        tanw.append(w.tanween_end)
    out = list(toks)
    if out and pause:
        out[-1] = pausal(out[-1])
    return ' '.join(t for t in out if t).replace(TM, 'T')


_UNIT = re.compile(r"\{[^}]*\}|AA|EE|OO|SH|KH|GH|TH|DH|[A-Zui'`^ \-]|.")
_VOW = {'A', 'I', 'U', 'AA', 'EE', 'OO', 'u', 'i'}
_GUTTURAL = {'H', "'", '`'}        # a short vowel before one of these with sukun stays open (MOHTADEEN)
_SHOW = {'TH': 'S', 'DH': 'Z'}


def render(internal):
    """Internal phoneme string -> house style (see the module docstring)."""
    u = _UNIT.findall(internal)
    # phones: the sounds in order, with the glottal stop a word-initial vowel
    # starts with, and a vowel-first word-initial 'ayn (A^) put back as ` + A
    ph = []                            # (unit index, phone)
    for k, x in enumerate(u):
        if x in (' ', '-') or x.startswith('{'):
            continue
        start = k == 0 or u[k - 1] in (' ', '-') or u[k - 1].startswith('{')
        if x in _VOW and start:
            ph.append((k, '`' if k + 1 < len(u) and u[k + 1] == AYN0 else "'"))
        if x == AYN0:
            continue
        ph.append((k, x))
    where = {k: n for n, (k, _) in enumerate(ph)}

    def closed(k):
        n = where[k] + 1
        if n >= len(ph):
            return False                # a short vowel at the very end (no pause)
        c1 = ph[n][1]
        if c1 in _VOW:
            return False
        c2 = ph[n + 1][1] if n + 1 < len(ph) else None
        if c1 in _GUTTURAL and c2 != c1:
            return False
        return c2 is None or c2 not in _VOW

    out = []
    for k, x in enumerate(u):
        nx = u[k + 1] if k + 1 < len(u) else ''
        last = ''.join(out)
        tok = last.rsplit(' ', 1)[-1]
        if x.startswith('{'):
            out.append(x[1:-1])
        elif x == AYN0:
            continue
        elif x in _VOW:
            if x == 'AA' and nx == "'":
                v = 'AAA'                      # alif + hamza in one word: RAJAAA-EE
            elif x == 'I':
                v = 'I' if closed(k) else 'E'
            elif x == 'U':
                v = 'U' if closed(k) else 'O'
            else:
                v = x.upper()
            if nx == AYN0:
                v = v[0] + '’' + v[1:]         # A’LAA, A’AFENEE, I’NDAKA
            out.append(v)
        elif x == "'":
            if nx in _VOW:
                if tok and not tok.endswith('-'):
                    out.append('-')            # SHAY-IN, AS-ALOKA
            elif nx and nx not in (' ', '-'):
                out.append('A')                # hamza with sukun: YAAWEE, MOAMENEENA
        elif x == '`':
            if nx in _VOW:
                if nx == 'AA' and k + 2 < len(u) and u[k + 2] == "'":
                    nx = 'AAA'                 # DO-A’AAA-E
                v = nx.upper() if nx not in ('I', 'U') else ('I' if closed(k + 1) else 'E') if nx == 'I' \
                    else ('U' if closed(k + 1) else 'O')
                if nx in ('u', 'i'):
                    v = nx.upper()
                out.append(('-' if tok and not tok.endswith('-') else '') + v[0] + '’' + v[1:])
                u[k + 1] = ''                  # vowel written
            elif re.search(r'(^|-)[AEIOU]$', tok):
                out.append('-' + tok[-1] + '’')   # أَعْ: A-A’TENEE, FA-A-A’TENEE
            else:
                out.append('’')
        elif x == '':
            continue
        else:
            out.append(_SHOW.get(x, x))
    text = ''.join(out)
    # iqlab: an unvowelled nun before ب is M (MIM BAYNE, JAMBEYAL)
    text = re.sub(r'N(?=[ -]?B)', 'M', text)
    return re.sub(r' +', ' ', text).strip()


_STOP = re.compile(r'\s*([.،,؛;:!?؟۔]+)\s*')


ABBREV = {'ص': '(S)', 'ع': '(A)', 'س': '(S)', 'عج': '(A.T.F.S.)', 'رض': '(R)'}


def transliterate(text, pause=True):
    """House-style transliteration of a line of vocalised Arabic. The reading
    pauses (drops the last vowel) at the end and at every full stop or comma;
    a bracketed honorific such as (ص) is copied as (S)."""
    if '(' in text:
        bits = re.split(r'\(([^()]*)\)', text)
        out = []
        for n, bit in enumerate(bits):
            key = re.sub('[^\u0621-\u064a]', '', bit)
            if n % 2:
                out.append(ABBREV.get(key) or '(' + transliterate(bit, pause) + ')')
            elif bit.strip():
                out.append(transliterate(bit, pause and n + 1 >= len(bits)))   # no pause before (S)
        return ' '.join(out).replace(' ,', ',').replace(' .', '.')
    parts = _STOP.split(text.strip())
    out = ''
    for n in range(0, len(parts), 2):
        seg = parts[n].strip()
        punct = parts[n + 1] if n + 1 < len(parts) else ''
        if seg:
            last = n + 1 >= len(parts) or not ''.join(parts[n + 2:]).strip()
            r = render(_internal(seg, pause=pause or not last))
            out += (' ' if out else '') + r
        if punct:
            out += {'،': ',', '؛': ';', '؟': '?', '۔': '.'}.get(punct[0], punct[0])
    return out


def corpus():
    """(uid, Arabic, transliteration) for the hand-made house-style lines in
    assets/zikr (duas, not the Quran): an Arabic line whose next line is an
    ALL-CAPS line written with ’ and none of the old I-style spellings."""
    import os
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'zikr')
    for u in sorted(os.listdir(root)):
        if u.startswith('A'):
            continue
        d = json.load(open(os.path.join(root, u)))
        texts = [d.get('data') or ''] + [t.get('data') or '' for t in d.get('tabs') or [] if isinstance(t, dict)]
        for tx in texts:
            L = tx.split('\n')
            for i in range(len(L) - 1):
                t = L[i + 1].strip()
                if re.search('[\u0621-\u064a]', L[i]) and re.fullmatch(r"[A-Z’\- ,.!?;:]{12,}", t) \
                        and not re.search(r"\b(MINAL|ILAYKA|ILAAHA|LILLAAHI|BISMILLAAHI)\b", t):
                    yield u, L[i], t


def check():
    """Word agreement with the hand-made lines (hyphen vs space ignored)."""
    import difflib
    from collections import Counter
    tot = same = lines = exact = 0
    diffs = Counter()
    for u, ar, want in corpus():
        got = transliterate(ar)
        alt = transliterate(ar, pause=False)    # hand-made lines often run on past the line end
        norm = lambda x: re.sub(r'[.,!?;:]', '', x).replace('-', ' ').split()
        a, b = norm(want), norm(got)
        if norm(alt)[-1:] == a[-1:]:
            got, b = alt, norm(alt)
        sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
        m = sum(bl.size for bl in sm.get_matching_blocks())
        tot += len(a)
        same += m
        lines += 1
        exact += a == b
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op == 'replace' and i2 - i1 == j2 - j1:
                for x, y in zip(a[i1:i2], b[j1:j2]):
                    diffs[(x, y)] += 1
        if '-v' in sys.argv and a != b:
            print(f'{u}: {ar}\n   want {want}\n   got  {got}')
    print(f'{same}/{tot} words ({100 * same / max(tot, 1):.1f}%), {exact}/{lines} lines identical')
    if '-d' in sys.argv:
        for (x, y), c in diffs.most_common(60):
            print(f'{c:5d}  {x:20s} {y}')


if __name__ == '__main__':
    if '--check' in sys.argv:
        check()
    else:
        for a in sys.argv[1:]:
            print(transliterate(a))
