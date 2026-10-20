"""Checks every field in docs/STORE_LISTING.md against its store's limit.

Fields are the fenced blocks under a **Field** line, grouped by the
`## Language` and `### App Store` / `### Google Play` headings above them
(Persian has no store heading: it is Play only). The App Store counts keywords
in UTF-8 bytes; everything else is counted in characters.
"""
import pathlib
import re
import sys

DOC = pathlib.Path(__file__).resolve().parents[2] / 'docs' / 'STORE_LISTING.md'

LIMITS = {
    'App Store': {'Name': 30, 'Subtitle': 30, 'Promotional text': 170,
                  'Keywords': 100, 'Description': 4000, "What's New": 4000},
    'Google Play': {'Title': 30, 'Short description': 80,
                    'Full description': 4000, 'Release notes': 500},
}


def fields(text):
    lang, store = None, None
    for block in re.split(r'^(?=#{2,3} |\*\*)', text, flags=re.M):
        if block.startswith('## '):
            lang = block[3:].splitlines()[0].strip()
            store = 'Google Play' if 'Google Play only' in lang else None
        elif block.startswith('### '):
            heading = block[4:].splitlines()[0].strip()
            if heading in LIMITS:
                store = heading
        elif block.startswith('**') and store:
            name = re.match(r'\*\*(.+?)\*\*', block).group(1)
            body = re.search(r'```\n(.*?)\n```', block, re.S)
            if body and name in LIMITS[store]:
                yield lang, store, name, body.group(1)


def main():
    bad = 0
    for lang, store, name, value in fields(DOC.read_text(encoding='utf-8')):
        limit = LIMITS[store][name]
        size = len(value.encode('utf-8')) if name == 'Keywords' else len(value)
        unit = 'bytes' if name == 'Keywords' else 'chars'
        flag = 'OVER' if size > limit else 'ok'
        bad += size > limit
        print(f'{flag:4} {lang[:22]:22} {store:11} {name:18} {size:5}/{limit} {unit}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
