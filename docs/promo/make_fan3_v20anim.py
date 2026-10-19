# Animated version of the tuned v20 glance frame (entrance: rise + fade, like the other scenes).
import sys
sys.path.insert(0, '/home/hatch/workspace/v7')
from make_fan3_v19 import place_soft
from make_fan3_v14 import (UPNEXT, PRAYERS, CAL, RECIT, watch_face, BG, W, H,
                           font, F_SERIF, F_SANS_N, GOLD_SOFT, BODY)
from PIL import Image, ImageDraw

def frame(t, out):
    img = BG.copy().convert('RGBA')
    d = ImageDraw.Draw(img)
    p = min(1.0, t / 0.45); dy = (1 - p) * 54
    d.text((W / 2, 300 - dy), 'At a glance', font=font(F_SERIF, 106, 560), fill=GOLD_SOFT, anchor='ma')
    d.text((W / 2, 424 - dy), 'Prayer widgets · Watch complications · Hijri events',
           font=font(F_SANS_N, 40), fill=BODY, anchor='ma')
    place_soft(img, watch_face(), 540, 1025 + dy, 380)
    place_soft(img, PRAYERS, 238, 710 + dy, 430)
    place_soft(img, CAL, 842, 734 + dy, 430)
    place_soft(img, RECIT, 238, 1315 + dy, 430)
    place_soft(img, UPNEXT, 842, 1288 + dy, 264)
    if p < 1.0:
        img.alpha_composite(Image.new('RGBA', (W, H), (24, 17, 12, round((1 - p) * 130))))
    img.convert('RGB').save(out, quality=92)

if __name__ == '__main__':
    import os
    os.makedirs('/home/hatch/workspace/v7/fan3frames20', exist_ok=True)
    for i in range(96):
        frame(i / 30.0, f'/home/hatch/workspace/v7/fan3frames20/{i:04d}.png')
    print('96 frames done')
