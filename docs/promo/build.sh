#!/usr/bin/env bash
# Rebuilds the promo videos from the Flutter web build.
# Needs: flutter, node + test_visual's Playwright, python3 with pillow/numpy, ffmpeg.
# Set CHROMIUM_PATH if Playwright's own browser isn't installed.
#   ./build.sh            record clips + render
#   ./build.sh --render   reuse existing clips/, only re-render (e.g. after editing promo.html)
set -euo pipefail
cd "$(dirname "$0")"
FFMPEG=${FFMPEG:-ffmpeg}
export FFMPEG

if [[ "${1:-}" != "--render" ]]; then
  (cd ../.. && flutter build web --release --no-web-resources-cdn)
  (cd ../../test_visual && WEB_BUILD_DIR=../build/web PORT=4173 node serve.js) & SERVER=$!
  trap 'kill $SERVER' EXIT
  sleep 2
  node rec.js clips clips.json
  for c in clips/*/; do python3 interp.py "$c"; done
  python3 - <<'PY'
import glob, json, os
taps = {c: json.load(open(f'clips/{c}/taps.json'))['taps'] for c in sorted(os.listdir('clips'))}
frames = {c: len(glob.glob(f'clips/{c}/[0-9]*.jpg')) for c in taps}
open('taps.js', 'w').write(f'window.TAPS={json.dumps(taps)};\nwindow.CLIP_FRAMES={json.dumps(frames)};\n')
PY
fi

# Soundtrack: the app's own Dua Kumayl recitation (same file the in-app player streams).
[[ -f kumayl.mp3 ]] || curl -sS -r 0-2000000 -o kumayl.mp3 \
  https://pub-ee9041af06e644c2932c50c137c28aef.r2.dev/dua_kumayl_96k.mp3
# Loudness envelope that drives the on-screen waveform.
"$FFMPEG" -v error -i kumayl.mp3 -t 90 -ac 1 -ar 24000 -f s16le - | python3 -c "
import sys, json, numpy as np
a = np.frombuffer(sys.stdin.buffer.read(), dtype=np.int16).astype(float)
r = [float(np.sqrt((a[i:i+800]**2).mean())) for i in range(0, len(a) - 800, 800)]
m = np.percentile(r, 98)
open('env.js', 'w').write('window.ENV=' + json.dumps([round(min(1, x / m), 3) for x in r]) + ';')"

# The promo (master + WhatsApp copy): windows of promo.html and the At a glance scene, crossfaded.
./assemble.sh

# App Store preview: 886x1920 (6.5"/6.9" iPhone), 29.5 s, stereo AAC.
node render.js "$PWD/store.html" video silent.mp4
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 silent.mp4)
"$FFMPEG" -v error -y -i silent.mp4 -i kumayl.mp3 -filter_complex \
  "[1:a]atrim=0:$DUR,asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.3,afade=t=out:st=$(python3 -c "print($DUR-1.5)"):d=1.5[a]" \
  -map 0:v -map "[a]" -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -crf 16 -preset slow -r 30 \
  -c:a aac -b:a 256k -ar 48000 -ac 2 -shortest -movflags +faststart app-store-preview.mp4
rm silent.mp4
echo "wrote docs/promo/app-store-preview.mp4"
