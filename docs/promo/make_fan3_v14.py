#!/usr/bin/env python3
"""fan3 v9: 'At a glance' built from Saeed's REAL widget screenshots (flood-fill
corner cutout, pasted pixel-true) + Watch face set to the same Toronto moment.
Splice offsets fixed: never cut inside v7's own dissolve."""
import math
from collections import deque
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
GOLD = (232, 199, 122); GOLD_SOFT = (243, 223, 174)
CREAM = (251, 238, 232); BODY = (235, 224, 211); SECOND = (217, 204, 184)

F_SERIF = "/home/hatch/workspace/v7/fonts/Roboto-Bold.ttf"
F_SANS = "/home/hatch/workspace/v7/fonts/Roboto-Regular.ttf"
F_SANS_N = "/home/hatch/workspace/v7/fonts/Roboto-Regular.ttf"
ROBOTO = {400: "/home/hatch/workspace/v7/fonts/Roboto-Regular.ttf",
          500: "/home/hatch/workspace/v7/fonts/Roboto-Medium.ttf",
          700: "/home/hatch/workspace/v7/fonts/Roboto-Bold.ttf"}

def font(path, size, weight=None):
    if path == F_SANS or path == F_SANS_N:
        w = weight or 400
        path = ROBOTO[700 if w >= 650 else 500 if w >= 450 else 400]
    return ImageFont.truetype(path, size)

def rounded_mask(w, h, rad, ss=4):
    m = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius=rad * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)

