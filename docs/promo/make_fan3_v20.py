# At a Glance v20 — tuned sizes/positions of the v19 concept:
# widgets aligned on shared top/bottom edges, watch centered in the group,
# comfortable clearances from case and bands everywhere.
import sys
sys.path.insert(0, '/home/hatch/workspace/v7')
from make_fan3_v19 import place_soft
from make_fan3_v14 import (UPNEXT, PRAYERS, CAL, RECIT, watch_face, BG, W, H,
                           font, F_SERIF, F_SANS_N, GOLD_SOFT, BODY)
from PIL import Image, ImageDraw

def frame(out):
    img = BG.copy().convert('RGBA')
    d = ImageDraw.Draw(img)
    d.text((W / 2, 300), 'At a glance', font=font(F_SERIF, 106, 560), fill=GOLD_SOFT, anchor='ma')
    d.text((W / 2, 424), 'Prayer widgets · Watch complications · Hijri events',
           font=font(F_SANS_N, 40), fill=BODY, anchor='ma')
    boxes = {}
    boxes['watch'] = place_soft(img, watch_face(), 540, 1025, 380)
    boxes['pt'] = place_soft(img, PRAYERS, 238, 710, 430)
    boxes['cal'] = place_soft(img, CAL, 842, 734, 430)
    boxes['rec'] = place_soft(img, RECIT, 238, 1315, 430)
    boxes['upn'] = place_soft(img, UPNEXT, 842, 1288, 264)
    print(boxes)
    img.convert('RGB').save(out, quality=92)

if __name__ == '__main__':
    frame('/tmp/fan3_v20.png')
    Image.open('/tmp/fan3_v20.png').resize((540, 960)).save('/tmp/fan3_v20.jpg', quality=88)
    print('v20 done')
