# App promo video

`shia-companion-promo.mp4` — 45 s, 1080×1920 (9:16), 30 fps, H.264, silent.
Suits Instagram Reels/Stories, YouTube Shorts, TikTok and the App Store /
Play Store preview slots.

Storyboard (weighted toward the zikr page, which is most of the app's
usage): logo intro with "FREE" → Duas list → Dua Kumayl scrolling (Arabic,
transliteration, translation) → Qalam (IndoPak) vs Scheherazade script →
font size → Arabic as a paragraph → focus mode → recitation audio →
on-page counter → quick montage (prayer times, calendar, Qibla, tasbeeh)
→ outro with the official App Store / Google Play badges and
`shia-companion.web.app`.

The Kumayl screens come from toggling the zikr settings drawer between
captures; those preferences persist in the browser, so reset them
(Qalam, size 32, transliteration + translation on, paragraph/focus off)
after recapturing. Badges: `shots/appstore.svg` from developer.apple.com,
`shots/gplay_c.png` from play.google.com (padding trimmed).

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