def cutout(path):
    """Widget screenshot on white -> RGBA with corners flood-filled away."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    def is_white(x, y):
        r, g, b = px[x, y]
        return r > 238 and g > 238 and b > 238
    seen = bytearray(w * h)
    dq = deque()
    for sx, sy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if is_white(sx, sy):
            dq.append((sx, sy)); seen[sy * w + sx] = 1
    while dq:
        x, y = dq.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_white(nx, ny):
                seen[ny * w + nx] = 1; dq.append((nx, ny))
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if seen[row + x]: ap[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.7))
    out = im.convert("RGBA"); out.putalpha(alpha)
    return out

def paste_fit(base, img, x, y, w):
    h = round(img.height * w / img.width)
    base.alpha_composite(img.resize((w, h), Image.LANCZOS), (x, y))
    return h

BG = Image.open("/home/hatch/workspace/v7/stage_bg_clean.png").convert("RGB")
DARK_TOP = (52, 38, 28); DARK_BOT = (26, 19, 14)
UPNEXT = cutout("/home/hatch/workspace/v7/w_upnext.jpg")
PRAYERS = cutout("/home/hatch/workspace/v7/w_prayers.jpg")
FAVORITES = cutout("/home/hatch/workspace/v7/w_favorites.jpg")
RECIT = cutout("/home/hatch/workspace/v7/w_recitations.jpg")
CAL = cutout("/home/hatch/workspace/v7/w_calendar.jpg")

def wallpaper(w, h):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for yy in range(h):
        t = yy / h
        d.line([(0, yy), (w, yy)], fill=tuple(round(DARK_TOP[i] + (DARK_BOT[i] - DARK_TOP[i]) * t) for i in range(3)))
    return im.convert("RGBA")

def base_card():
    w, h = 398, 752
    card = wallpaper(w, h)
    d = ImageDraw.Draw(card)
    d.text((28, 16), "10:09", font=font(F_SANS, 25, 600), fill=CREAM)
    d.text((w - 88, 20), "5G", font=font(F_SANS, 20, 600), fill=CREAM)
    d.rounded_rectangle([w - 58, 22, w - 26, 36], radius=4, outline=CREAM, width=2)
    return card

def left_card():
    card = base_card()
    y = 92
    y += paste_fit(card, PRAYERS, 24, y, 350) + 22
    paste_fit(card, UPNEXT, 24, y, 216)
    return card

def right_card():
    card = base_card()
    y = 92
    y += paste_fit(card, CAL, 24, y, 350) + 16
    y += paste_fit(card, RECIT, 24, y, 350)
    return card

def moon(d, cx, cy, r, color=GOLD):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    d.ellipse([cx - r * 0.25, cy - r * 1.06, cx + r * 1.35, cy + r * 0.62], fill=(0, 0, 0))

def watch_face():
    cw, chh = 560, 900
    im = Image.new("RGBA", (cw, chh), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    band = (16, 15, 14, 255)
    d.rounded_rectangle([190, 0, 370, 300], radius=54, fill=band)
    d.rounded_rectangle([190, 600, 370, 900], radius=54, fill=band)
    for i, yy in enumerate([86, 132, 178]):
        d.ellipse([268, yy, 292, yy + 24], fill=(52, 50, 47, 255))
    case = Image.new("RGBA", (440, 520), (0, 0, 0, 0))
    cd = ImageDraw.Draw(case)
    cd.rounded_rectangle([0, 0, 439, 519], radius=118, fill=(58, 55, 53, 255))
    cd.rounded_rectangle([14, 14, 425, 505], radius=106, fill=(0, 0, 0, 255))
    d.rounded_rectangle([434, 218, 446, 282], radius=6, fill=(70, 67, 64, 255))
    scr = Image.new("RGBA", (412, 477), (0, 0, 0, 0))
    sd = ImageDraw.Draw(scr)
    t = "TUE 29"; f = font(F_SANS, 26, 700)
    sd.text(((412 - sd.textlength(t, font=f)) / 2, 22), t, font=f, fill=(255, 159, 67))
    t = "10:09"; f = font(F_SANS, 118, 700)
    sd.text(((412 - sd.textlength(t, font=f)) / 2, 52), t, font=f, fill=(255, 255, 255))
    sd.arc([38, 208, 156, 326], start=-40, end=300, fill=(255, 214, 64), width=5)
    t = "18"; f = font(F_SANS, 46, 700)
    sd.text((97 - sd.textlength(t, font=f) / 2, 232), t, font=f, fill=(255, 255, 255))
    t = "RABI' II"; f = font(F_SANS, 19, 600)
    sd.text((97 - sd.textlength(t, font=f) / 2, 284), t, font=f, fill=(200, 195, 188))
    sd.arc([256, 208, 374, 326], start=-90, end=140, fill=(105, 240, 174), width=5)
    t = "128"; f = font(F_SANS, 38, 700)
    sd.text((315 - sd.textlength(t, font=f) / 2, 240), t, font=f, fill=(255, 255, 255))
    t = "TASBEEH"; f = font(F_SANS, 16, 600)
    sd.text((315 - sd.textlength(t, font=f) / 2, 286), t, font=f, fill=(200, 195, 188))
    sd.rounded_rectangle([26, 348, 386, 458], radius=26, fill=(34, 26, 20, 255))
    moon(sd, 62, 380, 13)
    sd.text((88, 362), "Zuhr", font=font(F_SANS, 30, 600), fill=(255, 255, 255))
    sd.text((46, 398), "1:22 PM", font=font(F_SANS, 29, 600), fill=(255, 255, 255))
    sd.text((168, 402), "· in 3:12:40", font=font(F_SANS, 25, 600), fill=GOLD)
    sd.text((46, 430), "Asr: 5:04 PM", font=font(F_SANS, 21), fill=(205, 199, 190))
    case.alpha_composite(scr, (14, 21))
    im.alpha_composite(case, (60, 190))
    return im

LEFT = left_card(); RIGHT = right_card(); WATCH = watch_face()

def place(base, card, cx, cy, ang, scale=1.0):
    w2, h2 = round(card.width * scale), round(card.height * scale)
    c = card.resize((w2, h2), Image.LANCZOS)
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    sh.alpha_composite(Image.new("RGBA", c.size, (0, 0, 0, 150)))
    sh.putalpha(c.split()[3].point(lambda a: int(a * 0.55)))
    # expand=True is essential: rotating inside the original canvas CLIPS the
    # card's corners (it sliced the '1' off the right card's clock and half the
    # left card's battery icon — Saeed's catch, Oct 19).
    sh = sh.rotate(ang, resample=Image.BICUBIC, expand=True)
    c = c.rotate(ang, resample=Image.BICUBIC, expand=True)
    base.alpha_composite(sh, (round(cx - c.width / 2 + 10 * scale), round(cy - c.height / 2 + 18 * scale)))
    base.alpha_composite(c, (round(cx - c.width / 2), round(cy - c.height / 2)))

def frame(t, out):
    img = BG.copy().convert("RGBA")
    d = ImageDraw.Draw(img)
    p = min(1.0, t / 0.45); dy = (1 - p) * 54; sc = 0.96 + 0.04 * p
    d.text((W / 2, 300 - dy), "At a glance", font=font(F_SERIF, 106, 560), fill=GOLD_SOFT, anchor="ma")
    d.text((W / 2, 424 - dy), "Prayer widgets · Watch complications · Hijri events", font=font(F_SANS_N, 40), fill=BODY, anchor="ma")
    # v14.1 fix (Saeed: side screenshots were cropped by the frame edges):
    # draw the whole fan group on a layer, then scale it to 0.86 and center it,
    # so every screenshot sits fully inside the frame with margin to spare.
    grp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # v15 fix: NO overlap at all — Saeed: screenshots must be fully visible.
    # Cards at 0.72 scale, watch at 0.62, spread apart, then a 0.97 safety scale.
    place(grp, RIGHT, 897, 992 + dy, 6, sc * 0.72)
    place(grp, LEFT, 183, 992 + dy, -6, sc * 0.72)
    wsc = WATCH.resize((round(560 * sc * 0.62), round(900 * sc * 0.62)), Image.LANCZOS)
    grp.alpha_composite(wsc, (round(540 - wsc.width / 2), round(930 + dy - wsc.height / 2)))
    gd = ImageDraw.Draw(grp)
    gd.text((183, 1330), "Prayer widgets", font=font(F_SANS_N, 33, 600), fill=GOLD_SOFT, anchor="ma")
    gd.text((540, 1252), "Apple Watch", font=font(F_SANS_N, 33, 600), fill=GOLD_SOFT, anchor="ma")
    gd.text((897, 1330), "Calendar · Recitations", font=font(F_SANS_N, 33, 600), fill=GOLD_SOFT, anchor="ma")
    GS = 0.97
    grp2 = grp.resize((round(W * GS), round(H * GS)), Image.LANCZOS)
    img.alpha_composite(grp2, (round(W / 2 - grp2.width / 2), round(1052 - grp2.height / 2)))
    if p < 1.0:
        fade = Image.new("RGBA", (W, H), (24, 17, 12, round((1 - p) * 130)))
        img.alpha_composite(fade)
    img.convert("RGB").save(out, quality=92)

if __name__ == "__main__":
    frame(1.0, "/home/hatch/workspace/v7/fan3_v10b_still.png")
    print("still ok")
