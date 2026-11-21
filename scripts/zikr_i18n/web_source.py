"""Rows for `deck_source.py align` from two published web editions of
*Mafatih al-Jinan* that print each Arabic phrase with its translation:

  - mafatih.duas.co (Urdu): Arabic, its number, the Urdu, its number;
  - mafatihuljinan.org (Gujarati): per timed block, the Arabic, a Gujarati
    transliteration, then the Gujarati translation;
  - lechiisme.com (French, "Mafatih al-Jinan en Français"): one box per
    phrase - the Arabic, a French-style phonetic transliteration and the
    French, split by dividers - with the book's prose (introductions,
    instructions, merits) as paragraphs between the boxes. Save a post
    from the WordPress API, e.g.
    curl 'https://lechiisme.com/wp-json/wp/v2/posts/47909?_fields=id,link,title,content'
    (the post ids are listed by /wp-json/wp/v2/posts?categories=1798).

    python3 -I scripts/zikr_i18n/web_source.py duasco page.html rows.json
    python3 -I scripts/zikr_i18n/web_source.py mafatihuljinan page.html rows.json
    python3 -I scripts/zikr_i18n/web_source.py lechiisme post.json rows.json

A lechiisme row also carries `prose`: the French paragraphs printed
before that phrase since the previous one (the last row's `prose_after`
holds what follows the last phrase), for the instructions and merits.

Pass a page saved with curl; this script never fetches. The rows are the
format `deck_source.py rows` writes ({"slide", "ar", "translation"}), so
the rest of the workflow is deck_source.py's: align, a draft divided by
meaning, validate, apply. See scripts/zikr_i18n/SOURCES.md.
"""
import argparse
import html
import json
import re

_HARAKAT = re.compile('[ً-ْٰ]')
_AR_LETTER = re.compile('[ء-يٱ-ۓ]')
_GU_LETTER = re.compile('[઀-૿]')
_TIMESTAMP = re.compile(r'^\[\d+:\d+(?:\.\d+)?\]$')


def _lines(fragment):
    fragment = re.sub(r'<script.*?</script>|<style.*?</style>', '', fragment, flags=re.S)
    text = re.sub(r'<br\s*/?>', '\n', fragment)
    text = re.sub(r'</?(p|div|li|h\d|span)\b[^>]*>', '\n', text)
    text = html.unescape(re.sub(r'<[^>]+>', '', text))
    return [' '.join(l.replace('‍', '').replace('‌', '').split())
            for l in text.split('\n') if l.strip()]


def _is_vowelled_arabic(line):
    letters = len(_AR_LETTER.findall(line))
    return letters >= 2 and len(_HARAKAT.findall(line)) / letters >= 0.3


def duasco_rows(page):
    """mafatih.duas.co: Arabic, n, Urdu, n - repeated."""
    lines = _lines(page)
    rows, i = [], 0
    while i < len(lines):
        if (_is_vowelled_arabic(lines[i]) and i + 3 < len(lines)
                and lines[i + 1].isdigit() and lines[i + 3] == lines[i + 1]):
            rows.append({'slide': int(lines[i + 1]), 'ar': lines[i],
                         'translation': lines[i + 2]})
            i += 4
        else:
            i += 1
    return rows


def mafatihuljinan_rows(page):
    """mafatihuljinan.org: the Arabic tab's blocks. A block is its Arabic
    line(s) and the Gujarati after them; with two or more Gujarati lines
    the first is the transliteration and the rest the translation. A block
    with one Gujarati line is kept with `ambiguous` set, for a reader to
    decide."""
    start = page.find('arabic_content active')
    end = page.find('translation_content', start + 1) if start >= 0 else -1
    lines = _lines(page[start:end] if start >= 0 and end > start else page)
    blocks, current = [], None
    for line in lines:
        if _TIMESTAMP.match(line):
            continue
        if _is_vowelled_arabic(line):
            if current is None or current['gu']:
                current = {'ar': [], 'gu': []}
                blocks.append(current)
            current['ar'].append(line)
        elif current is not None and len(_GU_LETTER.findall(line)) >= 2:
            current['gu'].append(line)
    rows = []
    for n, b in enumerate(blocks, 1):
        row = {'slide': n, 'ar': ' '.join(b['ar'])}
        if len(b['gu']) >= 2:
            row['translit'] = b['gu'][0]
            row['translation'] = ' '.join(b['gu'][1:])
        else:
            row['translation'] = ' '.join(b['gu'])
            row['ambiguous'] = True
        rows.append(row)
    return rows


_LC_BOX = re.compile(r'<div class="message-box\b')
_LC_DIVIDER = re.compile(r'<div class="is-divider\b[^>]*>\s*</div>')
_LC_DONATION = ('Soutenir Le Chiisme', 'Ces enseignements restent libres',
                'Seyed Ali Mousavi', 'Je donne')


def _lc_box_end(page, start):
    """Index just past the <div> opened at `start`."""
    depth, i = 0, start
    for m in re.finditer(r'<div\b|</div>', page[start:]):
        depth += 1 if m.group(0) != '</div>' else -1
        if depth == 0:
            return start + m.end()
    return len(page)


def _lc_prose(fragment):
    return [l for l in _lines(fragment)
            if not any(l.startswith(d) for d in _LC_DONATION)]


def lechiisme_rows(page):
    """lechiisme.com: each phrase box is Arabic | transliteration | French."""
    if page.lstrip().startswith('{'):
        page = json.loads(page)['content']['rendered']
    rows, pos, prose = [], 0, []
    for m in _LC_BOX.finditer(page):
        if m.start() < pos:
            continue
        end = _lc_box_end(page, m.start())
        prose += _lc_prose(page[pos:m.start()])
        pos = end
        parts = [_lines(p) for p in _LC_DIVIDER.split(page[m.start():end])]
        parts = [p for p in parts if p]
        if not parts or not _is_vowelled_arabic(' '.join(parts[0])):
            prose += [l for p in parts for l in p]
            continue
        row = {'slide': len(rows) + 1, 'ar': ' '.join(parts[0])}
        if len(parts) >= 3:
            row['translit'] = ' '.join(parts[1])
            row['translation'] = ' '.join(l for p in parts[2:] for l in p)
        else:
            row['translation'] = ' '.join(parts[-1]) if len(parts) > 1 else ''
            row['ambiguous'] = True
        if prose:
            row['prose'] = prose
        prose = []
        rows.append(row)
    prose += _lc_prose(page[pos:])
    if rows and prose:
        rows[-1]['prose_after'] = prose
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('site', choices=['duasco', 'mafatihuljinan', 'lechiisme'])
    parser.add_argument('page')
    parser.add_argument('out')
    args = parser.parse_args()
    page = open(args.page, encoding='utf-8').read()
    rows = {'duasco': duasco_rows, 'mafatihuljinan': mafatihuljinan_rows,
            'lechiisme': lechiisme_rows}[args.site](page)
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)
    ambiguous = sum(1 for r in rows if r.get('ambiguous'))
    print(f'{len(rows)} rows ({ambiguous} without a separate transliteration) -> {args.out}')


if __name__ == '__main__':
    main()
