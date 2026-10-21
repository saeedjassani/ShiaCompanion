#!/usr/bin/env python3
"""Link the surahs, duas, ziyarat and namaz a zikr names to their own entries.

    python3 scripts/zikr_structure/link_mentions.py            # list unlinked mentions
    python3 scripts/zikr_structure/link_mentions.py --write    # link them
    python3 scripts/zikr_structure/link_mentions.py F2 F3      # only those uids

"After Surah Hamd recite Surah Tawheed" becomes "After [Surah Hamd](A5)
recite [Surah Tawheed](A116)", so the reader can open the surah from the
instruction - see "One text lives in one place" in docs/ZIKR_STRUCTURE.md.

Only English that stands on its own is touched: instruction lines and other
notes, and merits. Arabic, transliteration and translation lines, tab
labels and titles are left alone, as is text already inside a link and a
mention of the entry itself. A surah is recognised by "Surah"/"Surat"
before its name in any common spelling (al-Faatehah, Fatiha, Hamd ...);
everything else by the names in NAMED below. lint.py reports what this
would link as UNLINKED.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import corpus  # noqa: E402

LINK = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')

# ---------------------------------------------------------------------------
# Surahs. A surah's uid is A<number + 4>.
# ---------------------------------------------------------------------------

# Spellings the zikr.json titles and slugs don't already give, by surah.
SURAH_ALIASES = {
    1: ['Hamd', 'Fatiha', 'Fateha', 'Kitab'],
    3: ['Imran', 'Al Imran', 'Ale Imran', 'Al-e-Imran', 'Aal Imran', 'Al-i-Imran'],
    9: ['Baraah', 'Bara’ah', 'Taubah'],
    17: ['Bani Israil', 'Bani Isra’il'],
    23: ['Muminoon', 'Mu’minoon'],
    36: ['Yasin', 'Yaseen', 'Ya Sin', 'Ya Seen', 'Yaa Seen'],
    40: ['Mumin', 'Mu’min', 'Momin'],
    41: ['Ha Mim Sajdah', 'Hamim Sajdah', 'Ha-Mim Sajdah'],
    44: ['Dukhaan'],
    55: ['Rehman'],
    56: ['Waqia', 'Waqiah', 'Waqeah'],
    62: ['Jumah', 'Jum’ah', 'Jumuah', 'Jumua'],
    67: ['Tabarak', 'Tabaarak'],
    76: ['Dahr', 'Hal Ata', 'Hal Ataa'],
    93: ['Zuha', 'Zoha', 'Dhuha'],
    94: ['Inshirah', 'Insherah', 'Alam Nashrah', 'Nashrah', 'Sharh'],
    96: ['Iqra'],
    97: ['Inna Anzalnahu', 'Inna Anzalna'],
    99: ['Zilzal', 'Zilzaal', 'Zilzalah', 'Zalzala'],
    105: ['Feel'],
    106: ['Quraish', 'Qureish'],
    108: ['Kausar', 'Kauthar', 'Kawsar'],
    109: ['Kaferoon', 'Kaafiroon', 'Kafiroon', 'Kafirun', 'Kaferun'],
    111: ['Lahab', 'Tabbat', 'Tabbat Yada'],
    112: ['Tawhid', 'Tawheed', 'Tauheed', 'Touheed', 'Ikhlas', 'Ikhlaas',
          'Qul Huwallah', 'Qul Huwa Allah'],
    113: ['Falaq'],
    114: ['Nas', 'Naas'],
}

_ARTICLE = r"(?:al|an|ash|at|ar|as|az|ad|adh|ath|ul|el)"


def surah_key(name):
    """One spelling of a surah name folded to the same key as every other:
    al-Faatehah, Al-Fatihah and Fatiha all give "fatiha"."""
    s = re.sub(r"[’‘'`ʿʾ]", '', name.lower())
    s = re.sub(r'^' + _ARTICLE + r'[\s-]+', '', s)
    s = re.sub(r'[^a-z]', '', s)
    for a, b in (('dh', 'z'), ('th', 's'), ('ee', 'i'), ('oo', 'u'),
                 ('ou', 'u'), ('aa', 'a'), ('ay', 'ai'), ('e', 'i'),
                 ('o', 'u')):
        s = s.replace(a, b)
    s = re.sub(r'(.)\1+', r'\1', s)
    if len(s) > 3 and s.endswith('h'):
        s = s[:-1]
    return s


def surah_keys(index):
    keys = {}

    def add(name, n):
        k = surah_key(name)
        if k and keys.setdefault(k, n) != n:
            raise SystemExit(f'surah spelling {name!r} names both {keys[k]} and {n}')

    for n in range(1, 115):
        entry = index[f'A{n + 4}']
        title = entry['title'].split(': ', 1)[1]
        add(re.sub(r'\s*[؀-ۿ].*$', '', title), n)
        add(entry['slug'].split('-', 1)[1], n)
    for n, names in SURAH_ALIASES.items():
        for name in names:
            add(name, n)
    return keys


_WORD = r"[A-Za-z][A-Za-z'’‘ʿ\-]*"
# "Surah al-Faatehah", "surah Hamd", "Surah Ya Sin"; plural "Surahs" is
# taken by the list rule below.
_SURAH_WORD = re.compile(r"\b(?:Surah|Surat|Sura|Soorah|Soora|Surah-e)\b(?!s)", re.I)
_SURAHS_WORD = re.compile(r"\b(?:Surahs|Suras|Surahs of)\b", re.I)


def _name_at(text, pos, keys):
    """The longest surah name (1-3 words, article included) starting at
    [pos]: (end, surah number), or None."""
    m = re.match(r'(?:' + _ARTICLE + r'[\s-])?' + _WORD + r'(?:\s' + _WORD + r'){0,2}',
                 text[pos:], re.I)
    if not m:
        return None
    words = m.group(0).split(' ')
    for n in range(len(words), 0, -1):
        cand = ' '.join(words[:n]).rstrip("-’'")
        # "al-Faatehah’" keeps a closing apostrophe of the spelling, but
        # never a trailing "-e" or the like.
        num = keys.get(surah_key(cand))
        if num:
            end = pos + len(cand)
            if text[end:end + 1] in ("’", "'") and not text[end + 1:end + 2].isalpha():
                end += 1
            return end, num
        if n == 1 and re.match(_ARTICLE + r'$', words[0], re.I):
            return None
    return None


def surah_mentions(text, keys):
    """(start, end, link text, uid) for each unlinked surah mention."""
    out = []
    for m in _SURAH_WORD.finditer(text):
        sp = re.match(r'[\s-]+', text[m.end():])
        if not sp:
            continue
        found = _name_at(text, m.end() + sp.end(), keys)
        if found:
            end, num = found
            word = m.group(0)
            word = 'Surah' if word.lower() == 'surah' else word[0].upper() + word[1:]
            label = word + text[m.end():end]
            out.append((m.start(), end, label, f'A{num + 4}'))
    for m in _SURAHS_WORD.finditer(text):
        pos = m.end()
        while True:
            sp = re.match(r'[\s-]+', text[pos:])
            if not sp:
                break
            start = pos + sp.end()
            linked = LINK.match(text, start)
            if linked:
                # One of the list already linked: step over it.
                end = linked.end()
            else:
                found = _name_at(text, start, keys)
                if not found:
                    break
                end, num = found
                out.append((start, end, text[start:end], f'A{num + 4}'))
            # "Surahs al-Nisa’ (No. 4), Hud (No. 11) and al-Kahf"
            sep = re.match(r'(?:\s*\([^()]{1,20}\))?(?:(?:\s*,)?\s+(?:and|or|&)(?=\s)|\s*,(?=\s))',
                           text[end:])
            if not sep:
                break
            pos = end + sep.end()
    return out


# ---------------------------------------------------------------------------
# Named duas, ziyarat, namaz and the like: (pattern, uid). The pattern is
# matched case-insensitively at word boundaries; keep it specific enough
# that it can't name anything else.
# ---------------------------------------------------------------------------

_DUA = r"(?:Dua|Du’a|Du'a|Dua’|Dua'|Duaa|Dua-e|Du’a-e|Supplication)[\s-]+(?:(?:al|e)[\s-]+)?"
_ZIY = r"(?:Ziyarat|Ziyaarat|Ziyarah|Ziyaarah|Ziarat|Ziyarat-e|Ziyaarat-e)[\s-]+(?:(?:al|e)[\s-]+)?"
_NAMAZ = r"(?:Namaz|Namaaz|Salat|Salaat|Salah|Prayer)(?:[\s-]+(?:e|of|al)[\s-]*|\s+)"

NAMED = [
    (r"Ayat(?:[\s-]?(?:al|ul))?[\s-]?Kursi|Ayatul[\s-]?Kursi|Ayat-ul-Kursi|Ayah al-Kursi", 'A4'),
    (_DUA + r"Kumayl|" + _DUA + r"Kumail|" + _DUA + r"Kumeel", 'E31'),
    (_ZIY + r"(?:Ashura|Ashoora|Aashura|Aashoora)(?![\s-]+Ghair)", 'G4'),
    (_ZIY + r"(?:Ashura|Ashoora)[\s-]+Ghair[\s-]+Ma’?roofa", 'G83'),
    (_DUA + r"Alqamah?", 'E8'),
    (_ZIY + r"Warith|" + _ZIY + r"Waris|" + _ZIY + r"Waarith", 'G6'),
    (_ZIY + r"(?:Aminullah|Ameenullah|Amin Allah|Amin-Allah|Amin al-Allah)", 'G2'),
    (_ZIY + r"(?:Aal|Ale|Al)[\s-]+(?:e[\s-]+)?(?:Yasin|Yaseen)", 'G1'),
    (_ZIY + r"(?:Jamia|Jami’ah|Jameah|Jame’ah|Jaame’ah|Jami'ah|Jamiah)[\s-]+(?:al-)?Kabir[ae]?h?", 'G13'),
    (_ZIY + r"(?:Jamia|Jami’ah|Jameah|Jame’ah|Jaame’ah|Jami'ah|Jamiah)[\s-]+(?:al-)?Saghir[ae]?h?", 'G12'),
    (_ZIY + r"(?:Arbaeen|Arba’een|Arbaʿin|Arbain|Arba'een)", 'G3'),
    (_ZIY + r"(?:Nahiya|Nahiyah|Naahiyah|Nahiya Muqaddasa)", 'G11'),
    (_ZIY + r"Rajabiyy?ah?", 'X4'),
    (_DUA + r"Nudbah?|" + _DUA + r"Nudba", 'E34'),
    (_DUA + r"(?:Simat|Simaat|Samaat|Simāt)", 'E26'),
    (_DUA + r"(?:Iftitah|Iftetah|Iftitaah|Iftetaah)", 'AA10'),
    (_DUA + r"Abu Hamz(?:a|ah)(?:[\s-]+(?:al-)?Thumali)?", 'AA12'),
    (_DUA + r"(?:Jawshan|Joshan|Jaushan)[\s-]+(?:al-)?Kabeer|" + _DUA + r"(?:Jawshan|Joshan|Jaushan)[\s-]+(?:al-)?Kabir", 'E29'),
    (_DUA + r"(?:Jawshan|Joshan|Jaushan)[\s-]+(?:al-)?Sag(?:h)?(?:ee|i)r", 'E30'),
    (_DUA + r"(?:Mujeer|Mujir)", 'E28'),
    (_DUA + r"(?:Ahad|Ahd)\b", 'E18'),
    (_DUA + r"Tawassul", 'E24'),
    (_DUA + r"Sabah\b", 'E35'),
    (_DUA + r"(?:Adeela|Adeelah|Adila|Adilah)", 'E4'),
    (_DUA + r"Mashlool|" + _DUA + r"Mashlul", 'E27'),
    (_DUA + r"(?:Asharat|Asharaat|Ashraat|Ashrat)", 'E10'),
    (_DUA + r"Hazeen|" + _DUA + r"Hazin\b", 'E15'),
    (_DUA + r"(?:Yastasheer|Yastashir)", 'E11'),
    (_DUA + r"(?:Mubahala|Mubahalah|Mubaahalah)", 'AC21'),
    (_DUA + r"(?:Umm|Umm-e|Umme)[\s-]+(?:Dawood|Dawud|Daud)", 'X14'),
    (_DUA + r"(?:Baha|Bahaa)\b", 'AA11'),
    (_DUA + r"Ihtijab", 'E154'),
    (_DUA + r"Maknoon", 'E88'),
    (_DUA + r"Ghariq|" + _DUA + r"Ghareeq", 'E21'),
    (_DUA + r"(?:Amaan|Aman)\b", 'E9'),
    (r"Hadith(?:[\s-]+(?:al|e))?[\s-]+Kisa|Hadees(?:[\s-]+(?:al|e))?[\s-]+Kisa", 'E14'),
    (r"Munajat(?:[\s-]+al)?[\s-]+Sha’?baniyy?ah?|Munajaat(?:[\s-]+al)?[\s-]+Sha’?baniyy?ah?", 'Y4'),
    (r"Tasb(?:ee|i|e)ha?t?[\s-]+(?:al|e|of)[\s-]+(?:Janab-e-|Lady |Hazrat |Bibi )?(?:Zahra|Lady Fatimah al-Zahra|Fatimah al-Zahra|Fatima al-Zahra|Fatemah Zahra|Faatemah Zahra|Fatimah Zahra|Fatima Zahra)[’']?(?:\s+\(s\.a\.\))?", 'I9'),
    (r"Tasbih[\s-]+of[\s-]+Lady[\s-]+Fatimah(?:\s+\(s\.a\.\))?", 'I9'),
    (r"Sajdah?(?:[\s-]+(?:e|al|of))?[\s-]+Shukr|Sajdah-e-Shukr|Sajda-e-Shukr", 'I19'),
    # Not "Night Prayer": the Ramazan night prayers go by that name too.
    (_NAMAZ + r"(?:Shab|Layl|Lail)\b|Namaz-e-Tahajjud", 'F2'),
    (_NAMAZ + r"(?:Ja[’']?far|Jafar-e|Ja’far-e)[\s-]+(?:al-|e-)?(?:Tayyar|Tayyaar|Tayyār|Tayyaar)", 'F11'),
    (_NAMAZ + r"(?:Ghufaila|Ghufailah|Ghufaylah|Ghufayla|Ghufailah)", 'F5'),
    (_NAMAZ + r"(?:Ayat|Ayaat|Aayaat|al-Ayat)\b", 'F4'),
    (_NAMAZ + r"(?:Wahshat|Wahshah)", 'F9'),
    (r"Namaz-e-Hadiya|Namaz-e-Hadiyah", 'F12'),
    (_NAMAZ + r"(?:Mayyit|Mayyat|Mayyet)", 'F7'),
    (_NAMAZ + r"(?:Kamila|Kamilah|Kaamelah)", 'F6'),
    (r"Salawat of Abul Hasan(?: al-)?Zarrab", 'E144'),
    (_NAMAZ + r"Salman\b", 'X10'),
]
NAMED = [(re.compile(r'(?<![\w\[-])(?:' + p + r')(?![\w])', re.I), uid) for p, uid in NAMED]


def named_mentions(text):
    out = []
    for pattern, uid in NAMED:
        for m in pattern.finditer(text):
            label = m.group(0).rstrip(' -')
            out.append((m.start(), m.start() + len(label), label, uid))
    return out


# ---------------------------------------------------------------------------


# Entries that carry the text a mention names, though they are not aliases
# of its entry: a link from one to the other would only lead away from it.
SAME_TEXT = {
    ('F2', 'F3'), ('F3', 'F2'),  # Namaz-e-Shab, in full and short
    ('I9', 'A4'),                # Ayat al-Kursi is one of its taqibaat
    ('D3', 'I9'),                # so is the Tasbih of Lady Fatimah
}


def same_entry(uid, target, aliases):
    return (uid == target or (uid, target) in SAME_TEXT
            or target in aliases.get(uid, ()) or uid in aliases.get(target, ()))


def alias_groups(index):
    """uid -> uids it is an alias of or aliased by ("E157|A4" ties E157 to A4)."""
    groups = {}
    for key in index:
        if '|' in key:
            a, b = key.split('|', 1)
            groups.setdefault(a, set()).add(b)
            groups.setdefault(b, set()).add(a)
    return groups


def mentions(text, keys, uid, aliases):
    """Non-overlapping unlinked mentions in [text], first come first served
    (the longer one wins a tie)."""
    taken = [(m.start(), m.end()) for m in LINK.finditer(text)]
    # A URL in parentheses or a bare link target is not prose.
    taken += [(m.start(), m.end()) for m in re.finditer(r'https?://\S+', text)]
    found = surah_mentions(text, keys) + named_mentions(text)
    found.sort(key=lambda f: (f[0], -(f[1] - f[0])))
    out = []
    for f in found:
        if same_entry(uid, f[3], aliases):
            continue
        if any(f[0] < e and s < f[1] for s, e in taken):
            continue
        taken.append((f[0], f[1]))
        out.append(f)
    return out


def link_text(text, keys, uid, aliases):
    found = mentions(text, keys, uid, aliases)
    for start, end, label, target in sorted(found, reverse=True):
        text = text[:start] + f'[{label}]({target})' + text[end:]
    return text, found


def link_entry(uid, entry, keys, aliases):
    """[entry] with its mentions linked, and what was linked."""
    found_all = []

    def fix_part(content, has_header):
        part = corpus.Part(content, has_header)
        raw = content.split('\n')
        offset = 1 if has_header else 0
        for i, kind in enumerate(part.kind):
            if kind != 'note':
                continue
            new, found = link_text(raw[i + offset], keys, uid, aliases)
            raw[i + offset] = new
            found_all.extend(found)
        return '\n'.join(raw)

    entry = dict(entry)
    raw_parts = [entry.get('data') or ''] + list(entry.get('tabs') or [])
    shown = [p for p in raw_parts if p.strip()]
    multi = len(shown) > 1
    if (entry.get('data') or '').strip():
        entry['data'] = fix_part(entry['data'], multi)
    if entry.get('tabs'):
        entry['tabs'] = [fix_part(t, multi) if t.strip() else t for t in entry['tabs']]
    if entry.get('merits'):
        lines = []
        for line in entry['merits'].split('\n'):
            new, found = link_text(line, keys, uid, aliases)
            lines.append(new)
            found_all.extend(found)
        entry['merits'] = '\n'.join(lines)
    return entry, found_all


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('uids', nargs='*')
    ap.add_argument('--write', action='store_true', help='link the mentions in place')
    args = ap.parse_args()
    index = corpus.load_index()
    keys = surah_keys(index)
    aliases = alias_groups(index)
    total = 0
    for uid in args.uids or corpus.entry_uids():
        path = os.path.join(corpus.ZIKR_DIR, uid)
        with open(path, encoding='utf-8') as f:
            src = f.read()
        entry = corpus.load_entry(uid, src)
        new, found = link_entry(uid, entry, keys, aliases)
        if not found:
            continue
        total += len(found)
        for _, _, label, target in found:
            print(f'{uid}\t{target}\t{label}')
        if args.write:
            out = corpus.json.dumps(new, ensure_ascii=False, indent=2) + '\n'
            with open(path, 'w', encoding='utf-8') as f:
                f.write(out)
    print(f'{total} mention(s){" linked" if args.write else " unlinked"}', file=sys.stderr)


if __name__ == '__main__':
    main()
