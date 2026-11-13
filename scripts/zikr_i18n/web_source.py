"""Rows for `deck_source.py align` from two published web editions of
*Mafatih al-Jinan* that print each Arabic phrase with its translation:

  - mafatih.duas.co (Urdu): Arabic, its number, the Urdu, its number;
  - mafatihuljinan.org (Gujarati): per timed block, the Arabic, a Gujarati
    transliteration, then the Gujarati translation.

    python3 -I scripts/zikr_i18n/web_source.py duasco page.html rows.json
    python3 -I scripts/zikr_i18n/web_source.py mafatihuljinan page.html rows.json

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


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('site', choices=['duasco', 'mafatihuljinan'])
    parser.add_argument('page')
    parser.add_argument('out')
    args = parser.parse_args()
    page = open(args.page, encoding='utf-8').read()
    rows = (duasco_rows if args.site == 'duasco' else mafatihuljinan_rows)(page)
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)
    ambiguous = sum(1 for r in rows if r.get('ambiguous'))
    print(f'{len(rows)} rows ({ambiguous} with one Gujarati line) -> {args.out}')


if __name__ == '__main__':
    main()
