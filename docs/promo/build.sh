#!/usr/bin/env bash
# Rebuilds shia-companion-promo.mp4 from the Flutter web build.
# Needs: flutter, node + test_visual's Playwright, python3 with pillow/numpy/imageio-ffmpeg.
#   ./build.sh            record clips + render
#   ./build.sh --render   reuse existing clips/, only re-render (e.g. after editing promo.html)
set -euo pipefail
cd "$(dirname "$0")"
FFMPEG=${FFMPEG:-$(python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())")}
export FFMPEG

if [[ "${1:-}" != "--render" ]]; then
  (cd ../.. && flutter build web --release)
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
"$FFMPEG" -v error -i kumayl.mp3 -t 60 -ac 1 -ar 24000 -f s16le - | python3 -c "
import sys, json, numpy as np
a = np.frombuffer(sys.stdin.buffer.read(), dtype=np.int16).astype(float)
r = [float(np.sqrt((a[i:i+800]**2).mean())) for i in range(0, len(a) - 800, 800)]
m = np.percentile(r, 98)
open('env.js', 'w').write('window.ENV=' + json.dumps([round(min(1, x / m), 3) for x in r]) + ';')"

node render.js "$PWD/promo.html" video silent.mp4
DUR=$(node -e "console.log(require('fs').readFileSync('promo.html','utf8').match(/END = ([0-9.]+)/)[1])")
"$FFMPEG" -v error -y -i silent.mp4 -i kumayl.mp3 -filter_complex \
  "[1:a]atrim=0:$DUR,asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.3,afade=t=out:st=$(python3 -c "print($DUR-3.7)"):d=3.7[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 160k -ar 48000 -shortest -movflags +faststart shia-companion-promo.mp4
rm silent.mp4
echo "wrote docs/promo/shia-companion-promo.mp4"
