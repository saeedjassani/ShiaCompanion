#!/usr/bin/env python3
"""The "At a glance" scene: the app's real widgets (shots/widget_*.jpg) around
an Apple Watch face, rising in over 0.45 s like the other scenes.

The widget screenshots sit on white with a soft grey rim and JPEG noise at the
corners, so instead of cutting them out by colour each card is trimmed a little
inside its own edge and masked with a clean, supersampled rounded rectangle; its
shadow is cast from that same mask. The watch is drawn at 3x and scaled down so
its curves stay smooth.

usage: python3 make_glance.py [out.mp4] [--still out.png]
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS, N = 1080, 1920, 30, 96
GOLD = (232, 199, 122); GOLD_SOFT = (243, 223, 174); BODY = (235, 224, 211)
ROBOTO = {400: 'Roboto-Regular.ttf', 500: 'Roboto-Medium.ttf', 700: 'Roboto-Bold.ttf'}
SS = 4  # supersampling for masks


def font(size, weight=400):
    name = ROBOTO[700 if weight >= 650 else 500 if weight >= 450 else 400]
    return ImageFont.truetype(os.path.join(HERE, 'fonts', name), size)


def rounded_mask(w, h, r, inset=0.0):
    """Anti-aliased rounded-rectangle alpha mask, `inset` px in from every edge."""
    m = Image.new('L', (w * SS, h * SS), 0)
    i = inset * SS
    ImageDraw.Draw(m).rounded_rectangle([i, i, w * SS - 1 - i, h * SS - 1 - i], radius=r * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def widget(name):
    """A widget screenshot trimmed to its card, plus the card's corner radius."""
    im = Image.open(os.path.join(HERE, 'shots', name)).convert('RGB')
    dark = im.convert('L').point(lambda v: 255 if v < 200 else 0)
    l, t, r, b = dark.getbbox()
    im = im.crop((l, t, r, b))
    # A rounded corner meets the diagonal r * (1 - 1/sqrt 2) in from the corner.
    px = im.convert('L').load()
    off = next(k for k in range(min(im.size) // 2) if px[k, k] < 200)
    return im, max(8, off / 0.293)


def card(name, width):
    """The widget at `width` px: RGBA, clipped to a clean rounded rectangle."""
    im, r = widget(name)
    k = width / im.width
    im = im.resize((width, round(im.height * k)), Image.LANCZOS).convert('RGBA')
    # 1.5 px inside the screenshot's own edge, so none of its grey rim survives
    im.putalpha(rounded_mask(im.width, im.height, r * k - 1.5, inset=1.5))
    # a hairline of light along the edge lifts the dark card off the dark stage
    rim = Image.new('L', (im.width * SS, im.height * SS), 0)
    i = 1.5 * SS
    ImageDraw.Draw(rim).rounded_rectangle([i, i, im.width * SS - 1 - i, im.height * SS - 1 - i],
                                          radius=(r * k - 1.5) * SS, outline=255, width=SS)
    rim = rim.resize(im.size, Image.LANCZOS).point(lambda v: v * 22 // 255)
    im.alpha_composite(Image.merge('RGBA', (*[Image.new('L', im.size, 255)] * 3, rim)))
    return im


def watch(width):
    """The Watch face (same moment as the widgets: 10:09 on Tue 29, Zuhr in 3:12:40)."""
    S = 3
    cw, ch = 560, 900
    im = Image.new('RGBA', (cw * S, ch * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    R = lambda *v: [x * S for x in v]
    band = (16, 15, 14, 255)
    d.rounded_rectangle(R(190, 0, 370, 300), radius=54 * S, fill=band)
    d.rounded_rectangle(R(190, 600, 370, 900), radius=54 * S, fill=band)
    for yy in (86, 132, 178):
        d.ellipse(R(268, yy, 292, yy + 24), fill=(52, 50, 47, 255))
    d.rounded_rectangle(R(494, 408, 506, 472), radius=6 * S, fill=(70, 67, 64, 255))      # crown
    d.rounded_rectangle(R(60, 190, 499, 709), radius=118 * S, fill=(58, 55, 53, 255))      # case
    d.rounded_rectangle(R(74, 204, 485, 695), radius=106 * S, fill=(0, 0, 0, 255))         # glass
    ox, oy = 74, 211

    def text(x, y, s, size, weight, fill, center=False):
        f = font(size * S, weight)
        if center:
            x -= d.textlength(s, font=f) / S / 2
        d.text(((ox + x) * S, (oy + y) * S), s, font=f, fill=fill)
    text(206, 22, 'TUE 29', 26, 700, (255, 159, 67), True)
    text(206, 52, '10:09', 118, 700, (255, 255, 255), True)
    d.arc(R(ox + 38, oy + 208, ox + 156, oy + 326), start=-40, end=300, fill=(255, 214, 64), width=5 * S)
    text(97, 232, '18', 46, 700, (255, 255, 255), True)
    text(97, 284, "RABI' II", 19, 600, (200, 195, 188), True)
    d.arc(R(ox + 256, oy + 208, ox + 374, oy + 326), start=-90, end=140, fill=(105, 240, 174), width=5 * S)
    text(315, 240, '128', 38, 700, (255, 255, 255), True)
    text(315, 286, 'TASBEEH', 16, 600, (200, 195, 188), True)
    d.rounded_rectangle(R(ox + 26, oy + 348, ox + 386, oy + 458), radius=26 * S, fill=(34, 26, 20, 255))
    cx, cy, r = ox + 62, oy + 380, 13
    d.ellipse(R(cx - r, cy - r, cx + r, cy + r), fill=GOLD)
    d.ellipse(R(cx - r * 0.25, cy - r * 1.06, cx + r * 1.35, cy + r * 0.62), fill=(34, 26, 20, 255))
    text(88, 362, 'Zuhr', 30, 600, (255, 255, 255))
    text(46, 398, '1:22 PM', 29, 600, (255, 255, 255))
    text(168, 402, '· in 3:12:40', 25, 600, GOLD)
    text(46, 430, 'Asr: 5:04 PM', 21, 400, (205, 199, 190))
    return im.resize((width, round(ch * width / cw)), Image.LANCZOS)


def shadow(item, blur, alpha, dy):
    a = item.split()[3].point(lambda v: v * alpha // 255)
    pad = blur * 3
    sh = Image.new('L', (item.width + pad * 2, item.height + pad * 2), 0)
    sh.paste(a, (pad, pad))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new('RGBA', sh.size, (0, 0, 0, 0))
    out.putalpha(sh)
    return out, pad, dy


def place(img, item, cx, cy):
    x, y = round(cx - item.width / 2), round(cy - item.height / 2)
    for sh, pad, dy in (shadow(item, 26, 150, 22), shadow(item, 6, 90, 6)):   # soft drop + contact shadow
        img.alpha_composite(sh, (x - pad, y - pad + dy))
    img.alpha_composite(item, (x, y))


BG = Image.open(os.path.join(HERE, 'shots', 'stage_bg_clean.png')).convert('RGBA')
ITEMS = [(watch(380), 540, 1025), (card('widget_prayers.jpg', 430), 238, 710),
         (card('widget_calendar.jpg', 430), 842, 734), (card('widget_recitations.jpg', 430), 238, 1315),
         (card('widget_upnext.jpg', 264), 842, 1288)]


def frame(t):
    img = BG.copy()
    d = ImageDraw.Draw(img)
    p = min(1.0, t / 0.45)
    p = 1 - (1 - p) ** 3
    dy = (1 - p) * 54
    d.text((W / 2, 300 - dy), 'At a glance', font=font(106, 700), fill=GOLD_SOFT, anchor='ma')
    d.text((W / 2, 424 - dy), 'Prayer widgets · Watch complications · Hijri events', font=font(40), fill=BODY, anchor='ma')
    for item, cx, cy in ITEMS:
        place(img, item, cx, cy + dy)
    if p < 1.0:
        img.alpha_composite(Image.new('RGBA', (W, H), (24, 17, 12, round((1 - p) * 130))))
    return img.convert('RGB')


if __name__ == '__main__':
    if '--still' in sys.argv:
        frame(1.0).save(sys.argv[sys.argv.index('--still') + 1])
        sys.exit()
    out = sys.argv[1] if len(sys.argv) > 1 else 'fan3_v20.mp4'
    ff = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                           '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-crf', '16', '-preset', 'medium',
                           '-pix_fmt', 'yuv420p', out], stdin=subprocess.PIPE)
    still = None
    for i in range(N):
        t = i / FPS
        if t >= 0.45 and still is None:
            still = frame(1.0).tobytes()
        ff.stdin.write(still if t >= 0.45 else frame(t).tobytes())
    ff.stdin.close()
    ff.wait()
    print('wrote', out, N, 'frames')
