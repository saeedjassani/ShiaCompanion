"""Builds assets/fonts/noto-nastaliq-urdu.ttf, the app's Urdu font.

    pip install fonttools
    curl -LO 'https://raw.githubusercontent.com/google/fonts/main/ofl/notonastaliqurdu/NotoNastaliqUrdu%5Bwght%5D.ttf'
    python3 scripts/build_urdu_font.py 'NotoNastaliqUrdu[wght].ttf'

From Google's Noto Nastaliq Urdu (variable weight, OFL - see
assets/fonts/NotoNastaliqUrdu-OFL.txt), two changes:

* Only Arabic-script characters (and space and the joiner and direction
  controls) are left in its character map, so English words and 0-9 in Urdu
  text come from the system font (see lib/theme/app_theme.dart). The glyphs
  stay: pyftsubset would drop them, but triples the shaping tables in doing
  so.
* Its glyphs are drawn at SCALE of their size, by raising unitsPerEm. Noto's
  Nastaliq stands about 2.5 em tall; at full size it collides between lines
  at the ~1.3x line heights the app's text styles set. At 0.8 regular and
  bold still clear in wrapped text (a stacked bold word can come close);
  0.7 cleared more easily but read clearly smaller than the English beside
  it, and from 0.85 bold lines start to touch.
"""

import sys

from fontTools.ttLib import TTFont

SCALE = 0.8
KEEP = [(0x20, 0x20), (0xA0, 0xA0), (0x600, 0x6FF), (0x750, 0x77F),
        (0x8A0, 0x8FF), (0x200C, 0x200F), (0xFB50, 0xFDFF), (0xFE70, 0xFEFF)]
OUTPUT = 'assets/fonts/noto-nastaliq-urdu.ttf'


def main(source: str) -> None:
    font = TTFont(source, recalcTimestamp=False)
    for table in font['cmap'].tables:
        table.cmap = {code: glyph for code, glyph in table.cmap.items()
                      if any(low <= code <= high for low, high in KEEP)}
    font['head'].unitsPerEm = round(font['head'].unitsPerEm / SCALE)
    font.save(OUTPUT)


if __name__ == '__main__':
    main(sys.argv[1])
