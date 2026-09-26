# App promo video

`shia-companion-promo.mp4` — 37 s, 1080×1920 (9:16), 30 fps, H.264, silent.
Suits Instagram Reels/Stories, YouTube Shorts, TikTok and the App Store /
Play Store preview slots.

Storyboard: logo intro → home (prayer times, Hijri date, daily hadith) →
Dua Kumayl scrolling → Ziyarat Ashura → Today's Recitations → Hijri
calendar → Qibla finder → Tasbeeh & Qaza tracker → Library → outro with
store names and `shia-companion.web.app`.

All phone screens are real screenshots of the Flutter web build (`shots/`).

## Regenerating

```sh
flutter build web --release
(cd test_visual && npm ci && WEB_BUILD_DIR=../build/web PORT=4173 node serve.js &)

# 1. (optional) recapture screens - see the tap plans used below
node docs/promo/cap.js docs/promo/shots '[{"name":"home_loc","taps":[[195,290,2000],[273,514,9000]]}]'
#   tall Dua Kumayl for the scroll: H=2400 with the viewport height patched,
#   path "/dua-kumayl"

# 2. render (needs ffmpeg on PATH or FFMPEG=/path/to/ffmpeg)
node docs/promo/render.js "$PWD/docs/promo/promo.html" video out.mp4
# or quick stills at given seconds:
node docs/promo/render.js "$PWD/docs/promo/promo.html" stills 2,10,33
```

Set `CHROMIUM_PATH` if Playwright's bundled browser isn't installed.
Captions, timings and scene order are the `scenes` array at the bottom of
`promo.html`.
