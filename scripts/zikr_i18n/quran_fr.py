#!/usr/bin/env python3
"""Build the French Quran (assets/zikr_i18n/fr/A5.json ... A118.json) from
Dr. G.H. Abolqasemi Fakhri's translation (Ansariyan, Qom, 2008).

Source: the "Lecture en ligne" HTML on lenoblecoran.fr
(https://www.lenoblecoran.fr/docteur-fakhri/), a Windows-1252 Word export:

    curl -A Mozilla/5.0 -o fakhri.htm \\
      https://www.lenoblecoran.fr/wp-content/uploads/Le-Coran-Traduction-du-Dr-G.H.-Abolqasemi-Fakhri.htm
    python3 -I scripts/zikr_i18n/quran_fr.py fakhri.htm

Segments are those of the Urdu, Persian and Gujarati Quran: each verse
segment takes the verse whose number its Arabic carries, and a surah's
unnumbered Bismillah takes the Bismillah the edition prints above it. Any
other segment already in a file (Al-Baqarah's two notes) is kept as it is.

The text is Fakhri's, with his [bracketed] additions and (glosses), except:
- a verse the export broke over two paragraphs, the second opening with a
  stray plain "[7]" (6:98, 71:11), is rejoined; an empty "[207]" after
  7:206 is dropped;
- the superscript "c" the edition writes for the ayn becomes "ʿ", and two
  chat-alphabet digits become letters (5:103 "7âmî" -> "hâmî", 71:23
  "Suwâ3" -> "Suwâʿ");
- six brackets opened "(" and closed "]" are closed ")" (20:50, 27:92,
  40:31, 44:7, 69:33, and 33:59's "(v. 55]]");
- straight double quotes become “ ” (French inner quotes), the side chosen
  from the neighbouring characters, since some open in one verse and close
  in the next.
"""
import html
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zikr_i18n as z  # noqa: E402

OUT_DIR = os.path.join(z.I18N_DIR, 'fr')
SURAHS = 114
FIRST_UID = 5  # Surah 1 is A5, surah N is A(N + 4).

VERSE = re.compile(r'^\[(\d+)\] ?\s*(.*)$', re.S)
BOLD_NUMBER = re.compile(
    r'^<p[^>]*>\s*<b>\s*(?:<i>\s*)?<span[^>]*>\s*\[\d+\]', re.S)
VERSE_NUMBER = re.compile(r'\((\d+)\)')

FIXES = {
    (5, 103): [('7âmî', 'hâmî')],
    (71, 23): [('Suwâ3', 'Suwâʿ')],
    (20, 50): [('son existence et sa vie]', 'son existence et sa vie)')],
    (27, 92): [('enseignements célestes]', 'enseignements célestes)')],
    (33, 59): [('(v. 55]]', '(v. 55)]')],
    (40, 31): [('qui sont venus]', 'qui sont venus)')],
    (44, 7): [('leurs lois,...]', 'leurs lois,...)')],
    (69, 33): [('enseignements de DIEU]', 'enseignements de DIEU)')],
}


def _text(fragment):
    fragment = re.sub(r'<sup>\s*c\s*</sup>', 'ʿ', fragment)
    s = html.unescape(re.sub(r'<[^>]+>', '', fragment))
    return re.sub(r'[ \t\r\n]+', ' ', s).strip('  ')


def parse(path):
    """{surah: {'bismillah': str | None, 'verses': {n: str}}}."""
    with open(path, encoding='cp1252') as f:
        doc = f.read()
    # The second "Avant-propos" is the foreword itself, after the contents.
    body = doc[doc.find('Avant-propos', doc.find('Avant-propos') + 1):]
    parts = re.split(r'(<h1[^>]*>.*?</h1>|<p[^>]*>.*?</p>)', body, flags=re.S)
    surahs, current, last = {}, None, None
    for part in parts:
        if not part.startswith('<'):
            continue
        text = _text(part)
        if part.startswith('<h1'):
            m = re.search(r'Sourate\s*(\d+)', text)
            if m:
                current, last = int(m.group(1)), None
                surahs[current] = {'bismillah': None, 'verses': {}}
            continue
        if current is None or not text:
            continue
        verses = surahs[current]['verses']
        m = VERSE.match(text)
        if m and not BOLD_NUMBER.match(part) and last is not None:
            verses[last] += ' ' + m.group(2).strip()
        elif m and m.group(2).strip():
            last = int(m.group(1))
            if last in verses:
                sys.exit(f'{current}:{last} appears twice')
            verses[last] = m.group(2).strip()
        elif not m and last is None and 'Nom de DIEU' in text:
            surahs[current]['bismillah'] = text
    return surahs


def _curl_quotes(text):
    out = []
    for i, ch in enumerate(text):
        if ch != '"':
            out.append(ch)
            continue
        before = text[i - 1] if i else ' '
        opens = before in '  ([«' or i == 0
        out.append('“' if opens else '”')
    return ''.join(out)


def clean(surah, number, text):
    for old, new in FIXES.get((surah, number), []):
        if old not in text:
            sys.exit(f'{surah}:{number}: expected {old!r}')
        text = text.replace(old, new)
    text = _curl_quotes(text)
    if re.search(r'\d', text) and (surah, number) != (33, 59):
        sys.exit(f'{surah}:{number}: unexpected digit in {text!r}')
    if text.count('(') != text.count(')') or text.count('[') != text.count(']'):
        sys.exit(f'{surah}:{number}: unbalanced brackets in {text!r}')
    return text


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    surahs = parse(sys.argv[1])
    if sorted(surahs) != list(range(1, SURAHS + 1)):
        sys.exit('expected 114 surahs')
    corpus = z.corpus()
    written = 0
    for surah in range(1, SURAHS + 1):
        uid = f'A{surah + FIRST_UID - 1}'
        source = surahs[surah]
        path = os.path.join(OUT_DIR, f'{uid}.json')
        segments = {}
        if os.path.exists(path):
            segments = z.load_json(path).get('segments', {})
        used = set()
        for number, segment in enumerate(z.document_segments(corpus[uid])):
            if segment['kind'] != 'verse' or segment['english'] is None:
                continue
            numbers = VERSE_NUMBER.findall(segment['arabic'])
            if not numbers:
                if not source['bismillah']:
                    sys.exit(f'{uid}: no Bismillah in the source')
                segments[str(number)] = source['bismillah']
                continue
            verse = int(numbers[-1])
            if verse not in source['verses']:
                sys.exit(f'{uid}: no verse {surah}:{verse} in the source')
            segments[str(number)] = clean(surah, verse, source['verses'][verse])
            used.add(verse)
        if used != set(source['verses']):
            sys.exit(f'{uid}: source verses {sorted(set(source["verses"]) - used)} '
                     'have no segment')
        ordered = dict(sorted(segments.items(), key=lambda kv: int(kv[0])))
        z.write_json(path, {'segments': ordered})
        written += 1
    index = os.path.join(OUT_DIR, 'index.json')
    if not os.path.exists(index):
        z.write_json(index, {'titles': {}})
    print(f'wrote {written} surahs to {os.path.relpath(OUT_DIR, z.ROOT)}')


if __name__ == '__main__':
    main()
