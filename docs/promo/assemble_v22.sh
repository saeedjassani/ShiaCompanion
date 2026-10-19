#!/usr/bin/env bash
# Assembles the final v22 promo cut (62.3 s) from the compositions in this folder.
# This is the exact pipeline that produced shia-companion-promo-whatsapp.mp4 (v22).
#
# Prerequisites (not in git): the recorded clip frames in clips/ and in a sibling
# render_thu/clips/thuhome/ layout — record them with:
#   node rec_fix2.js <out> clips_listen2.json     # listen: R2 audio via local mirror
#   node rec_fix2.js <out> clips_home3.json        # home: Toronto selected in the picker
#   node rec_home_pw2.js                           # Thursday home (clock pinned to Thu)
#   (then python3 interp.py <each clip dir>, and regenerate taps.js as in build.sh)
# The widget stills for the "At a glance" fan are shots/widget_*.jpg (screenshots
# of the app's real widgets) and the Apple Watch face is shots/watch.png if present.
set -euo pipefail
cd "$(dirname "$0")"
W=build-v22; mkdir -p "$W"

# 1) Full render of the composition (fan / languages / outro trims come from here)
node render.js "$PWD/promo.html" video "$W/render_full.mp4"

# 2) Window renders (render_win.js renders promo.html's render(t) over a window)
node render_win.js "$PWD/promo.html" 3.4 9.9   "$W/opening_new.mp4"
node render_win.js "$PWD/promo.html" 18.75 36.5 "$W/reader_new.mp4"
node render_win.js "$PWD/promo.html" 41.4 50.6  "$W/home_new.mp4"
node render_win.js "$PWD/promo.html" 68.6 74.9  "$W/outro_new.mp4"

# 3) Thursday Home segment: promo_thu2.html is promo_thu.html with the scene
#    extended so the window 1.55-7.45 opens on the SETTLED Thursday Home
#    (headline in, phone at rest) — that is what makes the hard cut below clean.
node render_win.js "$PWD/promo_thu2.html" 1.55 7.45 "$W/thu_settled.mp4"

# 4) Home -> Thursday joined by a HARD CUT (no fade): home_new ends at 4.25 s,
#    just before the Continue tap; the tap itself plays in the resume segment.
ffmpeg -y -v error -i "$W/home_new.mp4" -i "$W/thu_settled.mp4" -filter_complex \
 "[0:v]trim=0:4.25,setpts=PTS-STARTPTS,settb=AVTB[a];[1:v]trim=0:5.9,setpts=PTS-STARTPTS,settb=AVTB[b];[a][b]concat=n=2:v=1:a=0[v]" \
 -map "[v]" -c:v libx264 -crf 17 -preset medium -pix_fmt yuv420p -r 30 "$W/home_thu2.mp4"

# 5) "At a glance" fan: the app's real widgets around the Watch (PIL + ffmpeg).
python3 make_fan3_v20anim.py   # writes fan3_v20.mp4 (layout from make_fan3_v20.py,
                               # widget cut-outs from make_fan3_v14.py)
mv fan3_v20.mp4 "$W/" 2>/dev/null || true

# 6) Assembly: 13 segments, 0.3 s crossfades except the Home->Thursday hard cut
#    inside home_thu2.mp4. Soundtrack: the Dua Kumayl recitation track of the
#    previous promo file, one continuous stretch, faded out at the end.
ffmpeg -y -v error -i "$W/render_full.mp4" -i "$W/fan3_v20.mp4" -i "$W/outro_new.mp4" \
 -i "$W/opening_new.mp4" -i "$W/reader_new.mp4" -i "$W/home_new.mp4" -i "$W/home_thu2.mp4" \
 -i shia-companion-promo-whatsapp.mp4 -filter_complex "
[0:v]split=5[r4][r7][r8][r9][r10];
[3:v]trim=0:6.5,setpts=PTS-STARTPTS[s1];
[4:v]split=2[rd1][rd2];
[rd1]trim=0:9.25,setpts=PTS-STARTPTS[s2];
[rd2]trim=11.25:17.45,setpts=PTS-STARTPTS[s3];
[r4]trim=38.6:41.4,setpts=PTS-STARTPTS[s4];
[6:v]trim=0:10.17,setpts=PTS-STARTPTS[s56];
[5:v]trim=4.3:9.4,setpts=PTS-STARTPTS[s7];
[r7]trim=50.8:55.2,setpts=PTS-STARTPTS[s8];
[r8]trim=55.4:59.4,setpts=PTS-STARTPTS[s9];
[1:v]setpts=PTS-STARTPTS[s10];
[r9]trim=60.0:64.0,setpts=PTS-STARTPTS[s11];
[r10]trim=64.6:68.6,setpts=PTS-STARTPTS[s12];
[2:v]trim=0:6.0,setpts=PTS-STARTPTS[s13];
[s1][s2]xfade=transition=fade:duration=0.3:offset=6.2[v1];
[v1][s3]xfade=transition=fade:duration=0.3:offset=15.15[v2];
[v2][s4]xfade=transition=fade:duration=0.3:offset=21.05[v3];
[v3][s56]xfade=transition=fade:duration=0.3:offset=23.55[v4];
[v4][s7]xfade=transition=fade:duration=0.3:offset=33.42[v5];
[v5][s8]xfade=transition=fade:duration=0.3:offset=38.22[v6];
[v6][s9]xfade=transition=fade:duration=0.3:offset=42.32[v7];
[v7][s10]xfade=transition=fade:duration=0.3:offset=46.02[v8];
[v8][s11]xfade=transition=fade:duration=0.3:offset=48.92[v9];
[v9][s12]xfade=transition=fade:duration=0.3:offset=52.62[v10];
[v10][s13]xfade=transition=fade:duration=0.3:offset=56.32[vout];
[7:a]atrim=0:62.30,asetpts=PTS-STARTPTS,afade=t=out:st=61.50:d=0.8[aout]
" -map "[vout]" -map "[aout]" -c:v libx264 -crf 17 -preset medium -pix_fmt yuv420p -r 30 \
 -c:a aac -b:a 160k shia-companion-promo.mp4

# 7) WhatsApp copy (under the 16 MB inline limit)
ffmpeg -y -v error -i shia-companion-promo.mp4 -c:v libx264 -crf 26 -preset slow \
 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k shia-companion-promo-whatsapp.mp4
echo "wrote shia-companion-promo.mp4 + shia-companion-promo-whatsapp.mp4 (v22)"
