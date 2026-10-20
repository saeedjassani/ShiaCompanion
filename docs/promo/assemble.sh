#!/usr/bin/env bash
# Assembles the promo cut from windows of promo.html plus the "At a glance" scene,
# joined by 0.3 s crossfades, over the opening of the Dua Kumayl recitation.
# Writes shia-companion-promo.mp4 (master, gitignored) and shia-companion-promo-whatsapp.mp4.
#
# Needs the recorded clips in clips/ and taps.js (build.sh records them: node rec.js clips clips.json,
# then interp.py on each clip). Set CHROMIUM_PATH if Playwright's own browser isn't installed.
set -euo pipefail
cd "$(dirname "$0")"
W=build-cut; mkdir -p "$W"
XF=0.3

# Segments in order: name, then a window of promo.html (t0 t1), or a file made below.
SEGMENTS=(
  "opening  3.4  9.9"    # Bismillah and the first verse, word by word
  "reader  18.75 28.0"   # Read along, choose your script
  "listen  30.0  36.2"   # auto-scroll's end, Hear it recited
  "dark    38.6  41.4"   # Easy on the eyes at night
  "home    41.4  54.9"   # one take: prayer card, Home's features, Continue into the Quran, verse sheet
  "khatms  55.1  59.5"   # Keep several Khatms
  "track   59.7  63.7"   # Track · Read · Listen
  "glance  file"         # At a glance (make_glance.py)
  "more    64.3  68.3"   # And so much more
  "langs   68.9  72.9"   # In five languages
  "outro   72.9  78.9"   # logo, stores, 100% FREE
)

inputs=(); durs=()
for seg in "${SEGMENTS[@]}"; do
  read -r name t0 t1 <<<"$seg"
  out="$W/$name.mp4"
  if [[ "$t0" == file ]]; then
    python3 make_glance.py "$out"
  else
    node render_win.js "$PWD/promo.html" "$t0" "$t1" "$out"
  fi
  inputs+=(-i "$out")
  durs+=("$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")")
done

# xfade chain: each segment starts XF before the previous one ends
FILTER=$(python3 - "$XF" "${durs[@]}" <<'PY'
import sys
xf, durs = float(sys.argv[1]), [float(d) for d in sys.argv[2:]]
parts, prev, end = [], '[0:v]', durs[0]
for i, d in enumerate(durs[1:], 1):
    lab = '[vout]' if i == len(durs) - 1 else f'[v{i}]'
    parts.append(f'{prev}[{i}:v]xfade=transition=fade:duration={xf}:offset={end - xf:.3f}{lab}')
    prev, end = lab, end + d - xf
print(';'.join(parts))
print(f'{end:.3f}', file=sys.stderr)
PY
)
DUR=$(python3 -c "import sys; d=[float(x) for x in sys.argv[2:]]; print(round(sum(d) - float(sys.argv[1]) * (len(d) - 1), 3))" "$XF" "${durs[@]}")

[[ -f kumayl.mp3 ]] || curl -sS -r 0-2000000 -o kumayl.mp3 \
  https://pub-ee9041af06e644c2932c50c137c28aef.r2.dev/dua_kumayl_96k.mp3
ffmpeg -y -v error "${inputs[@]}" -i kumayl.mp3 -filter_complex "$FILTER;
[${#durs[@]}:a]atrim=0:$DUR,asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.3,afade=t=out:st=$(python3 -c "print($DUR - 1.2)"):d=1.2[aout]" \
  -map "[vout]" -map "[aout]" -c:v libx264 -crf 17 -preset medium -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 160k -ar 48000 -movflags +faststart shia-companion-promo.mp4
echo "wrote shia-companion-promo.mp4 ($DUR s)"

# WhatsApp copy: under the 16 MB inline limit, so WhatsApp sends it as-is
ffmpeg -y -v error -i shia-companion-promo.mp4 -c:v libx264 -crf 26 -preset slow \
  -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k shia-companion-promo-whatsapp.mp4
echo "wrote shia-companion-promo-whatsapp.mp4 ($(du -m shia-companion-promo-whatsapp.mp4 | cut -f1) MB)"
