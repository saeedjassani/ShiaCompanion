#!/usr/bin/env python3
"""Builds assets/fonts/arabic-ui.ttf, the theme's fallback for Arabic script.

    pip install fonttools
    python3 scripts/build_arabic_ui_font.py

The app's text is drawn in the platform's own font (Roboto, San Francisco),
which has no Arabic letters, so the theme lists a fallback for them
(lib/theme/app_theme.dart). That fallback was Scheherazade itself, and
Scheherazade also has Latin letters, digits, dashes, quotes and bullets.
Flutter only asks the system for its default font when none of a style's
families can be found, and the theme's family ('Roboto' on Android) is not
a name Android's font list goes by - so the bundled fallback was the only
font a style had, and it drew every English word in the app serif.

This is assets/fonts/scheherazade.ttf cut down to Arabic script and the
invisible joiners and direction marks Arabic text uses: anything else in a
line finds no glyph here and comes from the system font.

Scheherazade New is under the SIL Open Font License with "Scheherazade" and
"SIL" as Reserved Font Names, which a modified version may not use, so the
cut-down font is renamed. Its copyright and licence strings are kept; see
assets/fonts/ScheherazadeNew-OFL.txt.
"""

from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/fonts/scheherazade.ttf"
OUTPUT = ROOT / "assets/fonts/arabic-ui.ttf"

FAMILY = "Arabic UI"

# Arabic, Arabic Supplement, Arabic Extended-B and -A, the presentation
# forms, Rumi numerals and Arabic Extended-C.
ARABIC_BLOCKS = [
    (0x0600, 0x06FF),
    (0x0750, 0x077F),
    (0x0870, 0x08FF),
    (0xFB50, 0xFDFF),
    (0xFE70, 0xFEFF),
    (0x10E60, 0x10EFF),
]

# Invisible characters that sit inside Arabic text and must not split it
# into another font's run: the grapheme joiner, zero-width (non-)joiners,
# direction marks, embeddings and isolates, the word joiner and the Arabic
# shaping controls. Also the reversed comma and semicolon (Arabic-style
# punctuation), the dotted circle a shaper puts under a stray mark, and the
# font's two private-use glyphs.
EXTRA = [
    0x034F,
    *range(0x200B, 0x2010),
    *range(0x202A, 0x202F),
    0x2060,
    *range(0x2066, 0x206A),
    0x206C,
    0x206D,
    0x204F,
    0x2E41,
    0x25CC,
    0xF130,
    0xF131,
]


def main() -> None:
    font = TTFont(SOURCE)
    available = set(font.getBestCmap())
    wanted = {
        cp for lo, hi in ARABIC_BLOCKS for cp in range(lo, hi + 1)
    } | set(EXTRA)
    unicodes = sorted(wanted & available)

    # fontTools' default layout features: joining, ligatures, marks and
    # kerning. The character variants and stylistic sets are left out with
    # their alternate glyphs; menus never ask for them.
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)

    # Drop every name that carries a Reserved Font Name; keep the copyright
    # (0), version (5), licence (13, 14) and the rest as they are.
    name = font["name"]
    style = "Regular"
    renamed = {
        1: FAMILY,
        2: style,
        3: f"{FAMILY} {style}",
        4: f"{FAMILY} {style}",
        6: FAMILY.replace(" ", "") + "-" + style,
        16: FAMILY,
        17: style,
    }
    for record in list(name.names):
        if record.nameID in renamed:
            record.string = renamed[record.nameID]
        elif record.nameID > 255 or record.nameID in (7, 8, 9, 10, 11, 12):
            # Feature and trademark/vendor/designer names (some spell out
            # "SIL"); not needed in an app font.
            if "SIL" in record.toUnicode() or "Scheherazade" in record.toUnicode():
                name.removeNames(nameID=record.nameID)

    font.save(OUTPUT)
    print(f"{OUTPUT.relative_to(ROOT)}: {len(unicodes)} characters, "
          f"{len(font.getGlyphOrder())} glyphs, {OUTPUT.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
